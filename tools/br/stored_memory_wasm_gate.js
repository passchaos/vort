"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");

const artifact = process.argv[2];
assert.ok(artifact, "usage: node stored_memory_wasm_gate.js artifact.wasm [report.json]");
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
const operations = ["brStoredMemoryFreeInto", "brStoredMemoryOwned", "brStoredMemoryReusable", "brStoredMemoryIncremental"];
for (const name of [...operations, "brStoredMemoryReport"]) assert.equal(typeof wasmExports[name], "function", name);
const statuses = {};
for (const name of operations) {
    statuses[name] = wasmExports[name]();
    assert.equal(statuses[name], 0, `${name} failed in the actual stored-resource Wasm consumer`);
}
function value(index) {
    const result = wasmExports.brStoredMemoryReport(index);
    assert.equal(typeof result, "bigint");
    return BigInt.asUintN(64, result);
}
const cap = 16n * 1024n * 1024n;
for (const index of [0, 1, 2, 3]) assert.ok(value(index) >= 128n && value(index) < 256n);
assert.equal(value(4), 128n);
assert.equal(value(5), BigInt(Buffer.byteLength("stored Wasm metadata")));
assert.equal(value(6), 0n);
assert.ok(value(8) > value(9) && value(8) <= cap);
assert.equal(value(9), value(10));
assert.equal(value(11), 0n);
assert.equal(value(12), 2n);
assert.equal(value(16), 1024n);
assert.ok(value(17) > 0n);
assert.equal(value(18), value(16) + value(17));
assert.ok(value(19) > value(18) && value(19) <= cap);
assert.equal(value(20), value(18));
assert.equal(value(21), 2n);
assert.equal(value(22), 1n);
assert.equal(value(26), 128n);
assert.ok(value(27) > 128n);
assert.equal(value(28), 128n);
assert.equal(value(29), 1n);
assert.ok(value(30) > 0n && value(31) >= value(30) && value(31) <= cap);
assert.equal(value(32), 132n);
assert.equal(value(33), 2n);
assert.equal(value(34), 256n + value(5));
assert.equal(value(35), 64n);
assert.equal(value(36), 0n);
assert.ok(wasmExports.memory.buffer.byteLength <= 32 * 1024 * 1024, "stored resource consumer exceeded its 32 MiB physical envelope");
const decimal = (index) => value(index).toString();
const report = {
    schema: "vort-brotli-stored-memory-wasm-v1",
    status: "ok",
    utc: new Date().toISOString(),
    node_version: process.version,
    wasm_path: fs.realpathSync(artifact),
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    consumer_source_sha256: crypto.createHash("sha256").update(fs.readFileSync("src/tests/br_stored_memory_wasm.zig")).digest("hex"),
    node_gate_sha256: crypto.createHash("sha256").update(fs.readFileSync(__filename)).digest("hex"),
    imports,
    wasi_host: imports.length ? "node:wasi preview1; no preopened directories" : null,
    operations: statuses,
    integer_transport: "Wasm i64 via JavaScript BigInt; JSON quantities are decimal strings",
    heap_policy_cap: cap.toString(),
    actual_wasm_memory_bytes: String(wasmExports.memory.buffer.byteLength),
    free_into: {
        cases: ["standard16 contiguous", "standard16 chunks", "large30 contiguous", "large30 chunks"],
        wire_bytes: [decimal(0), decimal(1), decimal(2), decimal(3)], input_bytes: decimal(4), metadata_bytes: decimal(5),
        configured_limit: "0", profile_available: true, peak_requested_bytes: decimal(6), live_requested_bytes: "0",
        actual_roundtrips_and_metadata_capture: true, caller_output_tail_untouched: true,
    },
    owned: {
        format: "large30", measured_peak: decimal(8), wire_bytes: decimal(9), exact_cap_wire_bytes: decimal(10),
        live_after_operation: decimal(11), zero_and_one_below_refusals: decimal(12),
        exact_cap_same_wire: true, owned_wire_freeable_with_original_allocator: true,
    },
    reusable: {
        retained_scratch_capacity: decimal(16), control_bytes: decimal(17), adopted_live_bytes: decimal(18),
        alias_snapshot_peak: decimal(19), retained_live_after_calls: decimal(20), quota_refusals: decimal(21),
        full_capacity_adopted_once: true, refused_old_pointer_capacity_and_wire_unchanged: true,
        input_and_metadata_overlapping_actual_write_span_snapshotted: true,
        call_profiles_detached_before_later_calls_and_deinit: value(22) === 1n,
        scope: "Profiles remain valid addresses containing sentinel fields; later operations must not write after their call-scoped lifetime ends.",
    },
    incremental: {
        input_bytes: decimal(26), wire_bytes: decimal(27), first_stream_input: decimal(28), first_completed_streams: decimal(29),
        retained_live_bytes: decimal(30), peak_requested_bytes: decimal(31), cumulative_input_after_next_stream: decimal(32), completed_streams: decimal(33),
        metadata_bytes: decimal(34), snapshot_counter_bits: decimal(35), live_after_deinit: decimal(36),
        prefix_zero_quota_refused_without_progress: true, queued_metadata_quota_refusal_preserves_source_and_output: true,
        raised_quota_empty_input_retry: true, flush_metadata_finish_and_next_stream_roundtrips: true,
        next_stream_lower_quota_refuses_before_reset: true,
    },
    scope: "Actual bounded stored codec resource calls and wire decoding; no synthetic large-stream checkpoints and no 4 GiB processing.",
};
const json = JSON.stringify(report, null, 2) + "\n";
if (process.argv[3]) fs.writeFileSync(process.argv[3], json);
process.stdout.write(json);
