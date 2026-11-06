const std = @import("std");
pub const root = @import("codec");
pub const Z = root.zstd;

pub const Config = struct {
    operation: enum { encode, decode } = .encode,
    api: []const u8 = "native_alloc",
    format: Z.FrameFormat = .standard,
    include_dictionary_id: ?bool = null,
    dictionary_path: ?[]const u8 = null,
    use_dictionary_set: bool = false,
    selector: ?u32 = null,
    catalog_only: bool = false,
    level: c_int = 3,
    known_size: bool = true,
    checksum: bool = true,
    literal_only: bool = false,
    copy_mode: bool = false,
    block_size: usize = 4096,
    frame_size: usize = 552,
    input_chunk: usize = 31,
    output_chunk: usize = 29,
    worker_count: usize = 3,
    synchronous: bool = false,
    expected_output_len: ?usize = null,
    short_output: bool = false,
};
pub const State = struct {
    encoded_bound: ?usize = null,
    bound_verified: bool = false,
    caller_guards_verified: bool = false,
    borrowed_input_and_dictionary_preserved: bool = false,
    public_step_calls: usize = 0,
    input_consumed: usize = 0,
    self_decode_verified: bool = false,
    mode: ?Z.NativeFrameMode = null,
    parallel_profile: Z.ParallelProfile = .{},
    incremental_parallel_profile: Z.IncrementalParallelProfile = .{},
    dictionary_kind: ?Z.DictionaryKind = null,
    reader_entries: usize = 0,
};
pub fn native(c: Config) Z.NativeFrameOptions {
    var options: Z.NativeFrameOptions = .{ .format = c.format, .content_checksum = c.checksum, .include_content_size = c.known_size, .block_size_max = c.block_size };
    if (c.include_dictionary_id) |flag| options.include_dictionary_id = flag;
    if (c.literal_only) options.selection = .literal_only;
    if (c.copy_mode) {
        options.selection = .literal_only;
        options.match_search_budget = 0;
    }
    return options;
}
pub fn frame(c: Config) Z.FrameOptions {
    var options: Z.FrameOptions = .{ .format = c.format, .content_checksum = c.checksum, .include_content_size = c.known_size };
    if (c.include_dictionary_id) |flag| options.include_dictionary_id = flag;
    return options;
}
pub fn selected(c: Config, dictionary: Z.NativeDictionary) u32 {
    return c.selector orelse dictionary.id;
}
pub fn parallel(init: std.process.Init, c: Config, profile: *Z.ParallelProfile) Z.ParallelOptions {
    return .{ .io = if (c.synchronous) std.Io.failing else init.io, .worker_count = if (c.synchronous) 1 else c.worker_count, .job_size = c.block_size, .max_inflight_jobs = 4, .max_inflight_bytes = c.block_size * 4, .profile = profile };
}
pub fn require(ok: bool) !void {
    if (!ok) return error.DictionaryControlMismatch;
}
pub fn digest(bytes: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
pub fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(16 * 1024 * 1024));
}
pub fn guard(bytes: []const u8) !void {
    for (bytes) |byte| try require(byte == 0xa5);
}
