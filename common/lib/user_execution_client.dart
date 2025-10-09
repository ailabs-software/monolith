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
    String responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      throw new Exception(responseBody);
    }
    // return result
    Map<String, Object?> resultMap = json.decode(responseBody);
    return new ProcessResult( // TODO a better class for what we are returning, typed properly
      0,
      resultMap["exit_code"] as int,
      resultMap["stdout"],
      resultMap["stderr"]
    );
  }
}
