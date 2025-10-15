
async function _do(action, parameters, onOutput)
{
  let response = await fetch(
    "/~/system/bin/shell.aot?" + new URLSearchParams(environment).toString(),
    {
      method: "POST",
      body: JSON.stringify([action, ...parameters])
    }
  );
  let lastShellOutput = null;
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  
  while (true) {
    const {done, value} = await reader.read();
    if (done) {
      break;
    }

    buffer += decoder.decode(value, {stream: true});

    while (buffer.includes("\n")) {
      const line = buffer.substring(0, buffer.indexOf("\n"));
      buffer = buffer.substring(buffer.indexOf("\n") + 1);

      if (!line.trim()) {
        continue;
      }

      const chunk = JSON.parse(line);
      const linesProvider = chunk.stdout || chunk.stderr;
      if (!linesProvider) {
        continue;
      }

      const shellLines = linesProvider.split(/\r?\n/).filter(l => l.trim());
      for (const shellLine of shellLines) {
        try {
          const shellOutput = JSON.parse(shellLine);
          lastShellOutput = shellOutput;
          if (onOutput && shellOutput.output) {
            onOutput(shellOutput.output);
          }
        } catch (_) {
          if (onOutput) onOutput(shellLine + "\n");
        }
      }
    }
  }
  
  if (lastShellOutput) {
    environment = lastShellOutput.environment;
    return lastShellOutput.output;
  }
  return "";
}

async function doInit()
{
  return _do("init", []);
}

async function doExecute(commandString, onOutput)
{
  return _do("execute", [commandString], onOutput);
}

async function doCompletion(string)
{
  return _do("completion", [string]);
}