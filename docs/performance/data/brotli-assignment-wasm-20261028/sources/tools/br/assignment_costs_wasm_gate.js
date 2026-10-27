const fs = require("node:fs");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const { WASI } = require("node:wasi");

const modules = process.argv.slice(2);
assert.equal(modules.length, 2);
for (const [index, path] of modules.entries()) {
    const bytes = fs.readFileSync(path);
    const moduleObject = new WebAssembly.Module(bytes);
    for (const entry of WebAssembly.Module.imports(moduleObject)) {
        assert.equal(entry.module, "wasi_snapshot_preview1");
        assert.equal(entry.kind, "function");
    }
    const wasi = new WASI({ version: "preview1", args: [path], env: {}, preopens: {}, returnOnExit: true });
    const instance = new WebAssembly.Instance(moduleObject, { wasi_snapshot_preview1: wasi.wasiImport });
    assert.equal(wasi.start(instance), 0);
    console.log(JSON.stringify({
        target: index === 0 ? "wasm32-wasi-generic" : "wasm32-wasi-simd128",
        node_version: process.version,
        wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
        exit_code: 0,
    }));
}
