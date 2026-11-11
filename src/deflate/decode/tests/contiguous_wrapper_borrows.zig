//! Whole-operation borrows for contiguous wrapper output and scalar reset.
const std = @import("std");
const t = std.testing;
const raw = [_]u8{ 0, 3, 0, 0xfc, 0xff, 'a', 'b', 'c', 1, 3, 0, 0xfc, 0xff, 'd', 'e', 'f' };
const zlib = [_]u8{ 0x78, 1, 0, 3, 0, 0xfc, 0xff, 'a', 'b', 'c', 1, 3, 0, 0xfc, 0xff, 'd', 'e', 'f', 8, 0x1e, 2, 0x56 };
const gzip = [_]u8{ 0x1f, 0x8b, 8, 0, 0, 0, 0, 0, 0, 3, 0, 3, 0, 0xfc, 0xff, 'a', 'b', 'c', 1, 3, 0, 0xfc, 0xff, 'd', 'e', 'f', 0xef, 0x39, 0x8e, 0x4b, 6, 0, 0, 0 };
const Api = enum { z, z_options, z_dictionary, z_dictionary_options, z_stored, z_stored_dictionary, z_concat, z_concat_options, z_concat_dictionary, z_concat_dictionary_options, g, g_options, g_stored, g_concat, g_concat_options, auto, auto_options, auto_dictionary, auto_dictionary_options, prefix, prefix_options, prefix_dictionary, prefix_dictionary_options };
const Format = enum { zlib, gzip };
fn supports(comptime api: Api, comptime format: Format) bool {
    return switch (api) {
        .z, .z_options, .z_dictionary, .z_dictionary_options, .z_stored, .z_stored_dictionary, .z_concat, .z_concat_options, .z_concat_dictionary, .z_concat_dictionary_options => format == .zlib,
        .g, .g_options, .g_stored, .g_concat, .g_concat_options => format == .gzip,
        else => true,
    };
}
fn dictionaryApi(comptime api: Api) bool {
    return switch (api) {
        .z_dictionary, .z_dictionary_options, .z_stored_dictionary, .z_concat_dictionary, .z_concat_dictionary_options, .auto_dictionary, .auto_dictionary_options, .prefix_dictionary, .prefix_dictionary_options => true,
        else => false,
    };
}
fn invoke(comptime D: type, comptime api: Api, input: []const u8, output: []u8, dictionary: []const u8) !usize {
    const zo: D.ZlibDecodeOptions = .{ .ignore_adler = true };
    const go: D.GzipDecodeOptions = .{ .ignore_crc32 = true };
    const ao: D.ZlibOrGzipDecodeOptions = .{ .zlib = zo, .gzip = go };
    return switch (api) {
        .z => D.decodeZlib(input, output),
        .z_options => D.decodeZlibWithOptions(input, output, zo),
        .z_dictionary => D.decodeZlibWithDictionary(input, output, dictionary),
        .z_dictionary_options => D.decodeZlibWithDictionaryAndOptions(input, output, dictionary, zo),
        .z_stored => D.decodeZlibStored(input, output),
        .z_stored_dictionary => D.decodeZlibStoredWithDictionary(input, output, dictionary),
        .z_concat => D.decodeZlibConcatenated(input, output),
        .z_concat_options => D.decodeZlibConcatenatedWithOptions(input, output, zo),
        .z_concat_dictionary => D.decodeZlibConcatenatedWithDictionary(input, output, dictionary),
        .z_concat_dictionary_options => D.decodeZlibConcatenatedWithDictionaryAndOptions(input, output, dictionary, zo),
        .g => D.decodeGzip(input, output),
        .g_options => D.decodeGzipWithOptions(input, output, go),
        .g_stored => D.decodeGzipStored(input, output),
        .g_concat => D.decodeGzipConcatenated(input, output),
        .g_concat_options => D.decodeGzipConcatenatedWithOptions(input, output, go),
        .auto => D.decodeZlibOrGzip(input, output),
        .auto_options => D.decodeZlibOrGzipWithOptions(input, output, ao),
        .auto_dictionary => D.decodeZlibOrGzipWithDictionary(input, output, dictionary),
        .auto_dictionary_options => D.decodeZlibOrGzipWithDictionaryAndOptions(input, output, dictionary, ao),
        .prefix, .prefix_options, .prefix_dictionary, .prefix_dictionary_options => blk: {
            const result = switch (api) {
                .prefix => try D.decodeZlibOrGzipPrefix(input, output),
                .prefix_options => try D.decodeZlibOrGzipPrefixWithOptions(input, output, ao),
                .prefix_dictionary => try D.decodeZlibOrGzipPrefixWithDictionary(input, output, dictionary),
                .prefix_dictionary_options => try D.decodeZlibOrGzipPrefixWithDictionaryAndOptions(input, output, dictionary, ao),
                else => unreachable,
            };
            const expected_read = if (input.len >= 4 and std.mem.endsWith(u8, input, "TAIL")) input.len - 4 else input.len;
            try t.expectEqual(expected_read, result.input_read);
            break :blk result.output_written;
        },
    };
}

