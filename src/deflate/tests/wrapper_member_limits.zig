const std = @import("std");
const core = @import("../../core.zig");
const t = std.testing;
const allocator = t.allocator;
const limit = error.OutputLimitExceeded;
const sentinel: u8 = 0xa5;

// Independent RFC 1950/1952 fixtures: stored 'A', a stored empty member,
// and fixed-Huffman 'B'. The stored and mixed streams exercise distinct paths.
const Zlib = struct {
    const name = "Zlib";
    const format = .zlib;
    const a = "\x78\x01\x01\x01\x00\xfe\xffA\x00\x42\x00\x42";
    const empty = "\x78\x01\x01\x00\x00\xff\xff\x00\x00\x00\x01";
    const b = "\x78\x9c\x73\x02\x00\x00\x43\x00\x43";
    const pending = "\x78\xbb"; // Valid CMF/FLG, FDICT set but no DICTID.
    const invalid = "\x78\x00"; // Bad FCHECK.
    const bad_header = error.BadZlibHeader;
};

const Gzip = struct {
    const name = "Gzip";
    const format = .gzip;
    const fixed = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff";
    const a = fixed ++ "\x01\x01\x00\xfe\xffA\x8b\x9e\xd9\xd3\x01\x00\x00\x00";
    const empty = fixed ++ "\x01\x00\x00\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00";
    const b = fixed ++ "\x73\x02\x00\x31\xcf\xd0\x4a\x01\x00\x00\x00";
    const pending = "\x1f\x8b\x08\x04\x00\x00\x00\x00\x00\xff"; // FEXTRA but no XLEN.
    const invalid = "\x1f\x8b\x08\x20\x00\x00\x00\x00\x00\xff"; // Reserved flag.
    const bad_header = error.BadGzipHeader;
};

const max_wire_len = Gzip.a.len + Gzip.empty.len + Gzip.b.len + "tail".len;
const ChunkScratch = [2 * max_wire_len + 1][]const u8;

pub fn contracts(comptime D: type) !void {
    inline for (.{ Zlib, Gzip }) |F| {
        const Options = @field(D, F.name ++ "DecodeOptions");
        try t.expect(@TypeOf((Options{}).max_members) == core.StreamCount);
        try t.expectEqual(std.math.maxInt(core.StreamCount), (Options{}).max_members);
        try singleFixedOutput(D, F);
        try concatenatedFixedOutput(D, F);
        try allocationAndAppend(D, F);
        try autoWrapper(D, F);
    }
    try zlibDictionaryAdmission(D);
    try gzipMetadataAdmission(D);
}

fn byteChunks(wire: []const u8, scratch: *ChunkScratch) []const []const u8 {
    scratch[0] = "";
    for (wire, 0..) |_, i| {
        scratch[2 * i + 1] = wire[i..][0..1];
        scratch[2 * i + 2] = "";
    }
    return scratch[0 .. 2 * wire.len + 1];
}

fn expectOutput(result: anyerror!usize, expected: anyerror!usize, published: []const u8, output: *const [2]u8) !void {
    if (expected) |n| {
        try t.expectEqual(n, try result);
    } else |err| {
        try t.expectError(err, result);
    }
    try t.expectEqualSlices(u8, published, output[0..published.len]);
    for (output[published.len..]) |byte| try t.expectEqual(sentinel, byte);
}

fn expectProbeError(err: anyerror, probe: anytype) !void {
    try t.expect(!probe.ok);
    try t.expectEqualStrings(@errorName(err), probe.error_name);
}

