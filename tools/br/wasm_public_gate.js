const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");

const bytes = fs.readFileSync(process.argv[2]);
const moduleObject = new WebAssembly.Module(bytes);
const imports = WebAssembly.Module.imports(moduleObject);
// Debug builds can retain standard WASI support through checked allocator
// error paths. Supply Node's actual host for those imports; codec IO stays in
// the exported memory API and no filesystem directory is preopened.
const allowedWasiFunctions = new Set([
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
    assert.ok(allowedWasiFunctions.has(entry.name), `unexpected WASI import: ${entry.name}`);
}
let wasi;
let hostImports = {};
if (imports.length !== 0) {
    const { WASI } = require("node:wasi");
    wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {}, returnOnExit: true });
    hostImports = { wasi_snapshot_preview1: wasi.wasiImport };
}
const instance = new WebAssembly.Instance(moduleObject, hostImports);
if (wasi && typeof instance.exports._initialize === "function") {
    wasi.initialize(instance);
}
for (const name of ["brWasmHq10", "brWasmHq11", "brWasmHqSmoke", "brWasmTotalMemorySmoke", "brWasmWholeBlockSmoke", "brWasmCompleteLengthsSmoke"]) {
    assert.equal(typeof instance.exports[name], "function");
}
assert.equal(instance.exports.brWasmHqSmoke(), 0);
assert.equal(instance.exports.brWasmTotalMemorySmoke(), 0);
assert.equal(instance.exports.brWasmWholeBlockSmoke(), 0);
assert.equal(instance.exports.brWasmCompleteLengthsSmoke(), 0);
console.log(JSON.stringify({
    node_version: process.version,
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    imports,
    wasi_host: imports.length === 0 ? null : "node:wasi preview1",
    input_bytes: 4097,
    round_trips: 2,
    total_memory_qualities: [0, 11],
    total_memory_exact_and_below_checked: true,
    whole_block_modes: ["standard", "large_window"],
    whole_block_max_positions: 4098,
    complete_lengths_cases: [
        { quality: 10, format: "standard", parse_mode: "bounded", input_bytes: 48 },
        { quality: 11, format: "large_window", parse_mode: "whole_block", input_bytes: 64 },
    ],
    complete_lengths_actual_passes_checked: true,
    complete_lengths_sampled_wire_guard_checked: true,
    complete_lengths_exact_plan_budget_wire_checked: true,
    complete_lengths_zero_and_below_search_limits_checked: true,
    complete_lengths_memory_live_zero_checked: true,
}));
