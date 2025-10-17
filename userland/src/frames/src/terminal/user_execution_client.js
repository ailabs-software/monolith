
/** @fileoverview User execution client for the browser / JS */

function* iterateBufferOverNewlines(buffer)
{
  // iterate over the buffer, yielding lines as we go
  let last = null;
  let remainingBuffer = buffer;

  while (remainingBuffer.includes("\n"))
  {
    const index = remainingBuffer.indexOf("\n");
    const line = remainingBuffer.substring(0, index);
    remainingBuffer = remainingBuffer.substring(index + 1);
    if (line.trim().length > 0) {
      yield line;
    }
  }
  return {buffer: remainingBuffer, last};
}

// stream the response from the shell using generator
// yield each line as it arrives
async function* _streamExecuteResponseLines(response)
{
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let last = null;

  try {
    while (true)
    {
      // read the next chunk, if done no need to continue
      const {done, value} = await reader.read();
      if (done) {
        break;
      }

      buffer += decoder.decode(value, {stream: true});

      const generator = iterateBufferOverNewlines(buffer);
      for (const output of generator)
      {
        yield output;
      }

      const result = generator.return().value;
      if (result) {
        buffer = result.buffer;
        if (result.last) {
          last = result.last;
        }
      }
    }

    // Drain any remaining buffered content (no trailing newline)
    if (buffer.trim().length > 0) {
      yield buffer;
    }
  }
  finally {
    reader.releaseLock();
  }
}

// generator that yields a series of these objects::
// {"stdout": "string", "stderr": "string", "exit_code": 0}
async function* execute(command, parameters)
{
  const response = await fetch(
    "/~" + command + "?" + new URLSearchParams(environment).toString(),
    {
      method: "POST",
      body: JSON.stringify(parameters)
    }
  );
  for await (const line of _streamExecuteResponseLines(response) )
  {
    let lines = line.split("\n"); // TODO not simple, seems redundant
    for (const e of lines)
    {
      if (e.trim().length > 0) {
        yield JSON.parse(e);
      }
    }
  }
}

function _pushOutput(result, chunk, key)
{
  if (chunk[key] != null) {
    result[key].push(chunk[key]);
  }
}

async function collectResponse(generator)
{
  let result = {
    stdout: [],
    stderr: [],
    exit_code: null
  };
  for await (const chunk of generator)
  {
    // append each key to result
    _pushOutput(result, chunk, "stdout");
    _pushOutput(result, chunk, "stderr");
    if (chunk.exit_code != null) {
      result.exit_code = chunk.exit_code;
    }
  }
  return result;
}