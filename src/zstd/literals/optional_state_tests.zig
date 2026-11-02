//! Caller-owned optional Huffman state contracts. The root test injects its
//! private State/Section types and initializer/cursor/copy functions; this file
//! never imports the root or calls the optional-value initializer as an oracle.
const std = @import("std");

const guard_len = 32;
const workspace_poison = 0xa7;

fn Guarded(comptime State: type) type {
    comptime std.debug.assert(guard_len % @alignOf(State) == 0);
    return struct {
        bytes: [guard_len + @sizeOf(State) + guard_len]u8 align(@alignOf(State)),

        fn poison(self: *@This()) void {
            @memset(&self.bytes, workspace_poison);
        }

        fn state(self: *@This()) *State {
            return @ptrCast(@alignCast(&self.bytes[guard_len]));
        }

        fn expectGuards(self: *const @This()) !void {
            const expected = [_]u8{workspace_poison} ** guard_len;
            try std.testing.expectEqualSlices(u8, &expected, self.bytes[0..guard_len]);
            try std.testing.expectEqualSlices(u8, &expected, self.bytes[self.bytes.len - guard_len ..]);
        }

        fn expectUntouched(self: *const @This()) !void {
            for (self.bytes) |byte| try std.testing.expectEqual(@as(u8, workspace_poison), byte);
        }
    };
}

fn decodeHex(encoded: []const u8) ![]u8 {
    const hex = std.mem.trim(u8, encoded, " \r\n\t");
    const bytes = try std.testing.allocator.alloc(u8, hex.len / 2);
    errdefer std.testing.allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, hex);
    return bytes;
}

/// Independent old local construction: canonical lookup materialization and
/// cursor initialization happen before the State value is assembled.
fn initReference(comptime Support: type, block: []const u8, section: Support.Section) !Support.State {
    const tree = section.huffman_tree orelse return error.CorruptFrame;
    const Lookup = @TypeOf(@as(Support.State, undefined).lookup);
    const lookup = Lookup.build(&tree);
    const cursor = try Support.initCursor(block, section);
    return .{ .tree = tree, .lookup = lookup, .cursor = cursor, .decoded = 0 };
}

fn expectProgress(expected: anytype, actual: @TypeOf(expected)) !void {
    try std.testing.expectEqual(expected.decoded, actual.decoded);
    try std.testing.expectEqual(expected.cursor.stream_index, actual.cursor.stream_index);
    try std.testing.expectEqual(std.meta.activeTag(expected.cursor.streams), std.meta.activeTag(actual.cursor.streams));
    try std.testing.expectEqual(expected.cursor.reader.remaining_bits, actual.cursor.reader.remaining_bits);
    try std.testing.expectEqualSlices(u8, expected.cursor.reader.bytes, actual.cursor.reader.bytes);
    if (expected.cursor.streams == .four) {
        for (expected.cursor.streams.four, actual.cursor.streams.four) |expected_stream, actual_stream| {
            try std.testing.expectEqualSlices(u8, expected_stream, actual_stream);
        }
    }
}

fn initAndCompare(comptime Support: type, guarded: *Guarded(Support.State), block: []const u8, section: Support.Section) !Support.State {
    const expected = try initReference(Support, block, section);
    const initialized = (try Support.initInto(guarded.state(), block, section)) orelse return error.TestUnexpectedResult;
    try std.testing.expect(initialized == guarded.state());
    try std.testing.expectEqual(@as(usize, 0), initialized.decoded);
    try std.testing.expectEqual(expected.tree.max_bit_count, initialized.tree.max_bit_count);
    try std.testing.expectEqual(expected.tree.symbol_count_minus_one, initialized.tree.symbol_count_minus_one);
    const tree_len = @as(usize, expected.tree.symbol_count_minus_one) + 1;
    try std.testing.expectEqualDeep(expected.tree.nodes[0..tree_len], initialized.tree.nodes[0..tree_len]);
    try std.testing.expectEqualSlices(@TypeOf(expected.lookup.entries[0]), &expected.lookup.entries, &initialized.lookup.entries);
    try expectProgress(&expected, @as(*const Support.State, initialized));
    try guarded.expectGuards();
    return expected;
}

