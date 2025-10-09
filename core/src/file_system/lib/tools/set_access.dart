import "dart:io";
import "package:path/path.dart" as path_util;
import "package:common/util.dart";
import "package:common/access_types.dart";
import "package:common/entity_attributes_stores.dart";

/** @fileoverview Tool used to set access level of files from init */

Future<void> main(List<String> arguments) async
{
  String entityArgument = arguments[0];
  List<String> entityPaths = await getEntityPaths(entityArgument);
  EntityAccessLevel accessLevel = EntityAccessLevel.values.byName(arguments[1]);
  stdout.writeln("set_access(${entityArgument}): Matching entities...");
  await stdout.flush();
  stdout.write("Updating ${entityPaths.length} entities to ${accessLevel.name} access... ");
  await stdout.flush();
  stdout.writeln("done");
  await stdout.flush();
  for (String entityPath in entityPaths)
  {
    await entityAccessLevelStore.set(entityPath, accessLevel.name);
  }
}
