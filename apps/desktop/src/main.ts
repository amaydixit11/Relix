import { app, BrowserWindow, shell, dialog } from 'electron';
import * as path from 'path';
import { spawn, type ChildProcessWithoutNullStreams } from 'child_process';
import { existsSync, createWriteStream, mkdirSync } from 'fs';

const isDev = !app.isPackaged;
const DEFAULT_ACORDE_API_PORT = process.env.RELIX_ACORDE_API_PORT ?? '7331';
const DEFAULT_ACORDE_PORT = process.env.RELIX_ACORDE_PORT ?? '4001';

let mainWindow: BrowserWindow | null = null;
let acordeProcess: ChildProcessWithoutNullStreams | null = null;
let acordeRestarted = false;
let isAppQuitting = false;

function resolveAcordeBinary() {
  const candidates = [
    process.env.ACORDE_BIN,
    path.resolve(app.getAppPath(), '../../acorde'),
    path.resolve(app.getAppPath(), 'acorde'),
    path.resolve(process.cwd(), 'acorde'),
  ].filter((value): value is string => Boolean(value));

  return candidates.find((candidate) => existsSync(candidate)) ?? null;
}

function startAcordeDaemon() {
  if (acordeProcess) return;

  const binary = resolveAcordeBinary();
  if (!binary) {
    dialog.showErrorBox(
      'ACORDE Binary Missing',
      'Relix could not find the ACORDE daemon binary. Set ACORDE_BIN or place the acorde binary in the project root.'
    );
    return;
  }

  const dataDir = path.join(app.getPath('userData'), 'acorde-data');
  mkdirSync(dataDir, { recursive: true });

  const logFile = path.join(dataDir, 'acorde.log');
  const logStream = createWriteStream(logFile, { flags: 'a' });

  acordeProcess = spawn(
    binary,
    [
      'daemon',
      '--data',
      dataDir,
      '--port',
      DEFAULT_ACORDE_PORT,
      '--api-port',
      DEFAULT_ACORDE_API_PORT,
    ],
    {
      stdio: 'pipe',
    }
  );

  acordeProcess.stdout.pipe(logStream);
  acordeProcess.stderr.pipe(logStream);

  acordeProcess.on('exit', () => {
    acordeProcess = null;
    if (!isAppQuitting && !acordeRestarted) {
      acordeRestarted = true;
      startAcordeDaemon();
    }
  });
}

function stopAcordeDaemon() {
  if (!acordeProcess) return;
  acordeProcess.kill();
  acordeProcess = null;
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 600,
    titleBarStyle: 'hiddenInset',
    backgroundColor: '#0a0a0a',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      preload: path.join(__dirname, 'preload.js'),
    },
  });

  // Load the web app
  if (isDev) {
    // Development: load from Next.js dev server
    mainWindow.loadURL('http://localhost:3000');
    mainWindow.webContents.openDevTools();
  } else {
    // Production: load the exported Next.js static files
    mainWindow.loadFile(path.join(__dirname, '../web-export/index.html'));
  }

  // Handle external links
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: 'deny' };
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  startAcordeDaemon();
  createWindow();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (mainWindow === null) {
    createWindow();
  }
});

app.on('before-quit', () => {
  isAppQuitting = true;
  stopAcordeDaemon();
});

// Security: Disable navigation to external URLs
app.on('web-contents-created', (_, contents) => {
  contents.on('will-navigate', (event, url) => {
    if (!url.startsWith('http://localhost') && !url.startsWith('file://')) {
      event.preventDefault();
    }
  });
});
