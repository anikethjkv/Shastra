const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electronAPI', {
  platform: process.platform,
  openTerminal: () => ipcRenderer.send('open-terminal'),
});
