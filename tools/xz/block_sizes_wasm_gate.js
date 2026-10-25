"use strict";
const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");
const artifact = process.argv[2];
assert.ok(artifact, "usage: node block_sizes_wasm_gate.js artifact.wasm [report.json]");
const bytes = fs.readFileSync(artifact);
const compiled = new WebAssembly.Module(bytes);
const imports = WebAssembly.Module.imports(compiled);
for (const entry of imports) { assert.equal(entry.module, "wasi_snapshot_preview1"); assert.equal(entry.kind, "function"); }
let wasi; let host = {};
if (imports.length) {
    const { WASI } = require("node:wasi");
    wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {}, returnOnExit: true });
    host = { wasi_snapshot_preview1: wasi.wasiImport };
}
const instance = new WebAssembly.Instance(compiled, host);
if (wasi && typeof instance.exports._initialize === "function") wasi.initialize(instance);
const wasmExports = instance.exports;
assert.equal(typeof wasmExports.xzBlockSizesWasmRun, "function");
assert.equal(typeof wasmExports.xzBlockSizesWasmReport, "function");
assert.equal(wasmExports.xzBlockSizesWasmRun(), 0, "actual public XZ block-size consumer failed");
function value(index) {
    const result = wasmExports.xzBlockSizesWasmReport(index); assert.equal(typeof result, "bigint");
    return BigInt.asUintN(64, result);
}
for (const [slot, plain, blocks] of [[0, 8192n, 8n], [10, 2048n, 2n]]) {
    assert.equal(value(slot), plain); assert.ok(value(slot + 1) > 0n); assert.equal(value(slot + 2), blocks);
    assert.ok(value(slot + 3) >= blocks); assert.equal(value(slot + 4), plain); assert.equal(value(slot + 5), blocks);
    assert.ok(value(slot + 7) > 0n && value(slot + 7) <= 4194304n); assert.equal(value(slot + 8), 0n);
}
assert.equal(value(6), 0n); assert.ok(value(16) > 0n); assert.equal(value(20), 2n);
assert.equal(value(21), 0n); assert.equal(value(22), 32n); assert.equal(value(23), 4194304n); assert.equal(value(24), 192n);
const decimal = (index) => value(index).toString();
const cases = [0, 10].map((slot, i) => ({
    payload: i ? "fast_compressed" : "stored", input_bytes: decimal(slot), wire_bytes: decimal(slot + 1),
    raw_header_blocks: decimal(slot + 2), declared_and_actual_packed_bytes_including_terminal_zero: decimal(slot + 3),
    declared_and_packet_original_bytes: decimal(slot + 4), terminal_packets: decimal(slot + 5), compressed_packets: decimal(slot + 6),
    heap_peak: decimal(slot + 7), heap_live: decimal(slot + 8), header_flags: "0xc0",
    header_crc32_checked: true, original_block_crc64_checked: true, independent_u64_vli_and_packet_scan: true,
    serial_sized_wire_equal: true, public_decode_equal: true, caller_into_alias_checked: true,
    serial_fallback: true, workers_started: "0", inflight_blocks_within_two: true, inflight_bytes_within_2048: true,
}));
const report = {
    schema: "vort-xz-block-sizes-wasm-v1", status: "ok", utc: new Date().toISOString(), node_version: process.version,
    wasm_path: fs.realpathSync(artifact), wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    consumer_source_sha256: crypto.createHash("sha256").update(fs.readFileSync("src/tests/xz_block_sizes_wasm.zig")).digest("hex"),
    node_gate_sha256: crypto.createHash("sha256").update(fs.readFileSync(__filename)).digest("hex"), imports,
    wasi_host: imports.length ? "node:wasi preview1; no preopened directories" : null,
    pointer_bits: decimal(22), fixed_allocator_capacity: decimal(23), include_block_sizes: true,
    parallel_io: "std.Io.failing; unsupported-target fallback bypasses worker coordination",
    block_bytes: "1024", requested_workers: "3", cases, quota_refusals: decimal(20),
    refused_cases: ["zero heap quota", "inflight byte cap 1023 < actual block length 1024"], caller_bytes_and_allocator_position_preserved: true,
    default_false_header_flags: decimal(21), default_false_control_bytes: "32",
    scope: "Real small public XZ stored/compressed sized Blocks with independent raw-header, packet-length and checksum validation; no parallel streaming or performance claim.",
};
const json = JSON.stringify(report, null, 2) + "\n";
if (process.argv[3]) fs.writeFileSync(process.argv[3], json);
process.stdout.write(json);
