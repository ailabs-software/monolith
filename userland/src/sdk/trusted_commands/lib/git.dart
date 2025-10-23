import "dart:io";
import "package:mutex/mutex.dart";
import "package:common/constants/file_system_source_path.dart";
import "package:common/util.dart";
import "package:trusted_commands/trusted_command_wrapper.dart";

/** @fileoverview Wraps git. Runs in trusted, so outside chroot */

const String _GIT_SECRET_ACCESS = "git token here";

enum _GitCommand
{
  branch,
  checkout,
  $switch,
  push,
  pull,
  diff,
  stats,
  add,
  clone
}

class _GitWrapper extends TrustedCommandWrapper<_GitCommand>
{
  @override
  List<_GitCommand> getEnumValues()
  {
    return _GitCommand.values;
  }

  String _readGitToken()
  {
    return _GIT_SECRET_ACCESS;
  }

  List<String> _transformArgsToTokenUrl(List<String> args)
  {
    const String gitUrlPrefix = "https://github.com/";
    const String gitSshPrefix = "git@github.com:";

    return args.map( (String arg) {
      String? path;
      if (arg.startsWith(gitSshPrefix)) {
        path = arg.substring(gitSshPrefix.length);
      }
      if (arg.startsWith(gitUrlPrefix)) {
        path = arg.substring(gitUrlPrefix.length);
      }
      return path == null ? arg : "https://${_readGitToken()}@github.com/${path}";
    }).toList();
  }

  List<String> _getGitCloneArguments(List<String> args)
  {
    if (args.length != 2) {
      throw new Exception("git clone: arguments must be exactly: git clone [remote] [destination]");
    }
    String remote = args[0];
    String destination = args[1];
    return [
      remote,
      safeJoinPaths(file_system_source_path, destination)
    ];
  }

  List<String> _getFinalArguments(_GitCommand command, List<String> args)
  {
    final List<String> transformedArgs = _transformArgsToTokenUrl(args);

    // Force immediate progress for operations that emit progress (clone/pull/push)
    final bool isProgressy = command == _GitCommand.clone || command == _GitCommand.pull || command == _GitCommand.push;
    return [
      if (isProgressy) ...["-c", "progress.delay=0"],
      getCommandNameFromEnum(command),
      if (isProgressy && !transformedArgs.contains("--progress")) "--progress",
      if (command == _GitCommand.clone) ..._getGitCloneArguments(transformedArgs)
      else ...transformedArgs
    ];
  }

  String _quoteForShell(String arg) {
    // Replaces every single-quote (') with ('\'')
    // e.g., "my'arg" becomes "'my\'arg'"
    return "'${arg.replaceAll("'", "'\\''")}'";
  }

  ProcessInformation getProcessInformation(_GitCommand command, List<String> args)
  {
    const String gitExecutable = "/usr/bin/git";
    final List<String> gitArguments = _getFinalArguments(command, args);

    final String fullGitCommand = [
      gitExecutable,
      ...gitArguments
    ].map(_quoteForShell).join(' ');

    return ProcessInformation(
      executable: "/usr/bin/script",
      arguments: [
        "-q",         // Quiet mode (no "Script started" messages)
        "-e",         // Return the exit code of the command
        "-c",         // The command string to run
        fullGitCommand, // Our fully quoted `git ...` command
        "/dev/null"   // Where to write the log file (we discard it)
      ],
      environment: {
        ...Platform.environment,
        "GIT_ASKPASS": "echo",
        "GIT_TERMINAL_PROMPT": "0",
        "GITHUB_TOKEN": _readGitToken(),
        // Force Git to output progress as if writing to a terminal
        "GIT_FLUSH": "1",
        "TERM": "dumb",
      },
      workingDirectory: Directory.current.path
    );
  }
}

void main(List<String> args) async
{
  await new _GitWrapper().main(args);
}
