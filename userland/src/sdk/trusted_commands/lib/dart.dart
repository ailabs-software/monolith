import "dart:io";
import "package:mutex/mutex.dart";
import "package:common/constants/file_system_source_path.dart";
import "package:common/util.dart";
import "package:trusted_commands/trusted_command_wrapper.dart";

/** @fileoverview Wraps dart. Runs in trusted, so outside chroot */

enum _DartCommand
{
  compile
}

class _DartWrapper extends TrustedCommandWrapper<_DartCommand>
{
  @override
  List<_DartCommand> getEnumValues()
  {
    return _DartCommand.values;
  }

  ProcessInformation getProcessInformation(_DartCommand command, List<String> args)
  {
    return ProcessInformation(
      executable: "/opt/monolith/core/dart_sdk/bin/dart",
      arguments: [getCommandNameFromEnum(command), ...args],
      environment: Platform.environment,
      workingDirectory: Directory.current.path
    );
  }
}

void main(List<String> args) async
{
  await new _DartWrapper().main(args);
}
