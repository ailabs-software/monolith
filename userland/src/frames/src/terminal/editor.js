
/** @fileoverview Simple textarea-based text editor */

// Editor state
let editorMode = false;
let editorFilename = "";
let editorTextarea = null;

function showMessage(text, isError = false)
{
  const msg = document.createElement("div");
  msg.id = "save-message";
  msg.textContent = text;
  if (isError) {
    msg.style.backgroundColor = "#f44336";
  }
  document.body.appendChild(msg);
  setTimeout(() => msg.remove(), isError ? 2000 : 1500);
}

async function handleEditCommand(filename)
{
  if (!filename) {
    $print("Usage: edit <filename>\n");
    return;
  }

  editorFilename = filename;
  editorMode = true;

  // Read file content if it exists
  let fileContent = "";
  try {
    const cwd = environment.CWD || "/";
    const filePath = filename.startsWith("/") 
      ? filename 
      : (cwd === "/" ? `/${filename}` : `${cwd}/${filename}`);
    const response = await fetch(`/~${filePath}`);
    if (response.ok) {
      fileContent = await response.text();
    }
  } catch (e) {
    // File doesn't exist, start with empty content
  }

  // Hide terminal, show editor
  terminalElement.style.display = "none";

  // Create textarea
  editorTextarea = document.createElement("textarea");
  editorTextarea.id = "editor";
  editorTextarea.value = fileContent;
  document.body.appendChild(editorTextarea);
  editorTextarea.focus();

  // Add save handler (Ctrl+S or Cmd+S)
  editorTextarea.addEventListener("keydown", handleEditorKeyDown);
}

async function handleEditorKeyDown(event)
{
  // Save: Ctrl+S or Cmd+S
  if ((event.ctrlKey || event.metaKey) && event.key === "s") {
    event.preventDefault();
    await saveEditorContent();
  }
  // Exit: Escape
  else if (event.key === "Escape") {
    event.preventDefault();
    exitEditor();
  }
}

async function saveEditorContent()
{
  const content = editorTextarea.value;
  const cwd = environment.CWD || "/";
  const filePath = editorFilename.startsWith("/") 
    ? editorFilename 
    : (cwd === "/" ? `/${editorFilename}` : `${cwd}/${editorFilename}`);

  try {
    const response = await fetch(`/~${filePath}`, {
      method: "PUT",
      body: content
    });

    if (response.ok) {
      showMessage(`Saved ${editorFilename}`);
    } else {
      showMessage(`Failed to save: ${response.status}`, true);
    }
  } catch (e) {
    console.error("Failed to save file:", e);
    showMessage(`Error: ${e.message}`, true);
  }
}

function exitEditor()
{
  if (editorTextarea) {
    editorTextarea.remove();
    editorTextarea = null;
  }

  editorMode = false;
  editorFilename = "";

  // Show terminal again
  terminalElement.style.display = "block";
  terminalElement.focus();
}
