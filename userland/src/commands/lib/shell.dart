import "dart:convert";
import "dart:io";
import "package:path/path.dart" as path_util;
import "package:glob/glob.dart";
import "package:glob/list_local_fs.dart";
import "package:common/executable.dart";
import "package:common/user_execution_client.dart";
import "command_parser.dart";

class _ShellResponse
{
  /** Sent as a header first */
  final Map<String, String> environment;

  /** Command for terminal */
  final String? termCommand;

  /** Output body stream */
  final Stream<String> output;

  _ShellResponse({
    required Map<String, String> this.environment,
    required String? this.termCommand,
    required Stream<String> this.output
  });
}

final CommandParser _commandParser = new CommandParser();

_ShellResponse _init()
{
  return new _ShellResponse(
    environment: Platform.environment,
    termCommand: null,
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
      termCommand: null,
      output: new Stream.value("No such directory: ${newDirectory}")
    );
  }
  return new _ShellResponse(
    environment: {
      ...Platform.environment,
      // replace the CWD in the current environment
      "CWD": newDirectory
    },
    termCommand: null,
    output: new Stream.empty()
  );
}

String _formatExecuteFileOutput(CommandLine commandLine, UserExecutionClientResponse response)
{
  // pass through command output
  StringBuffer sb = new StringBuffer();
  sb.write( response.stdout.toString() );
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

/** Redirects the command output to a file */
Stream<String> _redirectOutputToFileStream(CommandLine commandLine, String outputFile, UserExecutionClient client) async*
{
  // Redirect output to file
  String cwd = Platform.environment["CWD"]!;
  String filePath = path_util.isAbsolute(outputFile)
    ? outputFile
    : path_util.join(cwd, outputFile);
  
  IOSink? fileSink;
  try {
    File file = new File(filePath);
    fileSink = file.openWrite(mode: FileMode.write);
    
    await for (UserExecutionClientResponse response in client.execute(commandLine) )
    {
      // Write stdout to file
      String stdout = response.stdout.toString();
      if (stdout.isNotEmpty) {
        fileSink.write(stdout);
      }
      
      // Still show stderr in the terminal
      String stderr = response.stderr.toString();
      if (stderr.isNotEmpty) {
        yield "[${commandLine.command} error]\n";
        yield stderr.trimRight() + "\n";
      }
      
      if (response.exitCode != null && response.exitCode != 0) {
        yield "[${commandLine.command}: exited with code ${response.exitCode}]\n";
      }
    }
    
    await fileSink.flush();
  }
  finally {
    await fileSink?.close();
  }
}

Stream<String> _executeFileOutputStream(CommandLine commandLine, String? outputFile) async*
{
  try {
    UserExecutionClient client = new UserExecutionClient(Platform.environment);
    
    if (outputFile != null) {
      yield* _redirectOutputToFileStream(commandLine, outputFile, client);
    } else {
      // Normal output to terminal
      await for (UserExecutionClientResponse response in client.execute(commandLine) )
      {
        yield _formatExecuteFileOutput(commandLine, response);
      }
    }
  }
  catch (e) {
    yield e.toString();
  }
}

_ShellResponse _executeFile(ParsedCommand parsedCommand)
{
  return new _ShellResponse(
    environment: Platform.environment,
    termCommand: null,
    output: _executeFileOutputStream(parsedCommand.commandLine, parsedCommand.outputFile)
  );
}

Future<_ShellResponse> _execute(ParsedCommand parsedCommand) async
{
  switch (parsedCommand.commandLine.command)
  {
    case "clear":
      return new _ShellResponse(
        environment: Platform.environment,
        termCommand: "clear",
        output: new Stream.empty()
      );
    case "cd":
      return await _changeDirectory(parsedCommand.commandLine.arguments.first);
    default:
      return _executeFile(parsedCommand);
  }
}

bool _isCommandArgumentCompletion(String input)
{
  return input.contains(" ");
}

/** Completes any word after the first -- an argument to the command */
Stream<String> _completeCommandArgument(String input) async*
{
  // Strip out > operator if present for completion
  String cleanInput = input;
  if (input.contains(">")) {
    List<String> parts = input.split(">");
    cleanInput = parts.last.trim();
  }
  
  Glob glob = new Glob(cleanInput + "*");
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
    try {
      ParsedCommand parsedCommand = _commandParser.parse(input);
      String argumentInput = parsedCommand.commandLine.arguments.firstOrNull ?? "";
      return ( await _completeCommandArgument(argumentInput).toList() )..sort();
    } catch (e) {
      // If parsing fails, try to complete as argument
      return ( await _completeCommandArgument(input).toList() )..sort();
    }
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
      return _execute( _commandParser.parse(arguments[1]) );
    case "completion":
      return new _ShellResponse(
        environment: Platform.environment,
        termCommand: null,
        output: new Stream.value( json.encode( await _completion(arguments[1] ) ) ),
      );
    default:
      return new _ShellResponse(
        environment: Platform.environment,
        termCommand: null,
        output: new Stream.value("shell.aot: Bad action type."),
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
  if (response.termCommand != null) {
    stdout.writeln( json.encode({"term_command": response.termCommand}) );
    await stdout.flush();
  }
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
