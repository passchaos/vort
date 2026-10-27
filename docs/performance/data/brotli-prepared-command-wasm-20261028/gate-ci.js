const fs = require("node:fs");
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const zlib = require("node:zlib");

function run(path) {
    const stored = fs.readFileSync(path);
    const bytes = path.endsWith(".br") ? zlib.brotliDecompressSync(stored) : stored;
    const moduleObject = new WebAssembly.Module(bytes);
    const imports = WebAssembly.Module.imports(moduleObject);
    for (const entry of imports) {
        assert.equal(entry.module, "wasi_snapshot_preview1");
        assert.equal(entry.kind, "function");
    }
    const { WASI } = require("node:wasi");
    const wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {}, returnOnExit: true });
    const instance = new WebAssembly.Instance(moduleObject, imports.length ? { wasi_snapshot_preview1: wasi.wasiImport } : {});
    // These are reactor modules. initialize also installs memory for real clock
    // imports when the Zig module does not export a separate _initialize.
    if (imports.length) wasi.initialize(instance);
    const api = instance.exports;
    assert.equal(api.brPreparedWideKeySmoke(), 0);
    const status = api.brPreparedEncodeSmoke();
    assert.equal(status, 0, `public q8 probe status=${status}`);
    const input = Buffer.from(new Uint8Array(api.memory.buffer, api.brPreparedInputPtr() >>> 0, api.brPreparedInputLen()));
    const wire = Buffer.from(new Uint8Array(api.memory.buffer, api.brPreparedWirePtr() >>> 0, api.brPreparedWireLen()));
    assert.ok(input.length >= 8192);
    assert.ok(api.brPreparedCommandCount() > 128);
    assert.ok(api.brPreparedCommandEntries() > 4);
    assert.ok(api.brPreparedComplexCommandTrees() > 0);
    assert.ok(api.brPreparedRecentCopies() > 0);
    assert.ok(api.brPreparedSharedGroupWitnesses() > 0);
    assert.deepEqual(zlib.brotliDecompressSync(wire), input);
    return {
        input, wire,
        report: {
            wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
            input_bytes: input.length,
            input_sha256: crypto.createHash("sha256").update(input).digest("hex"),
            wire_bytes: wire.length,
            wire_sha256: crypto.createHash("sha256").update(wire).digest("hex"),
            wire_crc32: api.brPreparedWireCrc32() >>> 0,
            command_count: api.brPreparedCommandCount(),
            command_active_entries: api.brPreparedCommandEntries(),
            complex_command_trees: api.brPreparedComplexCommandTrees(),
            recent_copy_count: api.brPreparedRecentCopies(),
            shared_candidate_groups: api.brPreparedSharedGroupWitnesses(),
            ordinary_profile_wire_equal: true,
            zig_decode_checked: true,
            node_native_decode_checked: true,
            wide_key_above_2_32_checked: true,
        },
    };
}

const baseline = run(process.argv[2]);
const candidate = run(process.argv[3]);
assert.deepEqual(candidate.input, baseline.input);
assert.deepEqual(candidate.wire, baseline.wire);
if (process.argv[4]) {
    fs.mkdirSync(process.argv[4], { recursive: true });
    fs.writeFileSync(`${process.argv[4]}/input.bin`, baseline.input);
    fs.writeFileSync(`${process.argv[4]}/baseline.br`, baseline.wire);
    fs.writeFileSync(`${process.argv[4]}/candidate.br`, candidate.wire);
}
console.log(JSON.stringify({ node_version: process.version, baseline: baseline.report, candidate: candidate.report, full_wire_equal: true }));
