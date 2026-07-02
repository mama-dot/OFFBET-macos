import { contextBridge, ipcRenderer } from "electron";

// Exposes a minimal, audited surface to the web app + native screens.
// The web app (my.offbet.app) can call these to read/drive protection state.
// NOTE: only the fixed verbs below — no arbitrary command passthrough.
contextBridge.exposeInMainWorld("offbet", {
  status: () => ipcRenderer.invoke("offbet:status"),
  enable: () => ipcRenderer.invoke("offbet:enable"),
  disable: (pinToken: string) => ipcRenderer.invoke("offbet:disable", pinToken),
  pinVerify: (candidateHash: string) => ipcRenderer.invoke("offbet:pin.verify", candidateHash),
  uninstallRequest: () => ipcRenderer.invoke("offbet:uninstall.request"),
  // TODO(mac): onState / onIncident push events (ipcRenderer.on) for live UI.
});
