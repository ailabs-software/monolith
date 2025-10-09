import "dart:async";
import "package:common/access_types.dart";
import "package:common/constants/file_system_source_path.dart";
import "package:file_system/driver/file_system.dart";
import "package:file_system/driver/monolith_fs_driver.dart";
import "package:file_system/monolith_file_system/monolith_file_system.dart";

Future<void> _startFileSystem(String mountPoint, UserAccessPrivilege privilege) async
{
  FileSystem fileSystem = new MonolithFileSystem(userAccessPrivilege: privilege);
  MonolithFSDriver driver = new MonolithFSDriver(fileSystem);
  await driver.mount(mountPoint);
}

Future<void> main(List<String> arguments) async
{
  String mountPoint = arguments[0]; // where will be mounted (the target)
  UserAccessPrivilege privilege = UserAccessPrivilege.values.byName(arguments[1]); // privilege level

  print("== Monolith File System ==");
  print("source path: ${file_system_source_path}");
  print("mount point: ${mountPoint}");
  print("user access privilege: ${privilege.name} (#${privilege.index})");

  await runZonedGuarded(
    () => _startFileSystem(mountPoint, privilege),
    (error, stackTrace) => print("Uncaught file system exception: ${error}, ${stackTrace}"),
  );
}
