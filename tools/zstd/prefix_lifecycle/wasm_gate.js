"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const { WASI } = require("node:wasi");
const paths = process.argv.slice(2);
assert.ok(paths.length, "usage: wasm_gate.js codec-tests.wasm [public-tests.wasm]");
const executions = [];
for (const path of paths) {
    const bytes = fs.readFileSync(path);
    const module = new WebAssembly.Module(bytes);
    for (const item of WebAssembly.Module.imports(module)) {
        assert.equal(item.module, "wasi_snapshot_preview1");
        assert.equal(item.kind, "function");
    }
    const wasi = new WASI({ version: "preview1", args: [path], env: {}, preopens: {}, returnOnExit: true });
    const instance = new WebAssembly.Instance(module, { wasi_snapshot_preview1: wasi.wasiImport });
    assert.equal(typeof instance.exports._start, "function");
    const status = wasi.start(instance);
    assert.equal(status, 0, path);
    executions.push({ path: fs.realpathSync(path), exit_code: status,
        sha256: crypto.createHash("sha256").update(bytes).digest("hex"), bytes: bytes.length });
}
console.log(JSON.stringify({ schema: "vort.zstd.prefix-lifecycle.wasm.v1", status: "ok",
    pointer_bits: 32, node_version: process.version, utc: new Date().toISOString(),
    actual_command: process.argv, executions }));
