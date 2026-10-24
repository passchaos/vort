const std = @import("std");
const vort = @import("vort");

const Pattern = enum { one, micro };
const input_chunks = [_]usize{ 1, 2, 3, 5, 7 };
const output_chunks = [_]usize{ 2, 3, 5, 7 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const compression = args.next() orelse return error.MissingCompression;
    const input_path = args.next() orelse return error.MissingInputPath;
    const pattern_name = args.next() orelse return error.MissingOutputPattern;
    if (args.next() != null) return error.UnexpectedArgument;
    const pattern: Pattern = if (std.mem.eql(u8, pattern_name, "one"))
        .one
    else if (std.mem.eql(u8, pattern_name, "micro"))
        .micro
    else
        return error.InvalidOutputPattern;

    const payload = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        input_path,
        init.gpa,
        .limited(256 * 1024 * 1024),
    );
    defer init.gpa.free(payload);

    const encoded = if (std.mem.eql(u8, compression, "gzip"))
        try encode(vort.TarGzipIncrementalWriter, init.gpa, payload, pattern)
    else if (std.mem.eql(u8, compression, "bzip2"))
        try encode(vort.TarBzip2IncrementalWriter, init.gpa, payload, pattern)
    else if (std.mem.eql(u8, compression, "brotli"))
        try encode(vort.TarBrotliIncrementalWriter, init.gpa, payload, pattern)
    else if (std.mem.eql(u8, compression, "compress-z"))
        try encode(vort.TarCompressZIncrementalWriter, init.gpa, payload, pattern)
    else if (std.mem.eql(u8, compression, "lzma"))
        try encode(vort.TarLzmaIncrementalWriter, init.gpa, payload, pattern)
    else if (std.mem.eql(u8, compression, "xz"))
        try encode(vort.TarXzIncrementalWriter, init.gpa, payload, pattern)
    else if (std.mem.eql(u8, compression, "lz4"))
        try encode(vort.TarLz4IncrementalWriter, init.gpa, payload, pattern)
    else if (std.mem.eql(u8, compression, "lz4-legacy"))
        try encode(vort.TarLz4LegacyIncrementalWriter, init.gpa, payload, pattern)
    else if (std.mem.eql(u8, compression, "lzf"))
        try encode(vort.TarLzfIncrementalWriter, init.gpa, payload, pattern)
    else if (std.mem.eql(u8, compression, "lzip"))
        try encode(vort.TarLzipIncrementalWriter, init.gpa, payload, pattern)
    else if (std.mem.eql(u8, compression, "zstd"))
        try encode(vort.TarZstandardIncrementalWriter, init.gpa, payload, pattern)
    else if (std.mem.eql(u8, compression, "lzop"))
        try encode(vort.TarLzopIncrementalWriter, init.gpa, payload, pattern)
    else
        return error.UnsupportedCompression;
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
}

fn encode(
    comptime WriterType: type,
    allocator: std.mem.Allocator,
    payload: []const u8,
    pattern: Pattern,
) ![]u8 {
    var writer = try WriterType.initWithOptions(allocator, .{
        .raw_bridge_size = if (pattern == .one) 1 else 31,
        .max_compressed_size = 512 * 1024 * 1024,
    });
    defer writer.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var output_storage: [7]u8 = undefined;
    var input_index: usize = 0;
    var output_index: usize = 0;

    try writer.beginEntry(.{
        .name = "payload.bin",
        .size = payload.len,
        .mode = 0o640,
    });
    var input_offset: usize = 0;
    while (input_offset < payload.len) {
        const input_end = @min(
            payload.len,
            input_offset + nextInputLen(pattern, &input_index),
        );
        while (input_offset < input_end) {
            const output = nextOutput(&output_storage, pattern, &output_index);
            const stepped = try writer.step(payload[input_offset..input_end], output);
            input_offset += stepped.input_read;
            try encoded.appendSlice(allocator, output[0..stepped.output_written]);
            if (stepped.input_read == 0 and stepped.output_written == 0)
                return error.WriterMadeNoProgress;
        }
    }
    try writer.finishEntry();
    while (true) {
        const output = nextOutput(&output_storage, pattern, &output_index);
        const stepped = try writer.step("", output);
        try encoded.appendSlice(allocator, output[0..stepped.output_written]);
        if (stepped.status == .entry_done) break;
        if (stepped.output_written == 0) return error.WriterMadeNoProgress;
    }
    try writer.finishArchive();
    while (true) {
        const output = nextOutput(&output_storage, pattern, &output_index);
        const stepped = try writer.step("", output);
        try encoded.appendSlice(allocator, output[0..stepped.output_written]);
        if (stepped.status == .done) break;
        if (stepped.output_written == 0) return error.WriterMadeNoProgress;
    }
    return encoded.toOwnedSlice(allocator);
}

fn nextInputLen(pattern: Pattern, index: *usize) usize {
    const len = switch (pattern) {
        .one => 1,
        .micro => input_chunks[index.* % input_chunks.len],
    };
    index.* += 1;
    return len;
}

fn nextOutput(storage: *[7]u8, pattern: Pattern, index: *usize) []u8 {
    const len = switch (pattern) {
        .one => 1,
        .micro => output_chunks[index.* % output_chunks.len],
    };
    index.* += 1;
    return storage[0..len];
}
