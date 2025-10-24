import "dart:io";
import "dart:convert";
import "dart:typed_data";
import "package:file_system/driver/request.dart";
import "package:file_system/driver/file_system.dart";

class MonolithFSDriver
{
  final FileSystem _fileSystem;

  MonolithFSDriver(FileSystem this._fileSystem);

  // Sort of middleware code between our file system and Dart
  Future<Object> _handleRequestInternal(Request request) async
  {
    //print("file system op: ${request.type} ${request.path} ${request.xParam} ${request.yParam} ${request.dataParam}");
    switch (request.type)
    {
      case "entity_type":
        FileSystemEntityType entityType = await _fileSystem.entityType(request.path);
        int entityTypeIndex = const {
          FileSystemEntityType.notFound: 0, // these ints must be aligned with monolith_fs_driver.c
          FileSystemEntityType.file: 1,
          FileSystemEntityType.unixDomainSock: 2,
          FileSystemEntityType.directory: 3}[entityType]!;
        return entityTypeIndex.toString();
      case "exists":
        bool exists = await _fileSystem.exists(request.path);
        return exists ? "1" : "0";
      case "read_dir":
        List<String> list = await _fileSystem.readDir(request.path);
        return list.join("\n");
      case "file_size":
        int fileSize = await _fileSystem.fileSize(request.path);
        return fileSize.toString();
      case "read_file":
        int offset = request.xParam;
        int size = request.yParam;
        Uint8List data = await _fileSystem.readFile(request.path, offset, size);
        return data;
      case "file_writable":
        bool writable = await _fileSystem.fileWritable(request.path);
        return writable ? "1" : "0";
      case "write_file":
        int offset = request.xParam;
        Uint8List data = request.dataParam;
        bool success = await _fileSystem.writeFile(request.path, offset, data);
        return success ? "1" : "0";
      case "create_file":
        await _fileSystem.createFile(request.path);
        return "1"; // always successful
      case "mkdir":
        await _fileSystem.createDirectory(request.path);
        return "1"; // always successful
      case "unlink":
        bool success = await _fileSystem.unlink(request.path);
        return success ? "1" : "0";
      case "rmdir":
        bool success = await _fileSystem.rmdir(request.path);
        return success ? "1" : "0";
      case "rename":
        String newFileName = utf8.decode(request.dataParam);
        await _fileSystem.rename(request.path, newFileName);
        return "1"; // always successful
      case "truncate":
        await _fileSystem.truncate(request.path, request.xParam);
        return "1"; // always successful
      default:
        throw new Exception("Bad file system operation: ${request.type}");
    }
  }

  Future<Object> _handleRequest(Request request) async
  {
    try {
      return await _handleRequestInternal(request);
    }
    catch (e, s) {
      print("file system op failed: ${request.type} ${request.path} ${request.xParam} ${request.yParam} ${request.dataParam.length}");
      print("error was:");
      print(e);
      print(s);
      rethrow;
    }
  }

  Future<void> mount(String mountPoint) async
  {
    print("Starting monolith_fs_driver.c process...");

    // Create process with specified arguments
    final process = await Process.start(
      "/opt/monolith/core/bin/monolith_fs_driver",
      [mountPoint],
    );

    print("monolith_fs_driver.c started with PID: ${process.pid}");

    // Set up request handler
    new RequestServer(
      process: process,
      handleRequest: _handleRequest
    );

    // Also listen on stderr for errors
    process.stderr.listen(
      (List<int> data) {
        String output = utf8.decode(data);
        print("STDERR Output: $output");
      },
      onError: (error) {
        print("STDERR Error: $error");
      },
      onDone: () {
        print("STDERR stream closed");
      },
    );

    // Wait until monolith_fs_driver.c ends
    int exitCode = await process.exitCode;
    print("monolith_fs_driver: exited with code: ${exitCode}");
  }
}
