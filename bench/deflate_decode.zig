const std = @import("std");
const vort = @import("vort");

const Case = struct {
    name: []const u8,
    kind: Kind,
    compressed: []const u8,
    plain_len: usize,

    const Kind = enum { raw, zlib, gzip };
};

const DecodeMode = enum { alloc, exact, into };

pub fn main(init: std.process.Init) !void {
    const cases = [_]Case{
        .{ .name = "raw-fixed-hello", .kind = .raw, .compressed = &.{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 }, .plain_len = 5 },
        .{ .name = "raw-dynamic-small", .kind = .raw, .compressed = &.{ 0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02, 0x30, 0x2b, 0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38, 0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01 }, .plain_len = 19 },
        .{ .name = "zlib-fixed-hello", .kind = .zlib, .compressed = &.{ 0x78, 0x01, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x06, 0x2c, 0x02, 0x15 }, .plain_len = 5 },
        .{ .name = "gzip-fixed-hello", .kind = .gzip, .compressed = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 }, .plain_len = 5 },
    };
    const iterations: usize = 200_000;
    const modes = [_]DecodeMode{ .alloc, .exact, .into };

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var mix: u64 = 0;
    for (cases) |case| {
        for (modes) |mode| {
            const start = std.Io.Clock.awake.now(init.io);
            for (0..iterations) |_| {
                mix +%= try decodeAndChecksum(init.gpa, case, mode);
            }
            const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
            const elapsed_ns: f64 = @floatFromInt(elapsed_ns_signed);
            const elapsed_s = elapsed_ns / @as(f64, std.time.ns_per_s);
            const total_mib = (@as(f64, @floatFromInt(case.plain_len)) * @as(f64, @floatFromInt(iterations))) / (1024.0 * 1024.0);
            try stdout.print("deflate decode {s}-{s}: plain_bytes={d} compressed_bytes={d} iterations={d} elapsed_s={d:.6} throughput_mib_s={d:.2}\n", .{
                case.name,
                @tagName(mode),
                case.plain_len,
                case.compressed.len,
                iterations,
                elapsed_s,
                total_mib / elapsed_s,
            });
        }
    }

    mix +%= try runDynamicStageBench(init.io, stdout, iterations);
    try stdout.print("deflate decode mix={d}\n", .{mix});
    try stdout.flush();
}

fn decodeAndChecksum(allocator: std.mem.Allocator, case: Case, mode: DecodeMode) !u64 {
    return switch (mode) {
        .alloc => blk: {
            const decoded = switch (case.kind) {
                .raw => try vort.decodeRawDeflateAlloc(allocator, case.compressed),
                .zlib => try vort.decodeZlibAlloc(allocator, case.compressed),
                .gzip => try vort.decodeGzipAlloc(allocator, case.compressed),
            };
            defer allocator.free(decoded);
            if (decoded.len != case.plain_len) return error.DecodeLengthMismatch;
            break :blk vort.crc32(decoded);
        },
        .exact => blk: {
            const decoded = switch (case.kind) {
                .raw => try vort.decodeRawDeflateAllocExactSize(allocator, case.compressed, case.plain_len),
                .zlib => try vort.decodeZlibAllocExactSize(allocator, case.compressed, case.plain_len),
                .gzip => try vort.decodeGzipAllocExactSize(allocator, case.compressed, case.plain_len),
            };
            defer allocator.free(decoded);
            break :blk vort.crc32(decoded);
        },
        .into => blk: {
            var scratch: [64]u8 = undefined;
            if (case.plain_len > scratch.len) return error.DecodeLengthMismatch;
            const written = switch (case.kind) {
                .raw => (try vort.decodeRawDeflate(case.compressed, scratch[0..case.plain_len])).output_written,
                .zlib => try vort.decodeZlib(case.compressed, scratch[0..case.plain_len]),
                .gzip => try vort.decodeGzip(case.compressed, scratch[0..case.plain_len]),
            };
            if (written != case.plain_len) return error.DecodeLengthMismatch;
            break :blk vort.crc32(scratch[0..case.plain_len]);
        },
    };
}

fn runDynamicStageBench(io: std.Io, stdout: *std.Io.Writer, iterations: usize) !u64 {
    const frame = [_]u8{ 0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02, 0x30, 0x2b, 0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38, 0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01 };
    var mix: u64 = 0;

    {
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const info = try vort.parseRawDeflateHeaderInfo(&frame);
            mix +%= info.header_bits_consumed;
            mix +%= info.dynamic_literal_nonzero orelse 0;
            mix +%= info.dynamic_distance_nonzero orelse 0;
        }
        try printStage(stdout, start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds(), "raw-dynamic-small-header-info", iterations, frame.len);
    }

    {
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            var scratch: [64]u8 = undefined;
            const decoded = try vort.decodeRawDeflate(&frame, &scratch);
            mix +%= vort.crc32(scratch[0..decoded.output_written]);
        }
        try printStage(stdout, start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds(), "raw-dynamic-small-into-total", iterations, frame.len);
    }

    return mix;
}

fn printStage(stdout: *std.Io.Writer, elapsed_ns_signed: i128, name: []const u8, iterations: usize, bytes: usize) !void {
    const elapsed_ns: f64 = @floatFromInt(elapsed_ns_signed);
    const elapsed_s = elapsed_ns / @as(f64, std.time.ns_per_s);
    try stdout.print("deflate decode-stage {s}: compressed_bytes={d} iterations={d} elapsed_s={d:.6} ns_per_iter={d:.2}\n", .{
        name,
        bytes,
        iterations,
        elapsed_s,
        elapsed_ns / @as(f64, @floatFromInt(iterations)),
    });
}
