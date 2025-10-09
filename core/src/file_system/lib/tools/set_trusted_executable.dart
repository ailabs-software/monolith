import "dart:io";
import "package:path/path.dart" as path_util;
import "package:glob/glob.dart";
import "package:glob/list_local_fs.dart";
import "package:common/access_types.dart";
import "package:common/entity_attributes_stores.dart";

/** @fileoverview Tool used to set trusted executable bit of files from init
 *  Usage:
 *  set_trusted_executable entity_path 1 or 0 */

Future<void> main(List<String> arguments) async
{
  String entityPath = arguments[0];
  bool trusted = arguments[1] == "1";
  String trustedString = trusted ? "1" : "0";
  print("set_trusted_executable: Updating ${entityPath} entity to trusted executable = ${trustedString}.");
  await trustedExecutablesStore.set(entityPath, trustedString);
}