fn singleFixedOutput(comptime D: type, comptime F: type) !void {
    const Options = @field(D, F.name ++ "DecodeOptions");
    const cases = [_]struct { wire: []const u8, cap: core.StreamCount, expected: D.Error!usize }{
        .{ .wire = "", .cap = 0, .expected = error.TruncatedFrame },
        .{ .wire = F.pending[0 .. F.pending.len - 1], .cap = 0, .expected = error.TruncatedFrame },
        .{ .wire = F.invalid[0 .. F.invalid.len - 1], .cap = 0, .expected = error.TruncatedFrame },
        .{ .wire = F.invalid, .cap = 0, .expected = F.bad_header },
        .{ .wire = F.pending, .cap = 0, .expected = limit },
        .{ .wire = F.pending, .cap = 1, .expected = error.TruncatedFrame },
        .{ .wire = F.a[0..F.pending.len], .cap = 0, .expected = limit },
        .{ .wire = F.a, .cap = 0, .expected = limit },
        .{ .wire = F.a, .cap = 1, .expected = 1 },
        .{ .wire = F.a ++ F.b, .cap = 1, .expected = 1 },
    };
    for (cases) |case| {
        var chunk_scratch: ChunkScratch = undefined;
        const chunks = byteChunks(case.wire, &chunk_scratch);
        var compressed: [max_wire_len]u8 = undefined;
        const opts: Options = .{ .max_members = case.cap, .allow_trailing_data = true };
        const published: []const u8 = if (case.expected) |_| "A" else |_| "";
        inline for (.{ "", "Chunks", "ChunksInto" }) |route| {
            var output: [2]u8 = @splat(sentinel);
            const decode = @field(D, "decode" ++ F.name ++ route ++ "WithOptions");
            const result = if (route.len == 0)
                decode(case.wire, &output, opts)
            else if (comptime std.mem.eql(u8, route, "Chunks"))
                decode(chunks, &compressed, &output, opts)
            else
                decode(chunks, &output, opts);
            try expectOutput(result, case.expected, published, &output);
        }
    }

    const denied: Options = .{ .max_members = 0 };
    var output: [2]u8 = @splat(sentinel);
    var chunk_scratch: ChunkScratch = undefined;
    const chunks = byteChunks(F.pending, &chunk_scratch);
    var compressed: [max_wire_len]u8 = undefined;
    try t.expectError(limit, @field(D, "decoded" ++ F.name ++ "SizeWithOptions")(F.pending, &output, denied));
    try t.expectError(limit, @field(D, "decoded" ++ F.name ++ "ChunksSizeWithOptions")(chunks, &compressed, &output, denied));
    try expectProbeError(limit, @field(D, "probe" ++ F.name ++ "WithOptions")(F.pending, &output, denied));
    try expectProbeError(limit, @field(D, "probe" ++ F.name ++ "ChunksWithOptionsExactSize")(chunks, &compressed, &output, denied, 0));
    try t.expectEqualSlices(u8, &.{ sentinel, sentinel }, &output);
}

