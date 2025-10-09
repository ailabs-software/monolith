import "dart:io";

/** @fileoverview Wraps git. Runs in trusted, so outside chroot */

final String _GIT_SECRET_ACCESS = "";

Future<void> _handleCommand(String command, List<String> arguments) async
{
  ProcessResult result = await Process.run("/usr/bin/git", [command, ...arguments]);
  stdout.write(result.stdout);
  await stdout.flush();
  stderr.write(result.stderr);
  await stderr.flush();
  exit(result.exitCode);
}

Future<void> main(List<String> arguments) async
{
  if (arguments.isEmpty) {
    stderr.writeln("Missing a git command argument.");
    await stderr.flush();
    exit(1);
  }
  String command = arguments[0];
  switch (command)
  {
    case "clone":
      Uri uri = Uri.parse(arguments[1]);
      uri = uri.replace(userInfo: _GIT_SECRET_ACCESS);
      return _handleCommand("clone", [uri.toString()]);
    case "diff":
      return _handleCommand("diff", const []);
    case "status":
      return _handleCommand("status", const []);
    default:
      stderr.writeln("Unrecognised git command ${command}.");
      await stderr.flush();
      exit(1);
  }
}
