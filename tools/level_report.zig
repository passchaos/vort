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
        .{ .name = "text", .input = "the quick brown fox jumps over the lazy dog\n" ** 64 },
        .{ .name = "structured", .input = "abcabcabcabc xyz xyz xyz lorem ipsum lorem ipsum\n" ** 64 },
        .{ .name = "repeated", .input = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ** 64 },
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
    try stdout.print("case,level,parser,block_selection,max_chain,nice_len,max_candidates,split_min,split_max,split_step,tokens,fixed_bits,raw_best_bytes,adaptive_bytes,roundtrip_crc32\n", .{});

    for (cases) |case| {
        for (levels) |level_case| {
            const options = vort.optionsForCompressionLevel(level_case.level);
            const plan = switch (options.parser) {
                .hash => try vort.hashGreedyLz77PlanAlloc(init.gpa, case.input, options.lz77_options),
                .greedy => try vort.greedyLz77PlanAlloc(init.gpa, case.input, options.lz77_options),
                .lazy => try vort.lazyGreedyLz77PlanAlloc(init.gpa, case.input, options.lz77_options),
                .optimal => try vort.optimalLz77PlanAlloc(init.gpa, case.input, options.lz77_options),
            };
            defer plan.deinit(init.gpa);

            const encoded = try vort.encodeRawBestAlloc(init.gpa, case.input, options);
            defer init.gpa.free(encoded);
            const decoded = try vort.decodeRawDeflateAlloc(init.gpa, encoded);
            defer init.gpa.free(decoded);
            if (!std.mem.eql(u8, case.input, decoded)) return error.RoundTripMismatch;

            const adaptive = try vort.encodeRawBestAdaptiveSplitAlloc(init.gpa, case.input, options, options.split_options);
            defer init.gpa.free(adaptive);
            const adaptive_decoded = try vort.decodeRawDeflateAlloc(init.gpa, adaptive);
            defer init.gpa.free(adaptive_decoded);
            if (!std.mem.eql(u8, case.input, adaptive_decoded)) return error.RoundTripMismatch;

            try stdout.print("{s},{s},{s},{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{
                case.name,
                level_case.name,
                @tagName(options.parser),
                @tagName(options.block_selection),
                options.lz77_options.max_chain,
                options.lz77_options.nice_len,
                options.lz77_options.max_candidates,
                options.split_options.min_block_len,
                options.split_options.max_block_len,
                options.split_options.search_step,
                plan.stats.tokenCount(),
                vort.fixedLz77BitCost(plan.tokens),
                encoded.len,
                adaptive.len,
                vort.crc32(decoded),
            });
        }
    }
    try stdout.flush();
}
