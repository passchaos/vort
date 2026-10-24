const fs = require("node:fs");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");

const bytes = fs.readFileSync(process.argv[2]);
const moduleObject = new WebAssembly.Module(bytes);
assert.deepEqual(WebAssembly.Module.imports(moduleObject), []);
const instance = new WebAssembly.Instance(moduleObject, {});
assert.equal(instance.exports.largeHqSmoke(), 0);
const qualities = [0, 1].map((index) => ({
    quality: index + 10,
    encoded_bytes: instance.exports.largeHqEncodedSize(index),
    bound_bytes: instance.exports.largeHqBound(index),
    peak_requested_bytes: instance.exports.largeHqMemoryPeak(index),
    wire_crc32: instance.exports.largeHqCrc(index) >>> 0,
}));
assert.ok(qualities[1].encoded_bytes <= qualities[0].encoded_bytes);
console.log(JSON.stringify({
    node_version: process.version,
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    imports: [],
    input_bytes: 4097,
    window_bits: 30,
    large_window: true,
    qualities,
}));
