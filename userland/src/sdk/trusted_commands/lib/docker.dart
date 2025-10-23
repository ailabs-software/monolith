import "dart:io";
import "package:trusted_commands/trusted_command_wrapper.dart";

/** @fileoverview Wraps docker build. Runs in trusted, so outside chroot */

enum _DockerCommand
{
  build,
  load,
  save,
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
      environment: Platform.environment,
      workingDirectory: Directory.current.path
    );
  }
}

void main(List<String> args) async
{
  await new _DockerWrapper().main(args);
}
