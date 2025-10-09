import "dart:io";
import "dart:async";
import "dart:typed_data";
import "package:meta/meta.dart";

abstract class HttpProxyServer
{
  late HttpServer _server;

  final Map<HttpRequest, HttpClientRequest> _activeRequests = {};

  final Map<HttpRequest, HttpClientResponse> _activeResponses = {};

  @protected Future<HttpServer> bind();

  @protected HttpClient createHttpClient()
  {
    return new HttpClient();
  }

  @protected (Map<String, String>, bool) getTargetHeaders(HttpRequest request)
  {
    return (const {}, true);
  }

  @protected Future<void> onComputeTargetHeadersFailed(HttpRequest request) async
  {
    // Default implementation is no-op
  }

  @protected String getTargetHost()
  {
    return InternetAddress.loopbackIPv4.host;
  }

  @protected int getTargetPort();

  @protected String getTargetPath(String path)
  {
    return path;
  }

  @protected Uri getTargetUri(HttpRequest request)
  {
    return new Uri(
      scheme: "http",
      host: getTargetHost(),
      port: getTargetPort(),
      path: getTargetPath(request.uri.path),
      query: request.uri.query
    );
  }

  Future<void> start() async
  {
    try {
      _server = await bind();
      print("${runtimeType} bind completed.");
      
      await for (HttpRequest request in _server)
      {
        _handleRequest(request);
      }
    }
    catch (e) {
      _handleError(e);
    }
  }
  
  Future<void> _handleRequest(HttpRequest request) async
  {
    try {

      (Map<String, String>, bool) targetHeaders = getTargetHeaders(request);

      if (!targetHeaders.$2) {
        // end
        await onComputeTargetHeadersFailed(request);
        request.response.close();
        return;
      }

      // Create HTTP client
      HttpClient client = createHttpClient();

      // Build target URI
      Uri targetUri = getTargetUri(request);
      
      // Create client request
      HttpClientRequest clientRequest = await client.openUrl(
        request.method,
        targetUri
      );

      for (MapEntry<String, String> entry in targetHeaders.$1.entries)
      {
        clientRequest.headers.set(entry.key, entry.value);
      }
      
      // Store active request for cleanup
      _activeRequests[request] = clientRequest;

      // Stream request body and wait for completion
      await request.forEach((Uint8List data) {
        clientRequest.add(data);
      });
      
      // Get response
      HttpClientResponse clientResponse = await clientRequest.close();
      _activeResponses[request] = clientResponse;
      
      // Handle response
      await _handleResponse(request, clientResponse);
      
    }
    catch (e) {
      _handleError(e);
      try {
        request.response.statusCode = 502;
        request.response.close();
      }
      catch (_) {

      }
    }
  }
  
  Future<void> _handleResponse(HttpRequest originalRequest, HttpClientResponse clientResponse) async
  {
    try {
      // Set response status and headers
      originalRequest.response.statusCode = clientResponse.statusCode;
      originalRequest.response.reasonPhrase = clientResponse.reasonPhrase;
    
      // Forward response headers (excluding hop-by-hop headers)
      final hopByHopHeaders = {
        "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
        "te", "trailers", "transfer-encoding", "upgrade"
      };
    
      clientResponse.headers.forEach((name, values) {
        if (!hopByHopHeaders.contains(name.toLowerCase())) {
          originalRequest.response.headers.set(name, values);
        }
      });
    
      // Stream response body
      await for (List<int> data in clientResponse)
      {
        originalRequest.response.add(data);
      }
    
      // Close response
      originalRequest.response.close();
    
      // Cleanup
      _activeRequests.remove(originalRequest);
      _activeResponses.remove(originalRequest);
    
    }
    catch (e) {
      _handleError(e);
      try {
        originalRequest.response.statusCode = 502;
        originalRequest.response.close();
      }
      catch (_) {

      }
    }
  }
  
  void _handleError(dynamic error)
  {
    print("HttpProxyServer handling error: $error");
    
    // Cleanup active requests on error
    for (var request in _activeRequests.keys.toList())
    {
      try {
        request.response.statusCode = 502;
        request.response.close();
      }
      catch (_) {

      }
    }
    _activeRequests.clear();
    _activeResponses.clear();
  }
}
