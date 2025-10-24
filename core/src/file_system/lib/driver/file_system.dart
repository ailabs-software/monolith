import "dart:io";
import "dart:convert";
import "package:meta/meta.dart";
import "package:path/path.dart" as path_util;
import "package:common/util.dart";

/** @fileoverview File system */

// all file systems using fs driver extend FileSystem
abstract class FileSystem
{
  Future<FileSystemEntityType> entityType(String path);

  @nonVirtual
  Future<bool> exists(String path) async
  {
    FileSystemEntityType result = await entityType(path);
    return result != FileSystemEntityType.notFound;
  }

  Future< List<String> > readDir(String path);

  Future<int> fileSize(String path);

  Future<String> readFile(String path, int offset, int size);

  Future<bool> fileWritable(String path);

  @protected Future<void> writeFileInternal(String path, int offset, String data);

  @nonVirtual
  Future<bool> writeFile(String path, int offset, String data) async
  {
    if ( await fileWritable(path) ) {
      await writeFileInternal(path, offset, data);
      return true;
    }
    return false; // refuse to write
  }

  Future<void> createFile(String path);

  Future<void> createDirectory(String path);

  Future<bool> unlink(String path);

  Future<bool> rmdir(String path);

  Future<void> rename(String path, String newPath);

  Future<void> truncate(String path, int size);
}

// Base class a file system representation based on a source directory
class MirrorFileSystem extends FileSystem
{
  final String sourcePath;

  MirrorFileSystem({required String this.sourcePath})
  {
    Directory sourceDirectory = new Directory(sourcePath);
    if ( sourcePath.endsWith("/") ||
         sourcePath.contains("..") ||
         sourcePath.contains("//") ) {
      throw new Exception("Bad source path.");
    }
    if ( !sourceDirectory.existsSync() ) {
      throw new Exception("monolith_fs_driver: Source path does not exist!");
    }
  }

  String _translatePath(String path)
  {
    path = getCanonicalPath(path);
    if (path == "/") {
      return sourcePath;
    }
    String translatedPath = safeJoinPaths(sourcePath, path);
    return translatedPath;
  }

  @override
  Future<FileSystemEntityType> entityType(String path) async
  {
    String translatedPath = _translatePath(path);
    FileSystemEntityType entityType = await FileSystemEntity.type(translatedPath);

    switch (entityType)
    {
      case FileSystemEntityType.file:
        return FileSystemEntityType.file;
      case FileSystemEntityType.unixDomainSock:
        return FileSystemEntityType.unixDomainSock;
      case FileSystemEntityType.directory:
        return FileSystemEntityType.directory;
      case FileSystemEntityType.notFound:
        return FileSystemEntityType.notFound;
      default:
        // Unsupported entity types are handled as not found
        return FileSystemEntityType.notFound;
    }
  }

  @override
  Future< List<String> > readDir(String path) async
  {
    String translatedPath = _translatePath(path);
    Directory directory = new Directory(translatedPath);
    if ( !await directory.exists() ) {
      return [];
    }
    return await directory.list().map(
      // provide the base name of each file
      (FileSystemEntity e) => path_util.basename(e.path)
    ).toList();
  }

  @override
  Future<int> fileSize(String path) async
  {
    String translatedPath = _translatePath(path);
    File file = new File(translatedPath);
    return file.length();
  }

  @override
  Future<String> readFile(String path, int offset, int size) async
  {
    String translatedPath = _translatePath(path);
    File file = new File(translatedPath);
    RandomAccessFile raf = await file.open();
    await raf.setPosition(offset);
    List<int> bytes = await raf.read(size);
    await raf.close();
    return base64.encode(bytes);
  }

  @override
  Future<bool> fileWritable(String path) async
  {
    return true; // default implementation is always writable
  }

  @override
  @protected Future<void> writeFileInternal(String path, int offset, String data) async
  {
    String translatedPath = _translatePath(path);
    File file = new File(translatedPath);
    final raf = await file.open(mode: FileMode.append);
    await raf.setPosition(offset);
    List<int> decodedData = base64.decode(data);
    await raf.writeFrom(decodedData);
    await raf.close();
  }

  @override
  Future<void> createFile(String path)
  {
    String translatedPath = _translatePath(path);
    File file = new File(translatedPath);
    return file.create();
  }

  @override
  Future<void> createDirectory(String path)
  {
    String translatedPath = _translatePath(path);
    Directory directory = new Directory(translatedPath);
    return directory.create(recursive: false);
  }

  @override
  Future<bool> unlink(String path) async
  {
    String translatedPath = _translatePath(path);
    try {
      await new File(translatedPath).delete();
    }
    catch (e) {
      print("unlink failed: ${e}");
      return false;
    }
    return true; // success
  }

  @override
  Future<bool> rmdir(String path) async
  {
    String translatedPath = _translatePath(path);
    try {
      await new Directory(translatedPath).delete(recursive: true);
    }
    catch (e) {
      print("rmdir failed: ${e}");
      return false;
    }
    return true; // success
  }

  @override
  Future<void> rename(String path, String newPath) async
  {
    path = _translatePath(path);
    newPath = _translatePath(newPath);

    // Check what type of entity we're dealing with
    final entityType = await FileSystemEntity.type(path);

    switch (entityType)
    {
      case FileSystemEntityType.file:
        await new File(path).rename(newPath);
        break;
      case FileSystemEntityType.directory:
        await new Directory(path).rename(newPath);
        break;
      case FileSystemEntityType.link:
        await new Link(path).rename(newPath);
        break;
      case FileSystemEntityType.notFound:
        throw new FileSystemException("Entity not found", path);
      default:
        throw new FileSystemException("Unsupported entity type: $entityType", path);
    }
  }

  @override
  Future<void> truncate(String path, int size) async
  {
    String translatedPath = _translatePath(path);
    File file = new File(translatedPath);
    RandomAccessFile raf = await file.open(mode: FileMode.append);
    await raf.truncate(size);
    await raf.close();
  }
}
