const std = @import("std");
const codec = @import("codec");
const zlib = @import("zlib");

const Wrapper = enum { raw, zlib, gzip };
const Mode = enum { fixed, dynamic, best, adaptive };
const Case = struct {
    name: []const u8,
    input: []const u8,
    dictionary: ?[]const u8,
    block_len: usize,
    window_len: usize = 32768,
};
const Counts = struct { cases: usize = 0, inflate_calls: usize = 0, dictionary_requests: usize = 0 };

pub fn main(init: std.process.Init) !void {
    const dictionary = try init.gpa.alloc(u8, 40000);
    defer init.gpa.free(dictionary);
    fillRandom(dictionary, 0x68f124e9);
    const payload = try init.gpa.alloc(u8, 36000);
    defer init.gpa.free(payload);
    fillRandom(payload, 0x39046dc1);
    @memcpy(payload[4096..8192], payload[0..4096]);
    var residual: [4096]u8 = undefined;
    fillRandom(residual[0..1024], 0x6948ebfc);
    @memcpy(residual[1024..], dictionary[dictionary.len - 3072 ..]);
    @memcpy(payload[32768..][0..3232], dictionary[0..3232]);
    var narrow: [2304]u8 = undefined;
    fillRandom(&narrow, 0xcbd35721);
    @memcpy(narrow[512..1024], narrow[0..512]);
    @memcpy(narrow[2048..], dictionary[dictionary.len - 256 ..]);
    const cases = [_]Case{
        .{ .name = "previous-input", .input = payload[0..8192], .dictionary = null, .block_len = 1024 },
        .{ .name = "residual-dictionary", .input = &residual, .dictionary = dictionary, .block_len = 1024 },
        .{ .name = "evicted-dictionary", .input = payload, .dictionary = dictionary[0..4096], .block_len = 4096 },
        .{ .name = "narrow-window", .input = &narrow, .dictionary = dictionary[dictionary.len - 2048 ..], .block_len = 257, .window_len = 1024 },
        .{ .name = "empty-dictionary", .input = "abcdefghijklmnopqrstuvwxyz" ** 5, .dictionary = "", .block_len = 7 },
        .{ .name = "empty-input", .input = "", .dictionary = dictionary, .block_len = 7 },
    };
    var counts: Counts = .{};
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("deflate_split_history_reference zlib_version={s}\n", .{std.mem.span(zlib.zlibVersion())});
    for (cases) |case| {
        const has_dictionary = if (case.dictionary) |dict| dict.len != 0 else false;
        inline for (.{ Wrapper.raw, Wrapper.zlib, Wrapper.gzip }) |wrapper| {
            if (wrapper != .gzip or !has_dictionary) {
                var effective = case;
                if (wrapper == .gzip) effective.dictionary = null;
                inline for (.{ Mode.fixed, Mode.dynamic, Mode.best, Mode.adaptive }) |mode| {
                    const wire = try encode(init.gpa, wrapper, mode, effective);
                    defer init.gpa.free(wire);
                    if (std.mem.eql(u8, case.name, "previous-input") and wire.len >= 5000)
                        return error.MissingPreviousInputMatches;
                    if (std.mem.eql(u8, case.name, "residual-dictionary") and wire.len >= 2000)
                        return error.MissingResidualDictionaryMatches;
                    try verifyLibz(init.gpa, wrapper, wire, effective, &counts);
                    const plain = if (wrapper == .raw)
                        try codec.decodeRawAutoAllocWithDictionaryExactSize(init.gpa, wire, case.dictionary orelse "", case.input.len)
                    else if (wrapper == .gzip)
                        try codec.decodeGzipAlloc(init.gpa, wire)
                    else if (case.dictionary) |dict|
                        try codec.decodeZlibAllocWithDictionary(init.gpa, wire, dict)
                    else
                        try codec.decodeZlibAlloc(init.gpa, wire);
                    defer init.gpa.free(plain);
                    if (!std.mem.eql(u8, case.input, plain)) return error.VortContentMismatch;
                    counts.cases += 1;
                    try stdout.print("split_history_row case={s} wrapper={s} mode={s} bytes={d}\n", .{ case.name, @tagName(wrapper), @tagName(mode), wire.len });
                }
            }
        }
    }
    if (counts.cases != cases.len * 8 + 8 or counts.dictionary_requests != (cases.len - 1) * 4)
        return error.MissingCoverage;
    try stdout.print("deflate_split_history_ok cases={d} vort_decode={d} libz_decode={d} dictionary_requests={d} tiny_inflate_calls={d}\n", .{
        counts.cases, counts.cases, counts.cases, counts.dictionary_requests, counts.inflate_calls,
    });
    try stdout.flush();
}

