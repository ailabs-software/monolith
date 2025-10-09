import "dart:io";
import "package:common/access_types.dart";
import "package:common/executable.dart";
import "package:user_execution/execute_as.dart";

/** @fileoverview Used only to start terminal.aot in userland with standard access level
 *
 * *Never* appears in user land (not that it could do anything)!
 *
 *  Usage:
 *  execute_as level command [...arguments]
 *
 * */

Future<void> main(List<String> arguments) async
{
  UserAccessPrivilege privilege = UserAccessPrivilege.values.byName(arguments[0]);
  String command = arguments[1];
  Process process;

  try {
    process = await ExecuteAs.executeAsPrivilegeLevel(privilege, new CommandLine(command: command, arguments: arguments.sublist(2) ), const {});
  }
  catch (e, s) {
    print("execute_as_command failed!");
    print(e);
    print(s);
    rethrow;
  }
  
  // Pass through stdout transparently
  process.stdout.listen( (List<int> data) {
    stdout.add(data);
  });
  
  // Pass through stderr transparently
  process.stderr.listen( (List<int> data) {
    stderr.add(data);
  });
  
  // Wait for the process to complete and get its exit code
  int exitCode = await process.exitCode;
  
  // Exit with the same code as the process
  exit(exitCode);
}
