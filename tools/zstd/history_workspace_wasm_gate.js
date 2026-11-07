"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const { WASI } = require("node:wasi");
const paths = process.argv.slice(2);
assert.equal(paths.length, 2);
const executions = [];
for (const path of paths) {
    const bytes = fs.readFileSync(path);
    const module = new WebAssembly.Module(bytes);
    const wasi = new WASI({ version: "preview1", args: [path], env: {}, preopens: {}, returnOnExit: true });
    const instance = new WebAssembly.Instance(module, { wasi_snapshot_preview1: wasi.wasiImport });
    const status = wasi.start(instance);
    assert.equal(status, 0, path);
    executions.push({ path, exit_code: status, bytes: bytes.length, sha256: crypto.createHash("sha256").update(bytes).digest("hex") });
}
console.log(JSON.stringify({ schema: "vort.zstd.history-workspace.wasm.v1", pointer_bits: 32, status: "ok", executions }));
