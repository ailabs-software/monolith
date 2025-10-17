
/** @fileoverview Higher level wrapper around execution_client.js in order to focus on interaction with
 *                shell.aot, which is the only binary that terminal.js directly interacts with. */

async function _shellDo(action, parameters)
{
  return execute("/system/bin/shell.aot", [action, ...parameters]);
}

async function shellInit()
{
  return _shellDo("init", []);
}

async function shellExecute(commandString)
{
  return _shellDo("execute", [commandString]);
}

async function shellCompletion(string)
{
  // json list of strings expected from shell.aot for completion action
  return JSON.parse( collectStdoutResponse( await _shellDo("completion", [string]) ) );
}