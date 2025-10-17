
/** @fileoverview Higher level wrapper around execution_client.js in order to focus on interaction with
 *                shell.aot, which is the only binary that terminal.js directly interacts with. */

function _shellDo(action, parameters)
{
  return execute("/system/bin/shell.aot", [action, ...parameters]);
}

function shellInit()
{
  return _shellDo("init", []);
}

// returns a generator that yields stream of output
function shellExecuteStream(commandString)
{
  return _shellDo("execute", [commandString]);
}

// returns all output at once, once available
async function shellExecute(commandString)
{
  let result = await collectResponse( shellExecuteStream(commandString) );
  console.log("result", result);
  console.log("result.stdout", result.stdout);
  return result.stdout.map( (outputChunk) => JSON.parse(outputChunk).output ).join("");
}

async function shellCompletion(string)
{
  // json list of strings expected from shell.aot for completion action
  return JSON.parse( ( await collectResponse( _shellDo("completion", [string]) ) ).stdout );
}