fn outputMatrix(comptime D: type, comptime format: Format, comptime api: Api) !void {
    errdefer std.debug.print("wrapper matrix format={s} api={s}\n", .{ @tagName(format), @tagName(api) });
    const wire: []const u8 = if (format == .zlib) &zlib else &gzip;
    const end = 64 + wire.len;
    const Range = struct { start: usize, len: usize };
    const ranges = [_]Range{ .{ .start = 64, .len = wire.len }, .{ .start = 62, .len = 6 }, .{ .start = end - 1, .len = 6 }, .{ .start = 65, .len = 1 }, .{ .start = 63, .len = wire.len + 2 }, .{ .start = 57, .len = 8 }, .{ .start = end, .len = 6 }, .{ .start = 64 + @as(usize, if (format == .zlib) 15 else 23), .len = 6 } };
    for (ranges, 0..) |range, index| {
        errdefer std.debug.print("wrapper format={s} api={s} range={d}\n", .{ @tagName(format), @tagName(api), index });
        var backing: [256]u8 = @splat(0xa5);
        @memcpy(backing[64..end], wire);
        @memcpy(backing[end..][0..4], "TAIL");
        const before = backing;
        const input = backing[64 .. end + @as(usize, if (index == 6) 4 else 0)];
        try t.expectError(error.InvalidBlockPlan, invoke(D, api, input, backing[range.start..][0..range.len], ""));
        try t.expectEqualSlices(u8, &before, &backing);
        var retry: [6]u8 = undefined;
        try t.expectEqual(@as(usize, 6), try invoke(D, api, backing[64..end], &retry, ""));
        try t.expectEqualSlices(u8, "abcdef", &retry);
        try t.expectEqualSlices(u8, &before, &backing);
    }
    for ([_]usize{ 58, end }) |output_start| {
        var backing: [256]u8 = @splat(0xa5);
        @memcpy(backing[64..end], wire);
        const output = backing[output_start..][0..6];
        try t.expectEqual(@as(usize, 6), try invoke(D, api, backing[64..end], output, ""));
        try t.expectEqualSlices(u8, "abcdef", output);
        try t.expectEqualSlices(u8, wire, backing[64..end]);
    }
    if (comptime dictionaryApi(api)) {
        for ([_]usize{ 32, 37, 39 }) |dictionary_start| {
            var backing: [64]u8 = @splat(0xa5);
            @memcpy(backing[dictionary_start..][0..4], "dict");
            const before = backing;
            if (comptime format == .gzip) {
                // Auto gzip explicitly ignores its dictionary argument; it is no read borrow.
                try t.expectEqual(@as(usize, 6), try invoke(D, api, wire, backing[32..40], backing[dictionary_start..][0..4]));
                try t.expectEqualSlices(u8, "abcdef", backing[32..38]);
                try t.expectEqualSlices(u8, before[0..32], backing[0..32]);
                try t.expectEqualSlices(u8, before[38..], backing[38..]);
            } else {
                try t.expectError(error.InvalidBlockPlan, invoke(D, api, wire, backing[32..40], backing[dictionary_start..][0..4]));
                try t.expectEqualSlices(u8, &before, &backing);
            }
        }
        var output: [6]u8 = undefined;
        try t.expectEqual(@as(usize, 6), try invoke(D, api, wire, &output, wire)); // Two read borrows may share.
    }
    var empty_output: [6]u8 = @splat(0xa5);
    try t.expectError(error.TruncatedFrame, invoke(D, api, "", &empty_output, &empty_output));
    try t.expectError(error.OutputTooSmall, invoke(D, api, wire, empty_output[0..0], ""));
}

