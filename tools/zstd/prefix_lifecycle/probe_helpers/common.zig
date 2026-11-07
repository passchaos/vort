//! Scripted lifecycle probe inputs and physical artifact receipts.
const std = @import("std");
pub const codec = @import("codec");
pub const Z = codec.zstd;
pub const Usage = enum { persistent, prefix };

pub const Stage = struct {
    operation: enum { observe, set_prefix, set_dictionary, clear_dictionary, reset_session, reset_parameters, reset_all, encode, decode, step, finish, next_stream, provide_dictionary },
    input_path: ?[]const u8 = null,
    dictionary_path: ?[]const u8 = null,
    output_path: ?[]const u8 = null,
    full_dictionary: bool = false,
    input_limit: ?usize = null,
    output_limit: usize = 65536,
    directive: i32 = 0,
    dictionary_usage: ?Usage = null,
};

pub const Config = struct {
    api: enum { native_encode, level_encode, native_decode, incremental_encode, incremental_parallel_encode, incremental_decode, one_shot_encode, one_shot_level_encode, one_shot_decode },
    entry: enum { alloc, scratch, append, into } = .alloc,
    initialization: enum { default, prefix, persistent } = .default,
    initial_dictionary_path: ?[]const u8 = null,
    initial_full_dictionary: bool = false,
    format: Z.FrameFormat = .standard,
    usage: Usage = .persistent,
    level: c_int = 3,
    known_size: bool = true,
    checksum: bool = true,
    ignore_checksum: bool = false,
    include_dictionary_id: bool = true,
    expected_input_len: usize = 0,
    expected_output_len: ?usize = null,
    input_chunk: usize = 3,
    output_chunk: usize = 7,
    synchronous: bool = true,
    stop_after_first_frame: bool = false,
    stages: []const Stage,
};

pub const Event = struct {
    stage: usize,
    operation: @FieldType(Stage, "operation"),
    error_name: ?[]const u8 = null,
    input_read: usize = 0,
    output_written: usize = 0,
    output_sha256: []const u8 = "",
    output_path: ?[]const u8 = null,
    status: ?[]const u8 = null,
    prefix_snapshot_json: []const u8 = "null",
    stream_snapshot_json: []const u8 = "null",
};

pub fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(16 * 1024 * 1024));
}

pub fn digest(bytes: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}

pub fn dictionary(bytes: []const u8, full: bool) !Z.NativeDictionary {
    return if (full) (try Z.NativeDictionary.initFromStandardDictionary(bytes)).dictionary else Z.NativeDictionary.initRawContent(bytes);
}

pub fn require(ok: bool) !void {
    if (!ok) return error.PrefixProbeInvariant;
}
