import "dart:convert";
import "dart:io";
import "package:meta/meta.dart";
import "package:common/http_proxy_server.dart";
import "package:common/constants/user_execution_service_port.dart";
import "constants.dart";

/** @fileoverview
 *     The first user land process that starts.
 *       terminal.aot runs itself with standard access privileges!
 *          terminal.apt relies on the UserExecutionService to execute the shell & read files (for loading frames)!
 *     Binds port 80 & responds to browser requests.
 *     Serves the super frame at "GET /" (which can be /frame/terminal/main.html or another frame like window_manager)
 *       -- the super frame is the top frame
 *
 *     Can serve any file into the browser that is accessible by the user's current privilege level.
 *       -- and so terminal.aot is how *all* frames are served to the browser.
 *
 *     Can execute any command, although primarily this will be shell.aot
 *
 *     Both reading of files & executing of commands goes through the User Execution Service.
 *
 */

class _TerminalService extends HttpProxyServer
{
  // Essentially a wrapper around User Execution Service

  @override
  @protected Future<HttpServer> bind()
  {
    // Bind to all network interfaces (0.0.0.0) on port
    print("terminal.aot binding port ${TERMINAL_PORT}...");
    return HttpServer.bind(InternetAddress.anyIPv4, TERMINAL_PORT);
  }

  String? _getAuthStringFromHeaders(HttpHeaders headers)
  {
    String? authString = headers.value(HttpHeaders.authorizationHeader);
    if (authString == null) {
      return null;
    }
    // Extract and decode credentials
    String credentials = authString.substring("Basic ".length);
    String decoded = utf8.decode(base64.decode(credentials));
    List<String> parts = decoded.split(":");
    String username = parts[0];
    String password = parts[1];
    if (parts.length != 2) {
      return null; // cannot parse
    }
    // return auth string formatted for ExecuteAs format
    return "${username}:${password}";
  }

  @override
  @protected (Map<String, String>, bool) getTargetHeaders(HttpRequest request)
  {
    String? authString = _getAuthStringFromHeaders(request.headers);
    if (authString == null) {
      return ({}, false);
    }
    else {
      // forward auth string plain
      return ({HttpHeaders.authorizationHeader: authString}, true);
    }
  }

  @override
  @protected Future<void> onComputeTargetHeadersFailed(HttpRequest request) async
  {
    request.response.statusCode = HttpStatus.unauthorized;
    request.response.headers.add(HttpHeaders.wwwAuthenticateHeader, "Basic realm=\"Secure Area\"");
    request.response.write("Authentication required");
  }

  @override
  @protected int getTargetPort()
  {
    return user_execution_service_port;
  }

  @override
  @protected String getTargetPath(String path)
  {
    if (path == "/") {
      return SUPER_FRAME_PATH + "/main.html"; // point to super frame as default
    }
    return path;
  }
}

void main()
{
  print("== Monolith: First Userland Process (Terminal) Running ==");
  _TerminalService service = new _TerminalService();
  service.start();
}
