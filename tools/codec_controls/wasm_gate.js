"use strict";
const fs = require("node:fs"), crypto = require("node:crypto"), assert = require("node:assert/strict");
const { WASI } = require("node:wasi");
const artifacts = process.argv.slice(2);
assert.ok(artifacts.length, "usage: node wasm_gate.js deflate-tests.wasm zstd-tests.wasm root-tests.wasm");
const executions = [];
for (const artifact of artifacts) {
    const bytes = fs.readFileSync(artifact), compiled = new WebAssembly.Module(bytes);
    const imports = WebAssembly.Module.imports(compiled);
    for (const entry of imports) { assert.equal(entry.module, "wasi_snapshot_preview1"); assert.equal(entry.kind, "function"); }
    const wasi = new WASI({ version: "preview1", args: [artifact], env: {}, preopens: {}, returnOnExit: true });
    const instance = new WebAssembly.Instance(compiled, { wasi_snapshot_preview1: wasi.wasiImport });
    assert.equal(typeof instance.exports._start, "function");
    const status = wasi.start(instance);
    assert.equal(status, 0, artifact + " codec controls WASI contracts failed");
    executions.push({ wasm_path: fs.realpathSync(artifact), exit_code: status,
        wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"), imports });
}
console.log(JSON.stringify({ schema: "vort-codec-format-controls-wasm-v1", status: "ok", utc: new Date().toISOString(),
    node_version: process.version, pointer_bits: 32, logical_counter_bits: 64,
    contract: "Zlib frame window controls and Zstd ignore-content-checksum public contracts", executions,
    gate_sha256: crypto.createHash("sha256").update(fs.readFileSync(__filename)).digest("hex") }));
