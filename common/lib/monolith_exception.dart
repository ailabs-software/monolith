
class MonolithException implements Exception
{
  final String _message;

  MonolithException(String this._message);

  @override
  String toString()
  {
    return _message;
  }
}