const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    const dict = "dictionary-only phrase with enough length to beat stored framing";
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("case,input_bytes,stream_bytes,frames,modes_store,modes_deflate,modes_rle,modes_dict,modes_ldm,range_offset,range_len,range_crc32\n", .{});

    var any = false;
    while (args.next()) |path| {
        any = true;
        const input = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(input);
        const stream = try vort.storeEncodeBlockedBestStreamAlloc(init.gpa, input, 8192);
        defer init.gpa.free(stream);
        try reportCase(init, stdout, path, input, stream, null);
    }
    if (any) {
        try stdout.flush();
        return;
    }

    const store_input = "alphabetagamma";
    const store_stream = try makeStoreStream(init.gpa);
    defer init.gpa.free(store_stream);
    try reportCase(init, stdout, "store-indexed", store_input, store_stream, null);

    const blocked_input = "abcdefghijklmnopqrstuvwxyz" ++ ("aaaaaaaaaaaaaaaa" ** 2) ++ ("abcabcabcabc" ** 2);
    const blocked_stream = try vort.storeEncodeBlockedBestStreamAlloc(init.gpa, blocked_input, 16);
    defer init.gpa.free(blocked_stream);
    try reportCase(init, stdout, "blocked-best", blocked_input, blocked_stream, null);

    const dict_input = (dict ++ "!") ** 3;
    const dict_stream = try vort.storeEncodeBlockedBestWithDictionaryStreamAlloc(init.gpa, dict, dict_input, dict.len + 1, 8);
    defer init.gpa.free(dict_stream);
    try reportCase(init, stdout, "dict-blocked", dict_input, dict_stream, dict);

    const self_dict_phrase = "self-contained dictionary phrase for native streams";
    const self_dict_input = (self_dict_phrase ++ "!") ** 4;
    const self_dict_stream = try vort.storeEncodeSelfContainedDictionaryStreamAlloc(init.gpa, self_dict_input, self_dict_phrase.len + 1, 256, 8);
    defer init.gpa.free(self_dict_stream);
    try reportSelfContainedDictionaryCase(init, stdout, "self-dict-blocked", self_dict_input, self_dict_stream);

    const ldm_prefix = makeLdmPrefix();
    const ldm_input = ldm_prefix ++ "----" ++ ldm_prefix[0..1024].* ++ "tail";
    const ldm_stream = try makeLdmStream(init.gpa, &ldm_prefix);
    defer init.gpa.free(ldm_stream);
    try reportCase(init, stdout, "ldm-indexed", ldm_input, ldm_stream, null);

    const ldm_blocked_stream = try vort.storeEncodeBlockedBestStreamWithLdmAlloc(init.gpa, ldm_input, ldm_input.len, .{}, .{ .min_distance = 32769, .min_length = 16 });
    defer init.gpa.free(ldm_blocked_stream);
    try reportCase(init, stdout, "ldm-blocked-best", ldm_input, ldm_blocked_stream, null);
    try stdout.flush();
}

fn reportCase(init: std.process.Init, stdout: *std.Io.Writer, name: []const u8, input: []const u8, stream: []const u8, dict: ?[]const u8) !void {
    const range_offset: usize = if (input.len == 0) 0 else @min(5, input.len - 1);
    const range_len: usize = @min(32, input.len - range_offset);
    const range = if (dict) |dictionary|
        try vort.storeDecodeIndexedRangeWithDictionaryAlloc(init.gpa, dictionary, stream, range_offset, range_len)
    else
        try vort.storeDecodeIndexedRangeAlloc(init.gpa, stream, range_offset, range_len);
    defer init.gpa.free(range);
    try printRangeReport(stdout, name, input, stream, range_offset, range_len, range);
}

fn reportSelfContainedDictionaryCase(init: std.process.Init, stdout: *std.Io.Writer, name: []const u8, input: []const u8, stream: []const u8) !void {
    const range_offset: usize = if (input.len == 0) 0 else @min(5, input.len - 1);
    const range_len: usize = @min(32, input.len - range_offset);
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
