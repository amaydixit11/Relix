import { contextBridge, ipcRenderer } from 'electron';

// Expose protected methods to renderer
contextBridge.exposeInMainWorld('electron', {
  // Platform info
  platform: process.platform,
  
  // App version
  getVersion: () => ipcRenderer.invoke('get-version'),
  
  // File operations (future use)
  openFile: () => ipcRenderer.invoke('open-file'),
  saveFile: (data: string) => ipcRenderer.invoke('save-file', data),
  
  // Notifications
  showNotification: (title: string, body: string) => {
    new Notification(title, { body });
  },
});
