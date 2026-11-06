"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const { WASI } = require("node:wasi");
const artifacts = process.argv.slice(2);
assert.ok(artifacts.length, "usage: node wasm_gate.js test-br.wasm [test-zstd.wasm ...]");
const executions = [];
for (const artifact of artifacts) {
    const bytes = fs.readFileSync(artifact);
    const compiled = new WebAssembly.Module(bytes);
    const imports = WebAssembly.Module.imports(compiled);
    for (const entry of imports) {
        assert.equal(entry.module, "wasi_snapshot_preview1");
        assert.equal(entry.kind, "function");
    }
    const wasi = new WASI({ version: "preview1", args: [artifact], env: {}, preopens: {}, returnOnExit: true });
    const instance = new WebAssembly.Instance(compiled, { wasi_snapshot_preview1: wasi.wasiImport });
    assert.equal(typeof instance.exports._start, "function");
    const status = wasi.start(instance);
    assert.equal(status, 0, artifact + " wide-size WASI tests failed");
    executions.push({
        wasm_path: fs.realpathSync(artifact), wasm_bytes: bytes.length, exit_code: status,
        wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"), imports,
    });
}
console.log(JSON.stringify({
    schema: "vort-br-zstd-wide-size-wasm-v1", status: "ok", utc: new Date().toISOString(),
    pointer_bits: 32, logical_counter_bits: 64, progress_counter_bits: 32,
    contract: "Brotli and Zstd wide decoded sizes, summary statistics, dictionaries and physical-buffer boundaries",
    node_version: process.version, executions,
    gate_sha256: crypto.createHash("sha256").update(fs.readFileSync(__filename)).digest("hex"),
    execution: "Actual filtered Zig WASI test runners",
}));
