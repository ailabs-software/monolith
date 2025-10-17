
/** @fileoverview Higher level wrapper around execution_client.js in order to focus on interaction with
 *                shell.aot, which is the only binary that terminal.js directly interacts with. */

function _shellDo(action, parameters, environment)
{
  return execute("/system/bin/shell.aot", [action, ...parameters], environment);
}

// return array of {"environment": ...} / {"output": ...} objects
function getShellResponsesFromChunkStdout(stdout)
{
  // each newline is an output
  return (
    stdout.split("\n")
    .filter( (e) => e.length > 0 ) // remove empty trailing line
    .map( (outputChunk) => JSON.parse(outputChunk) )
  );
}

async function _collectShellOutput(generator)
{
  let result = await collectResponse(generator);
  // each newline is an output
  return (
    getShellResponsesFromChunkStdout(result.stdout)
    .map( (e) => e.output )
    .join("")
  );
}

function shellInit(environment)
{
  return _collectShellOutput( _shellDo("init", [], environment) );
}

function _shellExecuteStreamInternal(commandString, environment)
{
  return _shellDo("execute", [commandString], environment);
}

// returns a generator that yields stream of output
async function* shellExecuteStream(commandString, environment)
{
  for await (const chunk of _shellExecuteStreamInternal(commandString, environment) )
  {
    if (chunk && typeof chunk.stdout === "string") {
      const responses = getShellResponsesFromChunkStdout(chunk.stdout);
      for (const response of responses) {
      yield response;
      }
    } else if (chunk && chunk.pid != null) {
      yield { pid: chunk.pid };
    } else if (chunk && typeof chunk.stderr === "string" && chunk.stderr.length > 0) {
      yield { output: chunk.stderr };
    } else {
      // ignore padding or exit_code-only chunks
    }
  }
}

// returns all output at once (from stdout), once available
async function shellExecute(commandString, environment)
{
  return _collectShellOutput( _shellExecuteStreamInternal(commandString, environment) );
}

async function shellCompletion(string, environment)
{
  // json list of strings expected from shell.aot for completion action
  return JSON.parse( await _collectShellOutput( _shellDo("completion", [string], environment) ) );
}

// Send a signal (e.g., SIGINT) to the shell to interrupt the running command
// Optionally target a specific PID if provided
async function shellSignal(signalName, environment, pid)
{
  // fire-and-forget; server should handle interrupting the active process
  try {
    const params = pid != null ? [signalName, String(pid)] : [signalName];
    await _collectShellOutput( _shellDo("signal", params, environment) );
  } catch (e) {
    // ignore errors from signaling
    console.error("Failed to signal shell: " + e);
  }
}
