"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const artifact = process.argv[2];
assert.ok(artifact, "usage: node parallel_wasm_gate.js artifact.wasm [report.json]");
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
if (wasi && typeof instance.exports._initialize === "function") wasi.initialize(instance);
const wasmExports = instance.exports;
assert.equal(typeof wasmExports.xzParallelWasmRun, "function");
assert.equal(typeof wasmExports.xzParallelWasmReport, "function");
assert.equal(wasmExports.xzParallelWasmRun(), 0, "actual XZ fallback consumer failed");
function value(index) {
    const result = wasmExports.xzParallelWasmReport(index);
    assert.equal(typeof result, "bigint");
    return BigInt.asUintN(64, result);
}
assert.equal(value(0), 8192n);
assert.equal(value(8), 2048n);
for (const [slot, blocks] of [[0, 8n], [8, 2n]]) {
    assert.ok(value(slot + 1) > 0n);
    assert.equal(value(slot + 2), blocks);
    assert.equal(value(slot + 3), blocks);
    assert.ok(value(slot + 4) <= 2n && value(slot + 5) <= 2048n);
    assert.ok(value(slot + 6) > 0n && value(slot + 6) <= 4194304n);
    assert.equal(value(slot + 7), 0n);
}
assert.equal(value(16), 2n);
assert.equal(value(17), 1023n);
assert.equal(value(18), 32n);
assert.equal(value(19), 4194304n);
assert.ok(value(9) < value(20), "compressed fixture must actually beat stored wire");
const decimal = (index) => value(index).toString();
const cases = [0, 8].map((slot, i) => ({
    payload: i === 0 ? "stored" : "fast_compressed",
    input_bytes: decimal(slot), wire_bytes: decimal(slot + 1),
    completed_blocks: decimal(slot + 2), published_blocks: decimal(slot + 3),
    peak_inflight_blocks: decimal(slot + 4), peak_inflight_bytes: decimal(slot + 5),
    heap_peak: decimal(slot + 6), heap_live: decimal(slot + 7),
    serial_fallback: true, workers_started: "0", serial_wire_equal: true, public_decode_equal: true,
    caller_into_alias_checked: i === 1,
}));
const report = {
    schema: "vort-xz-parallel-wasm-v1", status: "ok", utc: new Date().toISOString(), node_version: process.version,
    wasm_path: fs.realpathSync(artifact), wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    consumer_source_sha256: crypto.createHash("sha256").update(fs.readFileSync("src/tests/xz_parallel_wasm.zig")).digest("hex"),
    node_gate_sha256: crypto.createHash("sha256").update(fs.readFileSync(__filename)).digest("hex"), imports,
    wasi_host: imports.length ? "node:wasi preview1; no preopened directories" : null,
    pointer_bits: decimal(18), allocator: "FixedBufferAllocator", fixed_capacity: decimal(19),
    parallel_io: "std.Io.failing; unsupported Wasm target must choose fallback before touching coordination IO",
    block_bytes: "1024", requested_workers: "3", max_inflight_blocks: "2", max_inflight_bytes: "2048", cases,
    refused_cases: ["max_working_memory=0", "max_inflight_bytes=1023 < actual block length 1024"],
    refusal_count: decimal(16), caller_bytes_and_fixed_allocator_position_preserved: true,
    scope: "Real small multi-block XZ stored and compressed calls; unsupported-target serial fallback, no worker startup or large-input/performance claim.",
};
const json = JSON.stringify(report, null, 2) + "\n";
if (process.argv[3]) fs.writeFileSync(process.argv[3], json);
process.stdout.write(json);
