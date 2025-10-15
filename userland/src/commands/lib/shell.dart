import "dart:convert";
import "dart:io";
import "package:path/path.dart" as path_util;
import "package:common/monolith_exception.dart";
import "package:common/executable.dart";
import "package:common/user_execution_client.dart";

class _ShellResponse
{
  final String output;

  final Map<String, String> environment;

  _ShellResponse({
    required String this.output,
    required Map<String, String> this.environment
  });
}

class _CommandState
{
  late final String trimmedInput;

  late final bool isTrailing;

  late final List<String> tokens;

  late final String arg;

  late final String directoryPart;

  late final String namePrefix;

  late final String baseDir;

  _CommandState(String input)
  {
    isTrailing = input.endsWith(" ");
    trimmedInput = input.trimRight();
    tokens = trimmedInput.isEmpty ? [] : trimmedInput.split(RegExp(r"\s+"));

    arg = isTrailing ? "" : tokens.last;
    final int slashIndex = arg.lastIndexOf("/");
    directoryPart = slashIndex >= 0 ? arg.substring(0, slashIndex + 1) : ""; // keep trailing '/'
    namePrefix = slashIndex >= 0 ? arg.substring(slashIndex + 1) : arg;

    baseDir = (directoryPart.isNotEmpty && directoryPart.startsWith("/"))
      ? directoryPart
      : path_util.normalize(path_util.join(Platform.environment["CWD"]!, directoryPart.isEmpty ? "." : directoryPart));
  }
}

CommandLine _parseCommandString(String commandString)
{
  // TODO handle shell escaping
  List<String> parts = commandString.split(" ");
  return new CommandLine(
    command: parts.first,
    arguments: parts.sublist(1)
  );
}

Future<_ShellResponse> _init() async
{
  return new _ShellResponse(
    output: "\$ ",
    environment: Platform.environment
  );
}

Future<_ShellResponse> _changeDirectory(String directory) async
{
  String current = Platform.environment["CWD"]!;
  String newDirectory = path_util.normalize( path_util.join(current, directory) );
  if ( !await new Directory(newDirectory).exists() ) {
    return new _ShellResponse(
      output: "No such directory: ${newDirectory}",
      environment: Platform.environment
    );
  }
  return new _ShellResponse(
    output: "",
    environment: {
      ...Platform.environment,
      // replace the CWD in the current environment
      "CWD": newDirectory
    }
  );
}

Future<_ShellResponse> _executeFile(CommandLine commandLine) async
{
  try {
    // execute command line
    String? authString = Platform.environment["AUTH_STRING"];
    if (authString == null) {
      throw new Exception("shell.aot: Missing AUTH_STRING.");
    }
    UserExecutionClient client = new UserExecutionClient(authString: authString);
    ProcessResult result = await client.execute(commandLine, Platform.environment);
    // pass through command output
    StringBuffer sb = new StringBuffer();
    sb.writeln(result.stdout.toString().trimRight());
    String stderr = result.stderr.toString();
    if (stderr.isNotEmpty) {
      sb.writeln("[${commandLine.command} error]");
      sb.writeln(stderr.trimRight());
    }
    if (result.exitCode != 0) {
      sb.writeln("[${commandLine.command}: exited with code ${result.exitCode}]");
    }
    return new _ShellResponse(
      output: sb.toString(),
      environment: Platform.environment
    );
  }
  catch (e) {
    return new _ShellResponse(
      output: e.toString(),
      environment: Platform.environment
    );
  }
}

Future<_ShellResponse> _execute(String commandString)
{
  // parse command line
  CommandLine commandLine = _parseCommandString(commandString);
  switch (commandLine.command)
  {
    case "cd":
      return _changeDirectory(commandLine.arguments.first);
    default:
      return _executeFile(commandLine);
  }
}

Future<Set<String>> _getPossibleNextArguments(String input, _CommandState commandState) async
{
  final String namePrefix = commandState.namePrefix;
  final String baseDir = commandState.baseDir;

  try {
    final Directory dir = new Directory(baseDir);
    if (!await dir.exists()) {
      return {};
    }
    final List<FileSystemEntity> files = await dir.list().toList();
    // add all file names that start with prefix
    return files.map((FileSystemEntity e) => path_util.basename(e.path))
        .where((String n) => namePrefix.isEmpty || n.startsWith(namePrefix))
        .map<String>((String n) => commandState.directoryPart + n)
        .toSet();
  } on FileSystemException catch (_) {
    // ignore directories we cant read
    return {};
  }
}

Future<_ShellResponse> _completeSingleTokenCommand(_CommandState state) async
{
  final String prefix = state.trimmedInput;
  final Executable exe = new Executable(rootPath: "/", prefixPath: "");
  final List<String> cmds = await exe.getExecutablesInPathStartingWith(prefix, Platform.environment);
  return new _ShellResponse(
    output: json.encode(cmds),
    environment: Platform.environment
  );
}

bool _isCommandASingleToken(_CommandState state)
{
  return state.tokens.length <= 1 && !state.isTrailing;
}

Future<_ShellResponse> _completion(String input) async
{
  final _CommandState commandState = new _CommandState(input);
  // command completion when there is only one token and no trailing space
  if (_isCommandASingleToken(commandState)) {
    return _completeSingleTokenCommand(commandState);
  }

  return new _ShellResponse(
    output: json.encode( (await _getPossibleNextArguments(input, commandState)).toList()..sort() ),
    environment: Platform.environment
  );
}

Future<_ShellResponse> _run(List<String> arguments) async
{
  String action = arguments[0];
  switch (action)
  {
    case "init":
      return await _init();
    case "execute":
      return await _execute(arguments[1]);
    case "completion":
      return await _completion(arguments.last);
    default:
      return new _ShellResponse(
        output: "shell.aot: Bad action type.",
        environment: Platform.environment
      );
  }
}

Future<void> main(List<String> arguments) async
{
  _ShellResponse response = await _run(arguments);
  stdout.write(
    json.encode({
      // return the output of the shell execution
      "output": response.output,
      // return the environment with mutations we performed to it
      "environment": response.environment
    })
  );
  await stdout.flush();
}