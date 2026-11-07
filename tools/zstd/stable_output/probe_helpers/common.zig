const std = @import("std");
pub const root = @import("codec");
pub const Z = root.zstd;
pub const Tracker = @import("tracker.zig").Tracker;

pub const Config = struct {
    api: enum { stable, limited, owned } = .limited,
    scenario: enum { normal, footer, warm_owned, next_stream, crossing_32, overlap, overlap_setter, excess, dictionary_retry } = .normal,
    format: Z.FrameFormat = .standard,
    dictionary_path: ?[]const u8 = null,
    recover_dictionary: bool = false,
    ignore_checksum: bool = false,
    input_chunks: []const usize = &.{3},
    output_quanta: []const usize = &.{1},
    max_working_memory: ?usize = null,
    hard_heap_limit: ?usize = null,
    input_policy: root.CompressedInputPolicy = .block_stream,
    stop_after_first_frame: bool = false,
    expected_output_len: ?u64 = null,
    max_output_len: ?u64 = null,
    destination_size: ?usize = null,
};

pub const Observation = struct {
    call: usize,
    api: []const u8,
    input_before: u64,
    input_after: u64,
    output_before: u64,
    output_after: u64,
    input_read: usize,
    output_written: usize,
    input_offered: usize,
    output_quantum: usize,
    status: ?[]const u8 = null,
    failure: ?[]const u8 = null,
    requested_live: usize,
    requested_peak: usize,
    direct_history_capacity: usize,
    decoded_scratch_capacity: usize,
    compressed_capacity: usize,
};

pub fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(16 * 1024 * 1024));
}
pub fn require(ok: bool) !void {
    if (!ok) return error.StableOutputProbeMismatch;
}
pub fn digest(bytes: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
