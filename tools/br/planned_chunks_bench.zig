const std = @import("std");
const vort = @import("vort");

const first = "alpha beta gamma delta alpha beta gamma delta " ** 64;
const middle = "qzxwvbnm1234567890QZXWVBNM!@#$%^&*";
const last = "omega theta lambda omega theta lambda " ** 64;
const chunks = [_][]const u8{ first, middle, last };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |arg| try std.fmt.parseInt(usize, arg, 10) else 20_000;
    if (iterations == 0) return error.InvalidBlockPlan;

    var encoder = vort.BrotliPlannedStreamEncoder.init(init.gpa);
    defer encoder.deinit();
    const warmup = try encoder.encodeChunksAlloc(init.gpa, &chunks);
    init.gpa.free(warmup);

    var checksum: usize = 0;
    var start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const encoded = try encoder.encodeChunksAlloc(init.gpa, &chunks);
        checksum +%= encoded.len + encoded[0] + encoded[encoded.len - 1];
        init.gpa.free(encoded);
    }
    const multi_ns = elapsed(start, init.io);

    start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| for (chunks) |chunk| {
        const encoded = try encoder.encodeAlloc(init.gpa, chunk);
        checksum +%= encoded.len + encoded[0] + encoded[encoded.len - 1];
        init.gpa.free(encoded);
    };
    const separate_ns = elapsed(start, init.io);

    const multi = try encoder.encodeChunksAlloc(init.gpa, &chunks);
    defer init.gpa.free(multi);
    var separate_bytes: usize = 0;
    for (chunks) |chunk| {
        const encoded = try encoder.encodeAlloc(init.gpa, chunk);
        defer init.gpa.free(encoded);
        separate_bytes += encoded.len;
    }
    const summary = try vort.brSummarizeStream(multi);
    var buffer: [512]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll("input_bytes,multiblock_bytes,separate_bytes,iterations,multiblock_ns,separate_ns,speedup,compressed_blocks,stored_blocks,checksum\n");
    try stdout.interface.print("{d},{d},{d},{d},{d},{d},{d:.4},{d},{d},{d}\n", .{
        first.len + middle.len + last.len,
        multi.len,
        separate_bytes,
        iterations,
        multi_ns,
        separate_ns,
        @as(f64, @floatFromInt(separate_ns)) / @as(f64, @floatFromInt(multi_ns)),
        summary.compressed_meta_block_count,
        summary.uncompressed_meta_block_count,
        checksum,
    });
    try stdout.interface.flush();
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}
