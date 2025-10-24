import "dart:io";
import "package:path/path.dart" as path_util;
import "package:common/util.dart";
import "package:common/access_types.dart";
import "package:common/entity_attributes_stores.dart";

/** @fileoverview Tool used to set access level of files from init */

// TODO is largely duplicate with set_access.dart in core

Future<void> _handleSetAccess(List<String> entityPaths, String accessLevelArgument) async
{
  EntityAccessLevel accessLevel = EntityAccessLevel.values.byName(accessLevelArgument);
  stdout.write("Updating ${entityPaths.length} entities to ${accessLevel.name} access... ");
  await stdout.flush();
  DateTime started = new DateTime.now();
  for (String entityPath in entityPaths)
  {
    await entityAccessLevelStore.set(entityPath, accessLevel.name);
  }
  stdout.writeln("done after ${new DateTime.now().difference(started).inMilliseconds}ms");
  await stdout.flush();
}

Future<void> _handleShowAccess(List<String> entityPaths) async
{
  String defaultValue = DEFAULT_ENTITY_ACCESS_LEVEL.name;
  for (String entityPath in entityPaths)
  {
    String accessLevel = await entityAccessLevelStore.get(entityPath, defaultValue);
    bool isDefault = accessLevel == defaultValue;
    if (!isDefault) {
      print("${entityPath}: ${accessLevel}");
    }
  }
}

void _printHelpAndExit()
{
  print("Bad arguments to access");
  print("Usage: access show|set path [value]");
  exit(1);
}

Future<void> main(List<String> arguments) async
{
  if (arguments.length < 2) {
    _printHelpAndExit();
  }
  String command = arguments[0];
  List<String> entityPaths = await getEntityPaths(command);
  switch (command)
  {
    case "set":
      String accessLevelArgument = arguments[2];
      return _handleSetAccess(entityPaths, accessLevelArgument);
    case "show":
      return _handleShowAccess(entityPaths);
    default:
      _printHelpAndExit();
  }
}
