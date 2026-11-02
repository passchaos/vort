//! Fixed predefined/compressed/predefined reader and raw executor contracts.
//! Private root functions/types are injected; the scalar reader and generic
//! block loop remain independent oracles for fields and committed progress.
const std = @import("std");
const predefined = @import("predefined.zig");

const initial_offsets = [3]usize{ 1, 4, 8 };

const Coverage = struct {
    sequence_pairs: usize = 0,
    reader_errors: usize = 0,
    initialization_errors: usize = 0,
    grouped_candidates: usize = 0,
    bit_mutations: usize = 0,
    truncations: usize = 0,
    executor_pairs: usize = 0,
    executor_errors: usize = 0,
    public_decodes: usize = 0,
};

fn expectState(expected: anytype, actual: @TypeOf(expected)) !void {
    try std.testing.expect(expected.spec == actual.spec);
    try std.testing.expectEqual(expected.reader.remaining_bits, actual.reader.remaining_bits);
    try std.testing.expectEqualSlices(u8, expected.reader.bytes, actual.reader.bytes);
    try std.testing.expectEqual(expected.remaining, actual.remaining);
    try std.testing.expectEqual(expected.ll_state, actual.ll_state);
    try std.testing.expectEqual(expected.of_state, actual.of_state);
    try std.testing.expectEqual(expected.ml_state, actual.ml_state);
    try std.testing.expectEqual(expected.repeated_offsets, actual.repeated_offsets);
}

fn compareRead(comptime Support: type, expected: *Support.State, actual: *Support.State, coverage: *Coverage) !?anyerror {
    if (actual.remaining != 0 and actual.ll_state < predefined.literal_symbols.len and
        actual.ml_state < predefined.match_symbols.len and actual.of_state < actual.spec.offset_fse.len)
    {
        const ll = predefined.literal_symbols[actual.ll_state];
        const ml = predefined.match_symbols[actual.ml_state];
        const of = actual.spec.offset_fse.entries[actual.of_state];
        const transitions: usize = if (actual.remaining == 1) 0 else @as(usize, ll.state_bits) + ml.state_bits + of.state_bits;
        const total = @as(usize, of.additional_bits) + ml.additional_bits + ll.additional_bits + transitions;
        if (total <= 56 and actual.reader.remaining_bits >= 64) coverage.grouped_candidates += 1;
    }
    const scalar = Support.readGeneric(expected);
    const specialized = Support.readSpecialized(actual, Support.resolveOffset);
    if (scalar) |sequence| {
        const mapped = try specialized;
        try std.testing.expectEqual(sequence.literal_len, mapped.literal_len);
        try std.testing.expectEqual(sequence.match_len, mapped.match_len);
        try std.testing.expectEqual(sequence.match_offset, mapped.match_offset);
        coverage.sequence_pairs += 1;
        try expectState(expected, actual);
        return null;
    } else |err| {
        try std.testing.expectError(err, specialized);
        try expectState(expected, actual);
        coverage.reader_errors += 1;
        return @as(?anyerror, err);
    }
}

fn compareReaders(comptime Support: type, initialized: Support.State, coverage: *Coverage) !?anyerror {
    var expected = initialized;
    var actual = initialized;
    while (expected.remaining != 0) {
        if (try compareRead(Support, &expected, &actual, coverage)) |err| return @as(?anyerror, err);
    }
    const exhausted = (try compareRead(Support, &expected, &actual, coverage)) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(error.CorruptFrame, exhausted);
    return null;
}

fn compareEncoded(comptime Support: type, spec: *const Support.Codec.SequenceSpec, count: usize, bytes: []const u8, coverage: *Coverage) !?anyerror {
    const reader = Support.Reader.init(bytes) catch |err| {
        coverage.initialization_errors += 1;
        return @as(?anyerror, err);
    };
    const state = Support.initState(spec, count, reader, initial_offsets) catch |err| {
        coverage.initialization_errors += 1;
        return @as(?anyerror, err);
    };
    return compareReaders(Support, state, coverage);
}

fn Prepared(comptime Support: type) type {
    return struct {
        frame: []u8,
        block: []const u8,
        section: Support.Section,
        spec: Support.Codec.SequenceSpec,
        literals: []u8,
        output_len: usize,

        fn deinit(self: @This()) void {
            std.testing.allocator.free(self.literals);
            std.testing.allocator.free(self.frame);
        }

        fn rawSection(self: *const @This()) Support.Section {
            var section = self.section;
            section.kind = .raw;
            section.literal_payload_offset = 0;
            section.huffman_stream_offset = 0;
            section.huffman_streams = .none;
            section.huffman_tree = null;
            section.compressed_size = 0;
            return section;
        }
    };
}

