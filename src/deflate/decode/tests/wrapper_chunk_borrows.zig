//! Join admission must precede writes to source, output, dictionaries or state.
const std = @import("std");
const testing = std.testing;
const S = @import("wrapper_chunk_borrows_support.zig");

pub fn contracts(comptime D: type) !void {
    inline for (comptime std.meta.tags(S.Mode)) |mode| {
        errdefer std.debug.print("wrapper chunk borrow mode: {s}\n", .{@tagName(mode)});
        const wire = try S.encode(D, mode);
        defer testing.allocator.free(wire);
        try joinRanges(D, mode, wire);
        try borrowedSingle(D, mode, wire);
        try descriptorBorrow(D, mode, wire);
        try formatErrors(D, mode, wire);
    }
    try dictionaryBorrows(D);
    try inspectionAndProbe(D);
    try gzipMetadataLifetime(D);
    try emptyBorrows(D);
    try @import("wrapper_chunk_borrows_append.zig").contracts(D);
    try @import("wrapper_chunk_borrows_state.zig").contracts(D);
}

fn joinRanges(comptime D: type, comptime mode: S.Mode, wire: []const u8) !void {
    var output: [S.max_plain_len]u8 = @splat(0xa5);
    const output_before = output;
    var backing: [160]u8 = @splat(0xa5);
    // The first copied chunk overwrites the beginning of the unread second.
    @memcpy(backing[2..][0 .. wire.len - 4], wire[4..]);
    const chunks = [_][]const u8{ wire[0..4], backing[2..][0 .. wire.len - 4] };
    const before = backing;
    try testing.expectError(error.InvalidBlockPlan, S.decode(D, mode, &chunks, backing[0..wire.len], &output, S.dictionary));
    try testing.expectEqualSlices(u8, &before, &backing);
    try testing.expectEqualSlices(u8, &output_before, &output);
    // Scratch capacity is checked before borrow admission, retaining precedence.
    try testing.expectError(error.OutputTooSmall, S.decode(D, mode, &chunks, backing[0 .. wire.len - 1], &output, S.dictionary));
    try testing.expectEqualSlices(u8, &before, &backing);
    var independent: [80]u8 = @splat(0xa5);
    try S.expectDecoded(mode, try S.decode(D, mode, &chunks, &independent, &output, S.dictionary), &output);

    // Full output capacity remains protected even beyond the decoded payload.
    backing = @splat(0xa5);
    const separated = S.split(wire);
    const output_alias_before = backing;
    try testing.expectError(error.InvalidBlockPlan, S.decode(D, mode, &separated, backing[32..][0..wire.len], backing[0..33], S.dictionary));
    try testing.expectEqualSlices(u8, &output_alias_before, &backing);
    // Only the scratch prefix that will be written is reserved.
    try S.expectDecoded(mode, try S.decode(D, mode, &separated, &backing, backing[wire.len..][0..S.max_plain_len], S.dictionary), backing[wire.len..]);

    // Packed sources identical to the destination need no copy.
    backing = @splat(0xa5);
    @memcpy(backing[0..wire.len], wire);
    const packed_chunks = S.split(backing[0..wire.len]);
    const packed_before = backing;
    try S.expectDecoded(mode, try S.decode(D, mode, &packed_chunks, &backing, &output, S.dictionary), &output);
    try testing.expectEqualSlices(u8, &packed_before, &backing);
    // Exact identity still protects the output borrow.
    try testing.expectError(error.InvalidBlockPlan, S.decode(D, mode, &packed_chunks, &backing, backing[0..S.plain.len], S.dictionary));
    try testing.expectEqualSlices(u8, &packed_before, &backing);
}

fn borrowedSingle(comptime D: type, comptime mode: S.Mode, wire: []const u8) !void {
    var output: [S.max_plain_len]u8 = @splat(0xa5);
    const single = [_][]const u8{ "", wire, "" };
    try S.expectDecoded(mode, try S.decode(D, mode, &single, &.{}, &output, S.dictionary), &output);
    // Unused scratch may coincide with output or borrowed compressed bytes.
    try S.expectDecoded(mode, try S.decode(D, mode, &single, &output, &output, S.dictionary), &output);
    var backing: [120]u8 = @splat(0xa5);
    @memcpy(backing[32..][0..wire.len], wire);
    const borrowed = [_][]const u8{ "", backing[32..][0..wire.len], "" };
    const before = backing;
    try S.expectDecoded(mode, try S.decode(D, mode, &borrowed, &backing, &output, S.dictionary), &output);
    try testing.expectEqualSlices(u8, &before, &backing);
    // The actual source must still be protected, including an unused output tail.
    try testing.expectError(error.InvalidBlockPlan, S.decode(D, mode, &borrowed, &.{}, backing[0..33], S.dictionary));
    try testing.expectEqualSlices(u8, &before, &backing);
}

