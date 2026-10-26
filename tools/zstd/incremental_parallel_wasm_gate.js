"use strict";
const fs = require("node:fs"), path = require("node:path"), crypto = require("node:crypto"), assert = require("node:assert/strict");
const artifact = process.argv[2];
assert.ok(artifact, "usage: node incremental_parallel_wasm_gate.js artifact.wasm [report.json]");
const source = path.resolve(__dirname, "../../src/tests/zstd_incremental_parallel_wasm.zig");
const digest = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex");
const bytes = fs.readFileSync(artifact), compiled = new WebAssembly.Module(bytes), imports = WebAssembly.Module.imports(compiled);
for (const entry of imports) {
    assert.equal(entry.module, "wasi_snapshot_preview1");
    assert.equal(entry.kind, "function");
}
let wasi, host = {};
if (imports.length) {
    const { WASI } = require("node:wasi");
    wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {}, returnOnExit: true });
    host = { wasi_snapshot_preview1: wasi.wasiImport };
}
const instance = new WebAssembly.Instance(compiled, host), wasm = instance.exports;
if (wasi && typeof wasm._initialize === "function") wasi.initialize(instance);
const operations = ["zstdIncrementalParallelWasmStream", "zstdIncrementalParallelWasmCredit", "zstdIncrementalParallelWasmDictionary", "zstdIncrementalParallelWasmQuotas"];
for (const name of [...operations, "zstdIncrementalParallelWasmReport"]) assert.equal(typeof wasm[name], "function", name);
const statuses = {};
for (const name of operations) {
    statuses[name] = wasm[name]();
}
function value(index) {
    const result = wasm.zstdIncrementalParallelWasmReport(index);
    assert.equal(typeof result, "bigint", `report slot ${index} must use Wasm i64 / BigInt`);
    return BigInt.asUintN(64, result);
}
const decimal = (index) => value(index).toString(), heapCap = 4194304n;
if (Object.values(statuses).some((status) => status !== 0)) {
    const failure = {
        schema: "vort-zstd-incremental-parallel-wasm-v1", status: "failed", utc: new Date().toISOString(), node_version: process.version,
        wasm_path: fs.realpathSync(artifact), wasm_sha256: digest(bytes), consumer_source_sha256: digest(fs.readFileSync(source)), node_gate_sha256: digest(fs.readFileSync(__filename)),
        operations: statuses, imports, quota_stage: decimal(30), quota_error_code: decimal(31), report_slots: Array.from({ length: 48 }, (_,index) => decimal(index)),
        quota_stages: { 410: "heap measure", 411: "exact heap cap", 412: "one below heap cap", 420: "pending quota", 430: "HQ init", 431: "HQ header", 432: "HQ input", 433: "HQ first refusal", 434: "HQ sticky refusal", 435: "HQ reset", 436: "HQ empty finish", 437: "HQ full decode" },
        quota_error_codes: { 1: "InvalidBlockPlan", 2: "WorkingMemoryLimitExceeded", 3: "OutputLimitExceeded", 4: "SearchLimitExceeded", 5: "IncrementalFrameMismatch", 6: "ExpectedRefusal", 7: "other" },
    };
    const json = JSON.stringify(failure, null, 2) + "\n";
    if (process.argv[3]) fs.writeFileSync(process.argv[3], json);
    process.stdout.write(json);
}
for (const name of operations) assert.equal(statuses[name], 0, `${name} failed; quota stage=${decimal(30)}, error=${decimal(31)}`);
assert.equal(value(0), 1536n);
for (const index of [1, 2, 3, 4]) assert.ok(value(index) > 0n, `missing real stream work at slot ${index}`);
assert.ok(value(5) > 0n && value(5) <= heapCap);
assert.equal(value(6), 0n);
assert.equal(value(8), 65n);
for (const index of [9, 10, 11]) assert.ok(value(index) > 0n);
assert.equal(value(12), value(11) + 1n, "finish after the two explicit flushes must deliver one empty final job");
assert.equal(value(13), 128n);
assert.equal(value(14), 1n);
assert.ok(value(16) > 0n);
assert.equal(value(17), value(16));
assert.ok(value(18) > 0n && value(18) <= heapCap);
assert.equal(value(19), 2n);
assert.equal(value(20), 64n);
assert.equal(value(21), 4294967303n);
assert.equal(value(22), 0n);
assert.ok(value(24) > 1n && value(24) <= heapCap);
assert.equal(value(25), 2n);
assert.equal(value(26), 1n);
assert.equal(value(27), 1n);
assert.equal(value(28), 1n);
assert.equal(value(29), 0n);
assert.equal(value(30), 0n);
assert.equal(value(31), 0n);
assert.equal(value(40), 32n);
assert.equal(value(41), 8388608n);
assert.equal(value(42), heapCap);
assert.equal(value(43), 1024n);
for (const index of [44, 45, 46]) assert.equal(value(index), 0n, "Wasm fallback must not start OS workers");
assert.equal(value(47), 1n);

