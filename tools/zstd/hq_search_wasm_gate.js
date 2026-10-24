"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");

const artifact = process.argv[2];
assert.ok(artifact, "usage: node hq_search_wasm_gate.js artifact.wasm [report.json]");
const bytes = fs.readFileSync(artifact);
const moduleObject = new WebAssembly.Module(bytes);
const imports = WebAssembly.Module.imports(moduleObject);
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
const instance = new WebAssembly.Instance(moduleObject, host);
if (wasi && typeof instance.exports._initialize === "function") wasi.initialize(instance);
const wasmExports = instance.exports;
const operations = ["zstdHqSearchWholeComplete", "zstdHqSearchFullSpan", "zstdHqSearchIncrementalRetry", "zstdHqSearchUnsupported"];
for (const name of [...operations, "zstdHqSearchReport"]) assert.equal(typeof wasmExports[name], "function", name);
const statuses = {};
for (const name of operations) {
    statuses[name] = wasmExports[name]();
    assert.equal(statuses[name], 0, `${name} failed in the actual public Wasm consumer`);
}
function value(index) {
    const result = wasmExports.zstdHqSearchReport(index);
    assert.equal(typeof result, "bigint");
    return BigInt.asUintN(64, result);
}
const cap = 128n * 1024n * 1024n;
assert.equal(value(0), 512n);
assert.ok(value(1) > 0n && value(1) <= value(2));
for (const index of [3, 4, 5, 7, 8, 13]) assert.ok(value(index) > 0n, `missing whole/complete work at ${index}`);
assert.equal(value(6), 512n);
assert.ok(value(9) > value(8), "aggregate price work must remain separate from per-plan admission cap");
assert.ok(value(10) >= 2n);
assert.equal(value(11), value(1));
assert.ok(value(12) > 0n && value(12) <= cap);
assert.equal(value(16), 131072n);
assert.equal(value(17), 131072n);
assert.ok(value(18) > 0n && value(19) > 0n && value(20) > 0n);
assert.equal(value(21), 0n, "full high-entropy span uses sampled lengths");
assert.ok(value(22) > 0n && value(22) <= cap && value(23) > 0n && value(23) <= cap);
assert.equal(value(24), cap);
assert.equal(value(26), 10240n);
assert.ok(value(27) > 0n);
assert.equal(value(28), 8192n);
for (const index of [29, 30, 32]) assert.ok(value(index) > 0n);
assert.ok(value(31) >= 2n);
assert.ok(value(33) > 0n && value(33) <= cap);
assert.equal(value(34), 0n, "incremental safeguard is per block, not per complete frame");
assert.equal(value(35), 0n);
assert.equal(value(38), 0n);
assert.equal(value(39), 6n);
assert.equal(value(40), 32n);
assert.equal(value(41), 64n);
assert.ok(wasmExports.memory.buffer.byteLength <= 256 * 1024 * 1024, "Wasm memory exceeds this bounded gate's 256 MiB envelope");

const decimal = (index) => value(index).toString();
const report = {
    schema: "vort-zstd-hq-search-wasm-v1",
    status: "ok",
    utc: new Date().toISOString(),
    node_version: process.version,
    wasm_path: fs.realpathSync(artifact),
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    consumer_source_sha256: crypto.createHash("sha256").update(fs.readFileSync("src/tests/zstd_hq_search_wasm.zig")).digest("hex"),
    node_gate_sha256: crypto.createHash("sha256").update(fs.readFileSync(__filename)).digest("hex"),
    imports,
    wasi_host: imports.length ? "node:wasi preview1; no preopened directories" : null,
    operations: statuses,
    integer_transport: "Wasm i64 via JavaScript BigInt; JSON quantities are decimal strings",
    pointer_bits: decimal(40),
    price_limit_bits: decimal(41),
    memory_envelope_bytes: "268435456",
    actual_wasm_memory_bytes: String(wasmExports.memory.buffer.byteLength),
    whole_complete: {
        input_bytes: decimal(0), wire_bytes: decimal(1), bounded_sampled_wire_bytes: decimal(2),
        whole_passes: decimal(3), complete_passes: decimal(4), baseline_searches: decimal(5),
        max_actual_parse_positions: decimal(6), max_match_length_considered: decimal(7),
        per_plan_price_admissions: decimal(8), accumulated_price_admissions: decimal(9),
        search_refusals: decimal(10), exact_cap_wire_bytes: decimal(11), requested_heap_peak: decimal(12),
        guarded_frames: decimal(13), baseline_selected_frames: decimal(14),
        exact_cap_same_wire: true, zero_and_one_below_refused: true,
        failed_caller_output_untouched: true, failed_emitted_counters_restored: true,
        both_actual_wires_roundtrip: true,
    },
    full_span: {
        mode: "physical_input",
        input_bytes: decimal(16), max_actual_parse_positions: decimal(17), wire_bytes: decimal(18),
        whole_passes: decimal(19), bounded_passes: decimal(20), complete_passes: decimal(21),
        parser_workspace_peak: decimal(22), total_requested_heap_peak: decimal(23), heap_limit: decimal(24),
        min_match: 7, match_lengths: "sampled", high_entropy: true, actual_full_input_roundtrip: true,
        scope: "Actual public whole-block parse of every position in one real 128 KiB block; private DP predecessor behavior is verified by the separate native/x86 suite.",
    },
    incremental: {
        input_bytes: decimal(26), wire_bytes: decimal(27), max_actual_parse_positions: decimal(28),
        whole_passes: decimal(29), baseline_searches: decimal(30), search_refusals: decimal(31),
        max_per_plan_price_admissions: decimal(32), total_requested_heap_peak: decimal(33),
        guarded_frames: decimal(34), live_after_deinit: decimal(35),
        parse_mode: "whole_block", match_lengths: "sampled", first_block_bytes: "8192", final_block_bytes: "2048",
        flush_and_finish_zero_cap_refused: true, caller_output_and_state_preserved: true,
        raised_cap_empty_input_retry: true, actual_complete_wire_roundtrip: true,
        safeguard_scope: "Each block starts its requested and baseline search from the same committed state; it is not the one-shot complete-frame guard.",
    },
    unsupported: { strategy: "lazy2", invalid_controls: ["whole_block", "complete", "max_price_evaluations=0"], public_calls: decimal(39), allocator_attempts: decimal(38), error: "InvalidBlockPlan", caller_output_untouched: true },
};
const json = JSON.stringify(report, null, 2) + "\n";
if (process.argv[3]) fs.writeFileSync(process.argv[3], json);
process.stdout.write(json);
