import "dart:io";
import "package:common/constants/file_system_source_path.dart";
import "package:common/util.dart";
import "package:trusted_commands/trusted_command_wrapper.dart";

/** @fileoverview Wraps docker build. Runs in trusted, so outside chroot */

enum _DockerCommand
{
  build,
  image,
  ps,
  run,
  stop,
  exec,
  compose,
  version
}

class _DockerWrapper extends TrustedCommandWrapper<_DockerCommand>
{
  @override
  List<_DockerCommand> getEnumValues()
  {
    return _DockerCommand.values;
  }

  List<String> _getFinalArgs(_DockerCommand command, List<String> args)
  {
    if (command == _DockerCommand.image &&
        args.firstOrNull == "save") {
      for (int i = 0; i < args.length; i++)
      {
        if (args[i] == "-o") {
          args[i + 1] = safeJoinPaths(file_system_source_path, args[i + 1]);
        }
      }
    }
    return [getCommandNameFromEnum(command), ...args];
  }

  ProcessInformation getProcessInformation(_DockerCommand command, List<String> args)
  {
    return ProcessInformation(
      executable: "/usr/bin/docker",
      arguments: _getFinalArgs(command, args),
      environment: {
        ...Platform.environment,
        "TMPDIR": safeJoinPaths(file_system_source_path, "/tmp"),
      },
      workingDirectory: Directory.current.path
    );
  }
}

void main(List<String> args) async
{
  await new _DockerWrapper().main(args);
}
