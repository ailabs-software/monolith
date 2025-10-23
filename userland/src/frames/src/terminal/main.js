
/** @fileoverview Handle the terminal frame */

const CURSOR = "\u2588"
const MAX_COMMAND_HISTORY_LEN = 1996;

const terminalElement = document.getElementById("terminal");

let consoleContentFinal = "";
let consoleContentWorking = "";
let consoleContentWorkingIndex = 0; // insertion/cursor index within consoleContentWorking

// Busy mode: prevent race conditions during command execution
let isBusy = false;
let keystrokeQueue = [];

// History of submitted commands
let commandHistory = [];
let commandHistoryPosition = 0; // relative to end

function updateDisplay()
{
  const before = consoleContentWorking.slice(0, consoleContentWorkingIndex);
  const after = consoleContentWorking.slice(consoleContentWorkingIndex);
  terminalElement.textContent = consoleContentFinal + before + CURSOR + after;
  // Scroll to bottom
  terminalElement.scrollTop = terminalElement.scrollHeight;
  // Keep cursor at end by refocusing
  terminalElement.focus();
}

function $print(string)
{
  // splice the given string at the current cursor position
  const before = consoleContentWorking.slice(0, consoleContentWorkingIndex);
  const after = consoleContentWorking.slice(consoleContentWorkingIndex);
  consoleContentWorking = before + string + after;
  consoleContentWorkingIndex += string.length;
  updateDisplay();
}

function resetCursorWithCurrentWorking()
{
  consoleContentWorkingIndex = consoleContentWorking.length;
}

function finalise()
{
  consoleContentFinal += consoleContentWorking;
  consoleContentWorking = "";
  consoleContentWorkingIndex = 0; // reset index on finalise
}

function addNewLineToFinaliseIfNecessary()
{
  if ( consoleContentFinal.length > 0 &&
       !consoleContentFinal.endsWith("\n") ) {
    consoleContentFinal += "\n";
  }
}

function clampContenWorkingIndex()
{
  consoleContentWorkingIndex = Math.max(0, Math.min(consoleContentWorkingIndex, consoleContentWorking.length));
}

function handleDeleteOrBackspace(offset)
{
  console.log(consoleContentWorking.slice(0, consoleContentWorkingIndex + offset), consoleContentWorking.slice(consoleContentWorkingIndex + offset + 1));
  consoleContentWorking = consoleContentWorking.slice(0, consoleContentWorkingIndex + offset) + consoleContentWorking.slice(consoleContentWorkingIndex + offset + 1);
  consoleContentWorkingIndex += offset;
  clampContenWorkingIndex();
  updateDisplay();
}

function handleBackspace()
{
  handleDeleteOrBackspace(-1);
}

function handleDelete()
{
  handleDeleteOrBackspace(1);
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
    resetCursorWithCurrentWorking();
    updateDisplay();
  }
}

async function handleEnter()
{
  resetCursorWithCurrentWorking();
  $print("\n");
  let commandString = consoleContentWorking.trimEnd();
  finalise();

  if (!commandString) {
    return;
  }

  // Enter busy mode
  isBusy = true;

  commandHistoryAdd(commandString);
  
  // Execute command through shell with streaming output
  for await (const response of shellExecuteStream(commandString, environment) )
  {
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

  addNewLineToFinaliseIfNecessary();
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
  resetCursorWithCurrentWorking();
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
  resetCursorWithCurrentWorking();
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

function _moveCursorHorizontally(direction)
{
  // clamp cursor index between 0 and length
  consoleContentWorkingIndex += direction;
  clampContenWorkingIndex();
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
    handleBackspace();
    event.preventDefault();
  }

  // Handle delete
  else if (event.keyCode === 127) {
    // Delete: remove char at cursor
    handleDelete();
    event.preventDefault();
  }

  // Handle Left Arrow
  else if (event.keyCode === 37) {
    _moveCursorHorizontally(-1);
    event.preventDefault();
  }

  // Handle Right Arrow
  else if (event.keyCode === 39) {
    _moveCursorHorizontally(1);
    event.preventDefault();
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
      if (event.keyCode === 8) {
        handleBackspace();
      } else {
        handleDelete();
      }
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