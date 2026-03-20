const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const { spawn } = require('child_process');

// Determine if we're in development mode
const isDev = process.env.NODE_ENV === 'development';

// Disable GPU acceleration for Raspberry Pi compatibility
app.disableHardwareAcceleration();
app.commandLine.appendSwitch('disable-gpu');
app.commandLine.appendSwitch('disable-software-rasterizer');

// IPC: Open system terminal
ipcMain.on('open-terminal', () => {
  // Try common Linux terminal emulators in order of preference
  const terminals = [
    { cmd: 'lxterminal', args: [] },           // Pi OS default
    { cmd: 'x-terminal-emulator', args: [] },  // Debian default
    { cmd: 'xterm', args: [] },                // Fallback
  ];

  for (const t of terminals) {
    try {
      const proc = spawn(t.cmd, t.args, { detached: true, stdio: 'ignore' });
      proc.unref();
      return;
    } catch {
      continue;
    }
  }
});

function createWindow() {
  const win = new BrowserWindow({
    width: 1024,
    height: 600,
    fullscreen: !isDev,
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  if (isDev) {
    win.loadURL('http://localhost:5173');
    win.webContents.openDevTools({ mode: 'detach' });
  } else {
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
