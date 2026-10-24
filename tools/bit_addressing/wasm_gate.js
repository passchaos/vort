"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const artifact = process.argv[2];
assert.ok(artifact, "usage: node wasm_gate.js artifact.wasm [report.json]");
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
const operations = ["wideBitGeometry", "wideBitSmallReaders", "wideBitStoredBounds"];
for (const name of [...operations, "wideBitReport"]) assert.equal(typeof wasmExports[name], "function", name);
const statuses = {};
for (const name of operations) {
    statuses[name] = wasmExports[name]();
    assert.equal(statuses[name], 0, `${name} failed in the real public Wasm consumer`);
}
function value(index) {
    const result = wasmExports.wideBitReport(index);
    assert.equal(typeof result, "bigint");
    return BigInt.asUintN(64, result);
}
const lengths = [(1n << 29n) - 1n, 1n << 29n, (1n << 29n) + 1n, (1n << 32n) - 1n];
for (let i = 0; i < lengths.length; i++) assert.equal(value(i), lengths[i] * 8n);
assert.equal(value(4), lengths[3]);
assert.equal(value(5), lengths[3] * 8n + 7n);
assert.equal(value(6), 2n);
assert.equal(value(7), 64n);
const source = [0xad, 0x3f, 0x91, 0x27, 0xe6, 0x58, 0x0c, 0xf3, 0x41, 0x9b, 0x75, 0x22, 0xcd, 0x06, 0x8a, 0xf0];
function oracle(input, logical, start, width) {
    let result = 0n;
    for (let i = 0; i < width && start + i < logical; i++) {
        const at = start + i;
        result |= BigInt((input[Math.floor(at / 8)] >> (at % 8)) & 1) << BigInt(i);
    }
    return result;
}
assert.equal(value(8), oracle(source, 128, 2, 63));
for (const index of [9, 10, 11, 12]) assert.equal(value(index), 66n);
assert.equal(value(13), 9n);
assert.equal(value(14), oracle([0xad, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff], 13, 2, 63));
assert.equal(value(15), 13n);
assert.equal(value(16), 16n);
assert.equal(value(17), 4n);
assert.equal(value(18), 32n);
const overheads = [129n, 129n, 132n];
for (let i = 0; i < 3; i++) assert.equal(value(20 + i), lengths[i] + overheads[i]);
assert.ok(value(23) > 128n && value(23) <= 256n);
assert.equal(value(24), 128n);
assert.equal(value(25), value(23) * 8n);
assert.equal(value(26), 0n);
assert.equal(value(27), 0n);
assert.equal(value(28), 1n);
assert.ok(wasmExports.memory.buffer.byteLength <= 16 * 1024 * 1024);
const decimal = (index) => value(index).toString();
const report = {
    schema: "vort-wide-bit-wasm-v1",
    status: "ok",
    utc: new Date().toISOString(),
    node_version: process.version,
    wasm_path: fs.realpathSync(artifact),
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    consumer_source_sha256: crypto.createHash("sha256").update(fs.readFileSync("src/tests/wide_bit_wasm.zig")).digest("hex"),
    node_gate_sha256: crypto.createHash("sha256").update(fs.readFileSync(__filename)).digest("hex"),
    imports,
    wasi_host: imports.length ? "node:wasi preview1; no preopened directories" : null,
    operations: statuses,
    integer_transport: "Wasm i64 via JavaScript BigInt; JSON counts are decimal strings",
    actual_wasm_memory_bytes: String(wasmExports.memory.buffer.byteLength),
    geometry: {
        mode: "numeric_geometry",
        input_bytes: lengths.map(String), bit_counts: [decimal(0), decimal(1), decimal(2), decimal(3)],
        largest_local_byte_index: decimal(4), last_byte_bit_position: decimal(5), narrowing_refusals: decimal(6), bit_count_width: decimal(7),
        floor_ceil_and_position_checked: true, no_corresponding_input_allocated_or_read: true,
    },
    small_readers: {
        mode: "actual_small_buffers",
        source_bytes: decimal(16), public_readers: ["BitReader", "BufferedBitReader", "ChunkedBitReader", "ChunkedSpanBitReader"],
        unaligned_phase: 2, field_bits: 63, exact_value: decimal(8),
        final_bit_positions: [decimal(9), decimal(10), decimal(11), decimal(12)], final_byte_offset: decimal(13),
        peek_then_both_advances_and_next_bit_checked: true, copied_checkpoint_replay_checked: true,
        scalar_partial: { logical_bits: decimal(15), padded_probe_bits: 63, exact_padded_value: decimal(14), failed_read_preserves_position: true, dirty_high_padding_hidden: true },
        reservoir_count_width: decimal(18),
        scope: "Partial logical endpoints are tested for scalar BitReader. The other readers consume complete small byte inputs; private Brotli FastReader is covered by the separate native/x86 campaign.",
    },
    brotli_stored: {
        numeric_input_bytes: lengths.slice(0, 3).map(String), encoded_bounds: [decimal(20), decimal(21), decimal(22)],
        independent_block_header_overheads: overheads.map(String), large_window_and_metadata_overheads_checked: true, near_local_max_bound_error: "IntegerOverflow",
        actual_input_bytes: decimal(24), actual_wire_bytes: decimal(23), actual_wire_bit_count: decimal(25),
        configured_heap_cap: "0", profile_available: true, peak_requested_bytes: decimal(26), live_requested_bytes: decimal(27), actual_roundtrip: true,
    },
    scope: "Wide numeric bit addressing and real small-buffer decoding on wasm32-wasi; this gate does not allocate a 512 MiB buffer or prove Wasm processing of large input.",
};
const json = JSON.stringify(report, null, 2) + "\n";
if (process.argv[3]) fs.writeFileSync(process.argv[3], json);
process.stdout.write(json);