fn descriptorBorrow(comptime D: type, comptime mode: S.Mode, wire: []const u8) !void {
    const Holder = struct { chunks: [3][]const u8, tail: [96]u8 };
    var holder: Holder = undefined;
    @memset(std.mem.asBytes(&holder), 0xa5);
    holder.chunks = S.split(wire);
    const before = S.copyBytes(Holder, &holder);
    var output: [S.max_plain_len]u8 = @splat(0xa5);
    const output_before = output;
    try testing.expectError(error.InvalidBlockPlan, S.decode(D, mode, &holder.chunks, std.mem.asBytes(&holder), &output, S.dictionary));
    try testing.expectEqualSlices(u8, &before, std.mem.asBytes(&holder));
    try testing.expectEqualSlices(u8, &output_before, &output);
    var independent: [80]u8 = undefined;
    try S.expectDecoded(mode, try S.decode(D, mode, &holder.chunks, &independent, &output, S.dictionary), &output);
}

fn dictionaryBorrows(comptime D: type) !void {
    inline for (.{ S.Mode.zlib_dictionary, S.Mode.zlib_dictionary_options }) |mode| {
        const wire = try S.encode(D, mode);
        defer testing.allocator.free(wire);
        const chunks = S.split(wire);
        var backing: [128]u8 = @splat(0xa5);
        @memcpy(backing[0..S.dictionary.len], S.dictionary);
        const before = backing;
        var output: [S.plain.len]u8 = @splat(0xa5);
        const output_before = output;
        try testing.expectError(error.InvalidBlockPlan, S.decode(D, mode, &chunks, &backing, &output, backing[0..S.dictionary.len]));
        try testing.expectEqualSlices(u8, &before, &backing);
        try testing.expectEqualSlices(u8, &output_before, &output);
        var independent: [80]u8 = undefined;
        try S.expectPlain(try S.decode(D, mode, &chunks, &independent, &output, backing[0..S.dictionary.len]), &output);
        // Dictionary data in the unused scratch tail remains read-only.
        @memcpy(backing[wire.len..][0..S.dictionary.len], S.dictionary);
        try S.expectPlain(try S.decode(D, mode, &chunks, &backing, &output, backing[wire.len..][0..S.dictionary.len]), &output);
        const single = [_][]const u8{wire};
        const before_single = backing;
        try testing.expectError(error.InvalidBlockPlan, S.decode(D, mode, &single, &.{}, backing[wire.len..][0..S.dictionary.len], backing[wire.len..][0..S.dictionary.len]));
        try testing.expectEqualSlices(u8, &before_single, &backing);
        try S.expectPlain(try S.decode(D, mode, &single, &backing, &output, backing[wire.len..][0..S.dictionary.len]), &output);
    }
    // Input and preset dictionary may share storage because both are read-only.
    const wire = try S.encode(D, .zlib);
    defer testing.allocator.free(wire);
    const chunks = S.split(wire);
    var scratch: [80]u8 = undefined;
    var output: [S.plain.len]u8 = undefined;
    try S.expectPlain(try D.decodeZlibChunksWithDictionary(&chunks, &scratch, &output, wire), &output);
}

fn formatErrors(comptime D: type, comptime mode: S.Mode, wire: []const u8) !void {
    var scratch: [80]u8 = undefined;
    var chunk_output: [S.max_plain_len]u8 = @splat(0xa5);
    var single_output: [S.max_plain_len]u8 = @splat(0xa5);
    var bad: [80]u8 = undefined;
    @memcpy(bad[0..wire.len], wire);
    const data_offset: usize = if (S.isGzip(mode)) 10 else if (S.hasDictionary(mode)) 6 else 2;
    inline for (.{ "truncated", "malformed", "footer" }) |kind| {
        @memcpy(bad[0..wire.len], wire);
        const len = if (comptime std.mem.eql(u8, kind, "truncated")) wire.len - 1 else wire.len;
        if (comptime std.mem.eql(u8, kind, "malformed")) bad[data_offset] = 0x07;
        if (comptime std.mem.eql(u8, kind, "footer")) bad[len - (if (S.isGzip(mode)) @as(usize, 8) else 4)] ^= 1;
        chunk_output = @splat(0xa5);
        single_output = @splat(0xa5);
        const chunks = S.split(bad[0..len]);
        const single = [_][]const u8{bad[0..len]};
        const expected_error = if (S.decode(D, mode, &single, &.{}, &single_output, S.dictionary)) |_| return error.ExpectedDecodeError else |err| err;
        try testing.expectError(expected_error, S.decode(D, mode, &chunks, &scratch, &chunk_output, S.dictionary));
        try testing.expectEqualSlices(u8, &single_output, &chunk_output);
    }
}