fn prepare(comptime Support: type) !Prepared(Support) {
    const hex = std.mem.trim(u8, @embedFile("../testdata/libzstd-numbered-json.frame.hex"), " \r\n\t");
    const frame = try std.testing.allocator.alloc(u8, hex.len / 2);
    errdefer std.testing.allocator.free(frame);
    _ = try std.fmt.hexToBytes(frame, hex);
    const header = try Support.firstBlock(frame);
    const block = frame[header.payload_offset..][0..header.payload_len];
    var frame_state: Support.FrameState = .{};
    const section = try Support.Codec.parseLiterals(block, &frame_state);
    var offset = section.sequence_payload_offset;
    const spec = try Support.Codec.parseSequenceModes(block, &offset, section.sequence_count);
    try std.testing.expect(spec.ll_mode == .predefined and spec.of_mode == .compressed and spec.ml_mode == .predefined);
    try std.testing.expectEqual(@as(usize, 39), section.sequence_count);
    const literals = try std.testing.allocator.alloc(u8, section.regenerated_size);
    errdefer std.testing.allocator.free(literals);
    var huffman = (try Support.Codec.initHuffmanState(block, section)) orelse return error.TestUnexpectedResult;
    try Support.Codec.copyHuffmanLiterals(&huffman, &section, 0, literals);
    var state = try Support.initState(&spec, section.sequence_count, try Support.Reader.init(block[spec.bitstream_offset..]), initial_offsets);
    var output_len = section.regenerated_size;
    while (state.remaining != 0) {
        const sequence = try Support.readGeneric(&state);
        output_len = try std.math.add(usize, output_len, sequence.match_len);
    }
    return .{ .frame = frame, .block = block, .section = section, .spec = spec, .literals = literals, .output_len = output_len };
}

fn fixtureReaderCases(comptime Support: type, prepared: *const Prepared(Support), coverage: *Coverage) !void {
    const bytes = prepared.block[prepared.spec.bitstream_offset..];
    try std.testing.expect((try compareEncoded(Support, &prepared.spec, prepared.section.sequence_count, bytes, coverage)) == null);
    const changed = try std.testing.allocator.dupe(u8, bytes);
    defer std.testing.allocator.free(changed);
    for (0..bytes.len * 8) |bit| {
        @memcpy(changed, bytes);
        changed[bit / 8] ^= @as(u8, 1) << @intCast(bit % 8);
        _ = try compareEncoded(Support, &prepared.spec, prepared.section.sequence_count, changed, coverage);
        coverage.bit_mutations += 1;
    }
    // Test both physical ends: reverse streams consume the high end first,
    // whereas dropping the low end truncates their final sequence fields.
    for (0..bytes.len) |length| {
        _ = try compareEncoded(Support, &prepared.spec, prepared.section.sequence_count, bytes[0..length], coverage);
        _ = try compareEncoded(Support, &prepared.spec, prepared.section.sequence_count, bytes[bytes.len - length ..], coverage);
        coverage.truncations += 2;
    }
    const initialized = try Support.initState(&prepared.spec, prepared.section.sequence_count, try Support.Reader.init(bytes), initial_offsets);
    for (0..initialized.reader.remaining_bits) |available| {
        var state = initialized;
        state.reader.remaining_bits = available;
        _ = try compareReaders(Support, state, coverage);
        coverage.truncations += 1;
    }
    inline for (.{ "ll_state", "ml_state", "of_state", "remaining" }) |field| {
        var state = initialized;
        @field(state, field) = switch (field[0]) {
            'l' => predefined.literal_symbols.len,
            'm' => predefined.match_symbols.len,
            'o' => prepared.spec.offset_fse.len,
            else => 0,
        };
        var expected = state;
        var actual = state;
        const err = (try compareRead(Support, &expected, &actual, coverage)) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(error.CorruptFrame, err);
    }
}

const Field = struct { value: usize, width: u8 };

