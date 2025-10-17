import "dart:io";
import "package:common/executable.dart";

Future<void> main(List<String> arguments) async
{
  if (arguments.isNotEmpty) {
    String arg = arguments.first;
    Executable executable = new Executable(rootPath: "/", prefixPath: "", environment: Platform.environment);
    String resolved = await executable.resolveExecutablePath(arg);
    print(resolved);
  }
  else {
    print("Missing required argument command");
  }
}
