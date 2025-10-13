
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

      if (line.trim()) {
        const chunk = JSON.parse(line);
        console.log("Backend chunk:", chunk);
        if (chunk.stdout) {
          console.log("Shell stdout:", chunk.stdout);
          // Shell stdout may contain multiple newline-delimited JSON objects
          const shellLines = chunk.stdout.split('\n').filter(l => l.trim());
          for (const shellLine of shellLines) {
            const shellOutput = JSON.parse(shellLine);
            console.log("Parsed shell output:", shellOutput);
            lastShellOutput = shellOutput;
            if (onOutput && shellOutput.output) {
              onOutput(shellOutput.output);
            }
          }
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