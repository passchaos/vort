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
const name = process.argv[3] || "brWasmCompleteLengthsSmoke";
console.log(JSON.stringify({ name, initial_stack: instance.exports.reviewStackPointer.value, memory_bytes: instance.exports.memory.buffer.byteLength }));
try {
    const result = instance.exports[name]();
    console.log(JSON.stringify({ name, result, final_stack: instance.exports.reviewStackPointer.value }));
    assert.equal(result, 0);
} catch (err) {
    console.error(JSON.stringify({ trap_stack_signed: instance.exports.reviewStackPointer.value, trap_stack_unsigned: instance.exports.reviewStackPointer.value >>> 0 }));
    throw err;
}
