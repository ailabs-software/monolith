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

Future<Set<String>> _completeNamesFromPaths(List<String> pathDirs, String toComplete) async
{
  Set<String> matches = {};

  for (String pathDir in pathDirs)
  {
    try {
      Directory dir = new Directory(pathDir);
      if (!await dir.exists()) {
        continue;
      }

      List<FileSystemEntity> files = await dir.list().toList();
      for (FileSystemEntity f in files) {
        final String name = path_util.basename(f.path);
        if (name.startsWith(toComplete) || toComplete.isEmpty) {
          matches.add(name);
        }
      }
    }
    catch (e) {
      // skip directories we cant read or that dont exist
      continue;
    }
  }

  return matches;
}

Future<_ShellResponse> _completion(String input) async
{
  // extract the last word from the input to complete
  List<String> parts = input.trim().split(new RegExp(r"\s+"));
  String toComplete = parts.isEmpty ? "" : parts.last;
  
  // determine if we are completing a command (first word) or a path (subsequent words)
  bool isCommandCompletion = parts.length <= 1;
  
  List<String> matches;
  
  if (isCommandCompletion) {
    // complete based on executables in PATH
    Executable executable = new Executable(
      rootPath: "/",
      prefixPath: ""
    );
    matches = await executable.getExecutablesInPathStartingWith(toComplete, Platform.environment);
  }
  else {
    // complete based on files and directories in CWD only
    final Set<String> matchSet = await _completeNamesFromPaths(
      [Platform.environment["CWD"]!],
      toComplete
    );
    matches = matchSet.toList()..sort();
  }
  
  return new _ShellResponse(
    output: json.encode(matches),
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