/// Independent byte/bit writer for the small synthetic read-order fixtures.
fn emitBits(fields: []const Field) ![]u8 {
    var bit_count: usize = 1;
    for (fields) |field| bit_count += field.width;
    const bytes = try std.testing.allocator.alloc(u8, (bit_count + 7) / 8);
    @memset(bytes, 0);
    var position: usize = 0;
    var index = fields.len;
    while (index != 0) {
        index -= 1;
        const field = fields[index];
        for (0..field.width) |bit| {
            const value = if (bit >= @bitSizeOf(usize)) 0 else (field.value >> @intCast(bit)) & 1;
            bytes[position / 8] |= @as(u8, @intCast(value)) << @intCast(position % 8);
            position += 1;
        }
    }
    bytes[position / 8] |= @as(u8, 1) << @intCast(position % 8);
    return bytes;
}

fn syntheticSpec(comptime Support: type, base: u32, width: u8) Support.Codec.SequenceSpec {
    var spec: Support.Codec.SequenceSpec = .{
        .ll_mode = .predefined,
        .of_mode = .compressed,
        .ml_mode = .predefined,
        .literal_rle = null,
        .offset_rle = null,
        .match_rle = null,
        .bitstream_offset = 0,
    };
    spec.offset_fse.len = 1;
    spec.offset_fse.accuracy_log = 0;
    spec.offset_fse.entries[0] = .{ .base = base, .additional_bits = width, .next_state = 0, .state_bits = 0 };
    return spec;
}

fn syntheticState(comptime Support: type, spec: *const Support.Codec.SequenceSpec, bytes: []const u8, ll: usize, ml: usize, offsets: [3]usize) !Support.State {
    return .{ .spec = spec, .reader = try Support.Reader.init(bytes), .ll_state = ll, .ml_state = ml, .of_state = 0, .remaining = 1, .repeated_offsets = offsets };
}

fn symbolIndex(symbols: []const predefined.Symbol, base: u32) usize {
    for (symbols, 0..) |symbol, index| if (symbol.base == base) return index;
    @panic("missing predefined test symbol");
}

fn syntheticReaderCases(comptime Support: type, coverage: *Coverage) !void {
    const selectors = [_]struct { base: u32, width: u8, extra: usize }{
        .{ .base = 0, .width = 0, .extra = 0 },
        .{ .base = 1, .width = 1, .extra = 0 },
        .{ .base = 1, .width = 1, .extra = 1 },
        .{ .base = 2, .width = 1, .extra = 1 },
        .{ .base = 5, .width = 3, .extra = 7 },
        .{ .base = 0xffff_fffd, .width = 31, .extra = 0x7fff_ffff },
    };
    for (selectors) |selector| {
        const spec = syntheticSpec(Support, selector.base, selector.width);
        for ([_][3]usize{ .{ 1, 4, 8 }, .{ 0, 4, 8 }, .{ 1, 0, 8 }, .{ 1, 4, 0 }, .{ std.math.maxInt(usize), 4, 8 } }) |offsets| {
            for ([_]usize{ 0, 2, 11, 58 }) |ll| {
                const ml = symbolIndex(&predefined.match_symbols, 35);
                const fields = [_]Field{
                    .{ .value = selector.extra, .width = selector.width },
                    .{ .value = 1, .width = predefined.match_symbols[ml].additional_bits },
                    .{ .value = if (predefined.literal_symbols[ll].additional_bits == 0) 0 else 1, .width = predefined.literal_symbols[ll].additional_bits },
                };
                const bytes = try emitBits(&fields);
                defer std.testing.allocator.free(bytes);
                var expected = try syntheticState(Support, &spec, bytes, ll, ml, offsets);
                var actual = expected;
                _ = try compareRead(Support, &expected, &actual, coverage);
            }
        }
    }
    // A rep0-1 rejection after grouped extra reads must preserve the exact
    // committed reader progress. Padding keeps this on the >=64-bit path.
    const spec = syntheticSpec(Support, 1, 1);
    const fields = [_]Field{ .{ .value = 1, .width = 1 }, .{ .value = 0, .width = 64 } };
    const bytes = try emitBits(&fields);
    defer std.testing.allocator.free(bytes);
    var expected = try syntheticState(Support, &spec, bytes, 0, 0, initial_offsets);
    var actual = expected;
    try std.testing.expectEqual(@as(usize, 65), actual.reader.remaining_bits);
    const err = (try compareRead(Support, &expected, &actual, coverage)) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(error.InvalidMatch, err);
    try std.testing.expectEqual(@as(usize, 64), actual.reader.remaining_bits);
}

