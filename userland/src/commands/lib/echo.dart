import "dart:io";

Future<void> main(List<String> arguments) async
{
  String arg = arguments.first;
  if (arg.startsWith("\$")) {
    print(Platform.environment[arg.substring(1)]);
  }
  else {
    print(arg);
  }
}
