import "dart:convert";
import "dart:io";
import "package:mutex/mutex.dart";
import "package:path/path.dart" as path_util;
import "package:common/constants/file_system_source_path.dart";
import "package:common/util.dart";

class EntityAttributesStore
{
  final Mutex _mutex = new Mutex();

  final String storeName;

  EntityAttributesStore({
    required String this.storeName
  });

  String _getStoreFileDirName(String entityPath)
  {
    String fullEntityPath = safeJoinPaths(file_system_source_path, entityPath);
    return path_util.join(path_util.dirname(fullEntityPath), ".monolith");
  }

  // Finds the correct directory for the monolith file
  File _getStoreFile(String entityPath)
  {
    String dirName = _getStoreFileDirName(entityPath);
    String storePath = path_util.join(dirName, "${storeName}.json");
    return new File(storePath);
  }

  Future< Map<String, String> > _getMapFromFile(File storeFile) async
  {
    if ( await storeFile.exists() ) {
      Map<String, String> map = ( json.decode( await storeFile.readAsString() ) as Map ).cast<String, String>();
      return map;
    }
    else {
      return {}; // return new empty map
    }
  }

  Future<String> get(String entityPath, String defaultValue) async
  {
    // canonicalise the path
    entityPath = getCanonicalPath(entityPath);
    // if root, always return defaultValue -- no persistent store for this path
    if (entityPath == "/") {
      return defaultValue;
    }
    // now look up from store file
    File storeFile = _getStoreFile(entityPath);

    return _mutex.protect<String>( () async {
      Map<String, String> map = await _getMapFromFile(storeFile);

      String baseName = path_util.basename(entityPath);
      return map[baseName] ?? defaultValue;
    });
  }

  Future<void> set(String entityPath, String value) async
  {
    // canonicalise the path
    entityPath = getCanonicalPath(entityPath);

    // if root, do nothing -- no persistent store for this path
    if (entityPath == "/") {
      return;
    }

    // avoid entities within a .monolith directory
    if ( path_util.split(entityPath).contains(".monolith") ) {
      throw new Exception("Cannot set an entity attribute for an entity which is .monolith or within.");
    }
    // avoid entities within hidden directories
    if ( pathIsHidden( path_util.dirname(entityPath) ) ) {
      throw new Exception("Cannot set entity attribute for an entity within a hidden directory: \"${entityPath}\".");
    }

    // now look up the store file
    File storeFile = _getStoreFile(entityPath);
    return _mutex.protect( () async {
      String baseName = path_util.basename(entityPath);
      Map<String, String> map = await _getMapFromFile(storeFile);
      // create .monolith directory if needed.
      Directory storeFileDirectory = new Directory(_getStoreFileDirName(entityPath));
      if ( !await storeFileDirectory.exists() ) {
        await storeFileDirectory.create();
      }
      // set value
      map[baseName] = value;
      // save store file
      await storeFile.writeAsString( json.encode(map) );
    });
  }

  Future<void> remove(String entityPath) async
  {
    // canonicalise the path
    entityPath = getCanonicalPath(entityPath);

    // if root, do nothing -- no persistent store for this path
    if (entityPath == "/") {
      return;
    }
    // now look up the store file
    File storeFile = _getStoreFile(entityPath);

    if ( !await storeFile.exists() ) {
      return; // nothing to do
    }

    return _mutex.protect( () async {
      String baseName = path_util.basename(entityPath);
      Map<String, String> map = await _getMapFromFile(storeFile);
      // set value
      map.remove(baseName);
      // save store file
      await storeFile.writeAsString( json.encode(map) );
    });
  }
}

final EntityAttributesStore entityAccessLevelStore =
  new EntityAttributesStore(
    storeName: "access_map"
  );

final EntityAttributesStore trustedExecutablesStore =
  new EntityAttributesStore(
    storeName: "trusted_executables_map"
  );