fn expectFrame(expected: anytype, actual: @TypeOf(expected)) !void {
    try std.testing.expectEqual(expected.repeated_offsets, actual.repeated_offsets);
    try std.testing.expectEqual(expected.previous_tables == null, actual.previous_tables == null);
    if (expected.previous_tables) |tables| {
        const mapped = actual.previous_tables.?;
        try std.testing.expectEqual(tables.ll_mode, mapped.ll_mode);
        try std.testing.expectEqual(tables.of_mode, mapped.of_mode);
        try std.testing.expectEqual(tables.ml_mode, mapped.ml_mode);
        inline for (.{ "literal_fse", "offset_fse", "match_fse" }) |field| {
            const table = @field(tables, field);
            const other = @field(mapped, field);
            try std.testing.expectEqual(table.len, other.len);
            try std.testing.expectEqual(table.accuracy_log, other.accuracy_log);
            try std.testing.expectEqualSlices(predefined.Symbol, table.entries[0..table.len], other.entries[0..other.len]);
        }
    }
}

fn executeGeneric(comptime Support: type, block: []const u8, section: Support.Section, output: []u8, written: *usize, frame_start: usize, dictionary: []const u8, frame_state: *Support.FrameState, continuation: Support.Continuation, state: *Support.State) !void {
    var literal_offset: usize = 0;
    while (state.remaining != 0) {
        const sequence = try Support.readGeneric(state);
        try Support.copyLiterals(block, section, literal_offset, output, written, sequence.literal_len);
        literal_offset = try std.math.add(usize, literal_offset, sequence.literal_len);
        try Support.copyMatch(output, written, frame_start, dictionary, sequence.match_offset, sequence.match_len);
    }
    if (literal_offset > section.regenerated_size) return error.CorruptFrame;
    try Support.copyLiterals(block, section, literal_offset, output, written, section.regenerated_size - literal_offset);
    if (continuation.retainsState()) {
        frame_state.previous_tables = Support.tables(state.spec);
        frame_state.repeated_offsets = state.repeated_offsets;
    }
}

fn compareExecutor(comptime Support: type, initialized: Support.State, block: []const u8, section: Support.Section, prefix: []const u8, frame_start: usize, dictionary: []const u8, limit: usize, continuation: Support.Continuation, expected_error: ?anyerror, coverage: *Coverage) !void {
    const expected_storage = try std.testing.allocator.alloc(u8, limit + 2);
    defer std.testing.allocator.free(expected_storage);
    const actual_storage = try std.testing.allocator.alloc(u8, limit + 2);
    defer std.testing.allocator.free(actual_storage);
    @memset(expected_storage, 0xa5);
    @memset(actual_storage, 0xa5);
    expected_storage[0] = 0xd3;
    expected_storage[limit + 1] = 0xd3;
    actual_storage[0] = 0xd3;
    actual_storage[limit + 1] = 0xd3;
    const expected_output = expected_storage[1 .. limit + 1];
    const actual_output = actual_storage[1 .. limit + 1];
    @memcpy(expected_output[0..prefix.len], prefix);
    @memcpy(actual_output[0..prefix.len], prefix);
    var expected_written = prefix.len;
    var actual_written = prefix.len;
    var expected_state = initialized;
    var actual_state = initialized;
    var expected_frame: Support.FrameState = .{ .repeated_offsets = .{ 101, 103, 107 } };
    var actual_frame = expected_frame;
    const scalar = executeGeneric(Support, block, section, expected_output, &expected_written, frame_start, dictionary, &expected_frame, continuation, &expected_state);
    const specialized = Support.execute(block, section, actual_output, &actual_written, frame_start, dictionary, &actual_frame, continuation, &actual_state);
    if (scalar) |_| {
        try specialized;
        try std.testing.expect(expected_error == null);
    } else |err| {
        try std.testing.expectError(err, specialized);
        const required = expected_error orelse return err;
        try std.testing.expectEqual(required, err);
        coverage.executor_errors += 1;
    }
    try std.testing.expectEqual(expected_written, actual_written);
    try expectState(&expected_state, &actual_state);
    try expectFrame(&expected_frame, &actual_frame);
    try std.testing.expectEqualSlices(u8, expected_storage, actual_storage);
    try std.testing.expectEqual(@as(u8, 0xd3), actual_storage[0]);
    try std.testing.expectEqual(@as(u8, 0xd3), actual_storage[limit + 1]);
    coverage.executor_pairs += 1;
}

