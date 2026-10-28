const fs = require("node:fs");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { WASI } = require("node:wasi");
const path = process.argv[2];
const bytes = fs.readFileSync(path);
const moduleObject = new WebAssembly.Module(bytes);
for (const entry of WebAssembly.Module.imports(moduleObject)) {
    assert.equal(entry.module, "wasi_snapshot_preview1");
    assert.equal(entry.kind, "function");
}
const wasi = new WASI({ version: "preview1", args: [path, ...process.argv.slice(3)], env: {}, preopens: {}, returnOnExit: true });
const instance = new WebAssembly.Instance(moduleObject, { wasi_snapshot_preview1: wasi.wasiImport });
const status = wasi.start(instance);
assert.equal(typeof status, "number");
console.log(JSON.stringify({ target: "wasm32-wasi", node_version: process.version,
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"), exit_code: status }));
process.exitCode = status;
