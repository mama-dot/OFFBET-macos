"use strict";
// SHA-256 hex of a PIN. Shared verbatim by the native panel (browser
// crypto.subtle) and the unit tests (Node webcrypto). The helper stores and
// compares the SAME hex (Pin.swift), and the other platforms must too — so this
// function is the single source of truth for the PIN hashing and must not drift.
async function offbetHashPin(pin) {
  const data = new TextEncoder().encode(String(pin));
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

if (typeof module !== "undefined" && module.exports) module.exports = { offbetHashPin };
if (typeof window !== "undefined") window.offbetHashPin = offbetHashPin;