fn fixtureExecutorCases(comptime Support: type, prepared: *const Prepared(Support), coverage: *Coverage) !void {
    const initialized = try Support.initState(&prepared.spec, prepared.section.sequence_count, try Support.Reader.init(prepared.block[prepared.spec.bitstream_offset..]), initial_offsets);
    const section = prepared.rawSection();
    inline for (.{ Support.Continuation.terminal, Support.Continuation.followed_by_block }) |continuation| {
        try compareExecutor(Support, initialized, prepared.literals, section, &.{}, 0, &.{}, prepared.output_len, continuation, null, coverage);
    }
    // Every short output length covers literal and match admission boundaries
    // and verifies committed reader/sequence/repcodes on the failure path.
    for (0..prepared.output_len) |limit| {
        try compareExecutor(Support, initialized, prepared.literals, section, &.{}, 0, &.{}, limit, .followed_by_block, error.OutputTooSmall, coverage);
    }
    var prefix: [17]u8 = undefined;
    for (&prefix, 0..) |*byte, index| byte.* = @truncate(index * 19 + 7);
    try compareExecutor(Support, initialized, prepared.literals, section, &prefix, 0, &.{}, prefix.len + prepared.output_len, .followed_by_block, null, coverage);
    try compareExecutor(Support, initialized, prepared.literals, section, &prefix, prefix.len, "dictionary history", prefix.len + prepared.output_len, .terminal, null, coverage);
}

fn syntheticExecutorCases(comptime Support: type, coverage: *Coverage) !void {
    const cases = [_]struct {
        ll: usize,
        ml: usize,
        base: u32,
        width: u8,
        extra: usize,
        ll_extra: usize = 0,
        ml_extra: usize = 0,
        offsets: [3]usize = initial_offsets,
        prefix: []const u8,
        dictionary: []const u8 = "",
        frame_start: usize = 0,
        expected_error: ?anyerror = null,
    }{
        .{ .ll = 0, .ml = 0, .base = 0, .width = 0, .extra = 0, .prefix = "abcd" },
        .{ .ll = 0, .ml = 3, .base = 5, .width = 3, .extra = 0, .prefix = "", .dictionary = "ABCDE" },
        .{ .ll = 0, .ml = 3, .base = 5, .width = 3, .extra = 0, .prefix = "xxx", .dictionary = "ABCDE", .frame_start = 3 },
        .{ .ll = 2, .ml = 0, .base = 0, .width = 0, .extra = 0, .prefix = "" },
        .{ .ll = 11, .ml = symbolIndex(&predefined.match_symbols, 35), .base = 5, .width = 3, .extra = 7, .ll_extra = 1, .ml_extra = 1, .prefix = "" },
        .{ .ll = 0, .ml = 0, .base = 1, .width = 1, .extra = 1, .prefix = "abcd", .expected_error = error.InvalidMatch },
        .{ .ll = 0, .ml = 0, .base = 1, .width = 1, .extra = 1, .offsets = .{ 2, 4, 8 }, .prefix = "abcd" },
        .{ .ll = 2, .ml = 0, .base = 1, .width = 1, .extra = 0, .prefix = "abcd" },
        .{ .ll = 2, .ml = 0, .base = 1, .width = 1, .extra = 1, .prefix = "abcdefgh" },
        .{ .ll = 0, .ml = 0, .base = 0, .width = 0, .extra = 0, .offsets = .{ 1, 0, 8 }, .prefix = "abcd", .expected_error = error.InvalidMatch },
    };
    for (cases) |case| {
        const spec = syntheticSpec(Support, case.base, case.width);
        const ll = predefined.literal_symbols[case.ll];
        const ml = predefined.match_symbols[case.ml];
        const fields = [_]Field{ .{ .value = case.extra, .width = case.width }, .{ .value = case.ml_extra, .width = ml.additional_bits }, .{ .value = case.ll_extra, .width = ll.additional_bits } };
        const bytes = try emitBits(&fields);
        defer std.testing.allocator.free(bytes);
        const initialized = try syntheticState(Support, &spec, bytes, case.ll, case.ml, case.offsets);
        const literal_len = ll.base + case.ll_extra;
        const literals = try std.testing.allocator.alloc(u8, literal_len + 2);
        defer std.testing.allocator.free(literals);
        for (literals, 0..) |*byte, index| byte.* = @truncate(index * 13 + 41);
        const section: Support.Section = .{
            .kind = .raw,
            .size_format = 0,
            .regenerated_size = literals.len,
            .literal_payload_offset = 0,
            .huffman_stream_offset = 0,
            .huffman_streams = .none,
            .sequence_count = 1,
            .sequence_payload_offset = 0,
        };
        const limit = case.prefix.len + literals.len + ml.base + case.ml_extra;
        inline for (.{ Support.Continuation.terminal, Support.Continuation.followed_by_block }) |continuation| {
            try compareExecutor(Support, initialized, literals, section, case.prefix, case.frame_start, case.dictionary, limit, continuation, case.expected_error, coverage);
        }
        if (case.expected_error == null) {
            try compareExecutor(Support, initialized, literals, section, case.prefix, case.frame_start, case.dictionary, limit - 1, .followed_by_block, error.OutputTooSmall, coverage);
        }
    }
}

