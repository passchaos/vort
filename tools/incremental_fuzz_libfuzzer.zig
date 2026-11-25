//! Coverage-guided entry point for the bounded incremental decoder fuzz drivers.
//!
//! The raw-byte `fuzz_target` harness only reaches one-shot decoders; this entry
//! feeds the same arbitrary byte string to the Zstd, Brotli and Deflate
//! incremental `drive` functions, each of which derives a wire mutation and a
//! caller step schedule from the seed. A coverage-guided engine can therefore
//! explore the full schedule/canary/resource/sticky-error state space rather
//! than only the fixed deterministic matrix. A violated driver invariant (or a
//! real allocation failure) returns non-zero so the engine records the input.
const std = @import("std");
const vort = @import("vort");

export fn LLVMFuzzerTestOneInput(data: [*]const u8, len: usize) c_int {
    var gpa_state = std.heap.DebugAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const allocator = gpa_state.allocator();
    const seed = data[0..len];

    _ = vort.zstd.incremental_fuzz.drive(allocator, seed) catch return 1;
    _ = vort.br.incremental_fuzz.drive(allocator, seed) catch return 1;
    _ = vort.deflate.incremental_fuzz.drive(allocator, seed) catch return 1;
    return 0;
}

pub fn main() !void {
    // A short non-empty sample exercises every driver's seed derivation without
    // relying on an external fuzzing runtime; the fixed matrix coverage lives in
    // the per-codec in-graph tests.
    const sample = "incremental coverage guided fuzz entry";
    if (LLVMFuzzerTestOneInput(sample.ptr, sample.len) != 0) return error.IncrementalFuzzSmokeFailed;
    std.debug.print("incremental libfuzzer entry smoke: ok\n", .{});
}