/// Raw/RLE admission must neither dereference the block nor touch any byte of
/// caller state, even when all Huffman-only metadata is unusable.
pub fn checkRawRle(comptime Support: type) !void {
    var guarded: Guarded(Support.State) = undefined;
    const blocks = [_][]const u8{ &.{}, &.{ 0, 0xff, 0xf0 } };
    inline for (.{ .raw, .rle }) |kind| {
        for (blocks) |block| {
            guarded.poison();
            const section: Support.Section = .{
                .kind = kind,
                .size_format = 3,
                .regenerated_size = std.math.maxInt(usize),
                .literal_payload_offset = std.math.maxInt(usize),
                .huffman_stream_offset = std.math.maxInt(usize),
                .huffman_streams = .none,
                .compressed_size = std.math.maxInt(usize),
                .sequence_count = 0,
                .sequence_payload_offset = std.math.maxInt(usize),
                .huffman_tree = null,
            };
            try std.testing.expect((try Support.initInto(guarded.state(), block, section)) == null);
            try guarded.expectUntouched();
        }
    }
}

fn compareDecodeAndReuse(comptime Support: type, guarded: *Guarded(Support.State), block: []const u8, section: Support.Section) !void {
    const expected_output = try std.testing.allocator.alloc(u8, section.regenerated_size);
    defer std.testing.allocator.free(expected_output);
    const actual_output = try std.testing.allocator.alloc(u8, section.regenerated_size);
    defer std.testing.allocator.free(actual_output);
    for (0..2) |round| {
        // Round two reuses the fully consumed workspace, then resets once
        // more after decoding a prefix, exercising both reset boundaries.
        var expected = try initAndCompare(Support, guarded, block, section);
        if (round == 1 and section.regenerated_size != 0) {
            var expected_first: [1]u8 = undefined;
            var actual_first: [1]u8 = undefined;
            try Support.copyLiterals(&expected, &section, 0, &expected_first);
            try Support.copyLiterals(guarded.state(), &section, 0, &actual_first);
            try std.testing.expectEqualSlices(u8, &expected_first, &actual_first);
            try expectProgress(&expected, guarded.state());
            expected = try initAndCompare(Support, guarded, block, section);
        }
        @memset(expected_output, 0x31);
        @memset(actual_output, 0xc9);
        try Support.copyLiterals(&expected, &section, 0, expected_output[0..0]);
        try Support.copyLiterals(guarded.state(), &section, 0, actual_output[0..0]);
        try expectProgress(&expected, guarded.state());
        var offset: usize = 0;
        var run: usize = 0;
        while (offset < section.regenerated_size) : (run += 1) {
            const count = @min(section.regenerated_size - offset, 1 + (run * 7 + round * 11) % 23);
            try Support.copyLiterals(&expected, &section, offset, expected_output[offset..][0..count]);
            try Support.copyLiterals(guarded.state(), &section, offset, actual_output[offset..][0..count]);
            try expectProgress(&expected, guarded.state());
            offset += count;
        }
        try std.testing.expectEqualSlices(u8, expected_output, actual_output);
        try std.testing.expectEqual(section.regenerated_size, guarded.state().decoded);
        try std.testing.expectEqual(@as(usize, 0), guarded.state().cursor.reader.remaining_bits);
        try guarded.expectGuards();
    }

    // Null admission must preserve an already decoded workspace as well as
    // the arbitrary poisoned payload tested by checkRawRle.
    const before = guarded.bytes;
    inline for (.{ .raw, .rle }) |kind| {
        var non_huffman = section;
        non_huffman.kind = kind;
        non_huffman.huffman_tree = null;
        try std.testing.expect((try Support.initInto(guarded.state(), &.{}, non_huffman)) == null);
        try std.testing.expectEqualSlices(u8, &before, &guarded.bytes);
    }
}

/// Real libzstd/decodecorpus wire sections exercise one/four-stream Huffman
/// states and a treeless block whose tree comes from an earlier block.
pub fn checkHuffmanReuse(comptime Support: type) !void {
    const fixtures = [_][]const u8{
        @embedFile("../testdata/libzstd-numbered-json.frame.hex"),
        @embedFile("../testdata/decodecorpus-predefined-repeat.frame.hex"),
    };
    var guarded: Guarded(Support.State) = undefined;
    guarded.poison();
    var compressed_count: usize = 0;
    var treeless_count: usize = 0;
    var one_count: usize = 0;
    var four_count: usize = 0;
    for (fixtures) |fixture| {
        const frame = try decodeHex(fixture);
        defer std.testing.allocator.free(frame);
        var parse_state: Support.Codec.DecodeState = .{};
        var block_header = try Support.firstBlock(frame);
        while (true) {
            if (block_header.block_type == .compressed) {
                const block = frame[block_header.payload_offset..][0..block_header.payload_len];
                const section = try Support.Codec.parseLiterals(block, &parse_state);
                switch (section.kind) {
                    .compressed => compressed_count += 1,
                    .treeless => treeless_count += 1,
                    .raw, .rle => {},
                }
                if (section.kind == .compressed or section.kind == .treeless) {
                    if (section.huffman_streams == .one) one_count += 1;
                    if (section.huffman_streams == .four) four_count += 1;
                    try compareDecodeAndReuse(Support, &guarded, block, section);
                }
            }
            if (block_header.last) break;
            block_header = try Support.blockAt(frame, block_header.next_header_offset);
        }
    }
    try std.testing.expect(compressed_count != 0 and treeless_count != 0);
    try std.testing.expect(one_count != 0 and four_count != 0);
    std.debug.print("optional_huffman_state compressed_blocks={d} treeless_blocks={d} one_stream={d} four_stream={d}\n", .{
        compressed_count, treeless_count, one_count, four_count,
    });
}

