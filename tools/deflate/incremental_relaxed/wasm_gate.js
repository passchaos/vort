"use strict";
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const artifact = process.argv[2];
assert.ok(artifact, "usage: node wasm_gate.js artifact.wasm [report.json]");
const bytes = fs.readFileSync(artifact);
const compiled = new WebAssembly.Module(bytes);
const imports = WebAssembly.Module.imports(compiled);
for (const entry of imports) {
    assert.equal(entry.module, "wasi_snapshot_preview1");
    assert.equal(entry.kind, "function");
}
let wasi;
let host = {};
if (imports.length) {
    const { WASI } = require("node:wasi");
    wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {}, returnOnExit: true });
    host = { wasi_snapshot_preview1: wasi.wasiImport };
}
const instance = new WebAssembly.Instance(compiled, host);
if (wasi) {
    if (typeof instance.exports._start === "function") assert.equal(wasi.start(instance), 0);
    else wasi.initialize(instance);
}
const api = instance.exports;
for (const name of ["Footer", "Members", "Headers", "Progress"]) {
    assert.equal(typeof api[`deflateRelaxedWasm${name}`], "function");
    assert.equal(api[`deflateRelaxedWasm${name}`](), 0, `${name} contract failed`);
}
assert.equal(typeof api.deflateRelaxedWasmReport, "function");
const value = (i) => api.deflateRelaxedWasmReport(i);
assert.equal(value(0), 32n);
assert.ok(value(1) > 0n);
assert.ok(value(2) > 0n && value(3) > 0n);
assert.equal(value(4), 0n);
assert.equal(value(5), 15n);
for (const slot of [8, 12, 17, 18]) assert.equal(value(slot), value(6));
assert.equal(value(9), 4n);
assert.equal(value(10), 3n);
assert.equal(value(13), 8n);
assert.equal(value(14), 7n);
assert.equal(value(15), 2n);
assert.equal(value(16), 2n);
assert.equal(value(19), 1n);
assert.equal(value(20), 2n);
assert.equal(value(28), 2n);
assert.equal(value(22), value(21) + value(23));
assert.equal(value(30), value(29) + value(31));
assert.equal(value(26), value(23) + 3n);
assert.equal(value(34), value(31) + 3n);
assert.equal(value(21), value(38) + value(27));
assert.equal(value(29), value(39) + value(35));
for (const slot of [23, 31, 36, 37]) assert.equal(value(slot), 1n);
assert.equal(value(25), 0n);
assert.equal(value(33), 0n);
for (let slot = 40; slot <= 45; slot++) assert.equal(value(slot), 1n);
assert.ok(value(46) > 0n);
assert.equal(value(47), 6n);
assert.equal(value(48), 4n);
assert.equal(value(49), 1n);
for (const slot of [51, 52, 54]) assert.equal(value(slot), value(50));
for (const slot of [55, 56, 57, 60, 61]) assert.equal(value(slot), value(53));
assert.equal(value(58), value(59));
assert.equal(value(62), 0n);
assert.equal(value(63), 1n);

const hash = (data) => crypto.createHash("sha256").update(data).digest("hex");
const report = {
    schema: "vort-deflate-incremental-relaxed-wasm-v1", status: "ok", utc: new Date().toISOString(),
    node_version: process.version, wasm_path: fs.realpathSync(artifact), wasm_sha256: hash(bytes),
    consumer_sha256: hash(fs.readFileSync("src/deflate/incremental/tests/relaxed/wasm.zig")),
    library_sha256: hash(fs.readFileSync("src/deflate.zig")), gate_sha256: hash(fs.readFileSync(__filename)),
    pointer_bits: value(0).toString(), report_values: Array.from({ length: 64 }, (_, i) => value(i).toString()),
    footer_checks_independent: true, required_footer_lengths_checked: true,
    member_end_and_accepted_tail_distinguished: true, recognized_headers_strict: true,
    partial_error_progress_and_crc_equal: true, reset_clears_diagnostics: true,
};
const json = JSON.stringify(report, null, 2) + "\n";
if (process.argv[3]) {
    fs.mkdirSync(path.dirname(path.resolve(process.argv[3])), { recursive: true });
    fs.writeFileSync(process.argv[3], json);
}
process.stdout.write(json);
