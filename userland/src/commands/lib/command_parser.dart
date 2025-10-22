import "package:common/executable.dart";

class ParsedCommand {
  final CommandLine commandLine;
  final String? outputFile;

  ParsedCommand({
    required this.commandLine,
    this.outputFile,
  });
}

class CommandParser {  
  ParsedCommand parse(String commandString) {
    final List<String> allParts = _splitCommandString(commandString.trim());

    if (allParts.isEmpty) {
      throw Exception("Empty command");
    }

    final int redirectIndex = allParts.indexOf(">");
    String? outputFile;
    List<String> commandParts = allParts;

    if (redirectIndex != -1 && redirectIndex < allParts.length - 1) {
      outputFile = allParts[redirectIndex + 1];
      commandParts = allParts.sublist(0, redirectIndex);
    }

    if (commandParts.isEmpty) {
      throw Exception("No command specified before redirection.");
    }

    return ParsedCommand(
      commandLine: CommandLine(
        command: commandParts.first,
        arguments: commandParts.sublist(1),
      ),
      outputFile: outputFile,
    );
  }

  List<String> _splitCommandString(String command) {
    final List<String> parts = [];
    final StringBuffer currentPart = new StringBuffer();
    String? activeQuoteChar;

    for (int i = 0; i < command.length; i++) {
      final String char = command[i];

      if (char == r'\') {
        if (i + 1 >= command.length) {
          currentPart.write(char);
          continue;
        }

        final String nextChar = command[i + 1];
        if (activeQuoteChar != null && nextChar == activeQuoteChar) {
          currentPart.write(nextChar);
          i++;
        } else {
          currentPart.write(char);
        }

        continue;
      }

      if (char == '"' || char == "'") {
        if (activeQuoteChar == null) {
          activeQuoteChar = char;
        } else if (activeQuoteChar == char) {
          activeQuoteChar = null;
        } else {
          currentPart.write(char);
        }
        continue;
      }

      if (char == " " && activeQuoteChar == null) {
        if (currentPart.isNotEmpty) {
          parts.add(currentPart.toString());
          currentPart.clear();
        }
        continue;
      }

      currentPart.write(char);
    }

    if (currentPart.isNotEmpty) {
      parts.add(currentPart.toString());
    }

    return parts;
  }
}