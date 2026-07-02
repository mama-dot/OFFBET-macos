import { app, BrowserWindow, Tray, Menu, nativeImage, ipcMain, shell } from "electron";
import * as path from "path";
import { DASHBOARD_URL, LOGIN_URL } from "./config";
import { HelperClient } from "./ipc/helperClient";

// OFFBET macOS shell — "maximum webapp": the main window renders my.offbet.app
// (account / settings / Companion / Stripe). A menu-bar (Tray) item opens the
// native, offline **protection panel** (ON/OFF + PIN) that talks to the
// privileged helper over IPC and must work with the network down.

const helper = new HelperClient();
let mainWindow: BrowserWindow | null = null;
let controlWindow: BrowserWindow | null = null;
let tray: Tray | null = null;

const rendererDir = path.join(app.getAppPath(), "renderer");

// ---- main web window (the webapp) ----
function createMainWindow(): void {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.show();
    mainWindow.focus();
    return;
  }
  mainWindow = new BrowserWindow({
    width: 1100,
    height: 760,
    titleBarStyle: "hiddenInset",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  // TODO(mac): pick dashboard vs login from auth state, like Android/Windows.
  void mainWindow.loadURL(DASHBOARD_URL).catch(() => mainWindow?.loadURL(LOGIN_URL));
  mainWindow.on("closed", () => (mainWindow = null));
}

// ---- native protection panel (local, offline) ----
function createControlWindow(): BrowserWindow {
  const win = new BrowserWindow({
    width: 320,
    height: 500,
    show: false,
    frame: false,
    resizable: false,
    fullscreenable: false,
    skipTaskbar: true,
    vibrancy: "under-window",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  void win.loadFile(path.join(rendererDir, "control.html"));
  // Popover feel: hide when it loses focus.
  win.on("blur", () => win.hide());
  win.on("closed", () => (controlWindow = null));
  return win;
}

function positionControlUnderTray(win: BrowserWindow): void {
  if (!tray) return;
  const t = tray.getBounds();
  const w = win.getBounds();
  const x = Math.round(t.x + t.width / 2 - w.width / 2);
  const y = Math.round(t.y + t.height + 4);
  win.setPosition(x, Math.max(y, 24), false);
}

function toggleControlWindow(): void {
  if (!controlWindow || controlWindow.isDestroyed()) controlWindow = createControlWindow();
  if (controlWindow.isVisible()) {
    controlWindow.hide();
    return;
  }
  positionControlUnderTray(controlWindow);
  controlWindow.show();
  controlWindow.focus();
}

// ---- tray (menu bar) ----
function trayIcon(active: boolean): Electron.NativeImage {
  // System status dots — no asset to ship, correct in light & dark menu bars.
  return nativeImage.createFromNamedImage(
    active ? "NSStatusAvailable" : "NSStatusUnavailable",
    [0, 0, 0]
  );
}

function buildTray(): void {
  tray = new Tray(trayIcon(false));
  tray.setToolTip("OFFBET — protection");
  tray.on("click", () => toggleControlWindow());
  tray.on("right-click", () => {
    const menu = Menu.buildFromTemplate([
      { label: "Panneau de protection", click: () => toggleControlWindow() },
      { label: "Mon compte (OFFBET)", click: () => createMainWindow() },
      { type: "separator" },
      { label: "Quitter OFFBET", role: "quit" },
    ]);
    tray?.popUpContextMenu(menu);
  });
  void refreshTrayState();
  setInterval(refreshTrayState, 15000);
}

async function refreshTrayState(): Promise<void> {
  if (!tray) return;
  try {
    const s = await helper.status();
    tray.setImage(trayIcon(!!s.active));
    tray.setToolTip(s.active ? "OFFBET — protection active" : "OFFBET — protection désactivée");
  } catch {
    tray.setToolTip("OFFBET — service indisponible");
  }
}

// ---- IPC bridge: renderer → helper (see docs/IPC-CONTRACT.md) ----
ipcMain.handle("offbet:status", () => helper.status());
ipcMain.handle("offbet:enable", async () => {
  const r = await helper.enable();
  void refreshTrayState();
  return r;
});
ipcMain.handle("offbet:disable", async (_e, pinToken: string) => {
  const r = await helper.disable(pinToken);
  void refreshTrayState();
  return r;
});
ipcMain.handle("offbet:pin.set", (_e, hash: string) => helper.pinSet(hash));
ipcMain.handle("offbet:pin.verify", (_e, candidateHash: string) => helper.pinVerify(candidateHash));
ipcMain.handle("offbet:blocklist.refresh", () => helper.blocklistRefresh());
ipcMain.handle("offbet:uninstall.request", () => helper.uninstallRequest());
ipcMain.handle("offbet:open-account", () => {
  controlWindow?.hide();
  createMainWindow();
});

// ---- lifecycle ----
app.whenReady().then(() => {
  // TODO(mac): if no helper is registered/running, prompt to install it
  //            (SMAppService.daemon(...).register() on macOS 13+).
  buildTray();
  createMainWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
  });
});

app.on("window-all-closed", () => {
  // OFFBET keeps protecting via the daemon + tray even with no window open.
  // Do not quit on macOS — the menu-bar item stays the always-on control.
});

// Open external links (Stripe, help) in the system browser, not inside the shell.
app.on("web-contents-created", (_e, contents) => {
  contents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith("https://my.offbet.app")) return { action: "allow" };
    void shell.openExternal(url);
    return { action: "deny" };
  });
});
