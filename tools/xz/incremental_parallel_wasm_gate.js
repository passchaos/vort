"use strict";
const fs = require("node:fs"), crypto = require("node:crypto"), assert = require("node:assert/strict");
const artifact = process.argv[2]; assert.ok(artifact, "usage: node incremental_parallel_wasm_gate.js artifact.wasm [report.json]");
const bytes = fs.readFileSync(artifact), compiled = new WebAssembly.Module(bytes), imports = WebAssembly.Module.imports(compiled);
for (const entry of imports) { assert.equal(entry.module, "wasi_snapshot_preview1"); assert.equal(entry.kind, "function"); }
let wasi, host = {};
if (imports.length) { const { WASI } = require("node:wasi"); wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {}, returnOnExit: true }); host = { wasi_snapshot_preview1: wasi.wasiImport }; }
const instance = new WebAssembly.Instance(compiled, host);
if (wasi && typeof instance.exports._initialize === "function") wasi.initialize(instance);
const wasmExports = instance.exports;
assert.equal(typeof wasmExports.xzIncrementalParallelWasmRun, "function"); assert.equal(typeof wasmExports.xzIncrementalParallelWasmReport, "function");
assert.equal(wasmExports.xzIncrementalParallelWasmRun(), 0, "actual persistent incremental XZ Wasm consumer failed");
function value(index) { const result = wasmExports.xzIncrementalParallelWasmReport(index); assert.equal(typeof result, "bigint"); return BigInt.asUintN(64, result); }
assert.equal(value(0), 8192n); assert.ok(value(1) > 0n); assert.equal(value(2), 8n); assert.ok(value(3) > 0n);
assert.ok(value(4) >= value(5) && value(5) > 0n && value(4) <= 4194304n); assert.equal(value(6), 1n); assert.equal(value(7), 0n);
assert.equal(value(8), 2048n); assert.ok(value(9) > 0n); assert.equal(value(10), 2n); assert.equal(value(11), 2n);
assert.ok(value(13) >= value(12) && value(12) > 0n && value(13) <= 4194304n); assert.equal(value(14), 0n);
assert.equal(value(16), 65n); assert.ok(value(17) > 0n); assert.equal(value(18), 64n); assert.equal(value(19), 2n); assert.equal(value(20), 1n);
assert.equal(value(22), 1n); assert.equal(value(23), 0n); assert.equal(value(24), 32n);
const decimal = (index) => value(index).toString();
const report = {
    schema: "vort-xz-parallel-incremental-wasm-v1", status: "ok", utc: new Date().toISOString(), node_version: process.version,
    wasm_path: fs.realpathSync(artifact), wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    consumer_source_sha256: crypto.createHash("sha256").update(fs.readFileSync("src/tests/xz_parallel_incremental_wasm.zig")).digest("hex"),
    node_gate_sha256: crypto.createHash("sha256").update(fs.readFileSync(__filename)).digest("hex"), imports,
    allocator: "FixedBufferAllocator", fixed_capacity: "4194304", parallel_io: "std.Io.failing", requested_workers: "3", pointer_bits: decimal(24),
    serial_fallback: true, workers_started: "0", workers_live: "0", max_inflight_blocks: "2", max_inflight_bytes: "2048",
    stored: { input_bytes: decimal(0), wire_bytes: decimal(1), delivered_blocks: decimal(2), staging_overwrites: decimal(3), heap_peak: decimal(4), retained_heap_after_done: decimal(5), same_config_reset_no_allocation: true, live_after_deinit: decimal(7) },
    compressed_move: { input_bytes: decimal(8), wire_bytes: decimal(9), accepted_owned_jobs_before_move: decimal(10), final_body_byte_credit_checks: decimal(11), retained_heap_after_done: decimal(12), heap_peak: decimal(13), live_after_deinit: decimal(14), old_value_invalidated: true },
    partial_credit: { input_bytes: decimal(16), wire_bytes: decimal(17), capped_partial_bytes: decimal(18), delivered_blocks: decimal(19), recoverable_refusals: decimal(20), block_size: "128", flushed_first_block: "64", final_block: "1", serial_same_explicit_flush_wire: true, no_automatic_block_shrink: true },
    zero_heap_init: { refusals: decimal(22), live_bytes: decimal(23), backing_allocator_position: "0", error: "WorkingMemoryLimitExceeded" },
    all_wires_public_decoded: true, serial_wire_equal: true, caller_input_copied_before_overwrite: true,
    scope: "Real bounded persistent incremental XZ operations on unsupported-target synchronous fallback; no OS workers, giant input or performance claim.",
};
const json = JSON.stringify(report, null, 2) + "\n"; if (process.argv[3]) fs.writeFileSync(process.argv[3], json); process.stdout.write(json);
