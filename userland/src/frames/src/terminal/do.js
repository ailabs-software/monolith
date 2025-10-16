function _extractShellLinesFromChunk(line) {
  const chunk = JSON.parse(line);
  // use either stdout or stderr, if both are present, stderr takes precedence
  const provider = (chunk.stderr ?? chunk.stdout);
  return provider
    ? provider.split(/\r?\n/).filter(l => l.trim())
    : [];
}

function _tryParseShellOutput(shellLine) {
  try {
    return JSON.parse(shellLine);
  } catch (_) {
    return null;
  }
}

function _emitOutput(shellOutputOrText, onOutput) {
  if (!onOutput) {
    return;
  }

  // emit either a string or an object with an output property
  if (typeof shellOutputOrText === "string") {
    onOutput(shellOutputOrText + "\n");
  } else if (shellOutputOrText && shellOutputOrText.output) {
    onOutput(shellOutputOrText.output);
  }
}

function _emitShellLinesOutput(shellLines, onOutput)
{
  // iterate over the shell lines and emit their output
  let last = null;
  for (const shellLine of shellLines) {
    const parsed = _tryParseShellOutput(shellLine);
    if (parsed) {
      environment = parsed.environment;
      last = parsed;
      _emitOutput(parsed, onOutput);
    } else {
      _emitOutput(shellLine, onOutput);
    }
  }
  return last;
}

function iterateBufferOverNewlines(buffer, onOutput)
{
  // iterate over the buffer, emitting lines as we go
  let last = null;
  while (buffer.includes("\n")) {
    const index = buffer.indexOf("\n");
    const line = buffer.substring(0, index);
    buffer = buffer.substring(index + 1);
    if (!line.trim()) {
      continue;
    }

    const shellLines = _extractShellLinesFromChunk(line);
    const maybeLast = _emitShellLinesOutput(shellLines, onOutput);
    if (maybeLast) {
      last = maybeLast;
    }
  }
  return { buffer, last };
}

// stream the response from the shell
async function _streamShellResponse(response, onOutput) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let last = null;

  while (true) {
    // read the next chunk, if done no need to continue
    const { done, value } = await reader.read();
    if (done) {
      break;
    }

    buffer += decoder.decode(value, { stream: true });

    const res = iterateBufferOverNewlines(buffer, onOutput);
    buffer = res.buffer;
    if (res.last) {
      last = res.last;
    }
  }
  // Drain any remaining buffered content (no trailing newline)
  if (buffer.trim()) {
    const shellLines = _extractShellLinesFromChunk(buffer);
    const maybeLast = _emitShellLinesOutput(shellLines, onOutput);
    if (maybeLast) last = maybeLast;
  }
  return last;
}

async function _do(action, parameters, onOutput)
{
  const response = await fetch(
    "/~/system/bin/shell.aot?" + new URLSearchParams(environment).toString(),
    {
      method: "POST",
      body: JSON.stringify([action, ...parameters])
    }
  );
  const last = await _streamShellResponse(response, onOutput);
  return last && typeof last.output === "string" ? last.output : "";
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
  // json list of strings expected from shell.aot for completion action
  return JSON.parse( await _do("completion", [string]) );
}