fn inspectionAndProbe(comptime D: type) !void {
    const zlib_wire = try S.encode(D, .zlib_dictionary);
    defer testing.allocator.free(zlib_wire);
    const zlib_chunks = S.split(zlib_wire);
    var dict_scratch: [80]u8 = @splat(0xa5);
    @memcpy(dict_scratch[0..S.dictionary.len], S.dictionary);
    const dict_before = dict_scratch;
    var output: [80]u8 = @splat(0xa5);
    const output_before = output;
    try testing.expectError(error.InvalidBlockPlan, D.inspectZlibStreamFromChunksAllocWithDictionary(testing.allocator, &zlib_chunks, &dict_scratch, dict_scratch[0..S.dictionary.len]));
    try testing.expectEqualSlices(u8, &dict_before, &dict_scratch);
    inline for (.{ "probeZlibChunksWithDictionaryAndOptions", "probeZlibConcatenatedChunksWithDictionaryAndOptions", "probeZlibChunksWithDictionaryAndOptionsExactSize", "probeZlibConcatenatedChunksWithDictionaryAndOptionsExactSize" }) |name| {
        const probe = if (comptime std.mem.endsWith(u8, name, "ExactSize"))
            @field(D, name)(&zlib_chunks, &dict_scratch, dict_scratch[0..S.dictionary.len], &output, .{}, S.plain.len)
        else
            @field(D, name)(&zlib_chunks, &dict_scratch, dict_scratch[0..S.dictionary.len], &output, .{});
        try testing.expect(!probe.ok);
        try testing.expectEqualStrings("InvalidBlockPlan", probe.error_name);
        try testing.expectEqualSlices(u8, &dict_before, &dict_scratch);
        try testing.expectEqualSlices(u8, &output_before, &output);
    }
    var independent: [80]u8 = undefined;
    const valid_zlib_probe = D.probeZlibConcatenatedChunksWithDictionaryAndOptions(&zlib_chunks, &independent, dict_scratch[0..S.dictionary.len], &output, .{});
    try testing.expect(valid_zlib_probe.ok);
    try testing.expectEqual(S.plain.len, valid_zlib_probe.decoded_bytes);

    const gzip_wire = try S.encode(D, .gzip);
    defer testing.allocator.free(gzip_wire);
    const gzip_chunks = S.split(gzip_wire);
    var output_alias: [120]u8 = @splat(0xa5);
    const alias_before = output_alias;
    inline for (.{ "probeGzipChunksWithOptions", "probeGzipConcatenatedChunksWithOptions", "probeGzipChunksWithOptionsExactSize", "probeGzipConcatenatedChunksWithOptionsExactSize" }) |name| {
        const probe = if (comptime std.mem.endsWith(u8, name, "ExactSize"))
            @field(D, name)(&gzip_chunks, output_alias[32..], output_alias[0..33], .{}, S.plain.len)
        else
            @field(D, name)(&gzip_chunks, output_alias[32..], output_alias[0..33], .{});
        try testing.expect(!probe.ok);
        try testing.expectEqualStrings("InvalidBlockPlan", probe.error_name);
        try testing.expectEqualSlices(u8, &alias_before, &output_alias);
    }
    const valid_gzip_probe = D.probeGzipConcatenatedChunksWithOptions(&gzip_chunks, &independent, &output, .{});
    try testing.expect(valid_gzip_probe.ok);
    try testing.expectEqual(S.plain.len, valid_gzip_probe.decoded_bytes);

    // Metadata-only wrappers share the same unread-source admission.
    var unread: [80]u8 = @splat(0xa5);
    @memcpy(unread[2..][0 .. gzip_wire.len - 4], gzip_wire[4..]);
    const unread_chunks = [_][]const u8{ gzip_wire[0..4], unread[2..][0 .. gzip_wire.len - 4] };
    const unread_before = unread;
    try testing.expectError(error.InvalidBlockPlan, D.parseGzipHeaderInfoFromChunks(&unread_chunks, &unread));
    try testing.expectEqualSlices(u8, &unread_before, &unread);
    try testing.expectError(error.InvalidBlockPlan, D.inspectGzipMemberFromChunksAlloc(testing.allocator, &unread_chunks, &unread, 0));
    try testing.expectEqualSlices(u8, &unread_before, &unread);
}

