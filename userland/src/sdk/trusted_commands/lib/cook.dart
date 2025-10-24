import "dart:io";
import "package:mutex/mutex.dart";
import "package:common/constants/file_system_source_path.dart";
import "package:common/util.dart";
import "package:trusted_commands/trusted_command_wrapper.dart";

/** @fileoverview Wraps cook. Runs in trusted, so outside chroot */

enum _CookCommand
{
  assets,
  compile,
  dart,
  generate
}

class _CookWrapper extends TrustedCommandWrapper<_CookCommand>
{
  @override
  List<_CookCommand> getEnumValues()
  {
    return _CookCommand.values;
  }

  ProcessInformation getProcessInformation(_CookCommand command, List<String> args)
  {
    String cwd = Platform.environment["CWD"]!;
    return ProcessInformation(
      executable: "/opt/monolith/core/bin/monolith_chroot",
      arguments: ["/mnt/root_access", cwd, "/sdk/ailabs/bin/cook_internal", command.name, ...args],
      environment: {
        ...Platform.environment,
        // path to "dart"
        // dart compile executes "chmod +x", which resides in /usr/bin/
        "PATH": "/dart_sdk/bin/:/usr/bin/"
      },
      workingDirectory: Directory.current.path
    );
  }
}

void main(List<String> args) async
{
  await new _CookWrapper().main(args);
}
