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

Future<void> _executeStreaming(CommandLine commandLine) async
{
  try {
    String? authString = Platform.environment["AUTH_STRING"];
    if (authString == null) {
      throw new Exception("shell.aot: Missing AUTH_STRING.");
    }
    
    UserExecutionClient client = new UserExecutionClient(authString: authString);
    await client.executeStreaming(
      commandLine,
      Platform.environment,
      onStdout: (String output) {
        stdout.writeln(json.encode({"output": output, "environment": Platform.environment}));
      },
      onStderr: (String output) {
        stdout.writeln(json.encode({"output": output, "environment": Platform.environment}));
      }
    );
  } catch (e) {
    stdout.write(json.encode({"output": e.toString(), "environment": Platform.environment}));
    await stdout.flush();
  }
}

Future<void> _execute(String commandString) async
{
  // parse command line
  CommandLine commandLine = _parseCommandString(commandString);
  switch (commandLine.command)
  {
    case "cd":
      _ShellResponse response = await _changeDirectory(commandLine.arguments.first);
      stdout.write(json.encode({"output": response.output, "environment": response.environment}));
      await stdout.flush();
      break;
    default:
      await _executeStreaming(commandLine);
  }
}

Future<void> main(List<String> arguments) async
{
  String action = arguments[0];
  switch (action)
  {
    case "init":
      _ShellResponse response = await _init();
      stdout.write(json.encode({"output": response.output, "environment": response.environment}));
      await stdout.flush();
      break;
    case "execute":
      await _execute(arguments[1]);
      break;
    default:
      stdout.write(json.encode({"output": "shell.aot: Bad action type.", "environment": Platform.environment}));
      await stdout.flush();
  }
}