fn dictionarySet(comptime D: type) !void {
    const first = try D.encodeZlibFixedWithDictionaryAlloc(t.allocator, "alpha alpha alpha", "alpha ", .{});
    defer t.allocator.free(first);
    const second = try D.encodeZlibFixedWithDictionaryAlloc(t.allocator, "beta beta beta", "beta ", .{});
    defer t.allocator.free(second);
    const input = try t.allocator.alloc(u8, first.len + second.len);
    defer t.allocator.free(input);
    @memcpy(input[0..first.len], first);
    @memcpy(input[first.len..], second);
    const plain = "alpha alpha alphabeta beta beta";
    inline for (0..5) |site| {
        var backing: [256]u8 = @splat(0xa5);
        var entries = [_]D.ZlibDictionaryEntry{ D.ZlibDictionarySet.entry("alpha "), D.ZlibDictionarySet.entry("beta "), D.ZlibDictionarySet.entry("unused"), D.ZlibDictionarySet.entry("other") };
        var output: []u8 = backing[128..][0..plain.len];
        var borrowed_input: []const u8 = input;
        switch (site) {
            0 => {
                @memcpy(backing[128..133], "beta ");
                entries[1].bytes = backing[128..133]; // Selected only by the later member.
            },
            1 => {
                @memcpy(backing[128..134], "unused");
                entries[2].bytes = backing[128..134]; // Entire set, including unselected entries.
            },
            2 => output = std.mem.asBytes(&entries)[@sizeOf(D.ZlibDictionaryEntry)..][0..plain.len],
            3 => {
                @memcpy(backing[128..][0..input.len], input);
                borrowed_input = backing[128..][0..input.len];
            },
            4 => {
                @memcpy(backing[159..164], "beta ");
                entries[1].bytes = backing[159..164];
                output = backing[128..160]; // Dictionary intersects only unused output tail.
            },
            else => unreachable,
        }
        const before = backing;
        const entries_before = entries;
        inline for (.{ false, true }) |options| {
            const set = D.ZlibDictionarySet.fromEntries(&entries);
            const result = if (options) D.decodeZlibConcatenatedWithDictionarySetAndOptions(borrowed_input, output, set, .{ .ignore_adler = true }) else D.decodeZlibConcatenatedWithDictionarySet(borrowed_input, output, set);
            try t.expectError(error.InvalidBlockPlan, result);
            try t.expectEqualSlices(u8, &before, &backing);
            for (entries_before, entries) |old, current| {
                try t.expectEqual(old.id, current.id);
                try t.expectEqual(old.bytes.ptr, current.bytes.ptr);
                try t.expectEqual(old.bytes.len, current.bytes.len);
            }
        }
        var retry: [plain.len]u8 = undefined;
        try t.expectEqual(plain.len, try D.decodeZlibConcatenatedWithDictionarySet(borrowed_input, &retry, D.ZlibDictionarySet.fromEntries(&entries)));
        try t.expectEqualSlices(u8, plain, &retry);
    }
    var adjacent: [96]u8 = @splat(0xa5);
    @memcpy(adjacent[0..6], "alpha ");
    const entries = [_]D.ZlibDictionaryEntry{ D.ZlibDictionarySet.entry(adjacent[0..6]), D.ZlibDictionarySet.entry("beta "), D.ZlibDictionarySet.entry(input) };
    const set = D.ZlibDictionarySet.fromEntries(&entries);
    try t.expectEqual(plain.len, try D.decodeZlibConcatenatedWithDictionarySet(input, adjacent[6..][0..plain.len], set));
    try t.expectEqualSlices(u8, "alpha ", adjacent[0..6]);
    const owned = try D.decodeZlibConcatenatedAllocWithDictionarySetExactSize(t.allocator, input, set, plain.len);
    defer t.allocator.free(owned);
    try t.expectEqualSlices(u8, plain, owned);
    try t.expectError(error.SizeMismatch, D.decodeZlibConcatenatedAllocWithDictionarySetExactSize(t.allocator, input, set, plain.len + 1));
    try t.expectError(error.NeedDictionary, D.decodeZlibConcatenatedAllocWithDictionarySetExactSize(t.allocator, input, D.ZlibDictionarySet.fromEntries(entries[0..1]), plain.len));
    var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    try t.expectError(error.OutOfMemory, D.decodeZlibConcatenatedAllocWithDictionarySetExactSize(failing.allocator(), input, set, plain.len));
    const huge_len = std.math.maxInt(usize) / @sizeOf(D.ZlibDictionaryEntry) + 1;
    const huge_entries = @as([*]const D.ZlibDictionaryEntry, @ptrCast(&entries))[0..huge_len];
    var protected_output: [plain.len]u8 = @splat(0xa5);
    const before = protected_output;
    try t.expectError(error.IntegerOverflow, D.decodeZlibConcatenatedWithDictionarySet(input, &protected_output, D.ZlibDictionarySet.fromEntries(huge_entries)));
    try t.expectEqualSlices(u8, &before, &protected_output);
    try t.expectError(error.TruncatedFrame, D.decodeZlibConcatenatedWithDictionarySet("", &protected_output, D.ZlibDictionarySet.fromEntries(huge_entries)));
}

