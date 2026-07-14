const std = @import("std");
const vort = @import("vort");

const EncodeMode = enum { best, dynamic, fixed, split, adaptive };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    const input_path = args.next() orelse return error.MissingCorpusPath;
    const iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const mode = parseMode(args.next());
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(input);

    const warmup = try encode(init.gpa, input, mode);
    init.gpa.free(warmup);

    var mix: u64 = 0;
    var last_size: usize = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const encoded = try encode(init.gpa, input, mode);
        defer init.gpa.free(encoded);
        last_size = encoded.len;
        mix +%= encoded.len;
        if (encoded.len != 0) mix +%= encoded[0];
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("elapsed_ns={d} zlib_bytes={d} mix={d}\n", .{ elapsed_ns, last_size, mix });
    try stdout.flush();
}

const Mode = struct {
    kind: EncodeMode,
    level: vort.CompressionLevel,
};

fn parseMode(text: ?[]const u8) Mode {
    const value = text orelse return .{ .kind = .best, .level = .default };
    if (std.mem.startsWith(u8, value, "fixed-")) {
        return .{ .kind = .fixed, .level = parseLevel(value["fixed-".len..]) };
    }
    if (std.mem.startsWith(u8, value, "dynamic-")) {
        return .{ .kind = .dynamic, .level = parseLevel(value["dynamic-".len..]) };
    }
    if (std.mem.startsWith(u8, value, "split-")) {
        return .{ .kind = .split, .level = parseLevel(value["split-".len..]) };
    }
    if (std.mem.startsWith(u8, value, "adaptive-")) {
        return .{ .kind = .adaptive, .level = parseLevel(value["adaptive-".len..]) };
    }
    return .{ .kind = .best, .level = parseLevel(value) };
}

fn parseLevel(value: []const u8) vort.CompressionLevel {
    if (std.mem.eql(u8, value, "fastest")) return .fastest;
    if (std.mem.eql(u8, value, "fast")) return .fast;
    if (std.mem.eql(u8, value, "best")) return .best;
    return .default;
}

fn encode(allocator: std.mem.Allocator, input: []const u8, mode: Mode) ![]u8 {
    const options = vort.optionsForCompressionLevel(mode.level);
    return switch (mode.kind) {
        .best => vort.encodeZlibBestAlloc(allocator, input, options),
        .dynamic => vort.encodeZlibDynamicWithOptionsAlloc(allocator, input, options),
        .fixed => vort.encodeZlibFixedWithOptionsAlloc(allocator, input, options),
        .split => vort.encodeZlibBestSplitAlloc(allocator, input, options.split_options.min_block_len, options),
        .adaptive => vort.encodeZlibBestAdaptiveSplitAlloc(allocator, input, options, options.split_options),
    };
}
