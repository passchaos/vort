const std = @import("std");
pub const codec = @import("codec");
pub const Config = struct {
    family: enum { zlib, zstd },
    api: []const u8,
    payload_path: []const u8,
    output_path: ?[]const u8 = null,
    dictionary_path: ?[]const u8 = null,
    frame_path: ?[]const u8 = null,
    warm_frame_path: ?[]const u8 = null,
    window_bits: u8 = 15,
    ignore_content_checksum: bool = false,
    magicless: bool = false,
    expected_error: ?[]const u8 = null,
    input_chunk: usize = 3,
    output_chunk: usize = 3,
    runtime_schedule: bool = false,
    zlib_mode: []const u8 = "best",
    block_len: ?usize = null,
};
pub fn require(ok: bool) !void {
    if (!ok) return error.CodecControlOracleMismatch;
}
pub fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(16 * 1024 * 1024));
}
pub fn expectedError(config: Config, result: anytype) !bool {
    if (config.expected_error) |wanted| {
        if (result) |_| return error.ExpectedControlRefusal else |err| {
            try require(std.mem.eql(u8, @errorName(err), wanted));
            return true;
        }
    }
    _ = try result;
    return false;
}
