import "dart:convert";
import "dart:io";
import "package:mime/mime.dart";
import "package:common/http_request_extension.dart";
import "package:common/executable.dart";
import "package:common/constants/user_execution_service_port.dart";
import "package:mutex/mutex.dart";
import "package:user_execution/execute_as.dart";
import "package:user_execution/user_list_accessor.dart";

/** @fileoverview Executes commands under the privilege level of the current user
 *
 *    The main impetus for this existing is that terminal.aot runs inside a standard access level,
 *    and therefore cannot itself execute a command (or shell.aot) with an elevated privilege level --
 *      such as warranted when the current user has root access,
 *      or the current user is executing a trusted executable.
 * */

class _UserExecutionService
{
  Future<void> _handleReadFileAsUser(HttpRequest request, String path, String authString) async
  {
    File file = ExecuteAs.getFileAsUser(authString, path);
    
    // Check if file exists
    if (!await file.exists()) {
      request.response.statusCode = HttpStatus.notFound;
      return;
    }
    
    // Use file extension to determine MIME type
    String? mimeType = lookupMimeType(request.uri.path);
    
    // Set appropriate content type
    if (mimeType != null) {
      request.response.headers.contentType = ContentType.parse(mimeType);
    }
    else {
      // Default to application/octet-stream for unknown types
      request.response.headers.contentType = ContentType.binary;
    }
    
    // Read and send file content
    List<int> fileBytes = await file.readAsBytes();
    request.response.add(fileBytes);
  }

  Future<void> _handleExecuteCommandAsUser(HttpRequest request, String path, String authString) async
  {
    // Get arguments from request body
    List<String> arguments = <String>[
      ...( ( await request.readBodyAsJson() ) as List ).cast<String>()
    ];
    // Get environment from query string
    Map<String, String> environment = request.uri.queryParameters;
    
    // Execute command as this user
    Process process = await ExecuteAs.executeAsUser(authString, new CommandLine(command: path, arguments: arguments), environment);

    // Set up chunked transfer encoding for streaming output
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set("Cache-Control", "no-cache");
    request.response.headers.set("Transfer-Encoding", "chunked");

    Mutex flushMutex = new Mutex();

    // Stream stdout chunks as they arrive
    Future<void> stdoutDone = process.stdout.transform(utf8.decoder).forEach((String data) {
      String chunk = jsonEncode({"stdout": data}) + "\n";
      request.response.write(chunk);
      flushMutex.protect(request.response.flush);
    });
    
    // Stream stderr chunks as they arrive
    Future<void> stderrDone = process.stderr.transform(utf8.decoder).forEach((String data) {
      String chunk = jsonEncode({"stderr": data}) + "\n";
      request.response.write(chunk);
      flushMutex.protect(request.response.flush);
    });
    
    // Wait for both streams and process to complete
    await Future.wait([stdoutDone, stderrDone]);
    final int exitCode = await process.exitCode;
    request.response.write( jsonEncode({"exit_code": exitCode}) + "\n" );
  }

  Future<void> _routeRequest(HttpRequest request, String authString) async
  {
    String path = request.uri.path;
    if ( !path.startsWith("/~") ) {
      throw new Exception("User execution service requires all paths to start with /~ to disambiguate relative paths.");
    }
    path = path.substring(2);

    switch (request.method)
    {
      case "GET":
        // Get a file as the current user (used by terminal.aot for loading frames)
        await _handleReadFileAsUser(request, path, authString);
        break;
      case "POST":
        // Execute file (must be executable) as the current user.
        await _handleExecuteCommandAsUser(request, path, authString);
        break;
      default:
        // Method not supported
        request.response.statusCode = HttpStatus.methodNotAllowed;
        break;
    }
  }

  Future<bool> _preverifyAuthString(String? authString) async
  {
    if (authString == null) {
      return false;
    }
    return UserListAccessor.getHasUserFromAuthString(authString);
  }

  Future<void> handleRequest(HttpRequest request) async
  {
    try {
      // get auth string passed through as HTTP auth header.
      String? authString = request.headers.value(HttpHeaders.authorizationHeader);
      if ( await _preverifyAuthString(authString) ) {
        await _routeRequest(request, authString!);
      }
      else {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.writeln("Invalid or missing required header ${HttpHeaders.authorizationHeader} for user auth string.");
      }
      await request.response.close(); // close automatically calls flush
    }
    catch (e, s) {
      print("User execution service unhandled exception:");
      print(request.uri);
      print(e);
      print(s);
      request.response.statusCode = HttpStatus.badRequest;
      request.response.writeln("User execution service unhandled exception:");
      request.response.writeln(e);
      await request.response.close(); // close automatically calls flush
    }
  }
}

Future<void> main(List<String> arguments) async
{
  _UserExecutionService service = new _UserExecutionService();

  // Bind a ServerSocket on special port for user execution service
  HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, user_execution_service_port);

  server.listen(service.handleRequest);
}