"use strict";
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const { WASI } = require("node:wasi");

const artifact = process.argv[2];
assert.ok(artifact, "usage: node wasm_gate.js tests.wasm");
assert.equal(process.argv.length, 3, "usage: node wasm_gate.js tests.wasm");
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
assert.equal(exitCode, 0, "Brotli decode memory WASI contracts failed");

const hash = (data) => crypto.createHash("sha256").update(data).digest("hex");
const projectRoot = path.resolve(__dirname, "../../..");
process.stdout.write(JSON.stringify({
    schema: "vort-brotli-decode-memory-wasm-v1",
    status: "ok",
    utc: new Date().toISOString(),
    pointer_bits: 32,
    stack_bytes: 8 * 1024 * 1024,
    node_version: process.version,
    wasm_path: fs.realpathSync(artifact),
    wasm_sha256: hash(bytes),
    wasm_bytes: bytes.length,
    library_source_sha256: hash(fs.readFileSync(path.join(projectRoot, "src/br.zig"))),
    build_source_sha256: hash(fs.readFileSync(path.join(projectRoot, "build/br_decode_memory.zig"))),
    gate_sha256: hash(fs.readFileSync(__filename)),
    test_filters: ["Brotli decode total memory", "Brotli incremental decode policy"],
    execution: "Zig test runner through WASI _start",
    exit_code: exitCode,
    imports,
}, null, 2) + "\n");
