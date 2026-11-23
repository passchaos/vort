const std = @import("std");
const Count = @import("../../core.zig").StreamCount;
const testing = std.testing;

const magic = "\x28\xb5\x2f\xfd";
const narrow: Member = .{ .wire = magic ++ "\x20\x03\x19\x00\x00one", .decoded = "one" };
const wide: Member = .{ .wire = magic ++ "\x00\x01\x19\x00\x00two", .decoded = "two" };
const narrow_window = 3;
const wide_window = 1152;
const boundary = narrow.decoded.len - 1;
const output_canary = '!';
const scratch_canary = '?';

const Member = struct {
    wire: []const u8,
    decoded: []const u8,
};

fn makeStream(comptime Z: type, comptime members: []const Member, checksums: bool, storage: []u8) ![]u8 {
    var entries: [members.len]Z.NativeSeekTableFrameSize = undefined;
    var written: usize = 0;
    for (members, &entries) |member, *entry| {
        @memcpy(storage[written..][0..member.wire.len], member.wire);
        written += member.wire.len;
        entry.* = .{
            .compressed_size = @intCast(member.wire.len),
            .decompressed_size = @intCast(member.decoded.len),
            .checksum = if (checksums) @truncate(std.hash.XxHash64.hash(0, member.decoded)) else null,
        };
    }
    written += try Z.encodeNativeSeekTableInto(&entries, checksums, storage[written..]);
    return storage[0..written];
}

fn expectDecoded(comptime Z: type, stream: []const u8, index: Z.NativeSeekIndex, offset: u64, comptime expected: []const u8, options: Z.NativeSeekableRangeDecodeOptions) !void {
    inline for (.{ false, true }) |indexed| {
        var output: [expected.len]u8 = @splat(output_canary);
        var scratch: [3]u8 = undefined;
        const written = if (indexed)
            try Z.decodeNativeSeekableRangeIntoWithIndexAndOptions(index, offset, &output, &scratch, options)
        else
            try Z.decodeNativeSeekableRangeIntoWithOptions(stream, offset, &output, &scratch, options);
        try testing.expectEqual(expected.len, written);
        try testing.expectEqualStrings(expected, &output);

        const allocated = if (indexed)
            try Z.decodeNativeSeekableRangeAllocWithIndexAndOptions(testing.allocator, index, offset, expected.len, options)
        else
            try Z.decodeNativeSeekableRangeAllocWithOptions(testing.allocator, stream, offset, expected.len, options);
        defer testing.allocator.free(allocated);
        try testing.expectEqualStrings(expected, allocated);
    }
}

fn expectPreflightError(comptime Z: type, stream: []const u8, index: Z.NativeSeekIndex, offset: u64, comptime length: usize, options: Z.NativeSeekableRangeDecodeOptions, expected: anyerror) !void {
    inline for (.{ false, true }) |indexed| {
        var output: [length]u8 = @splat(output_canary);
        var scratch: [3]u8 = @splat(scratch_canary);
        const into_result = if (indexed)
            Z.decodeNativeSeekableRangeIntoWithIndexAndOptions(index, offset, &output, &scratch, options)
        else
            Z.decodeNativeSeekableRangeIntoWithOptions(stream, offset, &output, &scratch, options);
        try testing.expectError(expected, into_result);
        try testing.expect(std.mem.allEqual(u8, &output, output_canary));
        try testing.expect(std.mem.allEqual(u8, &scratch, scratch_canary));

        var failing = testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0, .resize_fail_index = 0 });
        const alloc_result = if (indexed)
            Z.decodeNativeSeekableRangeAllocWithIndexAndOptions(failing.allocator(), index, offset, length, options)
        else
            Z.decodeNativeSeekableRangeAllocWithOptions(failing.allocator(), stream, offset, length, options);
        try testing.expectError(expected, alloc_result);
        try testing.expect(!failing.has_induced_failure);
        try testing.expectEqual(@as(usize, 0), failing.allocations);
    }
}

fn selectedWindows(comptime Z: type) !void {
    var wire: [128]u8 = undefined;
    const stream = try makeStream(Z, &.{ narrow, wide }, false, &wire);
    var entries: [2]Z.NativeSeekTableEntry = undefined;
    const index = try Z.buildNativeSeekIndex(try Z.inspectNativeSeekTable(stream), &entries);
    const defaults: Z.NativeSeekableRangeDecodeOptions = .{};
    try testing.expectEqual(@as(Count, std.math.maxInt(Count)), defaults.max_window_size);
    try testing.expect(defaults.dictionary == null and defaults.dictionary_set == null);

    // Both entries decode to three bytes; only the second declares a larger window.
    const cap: Z.NativeSeekableRangeDecodeOptions = .{ .max_window_size = narrow_window };
    try expectDecoded(Z, stream, index, 0, "one", cap);
    try expectPreflightError(Z, stream, index, narrow.decoded.len, 1, cap, error.OutputLimitExceeded);
    try expectPreflightError(Z, stream, index, boundary, 2, .{ .max_window_size = wide_window - 1 }, error.OutputLimitExceeded);
    try expectDecoded(Z, stream, index, boundary, "et", .{ .max_window_size = wide_window });
    try expectDecoded(Z, stream, index, boundary, "et", defaults);
}

