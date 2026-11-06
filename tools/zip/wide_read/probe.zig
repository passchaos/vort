const std = @import("std");
const h = @import("common.zig");
const reader = @import("reader.zig");
const writer = @import("writer.zig");
const Config = struct { operation: enum { read_entry, read_archive, write_deflate64, write_archive }, path: []const u8, count: u64, crc32: u32 = 0, owned: bool = true, method: h.zip.CompressionMethod = .deflate64 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingConfig;
    const json = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(65536));
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, json, .{});
    defer parsed.deinit();
    const config = parsed.value;
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (config.operation == .write_deflate64 or config.operation == .write_archive) {
        const receipt = try writer.archive(init, config.path, config.count, if (config.operation == .write_deflate64) .deflate64 else config.method);
        try std.json.Stringify.value(.{ .schema = "vort.zip.wide-read.v1", .operation = config.operation, .pointer_bits = @bitSizeOf(usize), .count = config.count, .receipt = receipt, .build_mode = @tagName(@import("builtin").mode) }, .{}, &stdout.interface);
    } else {
        const result = if (config.operation == .read_entry) try reader.entry(init, config.path, config.count, config.owned) else try reader.archiveSource(init, config.path, config.count, config.crc32);
        try std.json.Stringify.value(.{ .schema = "vort.zip.wide-read.v1", .operation = config.operation, .pointer_bits = @bitSizeOf(usize), .count = config.count, .owned = config.owned, .result = result, .input_chunk_bytes = h.chunk_len, .output_chunk_bytes = h.chunk_len, .build_mode = @tagName(@import("builtin").mode), .all_output_bytes_checked = true }, .{}, &stdout.interface);
    }
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
