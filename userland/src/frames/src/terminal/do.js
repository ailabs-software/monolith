
/** @param action -- possible values of action:
 *  init
 *  execute
 *  completion
 *
 *  @param parameters -- arguments to run, if is exec (optional)
 *  */
async function _do(action, parameters)
{
  let response = await fetch(
    "/~/system/bin/shell.aot?" + new URLSearchParams(environment).toString(),
    {
      "method": "POST",
      "body": JSON.stringify([action, ...parameters])
    }
  );
  let resultRaw = await response.text();
  if (response.status !== 200) {
    return "shell exec failed:\n" + resultRaw;
  }
  let result = JSON.parse( JSON.parse(resultRaw)["stdout"] );

  // update environment
  environment = result.environment;

  return result.output;
}

async function doInit()
{
  return _do("init", []);
}

async function doExecute(string)
{
  return _do("execute", [string]);
}

async function doCompletion(string)
{
  return _do("completion", [string]);
}