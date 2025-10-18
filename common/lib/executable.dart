import "dart:convert";
import "dart:io";
import "package:path/path.dart" as path_util;
import "package:common/monolith_exception.dart";
import "package:common/util.dart";

/** @fileoverview Helper for running executables */

const List<String> _EXECUTABLE_EXTENSIONS = [".exe", ".sh", ".aot", ".js", ".alias"];
const String _DART_AOT_RUNTIME_PATH = "/system/dart_sdk/bin/dartaotruntime";
const String _NODE_JS_PATH = "/sdk/node_js/bin/node.exe";
const String PATH_ENV_VAR = "PATH";

class CommandLine
{
  String command;

  List<String> arguments;

  Map<String, String> environmentOverrides;

  CommandLine({
    required String this.command,
    required List<String> this.arguments,
    Map<String, String> this.environmentOverrides = const {}
  });
}

class Executable
{
  /** all paths are tested within this path, useful when running outside a chroot */
  final String rootPath;

  /** Add this path in front of all paths */
  final String prefixPath;

  /** The current environment */
  final Map<String, String> environment;

  Executable({
    required String this.rootPath,
    required String this.prefixPath,
    required Map<String, String> this.environment
  });

  List<String> _getFullPathWithExtensions(String fullPath)
  {
    return [
      fullPath, // in case has extension
      ..._EXECUTABLE_EXTENSIONS.map( (String e) => fullPath + e )
    ];
  }

  List<String> _getPathList()
  {
    if (environment.containsKey(PATH_ENV_VAR)) {
      return environment[PATH_ENV_VAR]!.split(":");
    }
    return const [];
  }

  List<String> _getPathsConsideredInExecutableResolutionLoop(String command)
  {
    List<String> pathList = _getPathList();
    if ( path_util.isAbsolute(command) ) {
      pathList = const [];
    }
    return ["/", ...pathList];
  }

  Stream<String> getExecutablesInPathStartingWith(String partialCommand) async*
  {
    for (String basePath in _getPathsConsideredInExecutableResolutionLoop(partialCommand) )
    {
      Directory directory = new Directory(basePath);
      if ( await directory.exists() ) {
        await for (FileSystemEntity entity in directory.list() )
        {
          if (
            entity is File &&
            _EXECUTABLE_EXTENSIONS.contains( path_util.extension(entity.path) ) &&
            path_util.basename(entity.path).startsWith(partialCommand)
          ) {
            bool partialCommandIsPath = partialCommand.contains("/");
            if (partialCommandIsPath) {
              yield entity.path;
            }
            else {
              yield path_util.basenameWithoutExtension(entity.path);
            }
          }
        }
      }
    }
  }

  Future<String> resolveExecutablePath(String command) async
  {
    for (String basePath in _getPathsConsideredInExecutableResolutionLoop(command) )
    {
      String fullPath = safeJoinPaths(basePath, command);
      for (String fullPathWithExtension in _getFullPathWithExtensions(fullPath) )
      {
        if ( await new File( safeJoinPaths(rootPath, fullPathWithExtension) ).exists() ) {
          return safeJoinPaths(prefixPath, fullPathWithExtension);
        }
      }
    }
    throw new MonolithException("command ${command} does not exist in \$PATH (which was: ${_getPathList().join(":")})");
  }

  Future<CommandLine> resolveExecutable(CommandLine commandLine) async
  {
    String command = await resolveExecutablePath(commandLine.command);
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
        Map aliasFile = (json.decode( ( new File( safeJoinPaths(rootPath, command) ) ).readAsStringSync()) as Map);
        List<String> aliasedCommandLine = (aliasFile["command_line"] as List).cast<String>();
        Map<String, String> environmentOverrides = (aliasFile["environment_overrides"] as Map).cast<String, String>();
        return new CommandLine(
          command: safeJoinPaths(prefixPath, aliasedCommandLine[0]),
          arguments: [...aliasedCommandLine.sublist(1), ...commandLine.arguments],
          environmentOverrides: environmentOverrides
        );
      default:
        throw new Exception("execute: Unsupported extension: ${extName}");
    }
  }
}