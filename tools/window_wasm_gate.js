const fs = require("node:fs");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");

const bytes = fs.readFileSync(process.argv[2]);
const moduleObject = new WebAssembly.Module(bytes);
const imports = WebAssembly.Module.imports(moduleObject);
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
let host = {};
if (imports.length !== 0) {
    const { WASI } = require("node:wasi");
    wasi = new WASI({ version: "preview1", args: [], env: {}, preopens: {}, returnOnExit: true });
    host = { wasi_snapshot_preview1: wasi.wasiImport };
}
const instance = new WebAssembly.Instance(moduleObject, host);
if (wasi && typeof instance.exports._initialize === "function") wasi.initialize(instance);
for (const name of ["windowBrotliSmoke", "windowZstdSmoke", "windowZstdRawSmoke", "windowMetric"]) {
    assert.equal(typeof instance.exports[name], "function");
}
assert.equal(instance.exports.windowBrotliSmoke(), 0);
assert.equal(instance.exports.windowZstdSmoke(), 0);
assert.equal(instance.exports.windowZstdRawSmoke(), 0);
const metric = (index) => instance.exports.windowMetric(index);
assert.equal(metric(0), 32n);
assert.equal(metric(1), 16n);
assert.equal(metric(3), 30n);
assert.ok(metric(2) > 0n && metric(4) > 0n);
assert.equal(metric(5), 1n << 41n);
assert.equal(metric(6), 128n * 1024n * 1024n);
assert.ok(metric(7) > 0n && metric(7) < 16n * 1024n * 1024n);
assert.equal(metric(8), 0n);
assert.equal(metric(9), 0n);
assert.ok(metric(10) > 0n && metric(10) < 1024n * 1024n);
assert.equal(metric(11), 0n);
assert.equal(metric(12), 1n << 41n);
console.log(JSON.stringify({
    node_version: process.version,
    wasm_sha256: crypto.createHash("sha256").update(bytes).digest("hex"),
    imports,
    wasi_host: imports.length === 0 ? null : "node:wasi preview1",
    pointer_bits: Number(metric(0)),
    brotli: [
        { quality: 0, large_window: 16, peak_requested_bytes: metric(2).toString() },
        { quality: 4, large_window: 30, peak_requested_bytes: metric(4).toString() },
    ],
    brotli_strict_reject_and_allow_decode_checked: true,
    exact_total_and_below_and_zero_checked: true,
    zstd: {
        window_log: 41,
        advertised_window_bytes: metric(5).toString(),
        effective_match_history_bytes: metric(6).toString(),
        peak_requested_bytes: metric(7).toString(),
        final_live_requested_bytes: metric(8).toString(),
        content_size_omitted: true,
    },
    zstd_raw_or_rle: {
        advertised_window_bytes: metric(12).toString(),
        retained_history_bytes: metric(9).toString(),
        peak_requested_bytes: metric(10).toString(),
        final_live_requested_bytes: metric(11).toString(),
    },
    actual_public_roundtrips: 4,
}));
