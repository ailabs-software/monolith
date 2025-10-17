
/** @fileoverview User execution client for the browser / JS */

// stream the response from the shell using generator
// yield each line as it arrives
async function* _streamExecuteResponseLines(response)
{
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let last = "";

  try {
    while (true)
    {
      // read the next chunk, if done no need to continue
      const {done, value} = await reader.read();
      if (done) {
        break;
      }

      let chunks = decoder.decode(value, {stream: true}).split("\n");

      for (let i = 0; i < chunks.length - 2; i++)
      {
        yield chunks[i];
      }
      // last chunk is not terminated by newline
      if (chunks.length > 0) {
        last = chunks[chunks.length - 1];
      }
    }

    // Drain any remaining buffered content (no trailing newline)
    if (last.trim().length > 0) {
      yield last;
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
  for await (const chunk of _streamExecuteResponseLines(response) )
  {
    yield JSON.parse(chunk);
  }
}

function _pushOutput(result, chunk, key)
{
  if (chunk[key] != null) {
    // add each stdout line as a different entry in output,
    // as multiple lines often are combined in a single chunk
    result[key].push(
      ...chunk[key].split("\n")
      .filter( (line) => line.length > 0 )
    );
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