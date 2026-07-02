"use strict";
// Unit tests for the shared PIN hashing (renderer/pinhash.js). Runs on plain
// Node (webcrypto), no Electron/DOM needed:  npm test
const test = require("node:test");
const assert = require("node:assert");
const crypto = require("node:crypto");
const { offbetHashPin } = require("../renderer/pinhash.js");

test("known SHA-256 vector for '1234'", async () => {
  assert.strictEqual(
    await offbetHashPin("1234"),
    "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4"
  );
});

test("matches an independent SHA-256 implementation", async () => {
  for (const pin of ["0000", "927461", "13", "99887766"]) {
    const expected = crypto.createHash("sha256").update(pin).digest("hex");
    assert.strictEqual(await offbetHashPin(pin), expected, `pin=${pin}`);
  }
});

test("output is lowercase hex, 64 chars", async () => {
  const h = await offbetHashPin("4242");
  assert.match(h, /^[0-9a-f]{64}$/);
});

test("numeric and string PINs hash identically", async () => {
  assert.strictEqual(await offbetHashPin(1234), await offbetHashPin("1234"));
});

test("different PINs produce different hashes", async () => {
  assert.notStrictEqual(await offbetHashPin("1234"), await offbetHashPin("1235"));
});
