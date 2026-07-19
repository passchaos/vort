const std = @import("std");
const vort = @import("vort");
const bitstream = vort.bitstream;
const huffman = vort.huffman;

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

    mix +%= try runGzipConcatenatedStoredBench(init, stdout, iterations);
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

fn runGzipConcatenatedStoredBench(init: std.process.Init, stdout: *std.Io.Writer, base_iterations: usize) !u64 {
    var first_payload: [4096]u8 = undefined;
    var second_payload: [4096]u8 = undefined;
    for (&first_payload, 0..) |*byte, i| {
        byte.* = @truncate((i * 251 + 19) & 0xff);
    }
    for (&second_payload, 0..) |*byte, i| {
        byte.* = "concatenated stored gzip member "[i % "concatenated stored gzip member ".len];
    }

    const first_frame = try vort.encodeGzipStoredAlloc(init.gpa, &first_payload);
    defer init.gpa.free(first_frame);
    const second_frame = try vort.encodeGzipStoredAlloc(init.gpa, &second_payload);
    defer init.gpa.free(second_frame);

    var frame = std.ArrayList(u8).empty;
    defer frame.deinit(init.gpa);
    try frame.appendSlice(init.gpa, first_frame);
    try frame.appendSlice(init.gpa, second_frame);

    const plain_len = first_payload.len + second_payload.len;
    const iterations = @max(@as(usize, 4096), base_iterations / 16);
    var mix: u64 = 0;
    {
        const start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            const decoded = try vort.decodeGzipConcatenatedAlloc(init.gpa, frame.items);
            {
                defer init.gpa.free(decoded);
                if (decoded.len != plain_len) return error.DecodeLengthMismatch;
                mix +%= sparseChecksum(decoded);
            }
        }
        try printDecodeThroughput(stdout, start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), "gzip-concat-stored-alloc", plain_len, frame.items.len, iterations);
    }
    {
        const start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            const decoded = try vort.decodeGzipConcatenatedAllocExactSize(init.gpa, frame.items, plain_len);
            {
                defer init.gpa.free(decoded);
                mix +%= sparseChecksum(decoded);
            }
        }
        try printDecodeThroughput(stdout, start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), "gzip-concat-stored-exact", plain_len, frame.items.len, iterations);
    }
    {
        const scratch = try init.gpa.alloc(u8, plain_len);
        defer init.gpa.free(scratch);
        const start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            const written = try vort.decodeGzipConcatenated(frame.items, scratch);
            if (written != plain_len) return error.DecodeLengthMismatch;
            mix +%= sparseChecksum(scratch);
        }
        try printDecodeThroughput(stdout, start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), "gzip-concat-stored-into", plain_len, frame.items.len, iterations);
    }
    return mix;
}

fn runDynamicStageBench(io: std.Io, stdout: *std.Io.Writer, iterations: usize) !u64 {
    const frame = [_]u8{ 0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02, 0x30, 0x2b, 0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38, 0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01 };
    var mix: u64 = 0;
    var parsed: huffman.DynamicLengths = undefined;

    {
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            var reader = bitstream.BitReader.init(&frame);
            parsed = try huffman.parseDynamicLengths(&reader);
            mix +%= reader.byteOffset();
            mix +%= parsed.header.hlit;
            mix +%= parsed.header.hdist;
        }
        try printStage(stdout, start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds(), "raw-dynamic-small-parse-lengths", iterations, frame.len);
    }

    {
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
            mix +%= table.len;
        }
        try printStage(stdout, start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds(), "raw-dynamic-small-lit-table", iterations, frame.len);
    }

    {
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
            mix +%= table.len;
        }
        try printStage(stdout, start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds(), "raw-dynamic-small-dist-table", iterations, frame.len);
    }

    {
        const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const decoder = huffman.FastDecoder(286, 9).init(lit_table);
            mix +%= decoder.table.len;
        }
        try printStage(stdout, start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds(), "raw-dynamic-small-lit-fastdecoder", iterations, frame.len);
    }

    {
        const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const decoder = huffman.FastDecoder(30, 8).init(dist_table);
            mix +%= decoder.table.len;
        }
        try printStage(stdout, start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds(), "raw-dynamic-small-dist-fastdecoder", iterations, frame.len);
    }

    {
        const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
        const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
        const lit_decoder = huffman.FastDecoder(286, 9).init(lit_table);
        const dist_decoder = huffman.FastDecoder(30, 8).init(dist_table);
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            var reader = bitstream.BitReader.init(&frame);
            _ = try huffman.parseDynamicLengths(&reader);
            var scratch: [64]u8 = undefined;
            var out_offset: usize = 0;
            try decodeDynamicPayloadForBench(&reader, &scratch, &out_offset, &lit_decoder, &dist_decoder);
            mix +%= vort.crc32(scratch[0..out_offset]);
        }
        try printStage(stdout, start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds(), "raw-dynamic-small-payload", iterations, frame.len);
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

