const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [2048]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    const command = args.next() orelse {
        try printHelp(stdout);
        try stdout.flush();
        return;
    };

    if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "help")) {
        try printHelp(stdout);
    } else if (std.mem.eql(u8, command, "checksum")) {
        const payload = args.next() orelse "";
        try stdout.print("input_bytes={d} adler32={d} crc32={d} crc32c={d}\n", .{
            payload.len,
            vort.adler32(payload),
            vort.crc32(payload),
            vort.crc32c(payload),
        });
    } else if (std.mem.eql(u8, command, "store-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.storeEncodeAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.storeDecodeAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} encoded_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "zlib-store-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeZlibStoredAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeZlibStoredAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} zlib_bytes={d} decoded_ok={} adler32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.adler32(decoded),
        });
    } else if (std.mem.eql(u8, command, "gzip-store-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeGzipStoredAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeGzipStoredAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} gzip_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "zlib-fixed-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeZlibFixedAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeZlibAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} zlib_fixed_bytes={d} decoded_ok={} adler32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.adler32(decoded),
        });
    } else if (std.mem.eql(u8, command, "gzip-fixed-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.encodeGzipFixedAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeGzipAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} gzip_fixed_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "encode-raw-fixed-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawFixedWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-fixed-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibFixedWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-fixed-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipFixedWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "vort-deflate-roundtrip")) {
        const payload = args.next() orelse "";
        const frame = try vort.storeEncodeDeflateAlloc(init.gpa, payload);
        defer init.gpa.free(frame);
        const decoded = try vort.storeDecodeAnyAlloc(init.gpa, frame);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} frame_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            frame.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else if (std.mem.eql(u8, command, "vort-threadpool-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
        const stream = try vort.storeEncodeThreadPoolDeflateStreamAlloc(init.gpa, input, 13, 3);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 10, 20);
        defer init.gpa.free(range);
        try stdout.print("range={s} threadpool_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "vort-parallel-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
        const stream = try vort.storeEncodeParallelDeflateStreamAlloc(init.gpa, input, 13, 3);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 10, 20);
        defer init.gpa.free(range);
        try stdout.print("range={s} parallel_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "vort-blocked-range-demo")) {
        const input = "abcdefghijklmnopqrstuvwxyz";
        const stream = try vort.storeEncodeBlockedDeflateStreamAlloc(init.gpa, input, 7);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 5, 12);
        defer init.gpa.free(range);
        try stdout.print("range={s} blocked_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "store-range-demo")) {
        const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
        const stream = try vort.storeEncodeIndexedStreamAlloc(init.gpa, &payloads);
        defer init.gpa.free(stream);
        const range = try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, 3, 8);
        defer init.gpa.free(range);
        try stdout.print("range={s} indexed_stream_bytes={d}\n", .{ range, stream.len });
    } else if (std.mem.eql(u8, command, "encode-raw-best-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawBestAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-best-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipBestAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-raw-dynamic-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeRawDynamicWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-dynamic-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibDynamicWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-gzip-dynamic-hex")) {
        const payload = args.next() orelse "";
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeGzipDynamicWithOptionsAlloc(init.gpa, payload, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-file-hex")) {
        const path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try printHex(stdout, encoded);
    } else if (std.mem.eql(u8, command, "encode-zlib-best-file")) {
        const input_path = args.next() orelse return error.MissingCorpusPath;
        const output_path = args.next() orelse return error.MissingCorpusPath;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        const options = parseCompressionOptions(args.next());
        const encoded = try vort.encodeZlibBestAlloc(init.gpa, data, options);
        defer init.gpa.free(encoded);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        try stdout.print("input_bytes={d} output_bytes={d} path={s}\n", .{ data.len, encoded.len, output_path });
    } else if (std.mem.eql(u8, command, "decode-raw-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = try vort.decodeRawDeflateAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "raw", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-zlib-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = try vort.decodeZlibAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "zlib", compressed.len, decoded);
    } else if (std.mem.eql(u8, command, "decode-gzip-hex")) {
        const hex = args.next() orelse return error.MissingHexInput;
        const compressed = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(compressed);
        const decoded = try vort.decodeGzipConcatenatedAlloc(init.gpa, compressed);
        defer init.gpa.free(decoded);
        try printDecoded(stdout, "gzip", compressed.len, decoded);
    } else {
        try stdout.print("unknown command: {s}\n\n", .{command});
        try printHelp(stdout);
    }

    try stdout.flush();
}

fn printHelp(stdout: *std.Io.Writer) !void {
    try stdout.print(
        \\vort bootstrap CLI
        \\
        \\commands:
        \\  help | --help              Show this message
        \\  checksum [text]            Print Adler-32, CRC-32, and CRC-32C for text
        \\  store-roundtrip [text]     Encode/decode the native store frame
        \\  zlib-store-roundtrip [text] Encode/decode zlib-wrapped stored deflate
        \\  gzip-store-roundtrip [text] Encode/decode gzip-wrapped stored deflate
        \\  decode-raw-hex [hex]      Decode raw deflate hex to text
        \\  decode-zlib-hex [hex]     Decode zlib-wrapped deflate hex to text
        \\  decode-gzip-hex [hex]     Decode gzip-wrapped deflate hex to text
        \\
        \\This CLI is a smoke surface for the library-first Vort APIs.
        \\
    , .{});
}

fn hexToOwnedBytes(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if ((hex.len & 1) != 0) return error.InvalidHexInput;
    const bytes = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(bytes);
    var i: usize = 0;
    while (i < bytes.len) : (i += 1) {
        bytes[i] = try std.fmt.parseInt(u8, hex[i * 2 .. i * 2 + 2], 16);
    }
    return bytes;
}

fn printDecoded(stdout: *std.Io.Writer, label: []const u8, compressed_len: usize, decoded: []const u8) !void {
    try stdout.print("{s}_compressed_bytes={d} decoded_bytes={d} crc32={d} text={s}\n", .{
        label,
        compressed_len,
        decoded.len,
        vort.crc32(decoded),
        decoded,
    });
}

fn printHex(stdout: *std.Io.Writer, bytes: []const u8) !void {
    for (bytes) |byte| try stdout.print("{x:0>2}", .{byte});
    try stdout.print("\n", .{});
}

fn parseParserMode(text: ?[]const u8) vort.ParserMode {
    return parseCompressionOptions(text).parser;
}

fn parseCompressionOptions(text: ?[]const u8) vort.CompressionOptions {
    const value = text orelse return vort.optionsForCompressionLevel(.default);
    if (std.mem.eql(u8, value, "fast")) return vort.optionsForCompressionLevel(.fast);
    if (std.mem.eql(u8, value, "hash")) return .{ .parser = .hash };
    if (std.mem.eql(u8, value, "default")) return vort.optionsForCompressionLevel(.default);
    if (std.mem.eql(u8, value, "best")) return vort.optionsForCompressionLevel(.best);
    if (std.mem.eql(u8, value, "greedy")) return .{ .parser = .greedy };
    if (std.mem.eql(u8, value, "lazy")) return .{ .parser = .lazy };
    if (std.mem.eql(u8, value, "optimal")) return .{ .parser = .optimal };
    return vort.optionsForCompressionLevel(.default);
}
