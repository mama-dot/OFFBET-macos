import { app, BrowserWindow, ipcMain } from "electron";
import * as path from "path";
import { DASHBOARD_URL, LOGIN_URL } from "./config";
import { HelperClient } from "./ipc/helperClient";

// OFFBET macOS shell — "maximum webapp": one window renders my.offbet.app
// (account/settings/Companion/Chronobet/Stripe). Native-feel local windows
// (ON/OFF, PIN, Chronobet timer) talk to the privileged helper over IPC.
//
// TODO(mac): register the helper as an SMAppService daemon on first run
//            (requires the Swift side + entitlements; do it from a small
//            native bridge or a Swift launcher, see helper/).

const helper = new HelperClient();
let mainWindow: BrowserWindow | null = null;

function createMainWindow(): void {
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

  // TODO(mac): decide initial URL from auth state (token present → dashboard,
  // else login) — mirror the Android/Windows logic.
  void mainWindow.loadURL(DASHBOARD_URL).catch(() => mainWindow?.loadURL(LOGIN_URL));
}

// --- IPC bridge: renderer → helper (see docs/IPC-CONTRACT.md) ---
ipcMain.handle("offbet:status", () => helper.status());
ipcMain.handle("offbet:enable", () => helper.enable());
ipcMain.handle("offbet:disable", (_e, pinToken: string) => helper.disable(pinToken));
ipcMain.handle("offbet:pin.verify", (_e, candidateHash: string) => helper.pinVerify(candidateHash));
ipcMain.handle("offbet:chronobet.start", (_e, sites: string[], durationSec: number) =>
  helper.chronobetStart(sites, durationSec),
);
ipcMain.handle("offbet:chronobet.stop", () => helper.chronobetStop());
ipcMain.handle("offbet:uninstall.request", () => helper.uninstallRequest());

app.whenReady().then(() => {
  // TODO(mac): if no helper is registered/running, prompt to install it
  //            (SMAppService.daemon(...).register()).
  createMainWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createMainWindow();
  });
});

app.on("window-all-closed", () => {
  // OFFBET keeps protecting via the daemon even with no window — only quit the UI.
  if (process.platform !== "darwin") app.quit();
});

// TODO(mac): native ON/OFF, PIN-entry and Chronobet-timer windows
//            (small local HTML windows, offline-capable — must NOT depend on
//            the WebView/network). See ARCHITECTURE.md §5.
