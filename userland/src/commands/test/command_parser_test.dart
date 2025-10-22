import "../lib/command_parser.dart";

void main()
{
  CommandParser parser = new CommandParser();
  
  _testBasicCommand(parser);
  
  _testMultipleSpaces(parser);
  
  _testQuotedArguments(parser);
  
  _testMixedQuotesAndSpaces(parser);
  
  _testOutputRedirection(parser);
  
  _testEmptyCommand(parser);
  
  _testEscapedQuotes(parser);
  
  _testQuotesInsideQuotes(parser);
  
  print("All tests passed!");
}

void _testBasicCommand(CommandParser parser)
{
  ParsedCommand result = parser.parse("echo hello world");
  _assert(result.commandLine.command == "echo", "Basic command: command name");
  _assert(result.commandLine.arguments.length == 2, "Basic command: argument count");
  _assert(result.commandLine.arguments[0] == "hello", "Basic command: first arg");
  _assert(result.commandLine.arguments[1] == "world", "Basic command: second arg");
  _assert(result.outputFile == null, "Basic command: no output file");
}

void _testMultipleSpaces(CommandParser parser)
{
  ParsedCommand result = parser.parse("echo    hello     world");
  _assert(result.commandLine.command == "echo", "Multiple spaces: command name");
  _assert(result.commandLine.arguments.length == 2, "Multiple spaces: argument count");
  _assert(result.commandLine.arguments[0] == "hello", "Multiple spaces: first arg");
  _assert(result.commandLine.arguments[1] == "world", "Multiple spaces: second arg");
}

void _testQuotedArguments(CommandParser parser)
{
  ParsedCommand result = parser.parse('echo "hello world"');
  _assert(result.commandLine.command == "echo", "Quoted args: command name");
  _assert(result.commandLine.arguments.length == 1, "Quoted args: argument count");
  _assert(result.commandLine.arguments[0] == "hello world", "Quoted args: quoted argument");
  
  ParsedCommand result2 = parser.parse("echo 'hello world'");
  _assert(result2.commandLine.arguments[0] == "hello world", "Quoted args: single quotes");
}

void _testMixedQuotesAndSpaces(CommandParser parser)
{
  ParsedCommand result = parser.parse('echo   "hello world"   foo   "bar baz"');
  _assert(result.commandLine.command == "echo", "Mixed: command name");
  _assert(result.commandLine.arguments.length == 3, "Mixed: argument count");
  _assert(result.commandLine.arguments[0] == "hello world", "Mixed: first quoted arg");
  _assert(result.commandLine.arguments[1] == "foo", "Mixed: unquoted arg");
  _assert(result.commandLine.arguments[2] == "bar baz", "Mixed: second quoted arg");
}

void _testOutputRedirection(CommandParser parser)
{
  ParsedCommand result = parser.parse("echo hello > output.txt");
  _assert(result.commandLine.command == "echo", "Redirection: command name");
  _assert(result.commandLine.arguments.length == 1, "Redirection: argument count");
  _assert(result.commandLine.arguments[0] == "hello", "Redirection: argument");
  _assert(result.outputFile == "output.txt", "Redirection: output file");
}

void _testEmptyCommand(CommandParser parser)
{
  try {
    parser.parse("   ");
    _assert(false, "Empty command: should throw exception");
  } catch (e) {
    _assert(e.toString().contains("Empty command"), "Empty command: correct exception");
  }
}

void _testEscapedQuotes(CommandParser parser)
{
  ParsedCommand result = parser.parse('echo "hello \\"world\\""');
  _assert(result.commandLine.arguments[0] == 'hello "world"', "Escaped quotes: double quotes");
  
  ParsedCommand result2 = parser.parse("echo 'hello \\'world\\''");
  _assert(result2.commandLine.arguments[0] == "hello 'world'", "Escaped quotes: single quotes");
}

void _testQuotesInsideQuotes(CommandParser parser)
{
  ParsedCommand result = parser.parse('echo "hello \'world\'"');
  _assert(result.commandLine.arguments[0] == "hello 'world'", "Quotes inside: single in double");
  
  ParsedCommand result2 = parser.parse("echo 'hello \"world\"'");
  _assert(result2.commandLine.arguments[0] == 'hello "world"', "Quotes inside: double in single");
}

void _assert(bool condition, String message)
{
  if (!condition) {
    throw new Exception("Test failed: ${message}");
  }
}
