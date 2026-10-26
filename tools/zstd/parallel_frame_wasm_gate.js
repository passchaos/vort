"use strict";
const fs = require("node:fs"), crypto = require("node:crypto"), assert = require("node:assert/strict");
const artifact = process.argv[2]; assert.ok(artifact, "usage: node parallel_frame_wasm_gate.js artifact.wasm [report.json]");
const bytes = fs.readFileSync(artifact), compiled = new WebAssembly.Module(bytes), imports = WebAssembly.Module.imports(compiled);
for (const entry of imports) { assert.equal(entry.module, "wasi_snapshot_preview1"); assert.equal(entry.kind, "function"); }
let wasi, host = {};
if (imports.length) { const { WASI } = require("node:wasi"); wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {}, returnOnExit: true }); host = { wasi_snapshot_preview1: wasi.wasiImport }; }
const instance = new WebAssembly.Instance(compiled, host);
if (wasi && typeof instance.exports._initialize === "function") wasi.initialize(instance);
const wasmExports = instance.exports;
const operations = ["zstdParallelFrameWasmRaw", "zstdParallelFrameWasmFast", "zstdParallelFrameWasmDictionary", "zstdParallelFrameWasmQuotas"];
for (const name of [...operations, "zstdParallelFrameWasmReport"]) assert.equal(typeof wasmExports[name], "function", name);
const statuses = {};
for (const name of operations) { statuses[name] = wasmExports[name](); assert.equal(statuses[name], 0, `${name} failed in the actual single-frame MT consumer`); }
function value(index) { const result = wasmExports.zstdParallelFrameWasmReport(index); assert.equal(typeof result, "bigint"); return BigInt.asUintN(64, result); }
for (const [slot, jobs, blocks] of [[0, 4n, 8n], [8, 4n, 8n], [20, 2n, 4n]]) {
    assert.ok(value(slot) > 0n); assert.equal(value(slot + 1), jobs); assert.equal(value(slot + 2), blocks);
    assert.ok(value(slot + 3) > 0n && value(slot + 3) <= 4194304n); assert.equal(value(slot + 4), 0n);
    assert.ok(value(slot + 5) <= 2n && value(slot + 6) <= 1024n);
}
assert.ok(value(0) <= value(7)); assert.ok(value(15) > 0n && value(16) > 0n); assert.equal(value(17), 1n);
assert.ok(value(27) > 0n); assert.equal(value(28), 77n); assert.ok(value(30) > 0n && value(30) <= 4194304n);
assert.ok(value(31) > 0n); assert.equal(value(32), 3n); assert.equal(value(33), 511n); assert.equal(value(34), 32n); assert.equal(value(35), 8388608n); assert.equal(value(36), 1n);
const decimal = (index) => value(index).toString();
const cases = [0, 8, 20].map((slot, i) => ({
    mode: ["raw_or_rle", "controlled_fast", "magicless_dictionary"][i], input_bytes: i === 2 ? "1024" : "2048",
    wire_bytes: decimal(slot), jobs: decimal(slot + 1), published_blocks: decimal(slot + 2), heap_peak: decimal(slot + 3), heap_live_after_operation: decimal(slot + 4),
    peak_inflight_jobs: decimal(slot + 5), peak_inflight_plain_bytes: decimal(slot + 6),
    serial_fallback: true, effective_workers: "1", workers_started: "0", workers_live: "0", peak_active_workers: "0",
    one_frame_and_terminal_block_checked: true, whole_content_xxh64_low32_checked: true, public_full_decode_equal: true,
}));
const report = {
    schema: "vort-zstd-parallel-frame-wasm-v1", status: "ok", utc: new Date().toISOString(), node_version: process.version,
    wasm_path: fs.realpathSync(artifact), wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    consumer_source_sha256: crypto.createHash("sha256").update(fs.readFileSync("src/tests/zstd_parallel_frame_wasm.zig")).digest("hex"),
    node_gate_sha256: crypto.createHash("sha256").update(fs.readFileSync(__filename)).digest("hex"), imports,
    allocator: "FixedBufferAllocator", backing_capacity_bytes: decimal(35), heap_limit_bytes: "4194304", max_inflight_jobs: "2", max_inflight_plain_bytes: "1024",
    requested_workers: "2", job_size_bytes: "512", block_size_bytes: "256", parallel_io: "std.Io.failing", pointer_bits: decimal(34), cases,
    controlled_fast: { history_sequences: decimal(15), max_distance: decimal(16), same_geometry_mt_one_worker_wire_equal: true },
    dictionary: { id: decimal(28), dictionary_sequences: decimal(27), raw_dictionary_bytes: "256", set_wire_equal: true, magicless_equals_standard_without_magic: true },
    publication: { append_additional_bytes_and_prefix_checked: true, into_input_alias_checked: true },
    quotas: { measured_peak_bytes: decimal(30), exact_cap_wire_bytes: decimal(31), exact_cap_same_wire: true, refused_cases: ["max_working_memory=0", "measured peak minus one", "max_inflight_bytes=511 < first job length 512"], refusals: decimal(32), caller_output_untouched: true, zero_and_credit_refusals_before_backing_allocation: true },
    scope: "Real bounded one-shot jobs form one Zstd frame. Inputs remain alive and immutable for the call; no incremental overwrite promise, OS worker startup, RSS or performance claim.",
};
const json = JSON.stringify(report, null, 2) + "\n"; if (process.argv[3]) fs.writeFileSync(process.argv[3], json); process.stdout.write(json);
