
const framesContainer = document.getElementById("frames_container");
const frameLauncher = document.getElementById("frame_launcher");
const framesInstances = [];

class FrameDragger
{
  constructor(frame)
  {
    this.frame = frame;
    this.offsetX = 0;
    this.offsetY = 0;
    this.isDragging = false;
    // bind events
    this.frame.titleBar.addEventListener("mousedown", this.handleMousedown.bind(this));
    // Use document for mousemove and mouseup to handle cases where mouse leaves element
    document.addEventListener("mousemove", this.handleMousemove.bind(this));
    document.addEventListener("mouseup", this.handleMouseup.bind(this));
    // Set initial cursor style
    this.frame.titleBar.style.cursor = "grab";
  }

  handleMousedown(e)
  {
    this.isDragging = true;
    // Calculate offset between mouse position and element position
    this.offsetX = e.clientX - this.frame.element.offsetLeft;
    this.offsetY = e.clientY - this.frame.element.offsetTop;
    // Change cursor to indicate dragging
    this.frame.titleBar.style.cursor = "grabbing";
    // Prevent text selection during drag
    e.preventDefault();
  }

  handleMousemove(e)
  {
    if (this.isDragging) {
      // Calculate new position
      const newX = e.clientX - this.offsetX;
      const newY = e.clientY - this.offsetY;
      // Update element position
      this.frame.setPosition(newX, newY);
    }
  }

  handleMouseup(e)
  {
    if (this.isDragging) {
      this.isDragging = false;
      this.frame.titleBar.style.cursor = "grab";
    }
  }
}

class Frame
{
  constructor(name)
  {
    framesInstances.push(this);
    this.name = name;
    this.element = document.createElement("div");
    this.element.className = "frame";
    this._buildTitleBar();
    this._buildFrame();
    new FrameDragger(this);
    // init size
    this.element.style.width = 800 + "px";
    this.element.style.height = 600 + "px";
    // init position z, x, y
    this.sendToFront();
    this.setPosition(20, 20);
  }

  _buildTitleBar()
  {
    this.titleBar = document.createElement("div");
    this.titleBar.className = "title_bar";
    this.titleBar.textContent = this.name;
    // add close button
    let closeButton= document.createElement("button");
    closeButton.textContent = "✖";
    this.titleBar.appendChild(closeButton);
    // add max max button
    let minMaxButton= document.createElement("button");
    minMaxButton.textContent = "☐";
    this.titleBar.appendChild(minMaxButton);
    this.element.appendChild(this.titleBar);
    // bind events
    minMaxButton.addEventListener("click", this.toggleMaximised.bind(this));
    closeButton.addEventListener("click", this.close.bind(this));
    this.titleBar.addEventListener("mousedown", this.sendToFront.bind(this));
  }

  _buildFrame()
  {
    this.iframe = document.createElement("iframe");
    this.iframe.src = "/~/system/frames/" + this.name + "/main.html";
    this.element.appendChild(this.iframe);
  }

  sendToFront()
  {
    framesInstances.forEach( frame => frame.element.style.zIndex = "0" );
    this.element.style.zIndex = "1";
  }

  setPosition(x, y)
  {
    this.element.style.left = x + "px";
    this.element.style.top = y + "px";
  }

  toggleMaximised()
  {
    if ( this.element.classList.contains("maximised") ) {
      this.element.classList.remove("maximised");
    }
    else {
      this.element.classList.add("maximised");
    }
  }

  close()
  {
    framesInstances.splice(framesInstances.indexOf(this), 1);
    this.element.remove();
  }
}

class FrameButton
{
  constructor(name)
  {
    this.name = name;
    this.element = document.createElement("button");
    this.element.textContent = name;
    // bind events
    this.element.addEventListener("click", this._handleAction.bind(this));
  }

  _handleAction()
  {
    let frame = new Frame(this.name);
    framesContainer.appendChild(frame.element);
  }
}

async function _load()
{
  let frameNames = ( await shellExecute("ls /system/frames/") ).trim().split("\n");

  for (let frameName of frameNames)
  {
    let frameButton = new FrameButton(frameName);
    frameLauncher.appendChild( frameButton.element );
  }
}

_load();