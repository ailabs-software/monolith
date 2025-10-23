import "dart:io";
import "package:mutex/mutex.dart";
import "package:common/constants/file_system_source_path.dart";
import "package:common/util.dart";
import "package:trusted_commands/trusted_command_wrapper.dart";

/** @fileoverview Wraps dart. Runs in trusted, so outside chroot */

enum _DartCommand
{
  compile,
  pub
}

class _DartWrapper extends TrustedCommandWrapper<_DartCommand>
{
  @override
  List<_DartCommand> getEnumValues()
  {
    return _DartCommand.values;
  }

  Iterable<String> _translateOutputArgs(List<String> args) sync*
  {
    for (String arg in args)
    {
      bool isAbsolutePath = arg.startsWith("/");
      if (isAbsolutePath) {
        // ensure path is relative
        yield safeJoinPaths(file_system_source_path, arg);
      }
      else {
        yield arg;
      }
    }
  }

  List<String> _getTranslatedArguments(_DartCommand command, List<String> args)
  {
    switch (command)
    {
      case _DartCommand.compile:
        return ["compile", ..._translateOutputArgs(args)];
      case _DartCommand.pub:
        switch (args[0])
        {
          case "get":
            return ["pub", "get"];
          default:
            throw new Exception("Bad sub command ${args[0]}.");
        }
    }
  }

  ProcessInformation getProcessInformation(_DartCommand command, List<String> args)
  {
    return ProcessInformation(
      executable: "/opt/monolith/core/dart_sdk/bin/dart",
      arguments: _getTranslatedArguments(command, args),
      environment: {
        ...Platform.environment,
        // dart pub executes "chmod", which resides in /bin/
        "PATH": "/bin/"
      },
      workingDirectory: Directory.current.path
    );
  }
}

void main(List<String> args) async
{
  await new _DartWrapper().main(args);
}