fn printDecodeThroughput(stdout: *std.Io.Writer, elapsed_ns_signed: i128, name: []const u8, plain_len: usize, compressed_len: usize, iterations: usize) !void {
    const elapsed_ns: f64 = @floatFromInt(elapsed_ns_signed);
    const elapsed_s = elapsed_ns / @as(f64, std.time.ns_per_s);
    const total_mib = (@as(f64, @floatFromInt(plain_len)) * @as(f64, @floatFromInt(iterations))) / (1024.0 * 1024.0);
    try stdout.print("deflate decode {s}: plain_bytes={d} compressed_bytes={d} iterations={d} elapsed_s={d:.6} throughput_mib_s={d:.2}\n", .{
        name,
        plain_len,
        compressed_len,
        iterations,
        elapsed_s,
        total_mib / elapsed_s,
    });
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

fn sparseChecksum(bytes: []const u8) u64 {
    var mix: u64 = bytes.len;
    const stride = @max(@as(usize, 1), bytes.len / 16);
    var index: usize = 0;
    while (index < bytes.len) : (index += stride) {
        mix = mix *% 131 +% bytes[index];
    }
    return mix;
}

fn decodeDynamicPayloadForBench(reader: *bitstream.BitReader, output: []u8, out_offset: *usize, lit_decoder: anytype, dist_decoder: anytype) !void {
    while (true) {
        const symbol = try lit_decoder.decodeValue(reader);
        if (symbol < 256) {
            if (out_offset.* == output.len) return error.OutputTooSmall;
            output[out_offset.*] = @intCast(symbol);
            out_offset.* += 1;
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLengthForBench(symbol, reader);
            const distance_symbol = try dist_decoder.decodeValue(reader);
            const distance = try decodeDistanceForBench(distance_symbol, reader);
            try copyMatchForBench(output[0..out_offset.*], output[out_offset.*..], length, distance);
            out_offset.* += length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeLengthForBench(symbol: u16, reader: *bitstream.BitReader) !usize {
    const bases = [_]u16{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258 };
    const extras = [_]u4{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0 };
    if (symbol < 257 or symbol > 285) return error.InvalidHuffmanCode;
    const index = symbol - 257;
    const extra = if (extras[index] == 0) 0 else try reader.readBits(u16, extras[index]);
    return bases[index] + extra;
}

fn decodeDistanceForBench(symbol: u16, reader: *bitstream.BitReader) !usize {
    const bases = [_]u16{ 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577 };
    const extras = [_]u4{ 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13 };
    if (symbol >= bases.len) return error.InvalidHuffmanCode;
    const extra = if (extras[symbol] == 0) 0 else try reader.readBits(u16, extras[symbol]);
    return bases[symbol] + extra;
}

fn copyMatchForBench(history: []const u8, dest: []u8, length: usize, distance: usize) !void {
    if (distance == 0 or distance > history.len) return error.InvalidMatch;
    if (dest.len < length) return error.OutputTooSmall;
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const absolute = history.len + i - distance;
        dest[i] = if (absolute < history.len) history[absolute] else dest[absolute - history.len];
    }
}
