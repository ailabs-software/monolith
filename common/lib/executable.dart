import "dart:convert";
import "dart:io";
import "package:path/path.dart" as path_util;
import "package:common/monolith_exception.dart";
import "package:common/util.dart";

/** @fileoverview Helper for running executables */

const List<String> _EXECUTABLE_EXTENSIONS = [".exe", ".sh", ".aot", ".js", ".alias"];
const String _DART_AOT_RUNTIME_PATH = "/system/dart_sdk/bin/dartaotruntime";
const String _NODE_JS_PATH = "/system/node_js/bin/node.exe";
const String PATH_ENV_VAR = "PATH";

class CommandLine
{
  String command;

  List<String> arguments;

  CommandLine({
    required String this.command,
    required List<String> this.arguments
  });
}

class Executable
{
  /** all paths are tested within this path, useful when running outside a chroot */
  final String rootPath;

  /** Add this path in front of all paths */
  final String prefixPath;

  Executable({
    required String this.rootPath,
    required String this.prefixPath
  });

  List<String> _getPathList(Map<String, String> environment)
  {
    if (environment.containsKey(PATH_ENV_VAR)) {
      return environment[PATH_ENV_VAR]!.split(":");
    }
    return const [];
  }

  List<String> _getFullPathWithExtensions(String fullPath)
  {
    return [
      fullPath, // in case has extension
      ..._EXECUTABLE_EXTENSIONS.map( (String e) => fullPath + e )
    ];
  }

  Future<String> resolveExecutablePath(String command, Map<String, String> environment) async
  {
    List<String> pathList = _getPathList(environment);
    if ( path_util.isAbsolute(command) ) {
      pathList = const [];
    }
    for (String basePath in ["/", ...pathList])
    {
      String fullPath = safeJoinPaths(basePath, command);
      for (String fullPathWithExtension in _getFullPathWithExtensions(fullPath) )
      {
        if ( await new File( safeJoinPaths(rootPath, fullPathWithExtension) ).exists() ) {
          return safeJoinPaths(prefixPath, fullPathWithExtension);
        }
      }
    }
    throw new MonolithException("command ${command} does not exist in \$PATH (which was: ${pathList.join(":")})");
  }

  Future<CommandLine> resolveExecutable(CommandLine commandLine, Map<String, String> environment) async
  {
    String command = await resolveExecutablePath(commandLine.command, environment);
    String extName = path_util.extension(command);
    switch (extName)
    {
      case ".exe":
        return new CommandLine(
          command: command,
          arguments: commandLine.arguments
        ); // execute directly
      case ".sh":
        return new CommandLine(
          command: safeJoinPaths(prefixPath, "/system/bin/busybox.exe"),
          arguments: ["sh", command, ...commandLine.arguments]
        );
      case ".aot":
        // translate to use dartaotruntime
        return new CommandLine(
          command: safeJoinPaths(prefixPath, _DART_AOT_RUNTIME_PATH),
          arguments: [command, ...commandLine.arguments]
        );
      case ".js":
        // translate to use nodejs
        return new CommandLine(
          command: safeJoinPaths(prefixPath, _NODE_JS_PATH),
          arguments: [command, ...commandLine.arguments]
        );
      case ".alias":
        List<String> aliasedCommandLine = (json.decode( ( new File( safeJoinPaths(rootPath, command) ) ).readAsStringSync()) as List).cast<String>();
        return new CommandLine(
          command: safeJoinPaths(prefixPath, aliasedCommandLine[0]),
          arguments: [...aliasedCommandLine.sublist(1), ...commandLine.arguments]
        );
      default:
        throw new Exception("execute: Unsupported extension: ${extName}");
    }
  }
}