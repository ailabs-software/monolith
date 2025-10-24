import "dart:io";
import "package:common/util.dart";
import "package:trusted_commands/trusted_command_wrapper.dart";

/** @fileoverview Wraps tar compile. Runs in trusted, so outside chroot
 *
 *  TODO break out into tar_compress specialised command, we don't want to wrap all of tar.
 *
 * */

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
    String cwd = Platform.environment["CWD"]!;
    return ProcessInformation(
      executable: "/opt/monolith/core/bin/monolith_chroot",
      arguments: ["/mnt/root_access", cwd, "/usr/bin/tar", "-cvf", ...args],
      environment: Platform.environment,
      workingDirectory: Directory.current.path
    );
  }
}

void main(List<String> args) async
{
  if (args.firstOrNull != "-cvf") {
    throw new Exception("Tar command not covered by trusted command wrapper.");
  }
  await new _TarWrapper().main([_TarCommand.cvf.name, ...args.sublist(1)]);
}
