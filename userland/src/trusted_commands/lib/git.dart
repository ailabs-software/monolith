import "dart:io";

/** @fileoverview Wraps git. Runs in trusted, so outside chroot */

final String _GIT_SECRET_ACCESS = "put your token here";

enum _GitCommands
{
  branch("branch"),
  checkout("checkout"),
  switchCmd("switch"),
  push("push"),
  pull("pull"),
  diff("diff"),
  stats("stats"),
  add("add"),
  clone("clone");

  final String command;

  const _GitCommands(String this.command);
}

class _GitWrapper
{
  final _GitCommands gitCommand;

  _GitWrapper(_GitCommands this.gitCommand);

  Future<void> parse(List<String> args) async
  {
    final String token = await _readGitToken();

    await _runGitCommand(token, args);
  }

  Future<String> _readGitToken() async
  {
    return _GIT_SECRET_ACCESS;
    final File file = File("/opt/monolith/secrets/git.txt");
    if (! await file.exists()) {
      print("git.txt does not exist");
      exit(3);
    }
    final String token = await file.readAsString();
    return token.trim();
  }

  Future<void> _runGitCommand(String token, [List<String> args = const []]) async
  {
    const String gitUrlPrefix = "https://github.com/";
    const String gitSshPrefix = "git@github.com:";

    final List<String> transformedArgs = args.map((arg) {
      String? path;
      if (arg.startsWith(gitSshPrefix)) {
        path = arg.substring(gitSshPrefix.length);
      }
      if (arg.startsWith(gitUrlPrefix)) {
        path = arg.substring(gitUrlPrefix.length);
      }
      return path == null ? arg : "https://${token}@github.com/${path}";
    }).toList();

    final String userCwd = Platform.environment["CWD"] ?? "/";
    final String actualCwd = "/opt/monolith/userland$userCwd";

    final ProcessResult result = await Process.run(
      "/usr/bin/git",
      [gitCommand.command, ...transformedArgs],
      environment: {
        ...Platform.environment,
        "GIT_ASKPASS": "echo",
        "GIT_TERMINAL_PROMPT": "0",
        "GITHUB_TOKEN": token
      },
      workingDirectory: actualCwd,
    );

    print(result.stdout);
    if (result.exitCode != 0) {
      print("Error: ${result.stderr}");
    }
  }
}

void main(List<String> args) async
{
  final String? commandName = args.firstOrNull;
  if (commandName == null) {
    print("Not command name provided");
    exit(1);
  }
  _GitCommands? command = _GitCommands.values.where((_GitCommands c) => c.command == commandName).firstOrNull;
  if (command == null) {
    print("Command \"${commandName}\" not covered by this wrapper");
    exit(2);
  }
  await new _GitWrapper(command).parse(args.sublist(1));
}
