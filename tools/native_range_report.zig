const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    const dict = "dictionary-only phrase with enough length to beat stored framing";
    var requested_offset: ?usize = null;
    var requested_len: ?usize = null;
    var sweep = false;
    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(init.gpa);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--offset")) {
            requested_offset = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
            continue;
        }
        if (std.mem.eql(u8, arg, "--length")) {
            requested_len = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
            continue;
        }
        if (std.mem.eql(u8, arg, "--sweep")) {
            sweep = true;
            continue;
        }
        try paths.append(init.gpa, arg);
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("case,input_bytes,stream_bytes,frames,modes_store,modes_deflate,modes_rle,modes_dict,modes_ldm,range_offset,range_len,range_crc32\n", .{});

    const range_options = RangeOptions{ .offset = requested_offset, .length = requested_len };
    var any = false;
    for (paths.items) |path| {
        any = true;
        const input = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(input);
        const stream = try vort.storeEncodeBlockedBestStreamAlloc(init.gpa, input, 8192);
        defer init.gpa.free(stream);
        if (sweep)
            try reportSweep(init, stdout, path, input, stream, null)
        else
            try reportCase(init, stdout, path, input, stream, null, range_options);
    }
    if (any) {
        try stdout.flush();
        return;
    }

    const store_input = "alphabetagamma";
    const store_stream = try makeStoreStream(init.gpa);
    defer init.gpa.free(store_stream);
    if (sweep) try reportSweep(init, stdout, "store-indexed", store_input, store_stream, null) else try reportCase(init, stdout, "store-indexed", store_input, store_stream, null, range_options);

    const blocked_input = "abcdefghijklmnopqrstuvwxyz" ++ ("aaaaaaaaaaaaaaaa" ** 2) ++ ("abcabcabcabc" ** 2);
    const blocked_stream = try vort.storeEncodeBlockedBestStreamAlloc(init.gpa, blocked_input, 16);
    defer init.gpa.free(blocked_stream);
    if (sweep) try reportSweep(init, stdout, "blocked-best", blocked_input, blocked_stream, null) else try reportCase(init, stdout, "blocked-best", blocked_input, blocked_stream, null, range_options);

    const dict_input = (dict ++ "!") ** 3;
    const dict_stream = try vort.storeEncodeBlockedBestWithDictionaryStreamAlloc(init.gpa, dict, dict_input, dict.len + 1, 8);
    defer init.gpa.free(dict_stream);
    if (sweep) try reportSweep(init, stdout, "dict-blocked", dict_input, dict_stream, dict) else try reportCase(init, stdout, "dict-blocked", dict_input, dict_stream, dict, range_options);

    const self_dict_phrase = "self-contained dictionary phrase for native streams";
    const self_dict_input = (self_dict_phrase ++ "!") ** 4;
    const self_dict_stream = try vort.storeEncodeSelfContainedDictionaryStreamAlloc(init.gpa, self_dict_input, self_dict_phrase.len + 1, 256, 8);
    defer init.gpa.free(self_dict_stream);
    if (sweep) try reportSelfContainedDictionarySweep(init, stdout, "self-dict-blocked", self_dict_input, self_dict_stream) else try reportSelfContainedDictionaryCase(init, stdout, "self-dict-blocked", self_dict_input, self_dict_stream, range_options);

    const ldm_prefix = makeLdmPrefix();
    const ldm_input = ldm_prefix ++ "----" ++ ldm_prefix[0..1024].* ++ "tail";
    const ldm_stream = try makeLdmStream(init.gpa, &ldm_prefix);
    defer init.gpa.free(ldm_stream);
    if (sweep) try reportSweep(init, stdout, "ldm-indexed", ldm_input, ldm_stream, null) else try reportCase(init, stdout, "ldm-indexed", ldm_input, ldm_stream, null, range_options);

    const ldm_blocked_stream = try vort.storeEncodeBlockedBestStreamWithLdmAlloc(init.gpa, ldm_input, ldm_input.len, .{}, .{ .min_distance = 32769, .min_length = 16 });
    defer init.gpa.free(ldm_blocked_stream);
    if (sweep) try reportSweep(init, stdout, "ldm-blocked-best", ldm_input, ldm_blocked_stream, null) else try reportCase(init, stdout, "ldm-blocked-best", ldm_input, ldm_blocked_stream, null, range_options);
    try stdout.flush();
}