fn concatenatedFixedOutput(comptime D: type, comptime F: type) !void {
    const Options = @field(D, F.name ++ "DecodeOptions");
    const cases = [_]struct {
        wire: []const u8,
        opts: Options,
        expected: D.Error!usize,
        published: []const u8 = "A",
    }{
        .{ .wire = F.empty, .opts = .{ .max_members = 0 }, .expected = limit, .published = "" },
        .{ .wire = F.a ++ F.empty, .opts = .{ .max_members = 1 }, .expected = limit },
        .{ .wire = F.a ++ F.empty ++ F.b, .opts = .{ .max_members = 2 }, .expected = limit },
        .{ .wire = F.a ++ F.empty ++ F.b, .opts = .{ .max_members = 3 }, .expected = 2, .published = "AB" },
        .{ .wire = F.a ++ F.empty ++ F.b, .opts = .{}, .expected = 2, .published = "AB" },
        .{ .wire = F.a ++ "tail", .opts = .{ .max_members = 1, .allow_trailing_data = true }, .expected = 1 },
        .{ .wire = F.a ++ F.pending[0..1], .opts = .{ .max_members = 1, .allow_trailing_data = true }, .expected = 1 },
        .{ .wire = F.a ++ F.pending[0..1], .opts = .{ .max_members = 1 }, .expected = error.TruncatedFrame },
        .{ .wire = F.a ++ F.invalid, .opts = .{ .max_members = 1 }, .expected = F.bad_header },
        .{ .wire = F.a ++ F.invalid, .opts = .{ .max_members = 1, .allow_trailing_data = true }, .expected = if (F == Zlib) 1 else F.bad_header },
        .{ .wire = F.a ++ F.pending, .opts = .{ .max_members = 1, .allow_trailing_data = true }, .expected = limit },
        .{ .wire = F.a ++ F.pending, .opts = .{ .max_members = 2, .allow_trailing_data = true }, .expected = error.TruncatedFrame },
    };
    for (cases) |case| {
        var chunk_scratch: ChunkScratch = undefined;
        const chunks = byteChunks(case.wire, &chunk_scratch);
        var compressed: [max_wire_len]u8 = undefined;
        var output: [2]u8 = @splat(sentinel);
        const decode = @field(D, "decode" ++ F.name ++ "ConcatenatedWithOptions");
        try expectOutput(decode(case.wire, &output, case.opts), case.expected, case.published, &output);
        output = @splat(sentinel);
        const size = @field(D, "decoded" ++ F.name ++ "ConcatenatedSizeWithOptions");
        try expectOutput(size(case.wire, &output, case.opts), case.expected, case.published, &output);
        output = @splat(sentinel);
        const chunk_size = @field(D, "decoded" ++ F.name ++ "ConcatenatedChunksSizeWithOptions");
        try expectOutput(chunk_size(chunks, &compressed, &output, case.opts), case.expected, case.published, &output);
        if (F == Gzip) {
            output = @splat(sentinel);
            try expectOutput(D.decodeGzipConcatenatedChunksWithOptions(chunks, &compressed, &output, case.opts), case.expected, case.published, &output);
        }
    }
    if (F == Gzip) {
        var output: [2]u8 = @splat(sentinel);
        const partial = Gzip.a ++ Gzip.pending[0 .. Gzip.pending.len - 1];
        try expectOutput(D.decodeGzipConcatenatedWithOptions(partial, &output, .{
            .max_members = 1,
            .allow_trailing_data = true,
        }), error.TruncatedFrame, "A", &output);
    }

    const joined = F.a ++ F.empty ++ F.b;
    var chunk_scratch: ChunkScratch = undefined;
    const chunks = byteChunks(joined, &chunk_scratch);
    var compressed: [max_wire_len]u8 = undefined;
    var output: [2]u8 = @splat(sentinel);
    const denied: Options = .{ .max_members = 2 };
    const probe = @field(D, "probe" ++ F.name ++ "ConcatenatedWithOptions")(joined, &output, denied);
    try expectProbeError(limit, probe);
    try t.expectEqual(@as(?usize, 2), probe.member_index);
    try t.expectEqual(@as(?usize, F.a.len + F.empty.len), probe.member_offset);
    try t.expectEqualSlices(u8, &.{ 'A', sentinel }, &output);
    output = @splat(sentinel);
    const chunk_probe = @field(D, "probe" ++ F.name ++ "ConcatenatedChunksWithOptionsExactSize")(chunks, &compressed, &output, denied, 2);
    try expectProbeError(limit, chunk_probe);
    try t.expectEqual(probe.member_index, chunk_probe.member_index);
    try t.expectEqual(probe.member_offset, chunk_probe.member_offset);
    try t.expectEqualSlices(u8, &.{ 'A', sentinel }, &output);

    const admitted = @field(D, "probe" ++ F.name ++ "ConcatenatedWithOptions")(F.a ++ F.empty ++ "tail", &output, .{
        .max_members = 2,
        .allow_trailing_data = true,
    });
    try t.expect(admitted.ok);
    try t.expectEqual(@as(?usize, 2), admitted.member_count);
    try t.expectEqual(@as(?usize, F.a.len + F.empty.len), admitted.stream_input_bytes);
}

