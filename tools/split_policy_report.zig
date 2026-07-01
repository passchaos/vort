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

const StrategyCase = struct {
    name: []const u8,
    strategy: vort.CompressionStrategy,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    const builtins = [_]Case{
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
    const strategies = [_]StrategyCase{
        .{ .name = "default", .strategy = .default },
        .{ .name = "filtered", .strategy = .filtered },
    };

    try stdout.print("case,level,strategy,input_bytes,one_shot_bytes,adaptive_bytes,delta_bytes,adaptive_ratio,roundtrip_crc32\n", .{});

    var any = false;
    while (args.next()) |path| {
        any = true;
        const input = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(input);
        try reportCase(init.gpa, stdout, path, input, &levels, &strategies);
    }

    if (!any) {
        for (builtins) |case| try reportCase(init.gpa, stdout, case.name, case.input, &levels, &strategies);
    }
    try stdout.flush();
}

fn reportCase(allocator: std.mem.Allocator, stdout: *std.Io.Writer, name: []const u8, input: []const u8, levels: []const LevelCase, strategies: []const StrategyCase) !void {
    for (levels) |level_case| {
        for (strategies) |strategy_case| {
            var options = vort.optionsForCompressionLevel(level_case.level);
            options.strategy = strategy_case.strategy;
            options = vort.normalizeCompressionOptionsForStrategy(options);
            const one_shot = try vort.encodeRawBestAlloc(allocator, input, options);
            defer allocator.free(one_shot);
            const adaptive = try vort.encodeRawBestAdaptiveSplitAlloc(allocator, input, options, options.split_options);
            defer allocator.free(adaptive);
            const decoded = try vort.decodeRawDeflateAlloc(allocator, adaptive);
            defer allocator.free(decoded);
            if (!std.mem.eql(u8, input, decoded)) return error.RoundTripMismatch;
            const ratio = if (input.len == 0) 0.0 else @as(f64, @floatFromInt(adaptive.len)) / @as(f64, @floatFromInt(input.len));
            try stdout.print("{s},{s},{s},{d},{d},{d},{d},{d:.4},{d}\n", .{
                name,
                level_case.name,
                strategy_case.name,
                input.len,
                one_shot.len,
                adaptive.len,
                @as(isize, @intCast(adaptive.len)) - @as(isize, @intCast(one_shot.len)),
                ratio,
                vort.crc32(decoded),
            });
        }
    }
}