const report = {
    schema: "vort-zstd-incremental-parallel-wasm-v1", status: "ok", utc: new Date().toISOString(), node_version: process.version,
    wasm_path: fs.realpathSync(artifact), wasm_sha256: digest(bytes), consumer_source_path: source,
    consumer_source_sha256: digest(fs.readFileSync(source)), node_gate_sha256: digest(fs.readFileSync(__filename)), imports,
    operations: statuses, wasi_host: imports.length ? "node:wasi preview1; no preopened directories" : null,
    integer_transport: "Wasm i64 via JavaScript BigInt; JSON quantities are decimal strings", pointer_bits: decimal(40),
    allocator: "FixedBufferAllocator", backing_capacity_bytes: decimal(41), requested_heap_limit_bytes: decimal(42), logical_inflight_plain_limit_bytes: decimal(43),
    requested_workers: "2", job_size_bytes: "512", block_size_bytes: "256", max_inflight_jobs: "2", parallel_io: "std.Io.failing",
    serial_fallback: value(47) === 1n, workers_started: decimal(44), workers_live: decimal(45), peak_active_workers: decimal(46),
    stream: {
        input_bytes: decimal(0), wire_bytes: decimal(1), actual_parsed_blocks: decimal(2), accepted_staging_overwrites: decimal(3),
        final_byte_credit_checks: decimal(4), requested_heap_peak: decimal(5), requested_heap_live_after_deinit: decimal(6),
        staging_bytes: "73", output_bytes: "3", drain_output_bytes: "1", header_before_input_checked: true,
        same_geometry_one_worker_wire_equal: true, one_header_terminal_block_checksum_and_full_public_decode_checked: true,
    },
    partial_credit: {
        input_bytes: decimal(8), wire_bytes: decimal(9), actual_parsed_blocks: decimal(10), jobs_after_two_flushes: decimal(11), jobs_after_finish: decimal(12),
        configured_job_bytes: decimal(13), logical_inflight_plain_limit_bytes: "64", flush_plain_boundaries: ["64", "1"], empty_final_job_delta: "1",
        partial_refusal_error: "WorkingMemoryLimitExceeded", refusal_is_sticky: false, zero_failed_progress_and_caller_preservation_checked: true,
        flush_recovers_then_input_resumes: value(14) === 1n, same_flush_boundaries_one_worker_wire_equal: true,
        one_header_terminal_block_checksum_and_full_public_decode_checked: true,
    },
    dictionary_lifecycle: {
        format: "magicless", dictionary_id: "77", raw_dictionary_bytes: "256", input_bytes_per_frame: "512", exact_size_frames: true,
        first_wire_bytes: decimal(16), second_wire_bytes: decimal(17), retained_requested_heap_bytes: decimal(18), completed_frames: decimal(19),
        cumulative_count_bits: decimal(20), numeric_width_sample: decimal(21), requested_heap_live_after_deinit: decimal(22),
        numeric_width_sample_scope: "Type/transport metadata only; no 4 GiB plaintext processing",
        active_state_moved_after_accepted_staging_overwrite: true, next_frame_preset_wire_equal: true, reset_retains_capacities_without_allocator_growth: true,
        each_frame_header_terminal_block_checksum_and_full_public_decode_checked: true,
    },
    quotas: {
        measured_requested_heap_peak_bytes: decimal(24), heap_refusals: decimal(25), heap_refused_caps: ["0", "measured peak minus one"], exact_peak_cap_succeeds: true,
        zero_heap_refusal_before_backing_allocation: true, final_job_pending_limit_bytes: "12", raised_pending_limit_bytes: "4096",
        encoded_jobs_before_pending_retry: decimal(26), pending_empty_input_retry_without_reencoding: value(27) === 1n,
        pending_refusal_error: "OutputLimitExceeded", pending_refusal_is_sticky: false,
        hq_strategy: "btopt", hq_selection: "auto", hq_price_limit: "0", hq_refusal_error: "SearchLimitExceeded", hq_refusal_is_sticky: true,
        hq_reset_empty_finish_with_captured_zero_cap: value(28) === 1n, zero_failed_progress_and_caller_preservation_checked: true,
        aggregate_requested_heap_live_after_deinit: decimal(29), successful_wires_full_public_decode_checked: true,
    },
    scope: "Real bounded persistent incremental frames, synchronous Wasm fallback, accepted staging reused before the next call. Backing capacity, requested heap and logical plaintext credit are separate quantities. No incremental input/output overlap promise, synthetic large stream, OS worker startup, RSS or throughput claim.",
};
const json = JSON.stringify(report, null, 2) + "\n";
if (process.argv[3]) fs.writeFileSync(process.argv[3], json);
process.stdout.write(json);
