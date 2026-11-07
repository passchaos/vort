const std = @import("std");
const vort = @import("vort");

const Config = struct {
    format: vort.ZlibOrGzipFormat,
    frame_len: usize,
    dictionary_path: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const plain_path = args.next() orelse return error.MissingPlain;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.UnexpectedArgument;
    const input = try read(init, input_path, 32 * 1024 * 1024);
    defer init.gpa.free(input);
    const plain = try read(init, plain_path, 32 * 1024 * 1024);
    defer init.gpa.free(plain);
    const config_bytes = try read(init, config_path, 4096);
    defer init.gpa.free(config_bytes);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, config_bytes, .{});
    defer parsed.deinit();
    const config = parsed.value;
    const dictionary: ?[]u8 = if (config.dictionary_path) |path| try read(init, path, 4 * 1024 * 1024) else null;
    defer if (dictionary) |bytes| init.gpa.free(bytes);

    const output = try init.gpa.alloc(u8, plain.len);
    defer init.gpa.free(output);
    const prefix = if (dictionary) |bytes|
        try vort.decodeZlibOrGzipPrefixWithDictionary(input, output, bytes)
    else
        try vort.decodeZlibOrGzipPrefix(input, output);
    try require(prefix.format == config.format and prefix.input_read == config.frame_len and prefix.output_written == plain.len);
    try require(std.mem.eql(u8, output, plain));
    const strict = if (dictionary) |bytes| vort.decodeZlibOrGzipWithDictionary(input, output, bytes) else vort.decodeZlibOrGzip(input, output);
    if (strict) |_| return error.ExpectedTrailingData else |err| try require(err == error.TrailingData);

    const owned = if (dictionary) |bytes|
        try vort.decodeZlibOrGzipPrefixAllocWithDictionaryExactSize(init.gpa, input, bytes, plain.len)
    else
        try vort.decodeZlibOrGzipPrefixAllocExactSize(init.gpa, input, plain.len);
    defer owned.deinit(init.gpa);
    try require(owned.input_read == config.frame_len and std.mem.eql(u8, owned.bytes, plain));

    var history: [65_536]u8 = undefined;
    var decoder = try vort.ZlibOrGzipIncrementalDecoder.init(.{
        .expected_output_len = plain.len,
        .allow_trailing_data = true,
    }, &history);
    const actual = try init.gpa.alloc(u8, plain.len);
    defer init.gpa.free(actual);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var steps: usize = 0;
    var dictionary_requests: usize = 0;
    while (steps < input.len * 8 + plain.len * 8 + 1024) : (steps += 1) {
        const input_end = @min(input.len, input_offset + 1 + steps % 3);
        const output_end = @min(actual.len, output_offset + 1 + steps % 7);
        const stepped = decoder.step(input[input_offset..input_end], actual[output_offset..output_end]) catch |err| {
            const progress = decoder.snapshot().last_step_progress;
            input_offset += progress.input_read;
            output_offset += progress.output_written;
            if (err != error.NeedDictionary) return err;
            const bytes = dictionary orelse return error.MissingDictionary;
            try require(decoder.requiredDictionaryId() != null);
            if (decoder.provideDictionary("wrong")) |_| return error.ExpectedDictionaryMismatch else |wrong| try require(wrong == error.DictionaryMismatch);
            try decoder.provideDictionary(bytes);
            dictionary_requests += 1;
            continue;
        };
        input_offset += stepped.progress.input_read;
        output_offset += stepped.progress.output_written;
        if (stepped.status == .done) break;
        if (stepped.status == .need_input and input_offset == config.frame_len) {
            try decoder.finish();
            break;
        }
    }
    if (!decoder.snapshot().done) try decoder.finish();
    try require(decoder.selectedFormat() == config.format);
    try require(decoder.memberEndOffset() == config.frame_len);
    try require(output_offset == plain.len and std.mem.eql(u8, actual, plain));

    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try std.json.Stringify.value(.{
        .schema = "vort.deflate.zlib-or-gzip-auto-probe.v1",
        .status = "ok",
        .pointer_bits = @bitSizeOf(usize),
        .format = config.format,
        .input_bytes = input.len,
        .frame_bytes = config.frame_len,
        .output_bytes = plain.len,
        .steps = steps,
        .dictionary_requests = dictionary_requests,
    }, .{}, &stdout.interface);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn read(init: std.process.Init, path: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(limit));
}

fn require(ok: bool) !void {
    if (!ok) return error.AutoWrapperProbeMismatch;
}