fn allocationAndAppend(comptime D: type, comptime F: type) !void {
    const Options = @field(D, F.name ++ "DecodeOptions");
    const zero: Options = .{ .max_members = 0 };
    const one: Options = .{ .max_members = 1 };
    var chunk_scratch: ChunkScratch = undefined;
    var compressed: [max_wire_len]u8 = undefined;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, "old data");

    inline for (.{ "", "Limited", "ExactSize" }) |suffix| {
        // One stream is all stored (preflight); the other starts with a fixed
        // block so the append loop can publish bytes before rolling back.
        for ([_][]const u8{ F.a ++ F.empty, F.b ++ F.empty }) |joined| {
            const chunks = byteChunks(joined, &chunk_scratch);
            const alloc = @field(D, "decode" ++ F.name ++ "ConcatenatedAllocWithOptions" ++ suffix);
            try t.expectError(limit, if (suffix.len == 0) alloc(allocator, joined, one) else alloc(allocator, joined, one, 1));
            const append = @field(D, "decode" ++ F.name ++ "ConcatenatedAppendWithOptions" ++ suffix);
            try t.expectError(limit, if (suffix.len == 0) append(allocator, &out, joined, one) else append(allocator, &out, joined, one, 1));
            try t.expectEqualStrings("old data", out.items);
            const chunk_append = @field(D, "decode" ++ F.name ++ "ConcatenatedChunksAppendWithOptions" ++ suffix);
            try t.expectError(limit, if (suffix.len == 0) chunk_append(allocator, &out, chunks, &compressed, one) else chunk_append(allocator, &out, chunks, &compressed, one, 1));
            try t.expectEqualStrings("old data", out.items);
            if (F == Gzip) {
                const chunk_alloc = @field(D, "decodeGzipConcatenatedChunksAllocWithOptions" ++ suffix);
                try t.expectError(limit, if (suffix.len == 0) chunk_alloc(allocator, chunks, &compressed, one) else chunk_alloc(allocator, chunks, &compressed, one, 1));
            }
        }
        const chunks = byteChunks(F.pending, &chunk_scratch);
        const alloc = @field(D, "decode" ++ F.name ++ "AllocWithOptions" ++ suffix);
        try t.expectError(limit, if (suffix.len == 0) alloc(allocator, F.pending, zero) else alloc(allocator, F.pending, zero, 1));
        const append = @field(D, "decode" ++ F.name ++ "AppendWithOptions" ++ suffix);
        try t.expectError(limit, if (suffix.len == 0) append(allocator, &out, F.pending, zero) else append(allocator, &out, F.pending, zero, 1));
        try t.expectEqualStrings("old data", out.items);
        const chunk_alloc = @field(D, "decode" ++ F.name ++ "ChunksAllocWithOptions" ++ suffix);
        const chunk_append = @field(D, "decode" ++ F.name ++ "ChunksAppendWithOptions" ++ suffix);
        if (F == Zlib) {
            try t.expectError(limit, if (suffix.len == 0) chunk_alloc(allocator, chunks, zero) else chunk_alloc(allocator, chunks, zero, 1));
            try t.expectError(limit, if (suffix.len == 0) chunk_append(allocator, &out, chunks, zero) else chunk_append(allocator, &out, chunks, zero, 1));
        } else {
            try t.expectError(limit, if (suffix.len == 0) chunk_alloc(allocator, chunks, &compressed, zero) else chunk_alloc(allocator, chunks, &compressed, zero, 1));
            try t.expectError(limit, if (suffix.len == 0) chunk_append(allocator, &out, chunks, &compressed, zero) else chunk_append(allocator, &out, chunks, &compressed, zero, 1));
        }
        try t.expectEqualStrings("old data", out.items);
    }
}

fn autoWrapper(comptime D: type, comptime F: type) !void {
    const denied: D.ZlibOrGzipDecodeOptions = if (F == Zlib) .{ .zlib = .{ .max_members = 0 } } else .{ .gzip = .{ .max_members = 0 } };
    const admitted: D.ZlibOrGzipDecodeOptions = if (F == Zlib)
        .{ .zlib = .{ .max_members = 1 }, .gzip = .{ .max_members = 0 } }
    else
        .{ .zlib = .{ .max_members = 0 }, .gzip = .{ .max_members = 1 } };
    var output: [2]u8 = @splat(sentinel);
    try t.expectError(limit, D.decodeZlibOrGzipWithOptions(F.pending, &output, denied));
    try t.expectError(limit, D.decodeZlibOrGzipPrefixWithOptions(F.a ++ "tail", &output, denied));
    try t.expectEqualSlices(u8, &.{ sentinel, sentinel }, &output);
    try t.expectError(limit, D.decodeZlibOrGzipAllocWithOptions(allocator, F.a, denied));
    try t.expectError(limit, D.decodeZlibOrGzipAllocWithOptionsExactSize(allocator, F.pending, denied, 1));
    try t.expectError(limit, D.decodeZlibOrGzipPrefixAllocWithOptions(allocator, F.a ++ "tail", denied));
    try t.expectError(limit, D.decodeZlibOrGzipPrefixAllocWithOptionsLimited(allocator, F.a ++ "tail", denied, 1));
    try t.expectError(limit, D.decodeZlibOrGzipPrefixAllocWithOptionsExactSize(allocator, F.a ++ "tail", denied, 1));

    try t.expectEqual(@as(usize, 1), try D.decodeZlibOrGzipWithOptions(F.a, &output, admitted));
    try t.expectEqualSlices(u8, &.{ 'A', sentinel }, &output);
    const prefix = try D.decodeZlibOrGzipPrefixAllocWithOptionsExactSize(allocator, F.a ++ F.b, admitted, 1);
    defer prefix.deinit(allocator);
    try t.expectEqual(@as(D.ZlibOrGzipFormat, F.format), prefix.format);
    try t.expectEqual(F.a.len, prefix.input_read);
    try t.expectEqualStrings("A", prefix.bytes);
}

