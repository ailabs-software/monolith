import "dart:io";
import "package:common/command.dart";
import "package:mutex/mutex.dart";

/** @fileoverview Wraps git. Runs in trusted, so outside chroot */

final String _GIT_SECRET_ACCESS = "git token here";

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

class _GitWrapper extends Command
{
  final _GitCommands gitCommand;

  _GitWrapper(_GitCommands this.gitCommand);

  String _readGitToken()
  {
    return _GIT_SECRET_ACCESS;
  }

  List<String> _transformArgsToTokenUrl(List<String> args)
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
      return path == null ? arg : "https://${_readGitToken()}@github.com/${path}";
    }).toList();
    return transformedArgs;
  }

  List<String> _getFinalArguments(List<String> args)
  {
    final List<String> transformedArgs = _transformArgsToTokenUrl(args);

    // Force immediate progress for operations that emit progress (clone/pull/push)
    final bool isProgressy = gitCommand == _GitCommands.clone || gitCommand == _GitCommands.pull || gitCommand == _GitCommands.push;
    return [
      if (isProgressy) ...["-c", "progress.delay=0"],
      gitCommand.command,
      if (isProgressy && !transformedArgs.contains("--progress")) "--progress",
      ...transformedArgs,
    ];
  }

  ProcessInformation getProcessInformation(List<String> args)
  {
    final String userCwd = Platform.environment["CWD"] ?? "/";
    final String actualCwd = "/opt/monolith/userland$userCwd";

    return ProcessInformation(
      executable: "/usr/bin/git",
      arguments: _getFinalArguments(args),
      environment: {
        ...Platform.environment,
        "GIT_ASKPASS": "echo",
        "GIT_TERMINAL_PROMPT": "0",
        "GITHUB_TOKEN": _readGitToken(),
        // Flush progress immediately
        "GIT_FLUSH": "1",
      },
      workingDirectory: actualCwd,
    );
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
