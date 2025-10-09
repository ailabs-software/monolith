import "dart:convert";
import "dart:io";

extension HttpRequestExtension on HttpRequest
{
  Future<String> readBodyAsString() async
  {
    List<int> bytes = [];
    await for (List<int> data in this)
    {
      bytes.addAll(data);
    }
    return utf8.decode(bytes);
  }

  Future<Object?> readBodyAsJson() async
  {
    return json.decode( await readBodyAsString() );
  }
}