fn zlibDictionaryAdmission(comptime D: type) !void {
    const dict_id = Zlib.pending ++ "\x00\x00\x00\x01";
    const denied: D.ZlibDecodeOptions = .{ .max_members = 0 };
    var output: [2]u8 = @splat(sentinel);
    try t.expectError(limit, D.decodeZlibWithOptions(dict_id, &output, denied));
    try t.expectError(error.NeedDictionary, D.decodeZlibWithOptions(dict_id, &output, .{ .max_members = 1 }));
    try t.expectError(limit, D.decodeZlibWithDictionaryAndOptions(dict_id, &output, "wrong", denied));
    try t.expectError(error.ChecksumMismatch, D.decodeZlibWithDictionaryAndOptions(dict_id, &output, "wrong", .{ .max_members = 1 }));
    try t.expectEqualSlices(u8, &.{ sentinel, sentinel }, &output);

    const dictionaries = D.ZlibDictionarySet.fromEntries(&.{});
    try t.expectError(limit, D.decodeZlibConcatenatedWithDictionarySetAndOptions(Zlib.a ++ dict_id, &output, dictionaries, .{
        .max_members = 1,
        .allow_trailing_data = true,
    }));
    try t.expectEqualSlices(u8, &.{ 'A', sentinel }, &output);
}

fn gzipMetadataAdmission(comptime D: type) !void {
    const has_xlen = Gzip.pending ++ "\x01\x00";
    var output: [2]u8 = @splat(sentinel);
    // Without XLEN, the metadata policy cannot determine the field length.
    // Once the member is admitted, XLEN can trigger its own (separate) cap.
    try t.expectError(limit, D.decodeGzipWithOptions(Gzip.pending, &output, .{ .max_members = 0, .max_header_metadata_len = 0 }));
    try t.expectError(error.TruncatedFrame, D.decodeGzipWithOptions(Gzip.pending, &output, .{ .max_members = 1, .max_header_metadata_len = 0 }));
    try t.expectError(limit, D.decodeGzipWithOptions(has_xlen, &output, .{ .max_members = 1, .max_header_metadata_len = 0 }));
    try t.expectError(error.TruncatedFrame, D.decodeGzipWithOptions(has_xlen, &output, .{ .max_members = 1, .max_header_metadata_len = 1 }));
    try t.expectEqualSlices(u8, &.{ sentinel, sentinel }, &output);

    var chunk_scratch: ChunkScratch = undefined;
    const chunks = byteChunks(has_xlen ++ "x" ++ Gzip.b[Gzip.fixed.len..], &chunk_scratch);
    try t.expectError(limit, D.decodeGzipChunksIntoWithOptions(chunks, &output, .{ .max_members = 1, .max_header_metadata_len = 0 }));
    try t.expectEqualSlices(u8, &.{ sentinel, sentinel }, &output);
    try t.expectEqual(@as(usize, 1), try D.decodeGzipChunksIntoWithOptions(chunks, &output, .{ .max_members = 1, .max_header_metadata_len = 1 }));
    try t.expectEqualSlices(u8, &.{ 'B', sentinel }, &output);
}
