
/** @fileoverview Handle the terminal frame */

const CURSOR = "\u2588"
const MAX_COMMAND_HISTORY_LEN = 1996;

const terminalElement = document.getElementById("terminal");

let consoleContentFinal = "";
let consoleContentWorking = "";

// Busy mode: prevent race conditions during command execution
let isBusy = false;
let keystrokeQueue = [];

// History of submitted commands
let commandHistory = [];
let commandHistoryPosition = 0; // relative to end

function updateDisplay()
{
  terminalElement.textContent = consoleContentFinal + consoleContentWorking + CURSOR;
  // Scroll to bottom
  terminalElement.scrollTop = terminalElement.scrollHeight;
  // Keep cursor at end by refocusing
  terminalElement.focus();
}

function $print(string)
{
  consoleContentWorking += string;
  updateDisplay();
}

function finalise()
{
  consoleContentFinal += consoleContentWorking;
  consoleContentWorking = "";
}

function commandHistoryAdd(command)
{
  if (commandHistory.length > MAX_COMMAND_HISTORY_LEN) {
    commandHistory.shift();
  }
  commandHistory.push(command);
}

function handleRecallCommandHistory(direction)
{
  if (commandHistory.length > 0) {
    // add the current command to history before moving (may be empty)
    if ( // only when at end of history
         commandHistoryPosition === 0
         // and only when direction is up
         && direction === 1
         // and not equal to the last command
         && commandHistory[commandHistory.length - 1] !== consoleContentWorking) {
      commandHistoryAdd(consoleContentWorking);
    }
    // apply the direction
    commandHistoryPosition += direction;
    // keep in range
    commandHistoryPosition = Math.max(0, Math.min(commandHistory.length - 1, commandHistoryPosition));
    consoleContentWorking = commandHistory[commandHistory.length - 1 - commandHistoryPosition];
    updateDisplay();
  }
}

async function handleEnter()
{
  $print("\n");
  let commandString = consoleContentWorking.trimEnd();
  finalise();

  console.log(`running ${commandString}`);
  
  // Execute command through shell with streaming output
  for await (const response of shellExecuteStream(commandString, environment) )
  {
    console.log("received shell response", response);
    // mutually exclusive
    if (response.environment != null) {
      // updating the environment
      environment = response.environment;
    }
    else if (response.term_command === "clear") {
      consoleContentFinal = "";
      consoleContentWorking = "";
      updateDisplay();
    }
    else if (response.output != null) {
      $print(response.output);
      finalise();
    }
  }

/*=======
  
  // Enter busy mode
  isBusy = true;

  commandHistoryAdd(commandString);
  let output = await doExecute(commandString);
  let isClearCommand = output === "\u001b[2J\u001b[H\n";
  if (isClearCommand) {
    consoleContentFinal = "";
    updateDisplay();
  }
  else {
    $print(output);
    finalise();
  }
>>>>>>> main*/

  await runInit();
  
  // Exit busy mode and replay queued keystrokes
  isBusy = false;
  replayQueuedKeystrokes();
}

function completeWithSingleMatch(completion)
{
  // Single match, complete it by replacing the last word
  let parts = consoleContentWorking.trim().split(" ");
  parts[parts.length - 1] = completion;
  consoleContentWorking = parts.join(" ");
}

async function completeWithMultipleMatches(completionList)
{
  // Multiple matches, show them as output
  let savedInput = consoleContentWorking;
  finalise();
  consoleContentFinal += "\n" + completionList.join("\n") + "\n";
  $print( await shellInit(environment) );
  finalise();
  consoleContentWorking = savedInput;
}

async function handleTab()
{
  let completionList = await shellCompletion(consoleContentWorking, environment);
  if (completionList.length === 1) {
    completeWithSingleMatch(completionList[0]);
  }
  else if (completionList.length > 1) {
    await completeWithMultipleMatches(completionList);
  }
  updateDisplay();
}

async function handleKeyDown(event)
{
  if ( !(event.metaKey || event.ctrlKey) ) {
    event.preventDefault();
  }

  // If busy, queue the keystroke for later
  if (isBusy) {
    keystrokeQueue.push(event);
    return;
  }

  // Handle printable characters & spaces
  if ( (event.key.length === 1 || event.keyCode === 32) &&
       !event.ctrlKey && !event.metaKey) {
    $print(event.key);
  }

  // Handle backspace
  else if (event.keyCode === 8) {
    consoleContentWorking = consoleContentWorking.slice(0, -1);
    updateDisplay();}

  // Handle delete
  else if (event.keyCode === 127) {
    // For simplicity, treating Delete like Backspace
    consoleContentWorking = consoleContentWorking.slice(0, -1);
    updateDisplay();
  }

  // Handle Enter
  else if (event.keyCode === 13) {
    await handleEnter();
  }

  // Handle Tab
  else if (event.keyCode === 9) {
    await handleTab();
  }

  // Handle cursor up arrow
  else if (event.keyCode === 38) {
    handleRecallCommandHistory(1);
  }
  // Handle cursor down arrow
  else if (event.keyCode === 40) {
    handleRecallCommandHistory(-1);
  }
}

async function handlePaste(event)
{
  event.preventDefault();

  // Get the pasted text from clipboard
  const pastedText = (event.clipboardData || window.clipboardData).getData("text");

  if (pastedText) {
    $print(pastedText);
  }
}

function replayQueuedKeystrokes()
{
  // copy and clear original queue
  const queue = keystrokeQueue.slice();
  keystrokeQueue = [];
  
  for (const event of queue)
  {
    // Don't replay Enter keys to avoid recursive command execution
    if (event.keyCode === 13) {
      continue;
    }

    // Replay each keystroke by processing it
    if ((event.key.length === 1 || event.keyCode === 32) &&
        !event.ctrlKey && !event.metaKey) {
      $print(event.key);
    }
    else if (event.keyCode === 8 || event.keyCode === 127) {
      consoleContentWorking = consoleContentWorking.slice(0, -1);
      updateDisplay();
    }
  }
}

async function runInit()
{
  // init
  $print( await shellInit(environment) );
  finalise();
}

terminalElement.addEventListener("keydown", handleKeyDown);

terminalElement.addEventListener("paste", handlePaste);

terminalElement.focus();

runInit();