import "dart:io";
import "package:common/util.dart";
import "package:trusted_commands/trusted_command_wrapper.dart";

/** @fileoverview Wraps docker build. Runs in trusted, so outside chroot */

enum _TarCommand
{
  cvf
}

class _TarWrapper extends TrustedCommandWrapper<_TarCommand>
{
  @override
  List<_TarCommand> getEnumValues()
  {
    return _TarCommand.values;
  }

  ProcessInformation getProcessInformation(_TarCommand command, List<String> args)
  {
    print("DEBUG workingDirectory = ${Directory.current.path}");

    return ProcessInformation(
      executable: "/bin/tar",
      arguments: ["-cvf", ...translateAnyAbsolutePathArgs(args)],
      environment: Platform.environment,
      workingDirectory: Directory.current.path
    );
  }
}

void main(List<String> args) async
{
  if (args.firstOrNull != "-cvf") {
    throw new Exception("Tar command not convered by trusted command wrapper.");
  }
  await new _TarWrapper().main(["cvf", ...args.sublist(1)]);
}
