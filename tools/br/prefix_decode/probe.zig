const std = @import("std");
const codec = @import("codec");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const plain_path = args.next() orelse return error.MissingPlain;
    const mode = args.next() orelse return error.MissingMode;
    if (args.next() != null) return error.UnexpectedArgument;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(32 * 1024 * 1024));
    defer init.gpa.free(input);
    const plain = try std.Io.Dir.cwd().readFileAlloc(init.io, plain_path, init.gpa, .limited(32 * 1024 * 1024));
    defer init.gpa.free(plain);

    const output = try init.gpa.alloc(u8, plain.len + 7);
    defer init.gpa.free(output);
    @memset(output, 0xa5);
    const direct = try codec.brDecodeStreamPrefixInto(input, output);
    try require(direct.output_written == plain.len);
    try require(std.mem.eql(u8, output[0..plain.len], plain));
    try require(std.mem.allEqual(u8, output[plain.len..], 0xa5));
    try expectStrictTail(input, output);

    const size = try codec.brDecodedStreamPrefixSize(input);
    try require(size.input_read == direct.input_read and size.decoded_bytes == plain.len);
    const owned = try codec.brDecodeStreamPrefixAllocExactSize(init.gpa, input, plain.len);
    defer owned.deinit(init.gpa);
    try require(owned.input_read == direct.input_read and std.mem.eql(u8, owned.bytes, plain));
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(init.gpa);
    try appended.appendSlice(init.gpa, "saved:");
    const appended_result = try codec.brDecodeStreamPrefixAppend(init.gpa, &appended, input);
    try require(appended_result.input_read == direct.input_read);
    try require(std.mem.eql(u8, appended.items["saved:".len..], plain));

    var chunks: std.ArrayList([]const u8) = .empty;
    defer chunks.deinit(init.gpa);
    if (std.mem.eql(u8, mode, "byte")) try appendByteChunks(init.gpa, &chunks, input) else if (std.mem.eql(u8, mode, "patterned")) try appendPatternedChunks(init.gpa, &chunks, input) else return error.InvalidMode;
    const scratch = try init.gpa.alloc(u8, input.len);
    defer init.gpa.free(scratch);
    const chunked = try codec.brDecodeStreamPrefixChunksInto(chunks.items, scratch, output);
    try require(chunked.input_read == direct.input_read and chunked.output_written == direct.output_written);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try std.json.Stringify.value(.{
        .schema = "vort.br.prefix-decode-probe.v1",
        .status = "ok",
        .mode = mode,
        .pointer_bits = @bitSizeOf(usize),
        .input_bytes = input.len,
        .input_read = direct.input_read,
        .output_written = direct.output_written,
        .chunk_count = chunks.items.len,
    }, .{}, &stdout.interface);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn expectStrictTail(input: []const u8, output: []u8) !void {
    const result = codec.brDecodeStreamInto(input, output);
    if (result) |_| return error.ExpectedTrailingData else |err| try require(err == error.TrailingData);
}

fn appendByteChunks(allocator: std.mem.Allocator, chunks: *std.ArrayList([]const u8), input: []const u8) !void {
    for (input, 0..) |_, index| {
        try chunks.append(allocator, input[index .. index + 1]);
        try chunks.append(allocator, input[index + 1 .. index + 1]);
    }
}

fn appendPatternedChunks(allocator: std.mem.Allocator, chunks: *std.ArrayList([]const u8), input: []const u8) !void {
    const widths = [_]usize{ 1, 7, 2, 31, 5, 257, 4093 };
    var offset: usize = 0;
    var index: usize = 0;
    while (offset < input.len) : (index += 1) {
        const end = @min(input.len, offset + widths[index % widths.len]);
        try chunks.append(allocator, input[offset..end]);
        try chunks.append(allocator, input[end..end]);
        offset = end;
    }
}

fn require(ok: bool) !void {
    if (!ok) return error.BrotliPrefixProbeMismatch;
}
