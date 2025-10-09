import "dart:io";

Future<void> main() async
{
  // VT100 escape sequence to clear screen and move cursor to home
  stdout.write("\x1B[2J\x1B[H");
  await stdout.flush();
}
