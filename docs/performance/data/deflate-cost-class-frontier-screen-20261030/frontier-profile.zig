const std = @import("std");
const lz77 = @import("lz77");

const class_ends = [_]u16{
    1,    2,    3,    4,    6,    8,    12,    16,    24,    32,
    48,   64,   96,   128,  192,  256,  384,   512,   768,   1024,
    1536, 2048, 3072, 4096, 6144, 8192, 12288, 16384, 24576, 32768,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const level = try std.fmt.parseInt(u4, args.next() orelse return error.MissingLevel, 10);
    const options = lz77.GreedyOptions{
        .window_len = lz77.default_window_len,
        .max_chain = if (level == 8) 384 else 512,
        .nice_len = 128,
        .max_candidates = lz77.default_best_optimal_candidates,
        .lazy_min_gain = 1,
        .min_match = 3,
        .max_match = lz77.max_match_len,
        .min_savings_bits = 0,
    };
    var buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    while (args.next()) |path| {
        const input = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(input);
        var prepared = try lz77.PreparedOptimal.initClassed(init.gpa, input, options, &class_ends);
        defer prepared.deinit(init.gpa);
        const fixed = try prepared.planFixedAlloc(init.gpa);
        defer fixed.deinit(init.gpa);
        try stdout_writer.interface.print(
            "{s},{d},{any},{d},{d}\n",
            .{
                path,
                input.len,
                prepared.distance_class_count != 0,
                prepared.scratch.frontier_lengths.items.len,
                prepared.scratch.frontier_counts.capacity +
                    prepared.scratch.frontier_lengths.capacity +
                    prepared.scratch.frontier_distances.capacity * @sizeOf(u16),
            },
        );
    }
    try stdout_writer.interface.flush();
}
