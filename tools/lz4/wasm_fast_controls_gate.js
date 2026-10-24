const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");

const bytes = fs.readFileSync(process.argv[2]);
const moduleObject = new WebAssembly.Module(bytes);
const imports = WebAssembly.Module.imports(moduleObject);
const knownPreview1Functions = new Set([
    "random_get", "clock_time_get", "clock_res_get", "poll_oneoff",
    "environ_sizes_get", "environ_get", "fd_pwrite", "fd_pread",
    "fd_filestat_set_times", "fd_filestat_set_size", "fd_fdstat_get",
    "fd_sync", "fd_seek", "fd_write", "fd_close", "fd_filestat_get",
    "path_link", "path_symlink", "path_readlink", "path_rename",
    "path_remove_directory", "path_unlink_file", "fd_readdir", "path_open",
    "path_filestat_get", "path_create_directory", "fd_read",
]);
for (const entry of imports) {
    assert.equal(entry.module, "wasi_snapshot_preview1");
    assert.equal(entry.kind, "function");
    assert.ok(knownPreview1Functions.has(entry.name), `unexpected WASI import: ${entry.name}`);
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
const smokeExports = [
    "lz4FastWasmDefaultSmoke", "lz4FastWasmMissSmoke", "lz4FastWasmMaximumPrefixSmoke",
];
for (const name of [...smokeExports, "lz4FastWasmProfileValue", "lz4FastWasmPointerBits"]) {
    assert.equal(typeof instance.exports[name], "function");
}
assert.equal(instance.exports.lz4FastWasmPointerBits(), 32);
const results = smokeExports.map(name => ({ export: name, status: instance.exports[name]() }));
for (const result of results) assert.equal(result.status, 0, `${result.export} failed at assertion ${result.status}`);
const fields = [
    "resolved_acceleration", "resolved_chain_depth", "positions_inspected", "positions_skipped",
    "chain_candidates", "history_positions_seeded", "match_positions_seeded", "blocks_attempted", "max_skip_step",
];
const names = ["default_raw", "unmatched_acceleration8_raw", "unmatched_acceleration8_frame", "clamped_maximum_raw", "clamped_maximum_prefix"];
const profiles = Object.fromEntries(names.map((name, index) => [name,
    Object.fromEntries(fields.map((field, id) => [field, instance.exports.lz4FastWasmProfileValue(index, id).toString()]))
]));
assert.equal(profiles.default_raw.resolved_acceleration, "1");
for (const name of names.slice(1, 3)) {
    assert.equal(profiles[name].resolved_acceleration, "8");
    assert.equal(profiles[name].positions_inspected, "64");
    assert.equal(profiles[name].positions_skipped, "437");
    assert.equal(profiles[name].max_skip_step, "8");
}
assert.equal(profiles.clamped_maximum_raw.resolved_acceleration, "65537");
assert.equal(profiles.clamped_maximum_raw.positions_inspected, "2");
assert.equal(profiles.clamped_maximum_raw.positions_skipped, "499");
assert.equal(profiles.clamped_maximum_raw.max_skip_step, "500");
assert.ok(BigInt(profiles.clamped_maximum_prefix.history_positions_seeded) > 0n);
console.log(JSON.stringify({
    schema: "vort-lz4-fast-controls-wasm-v1",
    node_version: process.version,
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    pointer_bits: 32,
    imports,
    wasi_host: imports.length === 0 ? null : "node:wasi preview1",
    results,
    profiles,
    input_bytes: { unmatched: 512, prefix: 128, prefixed_input: 96 },
    checks: { default_and_acceleration1_wire: true, nonpositive_normalization: true,
        maximum_clamp: true, raw_and_frame_roundtrip: true, prefix_roundtrip: true,
        actual_miss_skip_counts: true, wasm32_skip_clipped: true, profile_off_wire: true },
}));
