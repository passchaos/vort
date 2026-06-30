const std = @import("std");
const vort = @import("vort");

const Case = struct { name: []const u8, input: []const u8 };

pub fn main(init: std.process.Init) !void {
    const cases = [_]Case{
        .{ .name = "empty", .input = "" },
        .{ .name = "tiny", .input = "hello vort" },
        .{ .name = "text", .input = "the quick brown fox jumps over the lazy dog\n" ** 64 },
        .{ .name = "jsonish", .input = "{\"key\":\"value\",\"numbers\":[1,2,3,4],\"flag\":true}\n" ** 64 },
        .{ .name = "repeated", .input = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ** 64 },
    };

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("name,input_bytes,best_deflate_bytes,zlib_fixed_bytes,gzip_fixed_bytes,best_ratio,ldm_candidates,ldm_longest,ldm_max_distance\n", .{});
    for (cases) |case| {
        const raw = try vort.encodeRawBestAlloc(init.gpa, case.input, .{});
        defer init.gpa.free(raw);
        const zlib_frame = try vort.encodeZlibFixedAlloc(init.gpa, case.input);
        defer init.gpa.free(zlib_frame);
        const gzip_frame = try vort.encodeGzipFixedAlloc(init.gpa, case.input);
        defer init.gpa.free(gzip_frame);
        const ratio = if (case.input.len == 0) 0.0 else @as(f64, @floatFromInt(raw.len)) / @as(f64, @floatFromInt(case.input.len));
        const ldm = try vort.summarizeLongDistanceAlloc(init.gpa, case.input, .{});
        try stdout.print("{s},{d},{d},{d},{d},{d:.4},{d},{d},{d}\n", .{ case.name, case.input.len, raw.len, zlib_frame.len, gzip_frame.len, ratio, ldm.candidates, ldm.longest, ldm.max_distance });
    }
    try stdout.flush();
}
