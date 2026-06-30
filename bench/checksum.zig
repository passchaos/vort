const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    const len = 1 << 20;
    const iterations = 128;
    const input = try init.gpa.alloc(u8, len);
    defer init.gpa.free(input);

    for (input, 0..) |*byte, i| {
        byte.* = @truncate((i * 251 + 19) & 0xff);
    }

    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        mix +%= vort.adler32(input);
        mix +%= vort.crc32(input);
    }
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    const elapsed_ns: f64 = @floatFromInt(elapsed_ns_signed);
    const elapsed_s = elapsed_ns / @as(f64, std.time.ns_per_s);
    const total_mib = (@as(f64, @floatFromInt(len)) * @as(f64, @floatFromInt(iterations)) * 2.0) / (1024.0 * 1024.0);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("checksum smoke: bytes={d} iterations={d} streams=2 elapsed_s={d:.6} throughput_mib_s={d:.2} mix={d}\n", .{
        len,
        iterations,
        elapsed_s,
        total_mib / elapsed_s,
        mix,
    });
    try stdout.flush();
}
