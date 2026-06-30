const std = @import("std");
const vort = @import("vort");

const Mode = enum { planned, parallel, thread_pool, work_queue };

pub fn main(init: std.process.Init) !void {
    const input = "abcdefghijklmnopqrstuvwxyz0123456789" ** 64;
    const block_len: usize = 97;
    const workers: usize = 4;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("mode,input_bytes,stream_bytes,elapsed_ms,range_crc32\n", .{});

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
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 13, 257);
        defer init.gpa.free(range);
        try std.testing.expectEqualSlices(u8, input[13..270], range);
        const elapsed_ms = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, std.time.ns_per_ms);
        try stdout.print("{s},{d},{d},{d:.3},{d}\n", .{ @tagName(mode), input.len, stream.len, elapsed_ms, vort.crc32(range) });
    }
    try stdout.flush();
}
