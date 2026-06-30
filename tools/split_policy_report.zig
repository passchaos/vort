const std = @import("std");
const vort = @import("vort");

const Case = struct {
    name: []const u8,
    input: []const u8,
};

const LevelCase = struct {
    name: []const u8,
    level: vort.CompressionLevel,
};

pub fn main(init: std.process.Init) !void {
    const cases = [_]Case{
        .{ .name = "text", .input = "the quick brown fox jumps over the lazy dog\n" ** 128 },
        .{ .name = "structured", .input = "abcabcabcabc xyz xyz xyz lorem ipsum lorem ipsum\n" ** 128 },
        .{ .name = "repeated", .input = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ** 128 },
        .{ .name = "mixed", .input = (("0123456789abcdef" ** 64) ++ ("aaaaabbbbbccccc" ** 32) ++ ("json:{\"a\":1,\"b\":2}\n" ** 64)) },
    };
    const levels = [_]LevelCase{
        .{ .name = "fastest", .level = .fastest },
        .{ .name = "fast", .level = .fast },
        .{ .name = "default", .level = .default },
        .{ .name = "best", .level = .best },
    };

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("case,level,input_bytes,one_shot_bytes,adaptive_bytes,delta_bytes,adaptive_ratio,roundtrip_crc32\n", .{});

    for (cases) |case| {
        for (levels) |level_case| {
            const options = vort.optionsForCompressionLevel(level_case.level);
            const one_shot = try vort.encodeRawBestAlloc(init.gpa, case.input, options);
            defer init.gpa.free(one_shot);
            const adaptive = try vort.encodeRawBestAdaptiveSplitAlloc(init.gpa, case.input, options, options.split_options);
            defer init.gpa.free(adaptive);
            const decoded = try vort.decodeRawDeflateAlloc(init.gpa, adaptive);
            defer init.gpa.free(decoded);
            if (!std.mem.eql(u8, case.input, decoded)) return error.RoundTripMismatch;
            const ratio = if (case.input.len == 0) 0.0 else @as(f64, @floatFromInt(adaptive.len)) / @as(f64, @floatFromInt(case.input.len));
            try stdout.print("{s},{s},{d},{d},{d},{d},{d:.4},{d}\n", .{
                case.name,
                level_case.name,
                case.input.len,
                one_shot.len,
                adaptive.len,
                @as(isize, @intCast(adaptive.len)) - @as(isize, @intCast(one_shot.len)),
                ratio,
                vort.crc32(decoded),
            });
        }
    }
    try stdout.flush();
}
