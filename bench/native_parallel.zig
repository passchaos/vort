const std = @import("std");
const vort = @import("vort");

const Mode = enum { planned, parallel, thread_pool, work_queue };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var owned_input: ?[]u8 = null;
    defer if (owned_input) |input| init.gpa.free(input);
    const label = args.next() orelse "built-in";
    const input = if (std.mem.eql(u8, label, "built-in"))
        "abcdefghijklmnopqrstuvwxyz0123456789" ** 64
    else blk: {
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, label, init.gpa, .limited(64 * 1024 * 1024));
        owned_input = data;
        break :blk data;
    };
    const block_len: usize = if (args.next()) |value| try std.fmt.parseInt(usize, value, 10) else 97;
    const workers: usize = if (args.next()) |value| try std.fmt.parseInt(usize, value, 10) else 4;
    if (block_len == 0 or workers == 0) return error.InvalidBlockPlan;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("label,mode,workers,input_bytes,stream_bytes,elapsed_ms,range_offset,range_len,range_crc32\n", .{});

    inline for (.{ Mode.planned, Mode.parallel, Mode.thread_pool, Mode.work_queue }) |mode| {
        const start = std.Io.Clock.awake.now(init.io);
        const stream = switch (mode) {
            .planned => try vort.storeEncodePlannedDeflateStreamAlloc(init.gpa, input, block_len, workers),
            .parallel => try vort.storeEncodeParallelDeflateStreamAlloc(init.gpa, input, block_len, workers),
            .thread_pool => try vort.storeEncodeThreadPoolDeflateStreamAlloc(init.gpa, input, block_len, workers),
            .work_queue => try vort.storeEncodeWorkStealingDeflateStreamAlloc(init.gpa, input, block_len, workers),
        };
        const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        defer init.gpa.free(stream);
        const range_offset: usize = if (input.len == 0) 0 else @min(13, input.len - 1);
        const range_len: usize = @min(257, input.len - range_offset);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, range_offset, range_len);
        defer init.gpa.free(range);
        try std.testing.expectEqualSlices(u8, input[range_offset..][0..range_len], range);
        const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, std.time.ns_per_ms);
        try stdout.print("{s},{s},{d},{d},{d},{d:.3},{d},{d},{d}\n", .{ label, @tagName(mode), workers, input.len, stream.len, elapsed_ms, range_offset, range_len, vort.crc32(range) });
    }
    try stdout.flush();
}
