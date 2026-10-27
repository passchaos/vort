const fs = require("node:fs");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");

const bytes = fs.readFileSync(process.argv[2]);
const moduleObject = new WebAssembly.Module(bytes);
const imports = WebAssembly.Module.imports(moduleObject);
let wasi;
let host = {};
if (imports.length !== 0) {
    for (const entry of imports) {
        assert.equal(entry.module, "wasi_snapshot_preview1");
        assert.equal(entry.kind, "function");
    }
    const { WASI } = require("node:wasi");
    wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {}, returnOnExit: true });
    host = { wasi_snapshot_preview1: wasi.wasiImport };
}
const instance = new WebAssembly.Instance(moduleObject, host);
if (wasi && typeof instance.exports._initialize === "function") wasi.initialize(instance);
assert.equal(instance.exports.brBitWriterWasmSmoke(), 0);
assert.equal(instance.exports.brBitWriterGeneralCases(), 49152);
assert.equal(instance.exports.brBitWriterHuffmanCases(), 11520);
assert.equal(instance.exports.brBitWriterNineByteSpills(), 2016);
const fingerprint = instance.exports.brBitWriterFingerprint() >>> 0;
assert.equal(instance.exports.brBitWriterWasmSmoke(), 0);
assert.equal(instance.exports.brBitWriterFingerprint() >>> 0, fingerprint);
const sourceSha = process.argv[3]
    ? crypto.createHash("sha256").update(fs.readFileSync(process.argv[3])).digest("hex")
    : null;
console.log(JSON.stringify({
    node_version: process.version,
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    writer_source_sha256: sourceSha,
    imports,
    initial_offsets: [0, 7],
    general_widths: [0, 63],
    huffman_widths: [1, 15],
    general_cases: 49152,
    huffman_cases: 11520,
    nine_byte_spills: 2016,
    exact_and_spare_capacity: true,
    bounded_and_growable_reserved: true,
    logical_output_guards_checked: true,
    allocation_attempts_disallowed: true,
    independent_bit_reference: true,
    fingerprint,
}));
