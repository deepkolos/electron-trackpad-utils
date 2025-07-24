# electron-trackpad-utils-zh

[English](./README.en-US.md)


> 在 Electron on macOS 中触发触控板触觉反馈，并获取触控板滚动开始、滚动结束和强制点击事件。

[查看演示代码](demo)

## 安装

    npm install @deepkolos/electron-trackpad-utils

## API

**onTrackpadScrollBegan(callback)** (仅限 macOS)

- `callback` Function

当用户开始在触控板上拖动触摸时触发。

**onTrackpadScrollEnded(callback)** (仅限 macOS)

- `callback` Function

在滚动过程中触摸结束时触发。这可能与发送到浏览器的滚动事件结束的时间不同，例如在惯性滚动的情况下。

**onTrackpadScroll(callback)** (仅限 macOS)

- `callback` Function
  - `deltaX` Float
  - `deltaY` Float
  - `isTrackpad` Boolean

当用户在触控板上滚动时触发。

**onForceClick(callback)** (仅限 macOS)

- `callback` Function

**triggerFeedback()** (仅限 macOS)

在 MacBook 的内置触控板或妙控板上触发触觉反馈。例如，在拖动对象时对齐时触发反馈。

## 用法

在主进程中：

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

## 在 electron-vite 中使用

如果你正在使用 `electron-vite`，你需要将 C/C++ 插件配置为外部模块。

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

## 如何运行演示

克隆此存储库后，运行：

    npm install
    npm rebuild
    cd demo
    npm install
    npm start

## 许可证

MIT 许可证

## 原始仓库

[davidcann/electron-trackpad-utils](https://github.com/davidcann/electron-trackpad-utils)