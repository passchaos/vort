"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");

const artifactPath = process.argv[2];
assert.ok(artifactPath, "usage: node wasm_gate.js artifact.wasm [report.json]");
const bytes = fs.readFileSync(artifactPath);
const moduleObject = new WebAssembly.Module(bytes);
const imports = WebAssembly.Module.imports(moduleObject);
for (const entry of imports) {
    assert.equal(entry.module, "wasi_snapshot_preview1");
    assert.equal(entry.kind, "function");
}
let wasi;
let hostImports = {};
if (imports.length !== 0) {
    const { WASI } = require("node:wasi");
    wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {}, returnOnExit: true });
    hostImports = { wasi_snapshot_preview1: wasi.wasiImport };
}
const instance = new WebAssembly.Instance(moduleObject, hostImports);
if (wasi && typeof instance.exports._initialize === "function") wasi.initialize(instance);
const wasmExports = instance.exports;
const names = ["streamCounterTypes", "streamCounterBrotliModel", "streamCounterZstdWidePreflight", "streamCounterZstdPledge"];
for (const name of [...names, "streamCounterReport"]) assert.equal(typeof wasmExports[name], "function", name);
function value(index) {
    const actual = wasmExports.streamCounterReport(index);
    assert.equal(typeof actual, "bigint", `report slot ${index} must use Wasm i64/JS BigInt`);
    return BigInt.asUintN(64, actual);
}
const boundary = 1n << 32n;
const operationStatus = {};
for (const name of names) {
    operationStatus[name] = wasmExports[name]();
    assert.equal(operationStatus[name], 0, `${name} failed in the real Wasm consumer`);
}
assert.equal(value(0), boundary + 17n);
assert.equal(value(1), 32n);
assert.equal(value(2), 64n);
assert.equal(value(3), 32n);
assert.equal(value(4), boundary);
assert.equal(value(5), (boundary / 16n) * 19n + 1n);
assert.equal(value(6), 19n);
assert.equal(value(7), 16n);
assert.equal(value(8), 3n);
assert.equal(value(9), 8n);
assert.equal(value(10), 1n);
assert.equal(value(11), 19n);
assert.equal(value(12), 131090n);
assert.equal(value(13), boundary + 1n);
assert.equal(value(14), 18n);
assert.equal(value(15), 1n);
assert.equal(value(17), 131090n);
assert.equal(value(18), 1n);
assert.ok(value(16) <= 1048576n && value(19) <= 1048576n);
assert.equal(value(20), boundary + 1n);
assert.equal(value(21), boundary + 7n);
assert.equal(value(22), 14n);
assert.equal(value(23), 1n);
assert.equal(value(24), 0xdf58cf37dc00b095n);
assert.equal(value(25), 0xc0269e70681841e6n);
assert.equal(value(26), boundary + 1n);
assert.equal(value(27), 0x681841e6n);
assert.equal(value(28), value(24));
assert.equal(value(29), value(25));

const decimal = (index) => value(index).toString();
const report = {
    schema: "vort-stream-counter-wasm-v1",
    status: "ok",
    utc: new Date().toISOString(),
    node_version: process.version,
    wasm_path: fs.realpathSync(artifactPath),
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    consumer_source_sha256: crypto.createHash("sha256").update(fs.readFileSync("src/tests/stream_counter_wasm.zig")).digest("hex"),
    node_gate_sha256: crypto.createHash("sha256").update(fs.readFileSync(__filename)).digest("hex"),
    imports,
    wasi_host: imports.length === 0 ? null : "node:wasi preview1; no preopened directories",
    operations: operationStatus,
    types: { pointer_bits: decimal(1), stream_count_bits: decimal(2), local_progress_bits: decimal(3), wide_value: decimal(0), js_transport: "BigInt; JSON quantities are decimal strings" },
    brotli: {
        mode: "model",
        scope: "Repeated legal stored-prefix checkpoint after parsing one actual archived first block; actual next block and final marker resume the same decoder. This does not decode 4 GiB physically.",
        modeled_prefix_blocks: (boundary / 16n - 1n).toString(),
        output_count: decimal(4),
        input_count: decimal(5),
        actual_first_input_bytes: "19",
        actual_first_output_bytes: "16",
        actual_continuation_input_bytes: decimal(6),
        actual_continuation_output_bytes: decimal(7),
        final_marker_input_bytes: "1",
        ring_capacity: decimal(8),
        ring_contents_checked: true,
        coded_bit_wrap_phase: decimal(9),
        actual_partial_header_input_bytes: decimal(10),
        actual_checkpoint_replay_input_bytes: decimal(11),
        decoder_checkpoint_replays_same_reader_state: true,
    },
    zstd_preflight: {
        mode: "physical_small_wire",
        scope: "Real complete RLE frame is parsed, with only one output byte requested per policy. Wide FCS and preflight size are checked; 4 GiB of plaintext are not physically emitted.",
        wire_bytes: decimal(12),
        pledged_content_size: decimal(20),
        actual_rle_length_sum: decimal(13),
        blocks: 32769,
        policies: [
            { name: "block_stream", input_read: decimal(14), output_written: decimal(15), working_memory_bytes: decimal(16) },
            { name: "prevalidated_frame", input_read: decimal(17), output_written: decimal(18), working_memory_bytes: decimal(19) },
        ],
    },
    zstd_pledge: { mode: "physical_header", content_size: decimal(21), actual_header_bytes: decimal(22), encoder_finish_error: "SizeMismatch", failed_output_untouched: true, decoder_finish_error: "TruncatedFrame", policies: ["block_stream", "prevalidated_frame"] },
    checksum: {
        mode: "model",
        scope: "Independent XXH64 fixed-point stripe is updated physically and its unchanged lanes verified. Repeated valid stripes provide the logical prefix; actual 33-byte tail crosses the full-width length boundary.",
        physical_stripe_bytes: "32",
        physical_tail_bytes: "33",
        total_length_after_tail: decimal(26),
        xxh64_before: decimal(24),
        xxh64_after: decimal(25),
        zstd_checksum_low32_after: decimal(27),
        independent_vectors_checked: true,
    },
};
const json = JSON.stringify(report, null, 2) + "\n";
if (process.argv[3]) fs.writeFileSync(process.argv[3], json);
process.stdout.write(json);