fn metadataAliases(info: anytype, baseline: anytype, original: []const u8, borrowed: []const u8) !void {
    inline for (.{ "extra", "filename", "comment" }) |field| {
        const actual = @field(info, field).?;
        const expected = @field(baseline, field).?;
        const offset = @intFromPtr(expected.ptr) - @intFromPtr(original.ptr);
        try testing.expectEqual(expected.len, actual.len);
        try testing.expectEqual(borrowed.ptr + offset, actual.ptr);
        try testing.expectEqualSlices(u8, expected, actual);
    }
    try testing.expect(info.header_crc != null);
}

fn gzipMetadataLifetime(comptime D: type) !void {
    const wire = try D.encodeGzipStoredWithHeaderAlloc(testing.allocator, S.plain, .{
        .extra = "x\x00yz",
        .filename = "fixture.txt",
        .comment = "borrowed metadata",
        .header_crc = true,
    });
    defer testing.allocator.free(wire);
    const baseline = try D.parseGzipHeaderInfo(wire);
    var scratch: [160]u8 = @splat(0xa5);
    const scratch_before = scratch;
    const single = [_][]const u8{ "", wire, "" };
    const single_header = try D.parseGzipHeaderInfoFromChunks(&single, &scratch);
    const single_member = try D.inspectGzipMemberFromChunksAlloc(testing.allocator, &single, &scratch, 0);
    try metadataAliases(single_header, baseline, wire, wire);
    try metadataAliases(single_member.header, baseline, wire, wire);
    try testing.expectEqual(S.plain.len, single_member.output_bytes);
    try testing.expectEqualSlices(u8, &scratch_before, &scratch);
    const extra_offset = @intFromPtr(baseline.extra.?.ptr) - @intFromPtr(wire.ptr);
    wire[extra_offset] ^= 1;
    try testing.expectEqual(wire[extra_offset], single_header.extra.?[0]);
    try testing.expectEqual(wire[extra_offset], single_member.header.extra.?[0]);
    wire[extra_offset] ^= 1;

    // Split optional fields across chunks, then keep the returned borrows alive.
    const multiple = [_][]const u8{ wire[0..13], wire[13..21], wire[21..] };
    const multi_header = try D.parseGzipHeaderInfoFromChunks(&multiple, &scratch);
    const multi_member = try D.inspectGzipMemberFromChunksAlloc(testing.allocator, &multiple, &scratch, 0);
    try metadataAliases(multi_header, baseline, wire, scratch[0..wire.len]);
    try metadataAliases(multi_member.header, baseline, wire, scratch[0..wire.len]);
    scratch[extra_offset] ^= 1;
    try testing.expectEqual(scratch[extra_offset], multi_header.extra.?[0]);
    try testing.expectEqual(scratch[extra_offset], multi_member.header.extra.?[0]);
    try testing.expectEqual(@as(u8, 'x'), wire[extra_offset]);
    scratch[extra_offset] ^= 1;
    try testing.expectEqualSlices(u8, wire, scratch[0..wire.len]);
}

fn emptyBorrows(comptime D: type) !void {
    const empty = [_][]const u8{};
    const all_empty = [_][]const u8{ "", "", "" };
    inline for (.{ &empty, &all_empty }) |chunks| {
        var shared: [32]u8 = @splat(0xa5);
        const before = shared;
        try testing.expectError(error.TruncatedFrame, D.decodeZlibChunksWithDictionaryAndOptions(chunks, &shared, &shared, &shared, .{}));
        try testing.expectEqualSlices(u8, &before, &shared);
        try testing.expectError(error.TruncatedFrame, D.decodeGzipChunksWithOptions(chunks, &shared, &shared, .{}));
        try testing.expectEqualSlices(u8, &before, &shared);
        try testing.expectError(error.TruncatedFrame, D.ZlibDecoder.initFromChunksWithDictionaryAndOptions(chunks, &shared, &shared, &shared, .{}));
        try testing.expectEqualSlices(u8, &before, &shared);
        try testing.expectError(error.TruncatedFrame, D.GzipDecoder.initFromChunksWithOptions(chunks, &shared, &shared, .{}));
        try testing.expectEqualSlices(u8, &before, &shared);
    }
}
