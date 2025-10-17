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
  /** Sent as a header first */
  final Map<String, String> environment;

  /** Output body stream */
  final Stream<String> output;

  _ShellResponse({
    required Map<String, String> this.environment,
    required Stream<String> this.output
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

_ShellResponse _init()
{
  return new _ShellResponse(
    environment: Platform.environment,
    output: new Stream.value("\$ "),
  );
}

// changes the directory by returning a modified environment
Future<_ShellResponse> _changeDirectory(String directory) async
{
  String current = Platform.environment["CWD"]!;
  String newDirectory = path_util.normalize( path_util.join(current, directory) );
  if ( !await new Directory(newDirectory).exists() ) {
    return new _ShellResponse(
      environment: Platform.environment,
      output: new Stream.value("No such directory: ${newDirectory}")
    );
  }
  return new _ShellResponse(
    environment: {
      ...Platform.environment,
      // replace the CWD in the current environment
      "CWD": newDirectory
    },
    output: new Stream.empty()
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
    if (response.exitCode != 0) {
      sb.writeln("[${commandLine.command}: exited with code ${response.exitCode}]");
    }
  }
  return sb.toString();
}

Stream<String> _executeFileOutputStream(CommandLine commandLine) async*
{
  try {
    UserExecutionClient client = new UserExecutionClient(Platform.environment);
    await for (UserExecutionClientResponse response in client.execute(commandLine) )
    {
      yield _formatExecuteFileOutput(commandLine, response);
    }
  }
  catch (e) {
    yield e.toString();
  }
}

_ShellResponse _executeFile(CommandLine commandLine)
{
  return new _ShellResponse(
    environment: Platform.environment,
    output: _executeFileOutputStream(commandLine)
  );
}

Future<_ShellResponse> _execute(CommandLine commandLine) async
{
  switch (commandLine.command)
  {
    case "cd":
      return await _changeDirectory(commandLine.arguments.first);
    default:
      return _executeFile(commandLine);
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

Future<_ShellResponse> _run(List<String> arguments) async
{
  String action = arguments[0];
  switch (action)
  {
    case "init":
      return _init();
    case "execute":
      return _execute( _parseCommandString(arguments[1]) );
    case "completion":
      return new _ShellResponse(
        output: new Stream.value( json.encode( await _completion(arguments[1] ) ) ),
        environment: Platform.environment
      );
    default:
      return new _ShellResponse(
        output: new Stream.value("shell.aot: Bad action type."),
        environment: Platform.environment
      );
  }
}

Future<void> main(List<String> arguments) async
{
  _ShellResponse response = await _run(arguments);
  // output the header (environment)
  // returns the environment with mutations we performed to it
  stdout.writeln( json.encode({"environment": response.environment}) );
  await stdout.flush();
  // output the body (chunked)
  await for (String outputChunk in response.output)
  {
    stdout.writeln(
      json.encode({
        // return the output of the shell execution
        "output": outputChunk
      })
    );
    await stdout.flush();
  }
}
