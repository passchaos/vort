"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const { WASI } = require("node:wasi");
const artifact = process.argv[2];
assert.ok(artifact, "usage: node wasm_gate.js tests.wasm");
const bytes = fs.readFileSync(artifact);
const moduleObject = new WebAssembly.Module(bytes);
for (const entry of WebAssembly.Module.imports(moduleObject)) {
    assert.equal(entry.module, "wasi_snapshot_preview1");
    assert.equal(entry.kind, "function");
}
const wasi = new WASI({ version: "preview1", args: [artifact], env: {}, preopens: {}, returnOnExit: true });
const instance = new WebAssembly.Instance(moduleObject, { wasi_snapshot_preview1: wasi.wasiImport });
assert.equal(typeof instance.exports._start, "function");
assert.equal(wasi.start(instance), 0, "wide decoder WASI contracts failed");
console.log(JSON.stringify({
    schema: "vort-deflate-wide-decode-wasm-v1", status: "ok", utc: new Date().toISOString(),
    pointer_bits: 32, logical_counter_bits: 64, progress_counter_bits: 32,
    contract: "Deflate wide decode stream counters and overflow transactions",
    wasm_path: fs.realpathSync(artifact), node_version: process.version,
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    execution: "Zig test runner with checked lawful-prefix and physical-suffix contracts",
}));
