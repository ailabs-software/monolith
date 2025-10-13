
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

async function handleEnter(event)
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
  
  event.preventDefault();
}

async function handleKeyDown(event)
{
  // If busy, queue the keystroke for later
  if (isBusy) {
    keystrokeQueue.push(event);
    event.preventDefault();
    return;
  }

  // Handle printable characters & spaces
  if ( (event.key.length === 1 || event.keyCode === 32) &&
       !event.ctrlKey && !event.metaKey) {
    $print(event.key);
    event.preventDefault();
  }

  // Handle backspace
  else if (event.keyCode === 8) {
    consoleContentWorking = consoleContentWorking.slice(0, -1);
    updateDisplay();
    event.preventDefault();
  }

  // Handle delete
  else if (event.keyCode === 127) {
    // For simplicity, treating Delete like Backspace
    consoleContentWorking = consoleContentWorking.slice(0, -1);
    updateDisplay();
    event.preventDefault();
  }

  // Handle Enter
  else if (event.keyCode === 13) {
    handleEnter(event);
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

terminalElement.addEventListener("keydown", handleKeyDown);

terminalElement.addEventListener("paste", handlePaste);

terminalElement.focus();

function replayQueuedKeystrokes()
{
  // copy and clear original queue
  const queue = keystrokeQueue.slice();
  keystrokeQueue = [];
  
  for (const event of queue) {
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

runInit();