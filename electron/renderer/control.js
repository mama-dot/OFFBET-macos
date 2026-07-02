"use strict";
// OFFBET native control panel — offline ON/OFF + PIN. Talks to the privileged
// helper through window.offbet (see preload.ts / IPC-CONTRACT.md). No network,
// no framework: this screen must work with the WebView and the internet down.

const api = window.offbet;

const el = (id) => document.getElementById(id);
const card = el("statusCard");
const shield = el("shield");
const stateTitle = el("stateTitle");
const stateSub = el("stateSub");
const toggle = el("toggle");
const toggleLabel = el("toggleLabel");

let current = null; // last status
let busy = false;

/** SHA-256 hex of the PIN. The helper stores/compares the same hex (Pin.swift). */
async function hashPin(pin) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(pin));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function markRow(id, ok, textOk, textNo) {
  const b = el(id);
  b.textContent = ok ? textOk : textNo;
  b.className = ok ? "ok" : "no";
}

function render(s) {
  current = s;
  const on = !!s.active;
  card.dataset.state = on ? "on" : "off";
  shield.textContent = on ? "🛡️" : "⚠️";
  stateTitle.textContent = on ? "Protection active" : "Protection désactivée";
  stateSub.textContent = on
    ? "OFFBET filtre les sites de jeux d'argent."
    : "Vous n'êtes plus protégé.";
  toggleLabel.textContent = on ? "Désactiver la protection" : "Activer la protection";
  toggle.disabled = false;

  markRow("dDns", s.dnsPinned, "Verrouillé", "Non");
  markRow("dPf", s.pfActive, "Actif", "Non");
  markRow("dBrowser", s.browserPolicy, "Verrouillés", "Non");
  el("dCount").textContent =
    typeof s.blocklistSize === "number" ? s.blocklistSize.toLocaleString("fr-FR") : "—";
  el("dCount").className = "";
  markRow("dSync", s.lastHeartbeatOk, "OK", "En attente");
}

function renderError() {
  card.dataset.state = "off";
  shield.textContent = "🔌";
  stateTitle.textContent = "Service indisponible";
  stateSub.textContent = "Le service de protection ne répond pas.";
  toggleLabel.textContent = "Réessayer";
  toggle.disabled = false;
}

async function refresh() {
  try {
    const s = await api.status();
    render(s);
  } catch {
    renderError();
  }
}

// ---- PIN modal ----
const overlay = el("overlay");
const pinInput = el("pinInput");
const pinTitle = el("pinTitle");
const pinSub = el("pinSub");
const pinError = el("pinError");
let pinResolve = null;

function askPin({ title, sub, confirm }) {
  pinTitle.textContent = title;
  pinSub.textContent = sub;
  el("pinConfirm").textContent = confirm;
  pinInput.value = "";
  pinError.classList.add("hidden");
  overlay.classList.remove("hidden");
  setTimeout(() => pinInput.focus(), 30);
  return new Promise((resolve) => (pinResolve = resolve));
}
function closePin(value) {
  overlay.classList.add("hidden");
  const r = pinResolve;
  pinResolve = null;
  if (r) r(value);
}
function pinFail(msg) {
  pinError.textContent = msg;
  pinError.classList.remove("hidden");
  pinInput.value = "";
  pinInput.focus();
}

el("pinCancel").addEventListener("click", () => closePin(null));
el("pinConfirm").addEventListener("click", () => submitPin());
pinInput.addEventListener("keydown", (e) => {
  if (e.key === "Enter") submitPin();
  if (e.key === "Escape") closePin(null);
});
function submitPin() {
  const v = pinInput.value.trim();
  if (v.length < 4) return pinFail("Le code doit comporter au moins 4 chiffres.");
  closePin(v);
}

// ---- toggle flow ----
async function onToggle() {
  if (busy) return;
  if (!current) return refresh();
  busy = true;
  toggle.disabled = true;
  try {
    if (current.active) {
      // Turning OFF requires the PIN.
      const pin = await askPin({
        title: "Désactiver la protection",
        sub: "Entrez votre code PIN pour désactiver OFFBET.",
        confirm: "Désactiver",
      });
      if (pin == null) return;
      const res = await api.disable(await hashPin(pin));
      if (res && res.ok) {
        await refresh();
      } else {
        overlay.classList.remove("hidden");
        pinFail("Code PIN incorrect.");
        return; // leave modal open for a retry
      }
    } else if (!current.pinSet) {
      // First activation: create a PIN so the user can't silently disable later.
      const pin = await askPin({
        title: "Créez votre code PIN",
        sub: "Il vous sera demandé pour désactiver la protection. Choisissez un code que vous ne partagez pas.",
        confirm: "Créer et activer",
      });
      if (pin == null) return;
      await api.pinSet(await hashPin(pin));
      await api.enable();
      await refresh();
    } else {
      await api.enable();
      await refresh();
    }
  } catch {
    renderError();
  } finally {
    busy = false;
    if (overlay.classList.contains("hidden")) toggle.disabled = false;
  }
}

toggle.addEventListener("click", onToggle);
el("refreshBtn").addEventListener("click", refresh);
el("accountBtn").addEventListener("click", () => api.openAccount && api.openAccount());

// Live-ish updates while the panel is open.
refresh();
setInterval(() => {
  if (!busy && overlay.classList.contains("hidden")) refresh();
}, 5000);
