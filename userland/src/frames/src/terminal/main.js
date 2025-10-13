
/** @fileoverview Handle the terminal frame */

const CURSOR = "\u2588"

const terminalElement = document.getElementById("terminal");

let consoleContentFinal = "";
let consoleContentWorking = "";

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

  console.log(`running ${commandString}`);
  
  // Execute command through shell with streaming output
  await doExecute(commandString, (chunk) => {
    console.log("received chunk", chunk);
    // Check if this is a clear command (VT100 escape sequence)
    if (chunk.includes("\u001b[2J\u001b[H")) {
      consoleContentFinal = "";
      consoleContentWorking = "";
      updateDisplay();
    }
    else {
      $print(chunk);
    }
  });
  
  finalise();
  await runInit();
  event.preventDefault();
}

async function handleKeyDown(event)
{
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

async function runInit()
{
  // init
  $print( await doInit() );
  finalise();
}

runInit();