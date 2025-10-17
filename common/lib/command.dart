import "dart:io";
import "package:mutex/mutex.dart";

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

abstract class Command
{
  Command();

  ProcessInformation getProcessInformation(List<String> args);

  Future<Process> startProcess(List<String> args)
  {
    final ProcessInformation processInformation = getProcessInformation(args);
    return Process.start(
      processInformation.executable,
      processInformation.arguments,
      environment: processInformation.environment,
      workingDirectory: processInformation.workingDirectory,
      runInShell: processInformation.runInShell,
      includeParentEnvironment: processInformation.includeParentEnvironment,
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

  Future<void> parse(List<String> args) async
  {
    final Process process = await startProcess(args);

    _listenToStdOutputs(process);

    final int exitCode = await process.exitCode;
    if (exitCode != 0) {
      exit(exitCode);
    }
  }
}