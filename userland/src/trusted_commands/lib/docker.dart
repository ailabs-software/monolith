import "dart:io";

/** @fileoverview Wraps docker build. Runs in trusted, so outside chroot */

enum _DockerCommands
{
  build("build"),
  load("load"),
  save("save"),
  ps("ps"),
  run("run"),
  stop("stop"),
  exec("exec");

  final String command;

  const _DockerCommands(String this.command);
}

class _DockerWrapper
{
  final _DockerCommands dockerCommand;

  _DockerWrapper(_DockerCommands this.dockerCommand);

  Future<void> parse(List<String> args) async
  {
    await _runDockerCommand(args);
  }

  Future<void> _runDockerCommand([List<String> args = const []]) async
  {
    final String userCwd = Platform.environment["CWD"] ?? "/";
    final String actualCwd = "/opt/monolith/userland$userCwd";

    final ProcessResult result = await Process.run(
      "docker",
      [dockerCommand.command, ...args],
      environment: {
        ...Platform.environment,
      },
      workingDirectory: actualCwd,
    );

    print(result.stdout);
    if (result.exitCode != 0) {
      print("Error: ${result.stderr}");
    }
  }
}

void main(List<String> args) async
{
  final String? commandName = args.firstOrNull;
  if (commandName == null) {
    print("No command name provided");
    exit(1);
  }
  _DockerCommands? command = _DockerCommands.values.where((_DockerCommands c) => c.command == commandName).firstOrNull;
  if (command == null) {
    print("Command \"${commandName}\" not covered by this wrapper");
    exit(2);
  }
  await new _DockerWrapper(command).parse(args.sublist(1));
}
