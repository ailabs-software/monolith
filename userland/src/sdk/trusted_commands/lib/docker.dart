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
  compose
}

class _DockerWrapper extends TrustedCommandWrapper<_DockerCommand>
{
  @override
  List<_DockerCommand> getEnumValues()
  {
    return _DockerCommand.values;
  }

  ProcessInformation getProcessInformation(_DockerCommand command, List<String> args)
  {
    return ProcessInformation(
      executable: "/usr/bin/docker",
      arguments: [getCommandNameFromEnum(command), ...args],
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
