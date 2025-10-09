import "dart:io";
import "package:meta/meta.dart";
import "package:file_system/driver/file_system.dart";
import "package:common/constants/file_system_source_path.dart";
import "package:common/access_types.dart";
import "package:common/util.dart";
import "package:common/entity_attributes_stores.dart";

const String _INVISIBLE_STRING = "";
const int _INVISIBLE_STRING_LEN = _INVISIBLE_STRING.length;
const String _OPAQUE_STRING = "<opaque>";
const int _OPAQUE_STRING_LEN = _OPAQUE_STRING.length;

class MonolithFileSystem extends MirrorFileSystem
{
  final UserAccessPrivilege userAccessPrivilege;

  MonolithFileSystem({
    required UserAccessPrivilege this.userAccessPrivilege
  }):
    super(sourcePath: file_system_source_path);

  Future<EntityAccessLevel> _getEntityAccessLevel(String path) async
  {
    EntityAccessLevel fileAccessLevel =
      EntityAccessLevel.values.byName( await entityAccessLevelStore.get(path, DEFAULT_ENTITY_ACCESS_LEVEL.name) );
    // resolve entity access for this file using the current user access privilege
    return userAccessPrivilege.accessLevelRule(fileAccessLevel);
  }

  @override
  Future<FileSystemEntityType> entityType(String path) async
  {
    EntityAccessLevel accessLevel = await _getEntityAccessLevel(path);
    if (accessLevel.index <= EntityAccessLevel.invisible.index) {
      return FileSystemEntityType.notFound;
    }
    return await super.entityType(path);
  }

  Stream<String> _getVisibleEntities(String dirPath, Iterable<String> entities) async*
  {
    for (String entity in entities)
    {
      String fullEntityPath = safeJoinPaths(dirPath, entity);
      EntityAccessLevel accessLevel = await _getEntityAccessLevel(fullEntityPath);
      if ( accessLevel.index > EntityAccessLevel.invisible.index ) { // slow but good enough for now
        yield entity;
      }
    }
  }

  @override
  Future< List<String> > readDir(String path) async
  {
    Iterable<String> entities = await super.readDir(path);
    entities = entities.where( (String e) => e != ".monolith" );
    return await _getVisibleEntities(path, entities).toList();
  }

  @override
  Future<int> fileSize(String path) async
  {
    EntityAccessLevel accessLevel = await _getEntityAccessLevel(path);
    if (accessLevel.index <= EntityAccessLevel.invisible.index) {
      return _INVISIBLE_STRING_LEN;
    }
    if (accessLevel.index == EntityAccessLevel.opaque.index) {
      return _OPAQUE_STRING_LEN;
    }
    return await super.fileSize(path);
  }

  @override
  Future<String> readFile(String path, int offset, int size) async
  {
    EntityAccessLevel accessLevel = await _getEntityAccessLevel(path);
    if (accessLevel.index <= EntityAccessLevel.invisible.index) {
      return _INVISIBLE_STRING;
    }
    if (accessLevel.index == EntityAccessLevel.opaque.index) {
      return _OPAQUE_STRING;
    }
    return await super.readFile(path, offset, size);
  }

  @override
  Future<bool> fileWritable(String path) async
  {
    EntityAccessLevel accessLevel = await _getEntityAccessLevel(path);
    return accessLevel.index >= EntityAccessLevel.writable.index;
  }

  Future<void> _onFileMutated(String path) async
  {
    if (userAccessPrivilege == UserAccessPrivilege.standard) {
      // disable trusted executable on mutated by standard user
      await trustedExecutablesStore.remove(path);
    }
  }

  @override
  Future<void> createFile(String path) async
  {
    await _onFileMutated(path);
    // Set access automatically on create of file to be readable/writeable from current access level.
    if (userAccessPrivilege == UserAccessPrivilege.standard) {
      await entityAccessLevelStore.set(path, STANDARD_ACCESS_CREATED_FILE_INITIAL_ACCESS_LEVEL.name);
    }
    await super.createFile(path);
  }

  @override
  @protected Future<void> writeFileInternal(String path, int offset, String data) async
  {
    await _onFileMutated(path);
    await super.writeFileInternal(path, offset, data);
  }

  @override
  Future<bool> unlink(String path) async
  {
    await _onFileMutated(path);
    return super.unlink(path);
  }

  @override
  Future<bool> rmdir(String path) async
  {
    await _onFileMutated(path);
    return super.rmdir(path);
  }

  @override
  Future<void> rename(String path, newPath) async
  {
    await _onFileMutated(path);
    await super.rename(path, newPath);
  }

  @override
  Future<void> truncate(String path, int size) async
  {
    await _onFileMutated(path);
    await super.truncate(path, size);
  }
}
