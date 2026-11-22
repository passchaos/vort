"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const { WASI } = require("node:wasi");

const args = process.argv.slice(2);
assert.ok(args.length > 0 && args.length % 3 === 0,
    "usage: node wasi_test_gate.js label test-filter tests.wasm [label test-filter tests.wasm ...]");

const results = [];
for (let i = 0; i < args.length; i += 3) {
    const [label, filter, artifact] = args.slice(i, i + 3);
    const bytes = fs.readFileSync(artifact);
    const compiled = new WebAssembly.Module(bytes);
    const imports = WebAssembly.Module.imports(compiled);
    for (const entry of imports) {
        assert.equal(entry.module, "wasi_snapshot_preview1", "unexpected non-WASI import");
        assert.equal(entry.kind, "function", "unexpected non-function import");
    }
    const wasi = new WASI({
        version: "preview1", args: [artifact], env: {}, preopens: {}, returnOnExit: true,
    });
    const instance = new WebAssembly.Instance(compiled, { wasi_snapshot_preview1: wasi.wasiImport });
    assert.equal(typeof instance.exports._start, "function", "missing Zig test runner entry point");
    const exitCode = wasi.start(instance);
    assert.equal(exitCode, 0, `${label} WASI tests failed`);
    results.push({
        label, test_filter: filter, wasm_path: fs.realpathSync(artifact),
        wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
        wasm_bytes: bytes.length, exit_code: exitCode, imports,
    });
}

process.stdout.write(JSON.stringify({
    schema: "vort-wasi-tests-v1", status: "ok", utc: new Date().toISOString(),
    pointer_bits: 32, node_version: process.version,
    execution: "Zig test runner through WASI _start", results,
}, null, 2) + "\n");