fn concatenatedMembers(comptime D: type, comptime format: Format) !void {
    const wire: []const u8 = if (format == .zlib) &zlib else &gzip;
    inline for (.{ false, true }) |options| {
        var both: [2 * (if (format == .zlib) zlib.len else gzip.len)]u8 = undefined;
        @memcpy(both[0..wire.len], wire);
        @memcpy(both[wire.len..], wire);
        const before = both;
        const aliased = both[wire.len..][0..12]; // First output would overwrite the next header.
        const rejected = if (format == .zlib)
            (if (options) D.decodeZlibConcatenatedWithOptions(&both, aliased, .{ .ignore_adler = true }) else D.decodeZlibConcatenated(&both, aliased))
        else
            (if (options) D.decodeGzipConcatenatedWithOptions(&both, aliased, .{ .ignore_crc32 = true }) else D.decodeGzipConcatenated(&both, aliased));
        try t.expectError(error.InvalidBlockPlan, rejected);
        try t.expectEqualSlices(u8, &before, &both);
        var output: [12]u8 = undefined;
        const written = if (format == .zlib) try D.decodeZlibConcatenated(&both, &output) else try D.decodeGzipConcatenated(&both, &output);
        try t.expectEqual(output.len, written);
        try t.expectEqualSlices(u8, "abcdefabcdef", &output);
    }
}

