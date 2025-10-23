import "dart:io";
import "package:common/constants/file_system_source_path.dart";
import "package:common/access_types.dart";
import "package:common/util.dart";
import "package:common/executable.dart";
import "package:user_execution/user.dart";
import "package:user_execution/user_list_accessor.dart";
import "package:common/entity_attributes_stores.dart";

class ExecuteAs
{
  static String _getMountPointFromPrivilegeLevel(UserAccessPrivilege privilege)
  {
    return "/mnt/${privilege.name}_access";
  }

  static Future<Process> _executeResolvedExecutableAsPrivilegeLevel(UserAccessPrivilege privilege, CommandLine originalCommandLine, Map<String, String> environment) async
  {
    String workingDirectory = environment["CWD"] ?? "/";

    // if bare, run outside chroot
    if (privilege == UserAccessPrivilege.bare) {
      // re-resolve executable within file_system_source_path
      Executable executable = new Executable(rootPath: file_system_source_path, prefixPath: file_system_source_path, environment: environment);
      CommandLine commandLine = await executable.resolveExecutable(originalCommandLine);
      return Process.start(
        commandLine.command,
        commandLine.arguments,
        environment: {...environment, ...commandLine.environmentOverrides},
        workingDirectory: safeJoinPaths(file_system_source_path, workingDirectory)
      );
    }

    Executable executable = new Executable(rootPath: file_system_source_path, prefixPath: "", environment: environment);
    CommandLine commandLine = await executable.resolveExecutable(originalCommandLine);

    return Process.start(
      "/opt/monolith/core/bin/monolith_chroot",
      <String>[_getMountPointFromPrivilegeLevel(privilege), workingDirectory, commandLine.command, ...commandLine.arguments],
      environment: {...environment, ...commandLine.environmentOverrides},
      workingDirectory: "/" // when using monolith_chroot, this is the workingDirectory for chroot itself, NOT the process within.
    );
  }

  static Future<Process> executeAsPrivilegeLevel(UserAccessPrivilege privilege, CommandLine commandLine, Map<String, String> environment) async
  {
    print("execute as: ${commandLine.command}");

    Executable executable = new Executable(rootPath: file_system_source_path, prefixPath: "", environment: environment);

    bool isTrustedExecutable = await trustedExecutablesStore.get(await executable.resolveExecutablePath(commandLine.command), "0") == "1";
    if (isTrustedExecutable) {
      privilege = UserAccessPrivilege.bare; // trusted executables always run as bare, to perform trust requiring operations
    }

    print("execute as resolved command: ${privilege.name}: ${commandLine.command} -- ${commandLine.arguments}");

    return _executeResolvedExecutableAsPrivilegeLevel(privilege, commandLine, environment);
  }

  static Future<Process> executeAsUser(String authString, CommandLine commandLine, Map<String, String> environment) async
  {
    User user = UserListAccessor.getUserFromAuthString(authString);
    return executeAsPrivilegeLevel(user.privilege, commandLine, {...environment, "AUTH_STRING": authString});
  }

  // Returns file within the correct file system for access level
  static File getFileAsUser(String authString, String path)
  {
    User user = UserListAccessor.getUserFromAuthString(authString);
    return new File( safeJoinPaths(_getMountPointFromPrivilegeLevel(user.privilege), path) );
  }
}
