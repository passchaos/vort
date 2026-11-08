"use strict";

const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const { WASI } = require("node:wasi");

const paths = process.argv.slice(2);
assert.equal(paths.length, 1, "usage: source_reverse_wasm_gate.js tests.wasm");

const executions = [];
for (const path of paths) {
    const bytes = fs.readFileSync(path);
    const module = new WebAssembly.Module(bytes);
    for (const item of WebAssembly.Module.imports(module)) {
        assert.equal(item.module, "wasi_snapshot_preview1");
        assert.equal(item.kind, "function");
    }
    const wasi = new WASI({
        version: "preview1",
        args: [path],
        env: {},
        preopens: {},
        returnOnExit: true,
    });
    const instance = new WebAssembly.Instance(module, {
        wasi_snapshot_preview1: wasi.wasiImport,
    });
    const status = wasi.start(instance);
    assert.equal(status, 0, path);
    executions.push({
        path,
        exit_code: status,
        bytes: bytes.length,
        sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    });
}

console.log(JSON.stringify({
    schema: "vort.zstd.source-primitives.wasm.v1",
    pointer_bits: 32,
    minimum_page_len: 9,
    coverage: ["reverse-bit-reader", "literals-layout"],
    status: "ok",
    executions,
}));
