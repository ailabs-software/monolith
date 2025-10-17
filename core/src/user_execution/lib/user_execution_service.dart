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

class _StdOutputHandler
{
  final Mutex flushMutex;

  final HttpRequest request;

  final String type;

  _StdOutputHandler(Mutex this.flushMutex, HttpRequest this.request, String this.type);

  Future<void> handleOutput(List<int> bytes) async
  {
    final String data = utf8.decode(bytes);
    request.response.writeln( json.encode({type: data}) );
    await flushMutex.protect(request.response.flush);
  }
}

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

  void _setChunkStreamingHeaders(HttpRequest request)
  {
    // Configure for true streaming (disable output buffering and discourage proxy buffering)
    request.response.bufferOutput = false;
    request.response.headers.contentType = new ContentType("application", "x-ndjson", charset: "utf-8");
    request.response.headers.set("Cache-Control", "no-cache, no-transform");
    request.response.headers.set("Connection", "keep-alive");
    request.response.headers.set("X-Accel-Buffering", "no");
    request.response.headers.chunkedTransferEncoding = true; // explicit chunked
    request.response.headers.set("Content-Encoding", "identity");
  }

  Future<void> _registerStdListeners(HttpRequest request, Process process) async
  {
    final Mutex flushMutex = new Mutex();

    // Stream stdout chunks as they arrive (use raw bytes, flush per chunk)
    Future<void> stdoutDone = process.stdout.listen(
      new _StdOutputHandler(flushMutex, request, "stdout").handleOutput
    ).asFuture();
    
    // Stream stderr chunks as they arrive (use raw bytes, flush per chunk)
    Future<void> stderrDone = process.stderr.listen(
      new _StdOutputHandler(flushMutex, request, "stderr").handleOutput
    ).asFuture();
    
    // Wait for both streams and process to complete
    await Future.wait([stdoutDone, stderrDone]);
  }

  Future<void> _respondWithExitCode(HttpRequest request, Process process) async
  {
    final int exitCode = await process.exitCode;
    request.response.writeln( json.encode({"exit_code": exitCode}) );
    await request.response.flush();
  }

  Future<void> _handleSignal(HttpRequest request, String authString) async
  {
    // body format: [signalName, pidString]
    final List<dynamic> body = (await request.readBodyAsJson()) as List;
    final String signalName = (body.isNotEmpty ? body[0] : "SIGINT").toString();
    final int pid = int.parse(body.length > 1 ? body[1].toString() : "0");

    // map name to ProcessSignal
    ProcessSignal signal = switch (signalName.toUpperCase()) {
      "SIGTERM" => ProcessSignal.sigterm,
      "SIGKILL" => ProcessSignal.sigkill,
      "SIGINT" => ProcessSignal.sigint,
      _ => throw new Exception("Unknown signal name: $signalName")
    };

    bool ok = false;
    if (pid > 0) {
      ok = Process.killPid(pid, signal);
    }

    request.response.writeln( json.encode({"ok": ok}) );
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

    _setChunkStreamingHeaders(request);

    // Initial JSON padding to defeat proxy/browser buffering while staying valid NDJSON
    // This line is valid JSON but ignored by clients (no stdout/stderr/exit_code)
    final String _padding = json.encode({"_": "".padRight(8192)});
    request.response.writeln(_padding);
    await request.response.flush();

    // Send PID early so UIs can capture it
    request.response.writeln( json.encode({"pid": process.pid}) );
    await request.response.flush();

    await _registerStdListeners(request, process);

    await _respondWithExitCode(request, process);
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
        if (path == "signal") {
          await _handleSignal(request, authString);
        } else {
          // Execute file (must be executable) as the current user.
          await _handleExecuteCommandAsUser(request, path, authString);
        }
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