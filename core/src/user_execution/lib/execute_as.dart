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

  static Future<Process> _executeResolvedExecutableAsPrivilegeLevel(bool isTrustedExecutable, UserAccessPrivilege privilege, CommandLine originalCommandLine, Map<String, String> environment) async
  {
    String workingDirectory = environment["CWD"] ?? "/";

    // trusted commands run outside chroot, but are read from the user path's path for privilege level -- enforcing access to begin with to that command
    String mountPointForPrivilegeLevel = _getMountPointFromPrivilegeLevel(privilege);

    // if trusted executable, run outside chroot
    if (isTrustedExecutable) {
      // re-resolve executable to run outside of chroot (but within the mountpoint)
      Executable executable = new Executable(rootPath: mountPointForPrivilegeLevel, prefixPath: mountPointForPrivilegeLevel, environment: environment);
      CommandLine commandLine = await executable.resolveExecutable(originalCommandLine);
      return Process.start(
        commandLine.command,
        commandLine.arguments,
        environment: {...environment, ...commandLine.environmentOverrides},
        workingDirectory: safeJoinPaths(mountPointForPrivilegeLevel, workingDirectory)
      );
    }

    Executable executable = new Executable(rootPath: file_system_source_path, prefixPath: "", environment: environment);
    CommandLine commandLine = await executable.resolveExecutable(originalCommandLine);

    return Process.start(
      "/opt/monolith/core/bin/monolith_chroot",
      <String>[mountPointForPrivilegeLevel, workingDirectory, commandLine.command, ...commandLine.arguments],
      environment: {...environment, ...commandLine.environmentOverrides},
      workingDirectory: "/" // when using monolith_chroot, this is the workingDirectory for chroot itself, NOT the process within.
    );
  }

  static Future<Process> executeAsPrivilegeLevel(UserAccessPrivilege privilege, CommandLine commandLine, Map<String, String> environment) async
  {
    print("execute as: ${commandLine.command}");

    Executable executable = new Executable(rootPath: file_system_source_path, prefixPath: "", environment: environment);

    bool isTrustedExecutable = await trustedExecutablesStore.get(await executable.resolveExecutablePath(commandLine.command), "0") == "1";

    print("execute as resolved command: ${privilege.name}: ${commandLine.command} trusted = ${isTrustedExecutable} -- ${commandLine.arguments}");

    return _executeResolvedExecutableAsPrivilegeLevel(isTrustedExecutable, privilege, commandLine, environment);
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
