import { contextBridge, ipcRenderer } from 'electron';

// Expose protected methods to renderer
contextBridge.exposeInMainWorld('electron', {
  // Platform info
  platform: process.platform,
  
  // App version
  getVersion: () => ipcRenderer.invoke('get-version'),
  getDaemonStatus: () => ipcRenderer.invoke('get-daemon-status'),
  getDaemonLogPath: () => ipcRenderer.invoke('get-daemon-log-path'),
  onDaemonStatus: (callback: (status: unknown) => void) => {
    const listener = (_event: Electron.IpcRendererEvent, payload: unknown) => {
      callback(payload);
    };
    ipcRenderer.on('daemon-status', listener);
    return () => ipcRenderer.removeListener('daemon-status', listener);
  },
  
  // File operations (future use)
  openFile: () => ipcRenderer.invoke('open-file'),
  saveFile: (data: string) => ipcRenderer.invoke('save-file', data),
  
  // Notifications
  showNotification: (title: string, body: string) => {
    new Notification(title, { body });
  },
});
