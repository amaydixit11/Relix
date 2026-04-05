import { app, BrowserWindow, shell, dialog, ipcMain } from 'electron';
import * as path from 'path';
import { spawn, type ChildProcessWithoutNullStreams } from 'child_process';
import { existsSync, createWriteStream, mkdirSync } from 'fs';

const isDev = !app.isPackaged;
const DEFAULT_ACORDE_API_PORT = process.env.RELIX_ACORDE_API_PORT ?? '7331';
const DEFAULT_ACORDE_PORT = process.env.RELIX_ACORDE_PORT ?? '4001';
const DEV_SERVER_URL = process.env.RELIX_WEB_URL ?? 'http://localhost:3000';
const DEV_SERVER_TIMEOUT_MS = 30000;
const DEV_SERVER_POLL_MS = 500;
const DAEMON_HEALTH_POLL_MS = 5000;
const DAEMON_STARTUP_GRACE_MS = 15000;

let mainWindow: BrowserWindow | null = null;
let acordeProcess: ChildProcessWithoutNullStreams | null = null;
let acordeRestarted = false;
let isAppQuitting = false;
let daemonHealthTimer: NodeJS.Timeout | null = null;
let daemonStatus: 'starting' | 'healthy' | 'degraded' | 'missing-binary' = 'starting';
let daemonStatusMessage = 'Starting ACORDE daemon';
let daemonStartedAt = 0;
let daemonWasHealthy = false;

function getAcordeLogPath() {
  return path.join(app.getPath('userData'), 'acorde-data', 'acorde.log');
}

function getDaemonStatus() {
  return {
    status: daemonStatus,
    message: daemonStatusMessage,
    apiUrl: `http://localhost:${DEFAULT_ACORDE_API_PORT}`,
    logPath: getAcordeLogPath(),
  };
}

function updateDaemonStatus(
  status: typeof daemonStatus,
  message: string,
) {
  daemonStatus = status;
  daemonStatusMessage = message;
  if (mainWindow) {
    mainWindow.setTitle(`Relix [${status}]`);
    mainWindow.webContents.send('daemon-status', getDaemonStatus());
  }
}

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
    updateDaemonStatus(
      'missing-binary',
      'ACORDE binary not found. Set ACORDE_BIN or place the binary in the project root.',
    );
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
  daemonStartedAt = Date.now();
  daemonWasHealthy = false;
  updateDaemonStatus('starting', `Launching ACORDE from ${binary}`);

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
    updateDaemonStatus(
      isAppQuitting ? 'degraded' : 'starting',
      isAppQuitting
        ? 'ACORDE daemon stopped during app shutdown.'
        : 'ACORDE daemon exited unexpectedly. Attempting one restart.',
    );
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

async function pollDaemonHealth() {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 1500);
    const response = await fetch(`http://localhost:${DEFAULT_ACORDE_API_PORT}/status`, {
      method: 'GET',
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (response.ok) {
      daemonWasHealthy = true;
      updateDaemonStatus('healthy', 'ACORDE daemon reachable.');
      return;
    }

    if (!daemonWasHealthy && Date.now() - daemonStartedAt < DAEMON_STARTUP_GRACE_MS) {
      updateDaemonStatus('starting', 'Waiting for ACORDE daemon to finish starting.');
      return;
    }
    updateDaemonStatus('degraded', `ACORDE status probe failed with ${response.status}.`);
  } catch {
    if (!daemonWasHealthy && Date.now() - daemonStartedAt < DAEMON_STARTUP_GRACE_MS) {
      updateDaemonStatus('starting', 'Waiting for ACORDE daemon to finish starting.');
      return;
    }
    updateDaemonStatus('degraded', 'ACORDE daemon is not responding to /status.');
  }
}

function startDaemonHealthMonitor() {
  daemonHealthTimer?.unref?.();
  if (daemonHealthTimer) clearInterval(daemonHealthTimer);
  daemonHealthTimer = setInterval(() => {
    void pollDaemonHealth();
  }, DAEMON_HEALTH_POLL_MS);
  void pollDaemonHealth();
}

function stopDaemonHealthMonitor() {
  if (daemonHealthTimer) {
    clearInterval(daemonHealthTimer);
    daemonHealthTimer = null;
  }
}

function renderLoadingScreen(message: string) {
  if (!mainWindow) return;
  const daemon = getDaemonStatus();

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
          code {
            display: block;
            margin-top: 16px;
            padding: 10px 12px;
            border-radius: 10px;
            background: rgba(255,255,255,0.04);
            color: #d4d4d8;
            overflow-wrap: anywhere;
          }
        </style>
      </head>
      <body>
        <div class="wrap">
          <h1>Starting Relix</h1>
          <p>${message}</p>
          <code>Daemon: ${daemon.status}
${daemon.message}
Log: ${daemon.logPath}</code>
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

function registerIpcHandlers() {
  ipcMain.handle('get-version', () => app.getVersion());
  ipcMain.handle('get-daemon-status', () => getDaemonStatus());
  ipcMain.handle('get-daemon-log-path', () => getAcordeLogPath());
  ipcMain.handle('open-file', async () => null);
  ipcMain.handle('save-file', async () => null);
}

app.whenReady().then(() => {
  registerIpcHandlers();
  startAcordeDaemon();
  startDaemonHealthMonitor();
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
  stopDaemonHealthMonitor();
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