const Kind = enum { raw, zlib, gzip };
fn reset(comptime kind: Kind, comptime variant: usize, decoder: anytype, input: []const u8, dictionary: []const u8, output: []u8) !void {
    if (kind == .raw) return switch (variant) {
        0 => decoder.reset(input, output),
        1 => decoder.resetExactSize(input, output, 6),
        2 => decoder.resetWithDictionary(input, dictionary, output),
        3 => decoder.resetWithDictionaryExactSize(input, dictionary, output, 6),
        else => unreachable,
    };
    if (kind == .gzip) return switch (variant) {
        0 => decoder.reset(input, output),
        1 => decoder.resetWithOptions(input, output, .{ .ignore_crc32 = true }),
        2 => decoder.resetExactSize(input, output, 6),
        3 => decoder.resetWithOptionsExactSize(input, output, .{ .ignore_crc32 = true }, 6),
        4 => decoder.resetConcatenated(input, output),
        5 => decoder.resetConcatenatedWithOptions(input, output, .{ .ignore_crc32 = true }),
        6 => decoder.resetConcatenatedExactSize(input, output, 6),
        7 => decoder.resetConcatenatedWithOptionsExactSize(input, output, .{ .ignore_crc32 = true }, 6),
        else => unreachable,
    };
    return switch (variant) {
        0 => decoder.reset(input, output),
        1 => decoder.resetWithOptions(input, output, .{ .ignore_adler = true }),
        2 => decoder.resetExactSize(input, output, 6),
        3 => decoder.resetWithOptionsExactSize(input, output, .{ .ignore_adler = true }, 6),
        4 => decoder.resetWithDictionary(input, dictionary, output),
        5 => decoder.resetWithDictionaryAndOptions(input, dictionary, output, .{ .ignore_adler = true }),
        6 => decoder.resetWithDictionaryExactSize(input, dictionary, output, 6),
        7 => decoder.resetWithDictionaryAndOptionsExactSize(input, dictionary, output, .{ .ignore_adler = true }, 6),
        8 => decoder.resetConcatenated(input, output),
        9 => decoder.resetConcatenatedWithOptions(input, output, .{ .ignore_adler = true }),
        10 => decoder.resetConcatenatedExactSize(input, output, 6),
        11 => decoder.resetConcatenatedWithOptionsExactSize(input, output, .{ .ignore_adler = true }, 6),
        12 => decoder.resetConcatenatedWithDictionary(input, dictionary, output),
        13 => decoder.resetConcatenatedWithDictionaryAndOptions(input, dictionary, output, .{ .ignore_adler = true }),
        14 => decoder.resetConcatenatedWithDictionaryExactSize(input, dictionary, output, 6),
        15 => decoder.resetConcatenatedWithDictionaryAndOptionsExactSize(input, dictionary, output, .{ .ignore_adler = true }, 6),
        else => unreachable,
    };
}
fn expectState(before: anytype, after: anytype) !void {
    try t.expectEqual(before.decoded.ptr, after.decoded.ptr);
    try t.expectEqual(before.decoded.len, after.decoded.len);
    try t.expectEqual(before.frame_len, after.frame_len);
    try t.expectEqual(before.offset, after.offset);
    try t.expectEqual(before.done, after.done);
    try t.expectEqualSlices(u8, before.last_error_name, after.last_error_name);
    try t.expectEqual(before.last_recoverability_hint, after.last_recoverability_hint);
}
fn scalarResets(comptime D: type, comptime kind: Kind) !void {
    const Decoder = switch (kind) {
        .raw => D.RawDeflateDecoder,
        .zlib => D.ZlibDecoder,
        .gzip => D.GzipDecoder,
    };
    const wire: []const u8 = switch (kind) {
        .raw => &raw,
        .zlib => &zlib,
        .gzip => &gzip,
    };
    const count = switch (kind) {
        .raw => 4,
        .zlib => 16,
        .gzip => 8,
    };
    inline for (0..count) |variant| {
        const uses_dictionary = kind == .raw and variant >= 2 or kind == .zlib and (variant >= 4 and variant < 8 or variant >= 12);
        inline for (0..7) |site| {
            if (comptime (site == 2 or site == 4 or site == 6) and !uses_dictionary) continue;
            errdefer std.debug.print("scalar kind={s} variant={d} site={d}\n", .{ @tagName(kind), variant, site });
            var old_output: [64]u8 = @splat(0xa5);
            var decoder: Decoder = .{};
            try reset(kind, variant, &decoder, wire, "", &old_output);
            decoder.offset = 2;
            const state_before = decoder;
            const old_before = old_output;
            var backing: [256]u8 = @splat(0xa5);
            @memcpy(backing[64..][0..wire.len], wire);
            var output_storage: [64]u8 = @splat(0xa5);
            var input: []const u8 = wire;
            var dictionary: []const u8 = "";
            var output: []u8 = &output_storage;
            switch (site) {
                0 => output = std.mem.asBytes(&decoder),
                1 => input = std.mem.asBytes(&decoder)[0..1],
                2 => dictionary = std.mem.asBytes(&decoder),
                3 => {
                    input = backing[64..][0..wire.len];
                    output = backing[64..][0..wire.len];
                },
                4 => {
                    dictionary = backing[128..129];
                    output = backing[128..134];
                },
                5 => {
                    input = backing[64..][0..wire.len];
                    output = backing[57..65]; // Only unused output tail intersects input.
                },
                6 => {
                    dictionary = backing[128..129];
                    output = backing[121..129]; // Exact-size slicing cannot hide this borrow.
                },
                else => unreachable,
            }
            const before = backing;
            const output_before = output_storage;
            try t.expectError(error.InvalidBlockPlan, reset(kind, variant, &decoder, input, dictionary, output));
            try expectState(state_before, decoder);
            try t.expectEqualSlices(u8, &old_before, &old_output);
            try t.expectEqualSlices(u8, &before, &backing);
            try t.expectEqualSlices(u8, &output_before, &output_storage);
            // Empty input does not bypass receiver geometry: recordError would write it.
            try t.expectError(error.InvalidBlockPlan, reset(kind, variant, &decoder, "", "", std.mem.asBytes(&decoder)));
            if (comptime uses_dictionary) try t.expectError(error.InvalidBlockPlan, reset(kind, variant, &decoder, "", std.mem.asBytes(&decoder), &output_storage));
            try expectState(state_before, decoder);
            // Reusing the previous decoded output is a valid reset with independent input.
            try reset(kind, variant, &decoder, wire, "", &old_output);
            try t.expectEqualSlices(u8, "abcdef", decoder.decoded);
            try t.expectEqual(@as(usize, 0), decoder.offset);
            // Empty input with receiver-disjoint data keeps its ordinary error priority.
            try t.expectError(error.TruncatedFrame, reset(kind, variant, &decoder, "", &output_storage, &output_storage));
            try t.expectEqualSlices(u8, &output_before, &output_storage);
        }
    }
}

