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
for (const item of imports) {
    assert.equal(item.module, "wasi_snapshot_preview1");
    assert.equal(item.kind, "function");
}
let wasi;
let host = {};
if (imports.length) {
    const { WASI } = require("node:wasi");
    wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {}, returnOnExit: true });
    host = { wasi_snapshot_preview1: wasi.wasiImport };
}
const instance = new WebAssembly.Instance(compiled, host);
if (wasi && typeof instance.exports._initialize === "function") wasi.initialize(instance);
const api = instance.exports;
const cases = ["Owned", "Append", "Reusable", "SizeOnly"];
for (const name of cases) {
    assert.equal(typeof api[`zstdDecodeMemoryWasm${name}`], "function");
    assert.equal(api[`zstdDecodeMemoryWasm${name}`](), 0, `${name} memory contract failed`);
}
assert.equal(typeof api.zstdDecodeMemoryWasmReport, "function");
const value = (slot) => api.zstdDecodeMemoryWasmReport(slot);
assert.equal(value(0), 32n);
assert.ok(value(1) > 0n);
assert.ok(value(4) >= value(1));
assert.equal(value(4), value(5));
assert.equal(value(6), 0n);
assert.equal(value(7), 2n);
assert.ok(value(8) > value(9));
assert.ok(value(12) >= value(1));
assert.ok(value(13) >= value(12) + value(1));
assert.equal(value(14), 1n);
assert.equal(value(15), 1n);
assert.ok(value(16) > value(17));
assert.ok(value(17) >= value(18));
assert.ok(value(18) >= value(1));
assert.equal(value(19), 3n);
assert.equal(value(20), 1n);
assert.equal(value(24), value(1));
assert.equal(value(25), 0n);
assert.equal(value(26), 1n);
assert.equal(value(31), 0n);

const decimal = (slot) => value(slot).toString();
const hash = (data) => crypto.createHash("sha256").update(data).digest("hex");
const report = {
    schema: "vort-zstd-decode-memory-wasm-v1",
    status: "ok",
    utc: new Date().toISOString(),
    node_version: process.version,
    wasm_path: fs.realpathSync(artifact),
    wasm_sha256: hash(bytes),
    consumer_source_sha256: hash(fs.readFileSync("src/tests/zstd_decode_memory/wasm.zig")),
    library_source_sha256: hash(fs.readFileSync("src/zstd.zig")),
    gate_sha256: hash(fs.readFileSync(__filename)),
    pointer_bits: decimal(0),
    input_bytes: decimal(1),
    owned: { raw_peak: decimal(4), rle_peak: decimal(5), live_after_handoff: decimal(6), exact_minus_one_refusals: decimal(7) },
    append: { capacity: decimal(12), peak: decimal(13), exact_minus_one_refusals: decimal(14), state_preserved: true },
    reusable: { peak: decimal(16), retained_live: decimal(17), retained_capacity: decimal(18), lower_cap_refusals: decimal(19), cold_exact_minus_one_refusals: decimal(20) },
    size_only: { decoded_bytes: decimal(24), heap_requests: decimal(25), default_slice_zero_heap: true },
};
const json = JSON.stringify(report, null, 2) + "\n";
if (process.argv[3]) {
    fs.mkdirSync(path.dirname(path.resolve(process.argv[3])), { recursive: true });
    fs.writeFileSync(process.argv[3], json);
}
process.stdout.write(json);
