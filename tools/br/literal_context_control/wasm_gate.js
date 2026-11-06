"use strict";
const fs = require("node:fs"), crypto = require("node:crypto"), assert = require("node:assert/strict");
const { WASI } = require("node:wasi");
const artifacts = process.argv.slice(2);
assert.ok(artifacts.length, "usage: node wasm_gate.js codec-tests.wasm [consumer-tests.wasm]");
const executions = [];
for (const path of artifacts) {
    const bytes = fs.readFileSync(path), compiled = new WebAssembly.Module(bytes);
    for (const item of WebAssembly.Module.imports(compiled)) { assert.equal(item.module, "wasi_snapshot_preview1"); assert.equal(item.kind, "function"); }
    const wasi = new WASI({version:"preview1",args:[path],env:{},preopens:{},returnOnExit:true});
    const instance = new WebAssembly.Instance(compiled,{wasi_snapshot_preview1:wasi.wasiImport});
    assert.equal(typeof instance.exports._start,"function"); const status = wasi.start(instance); assert.equal(status,0,path);
    executions.push({path:fs.realpathSync(path),exit_code:status,sha256:crypto.createHash("sha256").update(bytes).digest("hex")});
}
console.log(JSON.stringify({schema:"vort-br-literal-context-control-wasm-v1",status:"ok",pointer_bits:32,
    contract:"Brotli literal context disable codec and package contracts",utc:new Date().toISOString(),node_version:process.version,executions}));
