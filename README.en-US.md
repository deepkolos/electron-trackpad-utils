# electron-trackpad-utils

> Trigger trackpad haptic feedback and get trackpad scroll began, scroll ended, and force click events in Electron on macOS.

[See demo code](demo)

## Installing

    npm install @deepkolos/electron-trackpad-utils

## API

**onTrackpadScrollBegan(callback)** (macOS only)

- `callback` Function

This fires when the user starts dragging touches on the trackpad.

**onTrackpadScrollEnded(callback)** (macOS only)

- `callback` Function

This is triggered when the touches end during scrolling. This may be different from when the scroll events sent to the browser end, in the case of inertial scrolling.

**onTrackpadScroll(callback)** (macOS only)

- `callback` Function
  - `deltaX` Float
  - `deltaY` Float
  - `isTrackpad` Boolean

This fires when the user scrolls on the trackpad.

**onForceClick(callback)** (macOS only)

- `callback` Function

**triggerFeedback()** (macOS only)

Triggers haptic feedback on the MacBook's built-in trackpad or Magic Trackpad. For example, trigger feedback when snapping to alignment while dragging an object.

## Usage

In main process:

    const { BrowserWindow } = require("electron");
    const trackpadUtils = require("@deepkolos/electron-trackpad-utils");

    trackpadUtils.onTrackpadScrollBegan(() => {
    	console.log("onTrackpadScrollBegan");
    });

    trackpadUtils.onTrackpadScrollEnded(() => {
    	console.log("onTrackpadScrollEnded");
    });

    trackpadUtils.onTrackpadScroll(({ deltaX, deltaY }) => {
      console.log('onTrackpadScroll', { deltaX, deltaY });
    });

    trackpadUtils.onForceClick(() => {
    	console.log("onForceClick");
    });

    function createWindow() {
    	const mainWindow = new BrowserWindow({
    		height: 500,
    		width: 800,
    	});
    	mainWindow.webContents.loadFile("index.html");
    	setInterval(() => {
    		trackpadUtils.triggerFeedback();
    	}, 3000);
    }

    app.whenReady().then(() => createWindow());

## Usage with electron-vite

If you are using `electron-vite`, you need to configure the C/C++ addon as an external module.

```javascript
import { defineConfig } from 'electron-vite'

export default defineConfig({
  main: {
    build: {
      rollupOptions: {
        external: ['@deepkolos/electron-trackpad-utils']
      }
    }
  }
})
```

## How to Run Demo

After cloning this repository, run:

    npm install
    npm rebuild
    cd demo
    npm install
    npm start

## License

MIT License