const std = @import("std");
const codec = @import("codec");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const frame_path = args.next() orelse return error.MissingFrame;
    const plain_path = args.next() orelse return error.MissingPlain;
    const mode = args.next() orelse return error.MissingMode;
    if (args.next() != null) return error.UnexpectedArgument;

    const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, frame_path, init.gpa, .limited(32 * 1024 * 1024));
    defer init.gpa.free(frame);
    const plain = try std.Io.Dir.cwd().readFileAlloc(init.io, plain_path, init.gpa, .limited(32 * 1024 * 1024));
    defer init.gpa.free(plain);

    var chunks: std.ArrayList([]const u8) = .empty;
    defer chunks.deinit(init.gpa);
    if (std.mem.eql(u8, mode, "byte")) {
        try appendByteChunks(init.gpa, &chunks, frame);
    } else if (std.mem.eql(u8, mode, "patterned")) {
        try appendPatternedChunks(init.gpa, &chunks, frame);
    } else return error.InvalidMode;

    const output = try init.gpa.alloc(u8, plain.len);
    defer init.gpa.free(output);
    const written = try codec.decodeGzipChunksInto(chunks.items, output);
    try require(written == plain.len and std.mem.eql(u8, output, plain));

    const decoded_scratch = try init.gpa.alloc(u8, plain.len);
    defer init.gpa.free(decoded_scratch);
    var decoder = try codec.GzipDecoder.initFromChunksExactSizeDirect(chunks.items, decoded_scratch, plain.len);
    const drained = try init.gpa.alloc(u8, @max(plain.len, 1));
    defer init.gpa.free(drained);
    var drained_len: usize = 0;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try require(calls <= plain.len + 1);
        const limit = @min(drained.len, drained_len + 17);
        const result = try decoder.step(drained[drained_len..limit]);
        drained_len += result.progress.output_written;
        if (result.status == .done) {
            try require(result.progress.input_read == frame.len);
            break;
        }
    }
    try require(drained_len == plain.len and std.mem.eql(u8, drained[0..plain.len], plain));

    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try std.json.Stringify.value(.{
        .schema = "vort.deflate.gzip-direct-probe.v1",
        .status = "ok",
        .mode = mode,
        .pointer_bits = @bitSizeOf(usize),
        .frame_bytes = frame.len,
        .plain_bytes = plain.len,
        .chunk_count = chunks.items.len,
        .drain_calls = calls + 1,
    }, .{}, &stdout.interface);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn appendByteChunks(allocator: std.mem.Allocator, chunks: *std.ArrayList([]const u8), frame: []const u8) !void {
    try chunks.append(allocator, frame[0..0]);
    for (frame, 0..) |_, index| {
        try chunks.append(allocator, frame[index .. index + 1]);
        try chunks.append(allocator, frame[index + 1 .. index + 1]);
    }
}

fn appendPatternedChunks(allocator: std.mem.Allocator, chunks: *std.ArrayList([]const u8), frame: []const u8) !void {
    const widths = [_]usize{ 1, 2, 7, 31, 3, 257, 5, 4093 };
    var offset: usize = 0;
    var index: usize = 0;
    while (offset < frame.len) : (index += 1) {
        const end = @min(frame.len, offset + widths[index % widths.len]);
        try chunks.append(allocator, frame[offset..end]);
        try chunks.append(allocator, frame[end..end]);
        offset = end;
    }
    if (frame.len == 0) try chunks.append(allocator, frame);
}

fn require(ok: bool) !void {
    if (!ok) return error.GzipDirectProbeMismatch;
}
