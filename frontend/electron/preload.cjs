const { contextBridge } = require('electron');

// Minimal preload — keeps renderer sandboxed.
// Extend here if you need to expose Node APIs to the renderer later.
contextBridge.exposeInMainWorld('electronAPI', {
  platform: process.platform,
});