fn ordinary(comptime D: type) !void {
    var output: [6]u8 = undefined;
    var bad_zlib = zlib;
    bad_zlib[zlib.len - 4] ^= 1;
    try t.expectError(error.ChecksumMismatch, D.decodeZlib(&bad_zlib, &output));
    try t.expectEqual(@as(usize, 6), try D.decodeZlibWithOptions(&bad_zlib, &output, .{ .ignore_adler = true }));
    var bad_gzip = gzip;
    bad_gzip[gzip.len - 8] ^= 1;
    try t.expectError(error.ChecksumMismatch, D.decodeGzip(&bad_gzip, &output));
    try t.expectEqual(@as(usize, 6), try D.decodeGzipWithOptions(&bad_gzip, &output, .{ .ignore_crc32 = true }));
    var tail: [gzip.len + 4]u8 = undefined;
    @memcpy(tail[0..gzip.len], &gzip);
    @memcpy(tail[gzip.len..], "TAIL");
    try t.expectError(error.TrailingData, D.decodeGzip(&tail, &output));
    _ = try invoke(D, .prefix, &tail, &output, "");
    try t.expectEqual(@as(usize, 6), try D.decodeGzipWithOptions(&tail, &output, .{ .allow_trailing_data = true }));
    try t.expectError(error.OutputLimitExceeded, D.decodeZlibAllocLimited(t.allocator, &zlib, 5));
    try t.expectError(error.OutputLimitExceeded, D.decodeGzipAllocLimited(t.allocator, &gzip, 5));
}

pub fn contracts(comptime D: type) !void {
    inline for (std.enums.values(Format)) |format| {
        inline for (std.enums.values(Api)) |api| {
            if (comptime supports(api, format)) try outputMatrix(D, format, api);
        }
        try concatenatedMembers(D, format);
    }
    try dictionarySet(D);
    inline for (std.enums.values(Kind)) |kind| try scalarResets(D, kind);
    try ordinary(D);
}