fn encode(allocator: std.mem.Allocator, comptime wrapper: Wrapper, comptime mode: Mode, case: Case) ![]u8 {
    var options = codec.optionsForLevel(.default);
    options.lz77_options.window_len = case.window_len;
    const plain = try encodeWithOptions(allocator, wrapper, mode, case, options);
    defer allocator.free(plain);
    var profile: codec.EncodeMemoryProfile = .{};
    options.memory_profile = &profile;
    const instrumented = try encodeWithOptions(allocator, wrapper, mode, case, options);
    defer allocator.free(instrumented);
    if (!std.mem.eql(u8, plain, instrumented)) return error.ProfileChangedWire;
    options.max_total_working_memory = profile.peak_requested_bytes;
    const bounded = try encodeWithOptions(allocator, wrapper, mode, case, options);
    errdefer allocator.free(bounded);
    if (!std.mem.eql(u8, plain, bounded)) return error.BudgetChangedWire;
    return bounded;
}

fn encodeWithOptions(allocator: std.mem.Allocator, comptime wrapper: Wrapper, comptime mode: Mode, case: Case, options: codec.CompressionOptions) ![]u8 {
    const split = codec.AdaptiveSplitOptions{
        .min_block_len = case.block_len,
        .max_block_len = case.block_len * 2,
        .sample_len = @min(case.block_len, 256),
        .search_step = case.block_len,
    };
    const method_name = "encode" ++ switch (wrapper) {
        .raw => "Raw",
        .zlib => "Zlib",
        .gzip => "Gzip",
    } ++ switch (mode) {
        .fixed => "FixedSplit",
        .dynamic => "DynamicSplit",
        .best => "BestSplit",
        .adaptive => "BestAdaptiveSplit",
    };
    if (wrapper != .gzip) {
        if (case.dictionary) |dictionary| {
            const method = @field(codec, method_name ++ "WithDictionaryAlloc");
            return if (mode == .adaptive)
                method(allocator, case.input, dictionary, options, split)
            else
                method(allocator, case.input, dictionary, case.block_len, options);
        }
    }
    const method = @field(codec, method_name ++ "Alloc");
    return if (mode == .adaptive)
        method(allocator, case.input, options, split)
    else
        method(allocator, case.input, case.block_len, options);
}

fn verifyLibz(allocator: std.mem.Allocator, comptime wrapper: Wrapper, wire: []const u8, case: Case, counts: *Counts) !void {
    var stream: zlib.z_stream = std.mem.zeroes(zlib.z_stream);
    if (zlib.inflateInit2_(&stream, switch (wrapper) {
        .raw => -15,
        .zlib => 15,
        .gzip => 31,
    }, zlib.ZLIB_VERSION, @sizeOf(zlib.z_stream)) != zlib.Z_OK)
        return error.ZlibFailure;
    defer _ = zlib.inflateEnd(&stream);
    if (wrapper == .raw) {
        if (case.dictionary) |dictionary| {
            if (dictionary.len != 0 and zlib.inflateSetDictionary(&stream, dictionary.ptr, @intCast(dictionary.len)) != zlib.Z_OK)
                return error.ZlibDictionaryFailure;
        }
    }
    const plain = try allocator.alloc(u8, case.input.len + 1);
    defer allocator.free(plain);
    @memset(plain, 0xa5);
    var supplied: usize = 0;
    var written: usize = 0;
    var dictionary_set = false;
    while (true) {
        if (stream.avail_in == 0 and supplied < wire.len) {
            const len = @min(@as(usize, 5), wire.len - supplied);
            stream.next_in = @constCast(wire[supplied..].ptr);
            stream.avail_in = @intCast(len);
            supplied += len;
        }
        const before_input = stream.avail_in;
        const capacity = @min(@as(usize, 13), plain.len - written);
        if (capacity == 0) return error.OutputOverrun;
        stream.next_out = plain[written..].ptr;
        stream.avail_out = @intCast(capacity);
        const result = zlib.inflate(&stream, zlib.Z_NO_FLUSH);
        counts.inflate_calls += 1;
        const produced = capacity - stream.avail_out;
        written += produced;
        if (written > case.input.len) return error.OutputOverrun;
        if (result == zlib.Z_STREAM_END) break;
        if (result == zlib.Z_NEED_DICT) {
            if (dictionary_set) return error.RepeatedDictionaryRequest;
            const dictionary = case.dictionary orelse return error.UnexpectedDictionaryRequest;
            if (zlib.inflateSetDictionary(&stream, dictionary.ptr, @intCast(dictionary.len)) != zlib.Z_OK)
                return error.ZlibDictionaryFailure;
            counts.dictionary_requests += 1;
            dictionary_set = true;
            continue;
        }
        if (result != zlib.Z_OK and result != zlib.Z_BUF_ERROR) return error.ZlibFailure;
        if (stream.avail_in == before_input and produced == 0) return error.NoProgress;
    }
    if (supplied != wire.len or stream.avail_in != 0) return error.TrailingCompressedData;
    if (written != case.input.len or !std.mem.eql(u8, case.input, plain[0..written]))
        return error.ZlibContentMismatch;
    if (plain[case.input.len] != 0xa5) return error.OutputOverrun;
    if (wrapper == .zlib and dictionary_set != (case.dictionary != null)) return error.MissingDictionaryRequest;
}

fn fillRandom(bytes: []u8, seed: u32) void {
    var state = seed;
    for (bytes) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
}
