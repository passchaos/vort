const std = @import("std");
const vort = @import("vort");

const Row = struct {
    name: []const u8,
    throughput_mib_s: f64,
    elapsed_s: f64,
    digest_mix: u64,
};

pub fn main(init: std.process.Init) !void {
    const len = 1 << 20;
    const iterations = 128;
    const input = try init.gpa.alloc(u8, len);
    defer init.gpa.free(input);

    for (input, 0..) |*byte, i| {
        byte.* = @truncate((i * 251 + 19) & 0xff);
    }

    const rows = [_]Row{
        measure("adler32", input, iterations, vort.adler32, init.io),
        measure("crc32-scalar", input, iterations, vort.crc32, init.io),
        measure("crc32-slice4", input, iterations, vort.crc32Slice4, init.io),
        measure("crc32-slice8", input, iterations, vort.crc32Slice8, init.io),
        measure("crc32-slice16", input, iterations, vort.crc32Slice16, init.io),
        measure("crc32-best", input, iterations, vort.crc32Best, init.io),
        measure("crc32c-scalar", input, iterations, vort.crc32c, init.io),
        measure("crc32c-slice8", input, iterations, vort.crc32cSlice8, init.io),
        measure("crc32c-slice16", input, iterations, vort.crc32cSlice16, init.io),
        measure("crc32c-best", input, iterations, vort.crc32cBest, init.io),
    };

    var mix: u64 = 0;
    var elapsed_s: f64 = 0;
    for (rows) |row| {
        mix +%= row.digest_mix;
        elapsed_s += row.elapsed_s;
    }
    const total_mib = (@as(f64, @floatFromInt(len)) * @as(f64, @floatFromInt(iterations)) * @as(f64, @floatFromInt(rows.len))) / (1024.0 * 1024.0);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("checksum smoke: bytes={d} iterations={d} streams={d} crc32_dispatch={s} crc32c_dispatch={s} elapsed_s={d:.6} throughput_mib_s={d:.2} mix={d}\n", .{
        len,
        iterations,
        rows.len,
        @tagName(vort.checksum.bestCrc32Dispatch()),
        @tagName(vort.checksum.bestCrc32CDispatch()),
        elapsed_s,
        total_mib / elapsed_s,
        mix,
    });
    try stdout.writeAll("algorithm,bytes,iterations,elapsed_s,throughput_mib_s,mix\n");
    for (rows) |row| {
        try stdout.print("{s},{d},{d},{d:.6},{d:.2},{d}\n", .{
            row.name,
            len,
            iterations,
            row.elapsed_s,
            row.throughput_mib_s,
            row.digest_mix,
        });
    }
    try stdout.flush();
}

fn measure(name: []const u8, input: []const u8, iterations: usize, comptime hash: fn ([]const u8) u32, io: std.Io) Row {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| mix +%= hash(input);
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    const elapsed_ns: f64 = @floatFromInt(elapsed_ns_signed);
    const elapsed_s = elapsed_ns / @as(f64, std.time.ns_per_s);
    const mib = (@as(f64, @floatFromInt(input.len)) * @as(f64, @floatFromInt(iterations))) / (1024.0 * 1024.0);
    return .{
        .name = name,
        .throughput_mib_s = mib / elapsed_s,
        .elapsed_s = elapsed_s,
        .digest_mix = mix,
    };
}
