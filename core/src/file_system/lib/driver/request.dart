import "dart:convert";
import "dart:io";
import "package:common/util.dart";

/** @fileoverview Manages the Dart side of the request.c protocol
 *
 *  Architecture:
 *  The child process sends requests to parent process via stdout,
 *  the parent process responds via stdin.
 *  The loop is blocking in the child process (request.c), commands/responses stay in order.
 *
 * */

class Request
{
  final String type;
  final String path;
  final int xParam;
  final int yParam;
  final String stringParam;

  Request({
    required String this.type,
    required String this.path,
    // parameters (may be zero or empty if not used)
    required int this.xParam,
    required int this.yParam,
    required String this.stringParam // must appear last so : separator can appear with data
  });
}

const String _SANITY_CHECK_PREFIX = "req-";
const int _EXPECTED_REQUEST_PARTS_LEN = 5;

/** Note: Return value *must not* contain newlines! Escape data first */
typedef Future<String> RequestCallback(Request request);

class RequestServer
{
  final Process process;

  final RequestCallback handleRequest;

  final StringBuffer _stdoutBuffer = new StringBuffer();

  RequestServer({
    required Process this.process,
    required RequestCallback this.handleRequest
  })
  {
    process.stdout.listen(
      _handleStdout,
      onError: (error) {
        print("RequestServer: STDOUT Error: $error");
      },
      onDone: () {
        print("RequestServer: STDOUT stream closed");
      }
    );
  }

  Request _parseRequest(String request)
  {
    if (!request.startsWith(_SANITY_CHECK_PREFIX)) {
      if (request.length > 96) {
        request = request.substring(0, 96) + "...";
      }
      throw new Exception("RequestServer: Bad request prefix from request.c: ${request}");
    }
    request = request.substring(_SANITY_CHECK_PREFIX.length);
    List<String> parts = splitN(request, ":", _EXPECTED_REQUEST_PARTS_LEN);
    if (parts.length != _EXPECTED_REQUEST_PARTS_LEN) {
      throw new Exception("Bad request parts length from request.c: ${parts.length}, ${request}");
    }
    return new Request(
      type: parts[0],
      path: parts[1],
      xParam: int.parse(parts[2]),
      yParam: int.parse(parts[3]),
      stringParam: parts[4]
    );
  }

  Future<void> _sendResponse(String data) async
  {
    if ( data.contains("\n") ) {
      throw new Exception("Response cannot contain newlines as this breaks request.c protocol");
    }
    process.stdin.writeln(data); // Note: Data *must not* contain newlines! Escape data first
  }

  Future<void> _handleStdout(List<int> data) async
  {
    String output = utf8.decode(data);
    bool isFinalChunk = output.endsWith("\n");
    if (isFinalChunk) {
      // remove \n line ending from request
      output = output.substring(0, output.length - 1);
    }
    _stdoutBuffer.write(output);
    Request request = _parseRequest( _stdoutBuffer.toString() );
    if (isFinalChunk) {
      _stdoutBuffer.clear();
    }
    String response = await handleRequest(request);
    _sendResponse(response);
  }
}