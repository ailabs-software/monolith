
/** @fileoverview Handle the terminal frame */

const CURSOR = "\u2588"

const terminalElement = document.getElementById("terminal");

let consoleContentFinal = "";
let consoleContentWorking = "";

// Busy mode: prevent race conditions during command execution
let isBusy = false;
let keystrokeQueue = [];

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

async function handleEnter()
{
  $print("\n");
  let commandString = consoleContentWorking.trimEnd();
  finalise();
  
  // Enter busy mode
  isBusy = true;
  
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
  await runInit();
  
  // Exit busy mode and replay queued keystrokes
  isBusy = false;
  replayQueuedKeystrokes();
}

function _completeWithSingleMatch(completion)
{
  // Single match, complete it by replacing the last word
  let parts = consoleContentWorking.trim().split(" ");
  parts[parts.length - 1] = completion;
  consoleContentWorking = parts.join(" ");
}

async function _completeWithMultipleMatches(completionList)
{
  // Multiple matches, show them as output
  let savedInput = consoleContentWorking;
  finalise();
  consoleContentFinal += "\n" + completionList.join("\n") + "\n";
  $print( await doInit() );
  finalise();
  consoleContentWorking = savedInput;
}

async function handleTab()
{
  let completionList = await doCompletion(consoleContentWorking);
  if (completionList.length === 1) {
    _completeWithSingleMatch(completionList[0]);
  }
  else if (completionList.length > 1) {
    await _completeWithMultipleMatches(completionList);
  }
  updateDisplay();
}

async function handleKeyDown(event)
{
  event.preventDefault();

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
  $print( await doInit() );
  finalise();
}

terminalElement.addEventListener("keydown", handleKeyDown);

terminalElement.addEventListener("paste", handlePaste);

terminalElement.focus();

runInit();