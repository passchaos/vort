"use strict";

const fs = require("node:fs");
const { WASI } = require("node:wasi");

const [path, ...args] = process.argv.slice(2);
if (path === undefined) {
    console.error("usage: decode_window_cli_wasi.js <probe.wasm> [args...]");
    process.exit(2);
}

const wasi = new WASI({
    version: "preview1",
    args: [path, ...args],
    env: {},
    preopens: { ".": process.cwd() },
    returnOnExit: true,
});
const moduleBytes = fs.readFileSync(path);
const instance = new WebAssembly.Instance(new WebAssembly.Module(moduleBytes), {
    wasi_snapshot_preview1: wasi.wasiImport,
});
process.exitCode = wasi.start(instance);