fn publicAdmission(comptime Support: type, prepared: *const Prepared(Support), coverage: *Coverage) !void {
    // Preserve count + mode + table description + bitstream: the sequence
    // payload offset points past the sequence count in the parsed section.
    const tail = prepared.block[prepared.section.literal_payload_offset + prepared.section.compressed_size ..];
    const payload_len = 3 + prepared.literals.len + tail.len;
    const frame = try std.testing.allocator.alloc(u8, 12 + payload_len);
    defer std.testing.allocator.free(frame);
    @memcpy(frame[0..4], &[_]u8{ 0x28, 0xb5, 0x2f, 0xfd });
    frame[4] = 0xa0; // Single segment, four-byte content size, no checksum.
    std.mem.writeInt(u32, frame[5..][0..4], @intCast(prepared.output_len), .little);
    std.mem.writeInt(u24, frame[9..][0..3], @intCast(payload_len * 8 + 5), .little);
    frame[12] = 0x0c | (@as(u8, @intCast(prepared.literals.len & 15)) << 4);
    std.mem.writeInt(u16, frame[13..][0..2], @intCast(prepared.literals.len >> 4), .little);
    @memcpy(frame[15..][0..prepared.literals.len], prepared.literals);
    @memcpy(frame[15 + prepared.literals.len ..], tail);
    const expected = try std.testing.allocator.alloc(u8, prepared.output_len);
    defer std.testing.allocator.free(expected);
    const actual = try std.testing.allocator.alloc(u8, prepared.output_len);
    defer std.testing.allocator.free(actual);
    var state = try Support.initState(&prepared.spec, prepared.section.sequence_count, try Support.Reader.init(prepared.block[prepared.spec.bitstream_offset..]), initial_offsets);
    var frame_state: Support.FrameState = .{};
    var written: usize = 0;
    try executeGeneric(Support, prepared.literals, prepared.rawSection(), expected, &written, 0, &.{}, &frame_state, .terminal, &state);
    try std.testing.expectEqual(prepared.output_len, written);
    @memset(actual, 0xa5);
    Support.blockHits.* = 0;
    try std.testing.expectEqual(written, try Support.decodePublic(frame, actual));
    try std.testing.expectEqualSlices(u8, expected, actual);
    try std.testing.expect(Support.blockHits.* != 0);
    coverage.public_decodes += 1;
    var reusable = Support.Reusable.init(std.testing.allocator);
    defer reusable.deinit();
    for (0..2) |_| {
        @memset(actual, 0xa5);
        Support.blockHits.* = 0;
        try std.testing.expectEqual(written, try reusable.decodeIntoSlice(frame, actual));
        try std.testing.expectEqualSlices(u8, expected, actual);
        try std.testing.expect(Support.blockHits.* != 0);
        coverage.public_decodes += 1;
    }
}

pub fn check(comptime Support: type) !void {
    var coverage: Coverage = .{};
    var prepared = try prepare(Support);
    defer prepared.deinit();
    try fixtureReaderCases(Support, &prepared, &coverage);
    try syntheticReaderCases(Support, &coverage);
    try fixtureExecutorCases(Support, &prepared, &coverage);
    try syntheticExecutorCases(Support, &coverage);
    try publicAdmission(Support, &prepared, &coverage);
    try std.testing.expect(coverage.grouped_candidates != 0);
    std.debug.print("raw_mixed sequence_pairs={d} reader_errors={d} init_errors={d} grouped={d} mutations={d} truncations={d} executor_pairs={d} executor_errors={d} public_decodes={d}\n", .{
        coverage.sequence_pairs, coverage.reader_errors, coverage.initialization_errors, coverage.grouped_candidates,
        coverage.bit_mutations,  coverage.truncations,   coverage.executor_pairs,        coverage.executor_errors,
        coverage.public_decodes,
    });
}
