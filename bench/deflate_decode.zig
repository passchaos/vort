const std = @import("std");
const vort = @import("vort");

const Case = struct {
    name: []const u8,
    kind: Kind,
    compressed: []const u8,
    plain_len: usize,

    const Kind = enum { raw, zlib, gzip };
};

pub fn main(init: std.process.Init) !void {
    const cases = [_]Case{
        .{ .name = "raw-fixed-hello", .kind = .raw, .compressed = &.{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 }, .plain_len = 5 },
        .{ .name = "raw-dynamic-small", .kind = .raw, .compressed = &.{ 0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02, 0x30, 0x2b, 0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38, 0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01 }, .plain_len = 19 },
        .{ .name = "zlib-fixed-hello", .kind = .zlib, .compressed = &.{ 0x78, 0x01, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x06, 0x2c, 0x02, 0x15 }, .plain_len = 5 },
        .{ .name = "gzip-fixed-hello", .kind = .gzip, .compressed = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 }, .plain_len = 5 },
    };
    const iterations: usize = 200_000;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var mix: u64 = 0;
    for (cases) |case| {
        const start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            const decoded = switch (case.kind) {
                .raw => try vort.decodeRawDeflateAlloc(init.gpa, case.compressed),
                .zlib => try vort.decodeZlibAlloc(init.gpa, case.compressed),
                .gzip => try vort.decodeGzipAlloc(init.gpa, case.compressed),
            };
            defer init.gpa.free(decoded);
            if (decoded.len != case.plain_len) return error.DecodeLengthMismatch;
            mix +%= vort.crc32(decoded);
        }
        const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        const elapsed_ns: f64 = @floatFromInt(elapsed_ns_signed);
        const elapsed_s = elapsed_ns / @as(f64, std.time.ns_per_s);
        const total_mib = (@as(f64, @floatFromInt(case.plain_len)) * @as(f64, @floatFromInt(iterations))) / (1024.0 * 1024.0);
        try stdout.print("deflate decode {s}: plain_bytes={d} compressed_bytes={d} iterations={d} elapsed_s={d:.6} throughput_mib_s={d:.2}\n", .{
            case.name,
            case.plain_len,
            case.compressed.len,
            iterations,
            elapsed_s,
            total_mib / elapsed_s,
        });
    }
    try stdout.print("deflate decode mix={d}\n", .{mix});
    try stdout.flush();
}
