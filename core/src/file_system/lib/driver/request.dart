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

/** Note: Return value *must not* contain newlines! Escape data first */
typedef Future<String> RequestCallback(Request request);

class RequestServer
{
  final Process process;

  final RequestCallback handleRequest;

  // Buffer for incoming binary data
  List<int> _buffer = [];
  // State for packet parser: -1 means waiting for length, >-1 means waiting for packet of that size
  int _expectedPacketSize = -1;

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

  Request _parseRequest(Uint8List packetData)
  {
    List<int> byteData = packetData.buffer
        .asByteData(packetData.offsetInBytes, packetData.lengthInBytes);
    int offset = 0;

    try {
      // Read type
      int typeLen = byteData.getUint32(offset, Endian.little);
      offset += 4;
      String type = utf8.decode(packetData.sublist(offset, offset + typeLen));
      offset += typeLen;

      // Read path
      int pathLen = byteData.getUint32(offset, Endian.little);
      offset += 4;
      String path = utf8.decode(packetData.sublist(offset, offset + pathLen));
      offset += pathLen;

      // Read params
      int xParam = byteData.getInt32(offset, Endian.little);
      offset += 4;
      int yParam = byteData.getInt32(offset, Endian.little);
      offset += 4;

      // Read stringParam
      int stringParamLen = byteData.getUint32(offset, Endian.little);
      offset += 4;
      String stringParam = utf8.decode(packetData.sublist(offset, offset + stringParamLen));

      return Request(
        type: type,
        path: path,
        xParam: xParam,
        yParam: yParam,
        stringParam: stringParam,
      );
    } catch (e) {
      print("RequestServer: Failed to parse binary packet: $e");
      rethrow;
    }
  }

  Future<void> _sendResponse(String data) async
  {
    // No more newline check, binary protocol can handle any data.
    List<int> responseBytes = utf8.encode(data);
    ByteData lengthData = ByteData(4);

    // Write length prefix (little-endian)
    lengthData.setUint32(0, responseBytes.length, Endian.little);

    // Send length prefix
    process.stdin.add(lengthData.buffer.asUint8List());
    // Send data
    process.stdin.add(responseBytes);
    
    // Flush to ensure C process receives it
    await process.stdin.flush();
  }

  Future<void> _handleStdout(List<int> data) async
  {
    _buffer.addAll(data);

    // Loop to process all complete packets in the buffer
    while (true) {
      // Waiting for packet length
      if (_expectedPacketSize == -1) {
        if (_buffer.length < 4) {
          // Not enough data for the length prefix. Wait for more.
          return;
        }
        // Read the 4-byte length prefix
        ByteData byteData = ByteData.view(Uint8List.fromList(_buffer).buffer);
        _expectedPacketSize = byteData.getUint32(0, Endian.little);
        _buffer = _buffer.sublist(4); // Consume the length prefix from buffer
      }

      // Waiting for packet body
      if (_buffer.length < _expectedPacketSize) {
        // Not enough data for the full packet. Wait for more.
        return;
      }

      // We have a full packet. Extract it.
      Uint8List packetData = Uint8List.fromList(_buffer.sublist(0, _expectedPacketSize));
      
      // Consume the packet from the buffer
      _buffer = _buffer.sublist(_expectedPacketSize);
      
      // Save size for error logging before resetting
      int processedPacketSize = _expectedPacketSize; 
      
      // Reset state for the next packet
      _expectedPacketSize = -1;

      // Process the Packet
      // This is async, but the C side will block until _sendResponse
      // is called, so we don't need a complex queue.
      try {
        Request request = _parseRequest(packetData);
        String response = await handleRequest(request);
        _sendResponse(response);
      } catch (e) {
        print("RequestServer: Error handling request (packet size: $processedPacketSize): $e");
        // Send an error response so the C side doesn't hang
        _sendResponse("ERROR: ${e.toString()}");
      }
      
      // Loop again to see if another full packet is already in the buffer
    }
  }
}