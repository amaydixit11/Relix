import { app, BrowserWindow, shell, dialog } from 'electron';
import * as path from 'path';
import { spawn, type ChildProcessWithoutNullStreams } from 'child_process';
import { existsSync, createWriteStream, mkdirSync } from 'fs';

const isDev = !app.isPackaged;
const DEFAULT_ACORDE_API_PORT = process.env.RELIX_ACORDE_API_PORT ?? '7331';
const DEFAULT_ACORDE_PORT = process.env.RELIX_ACORDE_PORT ?? '4001';
const DEV_SERVER_URL = process.env.RELIX_WEB_URL ?? 'http://localhost:3000';
const DEV_SERVER_TIMEOUT_MS = 30000;
const DEV_SERVER_POLL_MS = 500;

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

function renderLoadingScreen(message: string) {
  if (!mainWindow) return;

  const html = `
    <!doctype html>
    <html>
      <head>
        <meta charset="utf-8" />
        <title>Relix</title>
        <style>
          body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background: #0a0a0a;
            color: #fafafa;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 100vh;
          }
          .wrap {
            width: min(420px, 90vw);
            padding: 28px;
            border: 1px solid rgba(255,255,255,0.08);
            border-radius: 16px;
            background: rgba(255,255,255,0.03);
            box-shadow: 0 20px 40px rgba(0,0,0,0.35);
          }
          h1 {
            margin: 0 0 12px;
            font-size: 20px;
          }
          p {
            margin: 0;
            color: #a1a1aa;
            line-height: 1.5;
          }
        </style>
      </head>
      <body>
        <div class="wrap">
          <h1>Starting Relix</h1>
          <p>${message}</p>
        </div>
      </body>
    </html>
  `;

  void mainWindow.loadURL(`data:text/html;charset=utf-8,${encodeURIComponent(html)}`);
}

async function waitForDevServer(url: string, timeoutMs: number) {
  const deadline = Date.now() + timeoutMs;

  while (Date.now() < deadline) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 1500);
      const response = await fetch(url, {
        method: 'GET',
        signal: controller.signal,
      });
      clearTimeout(timeout);

      if (response.ok) return true;
    } catch {
      // Server is still starting up.
    }

    await new Promise((resolve) => setTimeout(resolve, DEV_SERVER_POLL_MS));
  }

  return false;
}

async function loadRenderer() {
  if (!mainWindow) return;

  if (isDev) {
    renderLoadingScreen('Waiting for the Next.js dev server on localhost:3000...');
    const ready = await waitForDevServer(DEV_SERVER_URL, DEV_SERVER_TIMEOUT_MS);

    if (!ready) {
      renderLoadingScreen(
        'The web app did not become ready in time. Keep `npm run dev` running and reload the Electron window once the site is available.'
      );
      return;
    }

    await mainWindow.loadURL(DEV_SERVER_URL);
    mainWindow.webContents.openDevTools();
    return;
  }

  await mainWindow.loadFile(path.join(__dirname, '../web-export/index.html'));
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

  mainWindow.webContents.on('did-fail-load', () => {
    if (isDev) {
      renderLoadingScreen(
        'Relix could not load the web UI yet. The dev server may still be compiling. It will retry when the window is reopened.'
      );
    }
  });

  void loadRenderer();

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