fn expectInitError(comptime Support: type, expected_error: anyerror, block: []const u8, section: Support.Section, counts: *[2]usize) !void {
    var guarded: Guarded(Support.State) = undefined;
    guarded.poison();
    try std.testing.expectError(expected_error, initReference(Support, block, section));
    try std.testing.expectError(expected_error, Support.initInto(guarded.state(), block, section));
    try guarded.expectGuards();
    std.debug.assert(expected_error == error.CorruptFrame or expected_error == error.TruncatedFrame);
    counts[@intFromBool(expected_error == error.TruncatedFrame)] += 1;
}

pub fn checkMalformed(comptime Support: type) !void {
    const frame = try decodeHex(@embedFile("../testdata/libzstd-numbered-json.frame.hex"));
    defer std.testing.allocator.free(frame);
    const header = try Support.firstBlock(frame);
    const block = frame[header.payload_offset..][0..header.payload_len];
    var parse_state: Support.Codec.DecodeState = .{};
    const original = try Support.Codec.parseLiterals(block, &parse_state);
    try std.testing.expect(original.kind == .compressed);
    var init_error_counts: [2]usize = @splat(0);
    var decode_error_count: usize = 0;
    inline for (.{ .compressed, .treeless }) |kind| {
        var section = original;
        section.kind = kind;
        section.huffman_tree = null;
        try expectInitError(Support, error.CorruptFrame, &.{}, section, &init_error_counts);

        section = original;
        section.kind = kind;
        section.huffman_streams = .none;
        try expectInitError(Support, error.CorruptFrame, block, section, &init_error_counts);

        section.huffman_streams = .one;
        section.literal_payload_offset = 0;
        section.huffman_stream_offset = 2;
        section.compressed_size = 1;
        try expectInitError(Support, error.CorruptFrame, &.{1}, section, &init_error_counts);
        section.huffman_stream_offset = 0;
        section.compressed_size = 2;
        try expectInitError(Support, error.CorruptFrame, &.{1}, section, &init_error_counts);
        section.compressed_size = 0;
        try expectInitError(Support, error.TruncatedFrame, &.{}, section, &init_error_counts);
        section.compressed_size = 1;
        try expectInitError(Support, error.CorruptFrame, &.{0}, section, &init_error_counts);

        section.huffman_streams = .{ .four = .{ &.{}, &.{1}, &.{1}, &.{1} } };
        try expectInitError(Support, error.TruncatedFrame, &.{}, section, &init_error_counts);
        section.huffman_streams = .{ .four = .{ &.{0}, &.{1}, &.{1}, &.{1} } };
        try expectInitError(Support, error.CorruptFrame, &.{}, section, &init_error_counts);

        // A marker-only stream initializes successfully but has no symbol
        // bits. Both cursors must report the same decode failure/progress.
        section.huffman_streams = .one;
        section.regenerated_size = 1;
        var guarded: Guarded(Support.State) = undefined;
        guarded.poison();
        var expected = try initAndCompare(Support, &guarded, &.{1}, section);
        var expected_byte: [1]u8 = undefined;
        var actual_byte: [1]u8 = undefined;
        try std.testing.expectError(error.CorruptFrame, Support.copyLiterals(&expected, &section, 0, &expected_byte));
        try std.testing.expectError(error.CorruptFrame, Support.copyLiterals(guarded.state(), &section, 0, &actual_byte));
        try expectProgress(&expected, guarded.state());
        try guarded.expectGuards();
        decode_error_count += 1;
    }
    std.debug.print("optional_huffman_state init_corrupt={d} init_truncated={d} decode_corrupt={d}\n", .{
        init_error_counts[0], init_error_counts[1], decode_error_count,
    });
}
