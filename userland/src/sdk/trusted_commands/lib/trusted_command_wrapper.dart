import "dart:io";
import "package:mutex/mutex.dart";
import "package:common/constants/file_system_source_path.dart";
import "package:common/util.dart";

class ProcessInformation
{
  String executable;
  List<String> arguments;
  String? workingDirectory;
  Map<String, String>? environment;
  bool runInShell;
  bool includeParentEnvironment;

  ProcessInformation({
    required String this.executable,
    required List<String> this.arguments,
    String? this.workingDirectory,
    Map<String, String>? this.environment,
    bool this.runInShell = false,
    bool this.includeParentEnvironment = true,
  });
}

abstract class TrustedCommandWrapper<T extends Enum>
{
  List<T> getEnumValues();

  String getCommandNameFromEnum(T command)
  {
    return command.name.replaceFirst("\$", "");
  }

  Iterable<String> translateAnyAbsolutePathArgs(List<String> args) sync*
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

  ProcessInformation getProcessInformation(T command, List<String> args);

  Future<Process> startProcess(T command, List<String> args)
  {
    final ProcessInformation processInformation = getProcessInformation(command, args);
    return Process.start(
      processInformation.executable,
      processInformation.arguments,
      environment: processInformation.environment,
      workingDirectory: processInformation.workingDirectory,
      runInShell: processInformation.runInShell,
      includeParentEnvironment: processInformation.includeParentEnvironment
    );
  }

  void _listenToStdOutputs(Process process)
  {
    Mutex flushMutex = new Mutex();

    // Stream stdout
    process.stdout.listen( (List<int> data) {
      stdout.add(data);
      flushMutex.protect(stdout.flush);
    });

    // Stream stderr
    process.stderr.listen( (List<int> data) {
      stderr.add(data);
      flushMutex.protect(stderr.flush);
    });
  }

  Future<void> run(T command, List<String> args) async
  {
    final Process process = await startProcess(command, args);

    _listenToStdOutputs(process);

    final int exitCode = await process.exitCode;
    if (exitCode != 0) {
      exit(exitCode);
    }
  }

  Future<void> main(List<String> args) async
  {
    final String? commandName = args.firstOrNull;
    if (commandName == null) {
      print("No command name provided");
      exit(1);
    }
    T? command = getEnumValues().where( (T c) => getCommandNameFromEnum(c) == commandName ).firstOrNull;
    if (command == null) {
      print("Command \"${commandName}\" not covered by this wrapper");
      exit(2);
    }
    await run(command, args.sublist(1));
  }
}