const RangeOptions = struct {
    offset: ?usize = null,
    length: ?usize = null,
};

fn chooseRange(input: []const u8, options: RangeOptions) struct { offset: usize, len: usize } {
    const offset = if (input.len == 0) 0 else @min(options.offset orelse 5, input.len - 1);
    return .{ .offset = offset, .len = @min(options.length orelse 32, input.len - offset) };
}

fn reportSweep(init: std.process.Init, stdout: *std.Io.Writer, name: []const u8, input: []const u8, stream: []const u8, dict: ?[]const u8) !void {
    const offsets = [_]usize{ 0, 5, if (input.len == 0) 0 else input.len / 2 };
    for (&offsets) |offset| try reportCase(init, stdout, name, input, stream, dict, .{ .offset = offset, .length = 32 });
}

fn reportSelfContainedDictionarySweep(init: std.process.Init, stdout: *std.Io.Writer, name: []const u8, input: []const u8, stream: []const u8) !void {
    const offsets = [_]usize{ 0, 5, if (input.len == 0) 0 else input.len / 2 };
    for (&offsets) |offset| try reportSelfContainedDictionaryCase(init, stdout, name, input, stream, .{ .offset = offset, .length = 32 });
}

fn reportCase(init: std.process.Init, stdout: *std.Io.Writer, name: []const u8, input: []const u8, stream: []const u8, dict: ?[]const u8, options: RangeOptions) !void {
    const selected = chooseRange(input, options);
    const range_offset = selected.offset;
    const range_len = selected.len;
    const range = if (dict) |dictionary|
        try vort.storeDecodeIndexedRangeWithDictionaryAlloc(init.gpa, dictionary, stream, range_offset, range_len)
    else
        try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, range_offset, range_len);
    defer init.gpa.free(range);
    try printRangeReport(stdout, name, input, stream, range_offset, range_len, range);
}

fn reportSelfContainedDictionaryCase(init: std.process.Init, stdout: *std.Io.Writer, name: []const u8, input: []const u8, stream: []const u8, options: RangeOptions) !void {
    const selected = chooseRange(input, options);
    const range_offset = selected.offset;
    const range_len = selected.len;
    const range = try vort.storeDecodeSelfContainedDictionaryRangeAlloc(init.gpa, stream, range_offset, range_len);
    defer init.gpa.free(range);
    try printRangeReport(stdout, name, input, stream, range_offset, range_len, range);
}

fn printRangeReport(stdout: *std.Io.Writer, name: []const u8, input: []const u8, stream: []const u8, range_offset: usize, range_len: usize, range: []const u8) !void {
    const modes = try vort.storeSummarizeModes(stream);
    const frames = try vort.store.countConcatenatedFrames(stream);
    if (!std.mem.eql(u8, input[range_offset..][0..range_len], range)) return error.RoundTripMismatch;
    try stdout.print("{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{
        name,
        input.len,
        stream.len,
        frames,
        modes.store,
        modes.deflate,
        modes.rle,
        modes.dictionary_patch + modes.dictionary_deflate,
        modes.ldm,
        range_offset,
        range_len,
        vort.crc32(range),
    });
}

fn makeStoreStream(allocator: std.mem.Allocator) ![]u8 {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    return vort.storeEncodeIndexedStreamAlloc(allocator, &payloads);
}

fn makeLdmStream(allocator: std.mem.Allocator, prefix: *const [33_000]u8) ![]u8 {
    const payloads = [_][]const u8{
        prefix.* ++ "----" ++ prefix[0..1024].*,
        "tail",
    };
    return vort.storeEncodeIndexedLongDistanceStreamAlloc(allocator, &payloads, .{ .min_distance = 32769, .min_length = 16 });
}

fn makeLdmPrefix() [33_000]u8 {
    var out: [33_000]u8 = undefined;
    var x: u32 = 0x1234_5678;
    for (&out) |*byte| {
        x = x *% 1664525 +% 1013904223;
        byte.* = @truncate(x >> 24);
    }
    return out;
}