fn selectedLayout(comptime Z: type) !void {
    var wire: [128]u8 = undefined;
    const stream = try makeStream(Z, &.{
        .{ .wire = narrow.wire[magic.len..], .decoded = narrow.decoded }, // Magicless, not standard.
        narrow,
        .{ .wire = "\xff", .decoded = "" }, // Malformed wire at an interior zero-size entry.
        wide,
        .{ .wire = "junk", .decoded = "b" },
    }, false, &wire);
    var entries: [5]Z.NativeSeekTableEntry = undefined;
    const index = try Z.buildNativeSeekIndex(try Z.inspectNativeSeekTable(stream), &entries);
    const cap: Z.NativeSeekableRangeDecodeOptions = .{ .max_window_size = wide_window };
    try expectDecoded(Z, stream, index, narrow.decoded.len + boundary, "et", cap);
    try expectDecoded(Z, stream, index, 0, "", .{ .max_window_size = 0 });
    try expectPreflightError(Z, stream, index, 0, 1, cap, error.InvalidMagic);

    var truncated_wire: [128]u8 = undefined;
    const truncated = try makeStream(Z, &.{
        narrow,
        .{ .wire = wide.wire[0 .. wide.wire.len - 1], .decoded = wide.decoded },
    }, false, &truncated_wire);
    var truncated_entries: [2]Z.NativeSeekTableEntry = undefined;
    const truncated_index = try Z.buildNativeSeekIndex(try Z.inspectNativeSeekTable(truncated), &truncated_entries);
    // Reading only frame headers would miss the truncated second block until
    // after the first frame had already written its output and scratch.
    try expectPreflightError(Z, truncated, truncated_index, boundary, 2, cap, error.TruncatedFrame);

    var output: [2]u8 = @splat(output_canary);
    var scratch: [3]u8 = undefined;
    try testing.expectError(error.TruncatedFrame, Z.decodeNativeSeekableRangeInto(truncated, boundary, &output, &scratch));
    try testing.expectEqualStrings("e!", &output);
    @memset(&output, output_canary);
    try testing.expectError(error.TruncatedFrame, Z.decodeNativeSeekableRangeIntoWithIndex(truncated_index, boundary, &output, &scratch));
    try testing.expectEqualStrings("e!", &output);
}

fn dictionaryAndChecksum(comptime Z: type) !void {
    var wire: [128]u8 = undefined;
    const stream = try makeStream(Z, &.{
        .{ .wire = magic ++ "\x21\x07\x03\x19\x00\x00one", .decoded = narrow.decoded },
        wide,
    }, true, &wire);
    const table = try Z.inspectNativeSeekTable(stream);
    var entries: [2]Z.NativeSeekTableEntry = undefined;
    const index = try Z.buildNativeSeekIndex(table, &entries);
    // No dictionary is supplied for the first selected frame, but admission
    // must see the second frame's over-limit window before trying to resolve it.
    try expectPreflightError(Z, stream, index, boundary, 2, .{ .max_window_size = narrow_window }, error.OutputLimitExceeded);

    const dictionary = Z.NativeDictionary.init(7, "dictionary bytes");
    const dictionaries = [_]Z.NativeDictionary{dictionary};
    const dictionary_set = Z.NativeDictionarySet.init(&dictionaries);
    try expectDecoded(Z, stream, index, boundary, "et", .{ .max_window_size = wide_window, .dictionary = dictionary });
    try expectDecoded(Z, stream, index, boundary, "et", .{ .max_window_size = wide_window, .dictionary_set = dictionary_set });
    try expectDecoded(Z, stream, index, boundary, "et", .{ .dictionary = dictionary });

    const first_checksum_offset = table.frame_offset + 8 + 8; // Skippable header and entry sizes.
    stream[first_checksum_offset] ^= 1;
    const corrupt_index = try Z.buildNativeSeekIndex(try Z.inspectNativeSeekTable(stream), &entries);
    const options: Z.NativeSeekableRangeDecodeOptions = .{ .max_window_size = narrow_window, .dictionary = dictionary };
    try expectPreflightError(Z, stream, corrupt_index, boundary, 2, options, error.OutputLimitExceeded);
    var output: [1]u8 = undefined;
    var scratch: [3]u8 = undefined;
    try testing.expectError(error.ChecksumMismatch, Z.decodeNativeSeekableRangeIntoWithOptions(stream, 0, &output, &scratch, options));
    try testing.expectError(error.ChecksumMismatch, Z.decodeNativeSeekableRangeIntoWithIndexAndOptions(corrupt_index, 0, &output, &scratch, options));
}

fn windowBeyondUsize32(comptime Z: type) !void {
    // The window descriptor declares 4 GiB + 512 MiB, independently of the
    // four-byte content size (three). No large allocation is needed on any target.
    const window: Count = (1 << 32) + (1 << 29);
    var wire: [64]u8 = undefined;
    const stream = try makeStream(Z, &.{
        .{ .wire = magic ++ "\x80\xb1\x03\x00\x00\x00\x19\x00\x00two", .decoded = wide.decoded },
    }, false, &wire);
    var entries: [1]Z.NativeSeekTableEntry = undefined;
    const index = try Z.buildNativeSeekIndex(try Z.inspectNativeSeekTable(stream), &entries);
    try expectPreflightError(Z, stream, index, 0, 1, .{ .max_window_size = window - 1 }, error.OutputLimitExceeded);
    try expectDecoded(Z, stream, index, 0, "two", .{ .max_window_size = window });
}

pub fn contracts(comptime Z: type) !void {
    try selectedWindows(Z);
    try selectedLayout(Z);
    try dictionaryAndChecksum(Z);
    try windowBeyondUsize32(Z);
}
