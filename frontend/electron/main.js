const { app, BrowserWindow } = require('electron');
const path = require('path');

// Determine if we're in development mode
const isDev = process.env.NODE_ENV === 'development';

// Disable GPU acceleration for Raspberry Pi compatibility
// Fixes: "failed to export buffer to dma_buf" errors
app.disableHardwareAcceleration();
app.commandLine.appendSwitch('disable-gpu');
app.commandLine.appendSwitch('disable-software-rasterizer');

function createWindow() {
  const win = new BrowserWindow({
    width: 1024,
    height: 600,
    fullscreen: !isDev,            // Fullscreen on Pi, windowed in dev
    autoHideMenuBar: true,         // Hide menu bar for kiosk feel
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (isDev) {
    // In development, load from Vite dev server
    win.loadURL('http://localhost:5173');
    win.webContents.openDevTools({ mode: 'detach' });
  } else {
    // In production, load the built frontend
    win.loadFile(path.join(__dirname, '..', 'dist', 'index.html'));
  }
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  app.quit();
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
