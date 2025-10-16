import "dart:convert";
import "dart:io";
import "package:path/path.dart" as path_util;
import "package:glob/glob.dart";
import "package:glob/list_local_fs.dart";
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

CommandLine _parseCommandString(String commandString)
{
  // TODO handle shell escaping quotes
  List<String> parts = commandString.split(" ");
  return new CommandLine(
    command: parts.first,
    arguments: parts.sublist(1).where( (String part) => part.isNotEmpty ).toList()
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

String _formatExecuteFileOutput(CommandLine commandLine, UserExecutionClientResponse response)
{
  // pass through command output
  StringBuffer sb = new StringBuffer();
  sb.writeln(response.stdout.toString().trimRight());
  String stderr = response.stderr.toString();
  if (stderr.isNotEmpty) {
    sb.writeln("[${commandLine.command} error]");
    sb.writeln(stderr.trimRight());
  }
  if (response.exitCode != null) {
    sb.writeln("[${commandLine.command}: exited with code ${response.exitCode}]");
  }
  return sb.toString();
}

Stream<_ShellResponse> _executeFile(CommandLine commandLine) async*
{
  try {
    String? authString = Platform.environment["AUTH_STRING"];
    if (authString == null) {
      throw new Exception("shell.aot: Missing AUTH_STRING.");
    }

    UserExecutionClient client = new UserExecutionClient(authString: authString);
    await for (UserExecutionClientResponse response in client.execute(commandLine, Platform.environment) )
    {
      yield new _ShellResponse(
        output: _formatExecuteFileOutput(commandLine, response),
        environment: Platform.environment
      );
    }
  }
  catch (e) {
    stdout.write(json.encode({"output": e.toString(), "environment": Platform.environment}));
  }
}

Stream<_ShellResponse> _execute(CommandLine commandLine) async*
{
  switch (commandLine.command)
  {
    case "cd":
      _ShellResponse response = await _changeDirectory(commandLine.arguments.first);
      yield response;
      break;
    default:
      yield* _executeFile(commandLine);
  }
}

bool _isCommandArgumentCompletion(String input)
{
  return input.contains(" ");
}

/** Completes any word after the first -- an argument to the command */
Stream<String> _completeCommandArgument(String input) async*
{
  Glob glob = new Glob(input + "*");
  await for (FileSystemEntity entity in glob.list())
  {
    String normalised = path_util.normalize(entity.path);
    if ( entity is Directory ) {
      normalised = "${normalised}/";
    }
    yield normalised;
  }
}

/** Completes the first word in a command line -- the name of the command itself */
Future< List<String> > _completeCommand(String input)
{
  Executable executable = new Executable(rootPath: "/", prefixPath: "", environment: Platform.environment);
  return executable.getExecutablesInPathStartingWith(input).toList();
}

Future< List<String> > _completion(String input) async
{
  // command completion when there is only one token and no trailing space
  if ( _isCommandArgumentCompletion(input) ) {
    CommandLine commandLine = _parseCommandString(input);
    String argumentInput = commandLine.arguments.firstOrNull ?? "";
    return ( await _completeCommandArgument(argumentInput).toList() )..sort();
  }
  else {
    return _completeCommand(input);
  }
}

Future< Stream<_ShellResponse> > _run(List<String> arguments) async
{
  String action = arguments[0];
  switch (action)
  {
    case "init":
      return new Stream.value( await _init() );
    case "execute":
      return _execute( _parseCommandString(arguments[1]) );
    case "completion":
      return new Stream.value(
        new _ShellResponse(
          output: json.encode( await _completion(arguments[1] ) ),
          environment: Platform.environment
        )
      );
    default:
      return new Stream.value(
        new _ShellResponse(
          output: "shell.aot: Bad action type.",
          environment: Platform.environment
        )
      );
  }
}

Future<void> main(List<String> arguments) async
{
  Stream<_ShellResponse> responseStream = await _run(arguments);
  await for (_ShellResponse response in responseStream)
  {
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
}
