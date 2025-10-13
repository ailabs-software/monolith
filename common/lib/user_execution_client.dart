import "dart:convert";
import "dart:io";
import "package:common/constants/user_execution_service_port.dart";
import "package:common/executable.dart";

class UserExecutionClient
{
  final String authString;

  UserExecutionClient({required String this.authString});

  Future<ProcessResult> execute(CommandLine commandLine, Map<String, String> environment) async
  {
    HttpClient client = new HttpClient();
    client.idleTimeout = new Duration(milliseconds: 0);
    HttpClientRequest request = await client.postUrl(
      new Uri(
        scheme: "http",
        host: "127.0.0.1",
        port: user_execution_service_port,
        path: "/~" + commandLine.command,
        queryParameters: environment
      )
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, authString);
    request.write( json.encode(commandLine.arguments) );
    // Send request and get response
    HttpClientResponse response = await request.close();
    
    if (response.statusCode != HttpStatus.ok) {
      String errorBody = await response.transform(utf8.decoder).join();
      throw new Exception(errorBody);
    }
    
    // Parse newline-delimited JSON streaming response
    StringBuffer stdoutBuffer = new StringBuffer();
    StringBuffer stderrBuffer = new StringBuffer();
    int exitCode = 0;
    
    await for (final String line in response.transform(utf8.decoder).transform(LineSplitter())) {
      if (line.trim().isEmpty) {
        continue;
      }
      
      try {
        final Map<String, dynamic> chunk = json.decode(line);
        
        if (chunk.containsKey("stdout")) {
          stdoutBuffer.write(chunk["stdout"]);
        }
        else if (chunk.containsKey("stderr")) {
          stderrBuffer.write(chunk["stderr"]);
        }
        else if (chunk.containsKey("exit_code")) {
          exitCode = chunk["exit_code"] as int;
        }
      }
      catch (e) {
        throw new Exception("Malformed json \nLine: ${line}\n ${e.toString()}");
      }
    }
    
    return new ProcessResult(
      0,
      exitCode,
      stdoutBuffer.toString(),
      stderrBuffer.toString()
    );
  }

  Future<void> executeStreaming(
    CommandLine commandLine,
    Map<String, String> environment,
    {
      required void Function(String stdout) onStdout,
      required void Function(String stderr) onStderr,
    }
  ) async
  {
    HttpClient client = new HttpClient();
    client.idleTimeout = new Duration(milliseconds: 0);
    HttpClientRequest request = await client.postUrl(
      new Uri(
        scheme: "http",
        host: "127.0.0.1",
        port: user_execution_service_port,
        path: "/~" + commandLine.command,
        queryParameters: environment
      )
    );
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, authString);
    request.write( json.encode(commandLine.arguments) );
    HttpClientResponse response = await request.close();
    
    if (response.statusCode != HttpStatus.ok) {
      String errorBody = await response.transform(utf8.decoder).join();
      throw new Exception(errorBody);
    }
    
    await for (final String line in response.transform(utf8.decoder).transform(LineSplitter())) {
      if (line.trim().isEmpty) {
        continue;
      }
      
      try {
        final Map<String, dynamic> chunk = json.decode(line);
        
        if (chunk.containsKey("stdout")) {
          onStdout(chunk["stdout"]);
        }
        else if (chunk.containsKey("stderr")) {
          onStderr(chunk["stderr"]);
        }
      }
      catch (e) {
        throw new Exception("Malformed json \nLine: ${line}\n ${e.toString()}");
      }
    }
  }
}
