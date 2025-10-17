
/** @fileoverview Higher level wrapper around execution_client.js in order to focus on interaction with
 *                shell.aot, which is the only binary that terminal.js directly interacts with. */

function _shellDo(action, parameters, environment)
{
  return execute("/system/bin/shell.aot", [action, ...parameters], environment);
}

async function _collectShellOutput(generator)
{
  let result = await collectResponse(generator);
  return result.stdout.map( (outputChunk) => JSON.parse(outputChunk).output ).join("");
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
// yields output
async function* shellExecuteStream(commandString, environment)
{
  for await (const response of _shellExecuteStreamInternal(commandString, environment) )
  {
    console.log("shellExecuteStream for response:", response);
    let responseParsed = JSON.parse(response.stdout);
    yield responseParsed;
  }
}

// returns all output at once, once available
async function shellExecute(commandString, environment)
{
  return _collectShellOutput( _shellExecuteStreamInternal(commandString, environment) );
}

async function shellCompletion(string, environment)
{
  // json list of strings expected from shell.aot for completion action
  return JSON.parse( await _collectShellOutput( _shellDo("completion", [string], environment) ) );
}
