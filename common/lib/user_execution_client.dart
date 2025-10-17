import "dart:convert";
import "dart:io";
import "package:common/constants/user_execution_service_port.dart";
import "package:common/executable.dart";

/** @fileoverview User execution client for Dart, used on the server side */

class UserExecutionClientResponse
{
  final String stdout;

  final String stderr;

  final int? exitCode;

  UserExecutionClientResponse({
    required String this.stdout,
    required String this.stderr,
    required int? this.exitCode
  });
}

class UserExecutionClient
{
  final String authString;

  UserExecutionClient({required String this.authString});

  /** Provides a stream of events as stdout/stderr is printed by the executable */
  Stream<UserExecutionClientResponse> execute(CommandLine commandLine, Map<String, String> environment) async*
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
    
    await for (final String line in response.transform(utf8.decoder).transform(new LineSplitter()) )
    {
      if (line.trim().isEmpty) {
        continue;
      }
      
      try {
        final Map<String, dynamic> chunk = json.decode(line);

        yield new UserExecutionClientResponse(
          stdout: chunk["stdout"] ?? "",
          stderr: chunk["stderr"] ?? "",
          exitCode: chunk["exit_code"]
        );
      }
      catch (e) {
        throw new Exception("Malformed json \nLine: ${line}\n ${e.toString()}");
      }
    }
  }
}
