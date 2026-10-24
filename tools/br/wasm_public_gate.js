const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");

const bytes = fs.readFileSync(process.argv[2]);
const moduleObject = new WebAssembly.Module(bytes);
const imports = WebAssembly.Module.imports(moduleObject);
assert.deepEqual(imports, []);
const instance = new WebAssembly.Instance(moduleObject, {});
for (const name of ["brWasmHq10", "brWasmHq11", "brWasmHqSmoke"]) {
    assert.equal(typeof instance.exports[name], "function");
}
assert.equal(instance.exports.brWasmHqSmoke(), 0);
console.log(JSON.stringify({
    node_version: process.version,
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    imports,
    input_bytes: 4097,
    round_trips: 2,
}));
