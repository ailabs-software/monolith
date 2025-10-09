import "dart:convert";
import "dart:io";
import "package:path/path.dart" as path_util;
import "package:common/monolith_exception.dart";
import "package:common/executable.dart";
import "package:common/user_execution_client.dart";

CommandLine _parseCommandString(String commandString)
{
  // TODO handle shell escaping
  List<String> parts = commandString.split(" ");
  return new CommandLine(
    command: parts.first,
    arguments: parts.sublist(1)
  );
}

Future<void> _writeResponse(String output, Map<String, String> environment) async
{
  stdout.write(
    json.encode({
      "output": output,
      "environment": environment
    })
  );
  await stdout.flush();
}

Future<void> _writeShellPrompt() async
{
  _writeResponse("\$ ", Platform.environment);
}

Future<void> _changeDirectory(String directory) async
{
  String current = Platform.environment["CWD"]!;
  String newDirectory = path_util.join(current, directory);
  if ( !await new Directory(newDirectory).exists() ) {
    await _writeResponse("No such directory: ${newDirectory}", Platform.environment);
    return;
  }
  Map<String, String> environment = {
    ...Platform.environment,
    "CWD": newDirectory
  };
  await _writeResponse("", environment);
}

Future<void> _executeFile(CommandLine commandLine) async
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
    _writeResponse(sb.toString(), Platform.environment);
  }
  catch (e) {
    _writeResponse(e.toString(), Platform.environment);
  }
}

Future<void> _execute(String commandString) async
{
  // parse command line
  CommandLine commandLine = _parseCommandString(commandString);
  switch (commandLine.command)
  {
    case "cd":
      _changeDirectory(commandLine.arguments.first);
      break;
    default:
      _executeFile(commandLine);
      break;
  }
}

Future<void> main(List<String> arguments) async
{
  String action = arguments[0];
  switch (action)
  {
    case "init":
      await _writeShellPrompt();
      break;
    case "execute":
      await _execute(arguments[1]);
      break;
    default:
      await _writeResponse("shell.aot: Bad action type.", Platform.environment);
      break;
  }
}
