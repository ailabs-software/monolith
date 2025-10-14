
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
  event.preventDefault();
}

async function handleTab()
{
  let completion = await doCompletion(consoleContentWorking);
  if (!completion || completion.trim() === "") {
    console.log("no completion", completion);
    return; // No completions
  }
  
  let completionList = completion.split("\n").filter(c => c.trim());

  if (completionList.length === 1) {
    console.log("one completion", completionList);
    // Single match, complete it by replacing the last word
    let parts = consoleContentWorking.trim().split(" ");
    parts[parts.length - 1] = completionList[0];
    consoleContentWorking = parts.join(" ");
  }
  else if (completionList.length > 1) {
    console.log("multiple completion", completionList);
    // Multiple matches, show them as output
    let savedInput = consoleContentWorking;
    finalise();
    consoleContentFinal += "\n" + completion + "\n";
    $print( await doInit() );
    finalise();
    consoleContentWorking = savedInput;
  }

  updateDisplay();
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
    await handleEnter(event);
  }

  // Handle Tab
  else if (event.keyCode === 9) {
    await handleTab(event);
    event.preventDefault();
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