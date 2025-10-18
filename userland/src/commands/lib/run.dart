import "dart:io";
import "package:common/executable.dart";
import "package:common/user_execution_client.dart";

/** @fileoverview Command to execute an executable through the UserExecutionService, which is useful
 *                for running trusted binaries */

Future<void> main(List<String> arguments) async
{
  UserExecutionClient client = new UserExecutionClient(Platform.environment);

  CommandLine commandLine = new CommandLine(
    command: arguments.first,
    arguments: arguments.sublist(1)
  );
  
  await for (UserExecutionClientResponse response in client.execute(commandLine) )
  {
    stdout.writeln(response.stdout);
    await stdout.flush();
    stderr.writeln(response.stderr);
    await stderr.flush();
    if (response.exitCode != null) {
      exit(response.exitCode!);
    }
  }
}
