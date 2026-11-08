const std = @import("std");
const byte_source = @import("../../io/source.zig");
const source_input = @import("input.zig");
const source_literals = @import("literals.zig");
const source_sequences = @import("sequences.zig");

const SourceMode = enum { normal, zero, excessive, fail };

const Span = struct {
    offset: usize,
    len: usize,
};

const TrackingSource = struct {
    bytes: []const u8,
    base_offset: u64 = 0,
    max_chunk: usize = std.math.maxInt(usize),
    mode: SourceMode = .normal,
    fault_call: ?usize = null,
    forbidden: []const Span = &.{},
    calls: usize = 0,
    bytes_returned: usize = 0,
    max_requested: usize = 0,
    forbidden_read: bool = false,
    min_observed_offset: ?u64 = null,
    max_observed_offset: u64 = 0,

    fn source(self: *TrackingSource, max_read_size: usize) byte_source.Source {
        return .{
            .context = self,
            .len = self.base_offset + @as(u64, @intCast(self.bytes.len)),
            .read_at = readAt,
            .max_read_size = max_read_size,
        };
    }

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *TrackingSource = @ptrCast(@alignCast(raw));
        self.calls += 1;
        self.max_requested = @max(self.max_requested, output.len);
        self.min_observed_offset = if (self.min_observed_offset) |old| @min(old, offset) else offset;
        self.max_observed_offset = @max(self.max_observed_offset, offset);
        if (self.fault_call == null or self.fault_call.? == self.calls) {
            switch (self.mode) {
                .zero => return 0,
                .excessive => return output.len + 1,
                .fail => return error.SourceReadFailed,
                .normal => {},
            }
        }
        if (offset < self.base_offset) return error.SourceReadFailed;
        const relative = std.math.cast(usize, offset - self.base_offset) orelse
            return error.SourceReadFailed;
        const request_end = std.math.add(usize, relative, output.len) catch
            return error.SourceReadFailed;
        for (self.forbidden) |span| {
            const span_end = span.offset + span.len;
            if (relative < span_end and span.offset < request_end) {
                self.forbidden_read = true;
                return error.SourceReadFailed;
            }
        }
        if (relative >= self.bytes.len) return 0;
        const amount = @min(self.max_chunk, @min(output.len, self.bytes.len - relative));
        @memcpy(output[0..amount], self.bytes[relative..][0..amount]);
        self.bytes_returned += amount;
        return amount;
    }
};

fn layoutFor(range: source_input.Range, sequence_count: usize) !source_literals.Layout {
    const empty = try range.subrange(0, 0);
    return .{
        .kind = .raw,
        .size_format = 0,
        .regenerated_size = 0,
        .compressed_size = 0,
        .header_range = empty,
        .literal_payload = empty,
        .tree_description = null,
        .streams = .none,
        .sequence_count = sequence_count,
        .sequence_count_range = empty,
        .sequence_payload = range,
    };
}

fn modeByte(comptime Support: type, modes: [3]Support.Mode) u8 {
    return (@as(u8, @intFromEnum(modes[0])) << 6) |
        (@as(u8, @intFromEnum(modes[1])) << 4) |
        (@as(u8, @intFromEnum(modes[2])) << 2);
}

fn repeatMask(comptime Support: type, modes: [3]Support.Mode) u3 {
    var mask: u3 = 0;
    for (modes, 0..) |mode, index| {
        if (mode == .repeat) mask |= @as(u3, 1) << @intCast(index);
    }
    return mask;
}

fn descriptionLen(comptime Support: type, mode: Support.Mode) usize {
    return switch (mode) {
        .predefined, .repeat => 0,
        .rle => 1,
        .compressed => 2,
    };
}

fn expectRange(range: source_input.Range, offset: u64, len: u64) !void {
    try std.testing.expectEqual(offset, range.offset);
    try std.testing.expectEqual(len, range.len);
}

fn expectPreparedGeometry(
    comptime Support: type,
    prepared: *const source_sequences.Prepared(Support.Tables),
    modes: [3]Support.Mode,
    payload_len: usize,
    base: u64,
    sequence_count: usize,
) !void {
    try std.testing.expectEqual(sequence_count, prepared.sequence_count);
    try std.testing.expectEqual(modeByte(Support, modes), prepared.mode_byte);
    try std.testing.expectEqual(modes[0], prepared.wire_modes.literal_length);
    try std.testing.expectEqual(modes[1], prepared.wire_modes.offset);
    try std.testing.expectEqual(modes[2], prepared.wire_modes.match_length);
    try std.testing.expectEqual(repeatMask(Support, modes), prepared.repeat_mask);
    try expectRange(prepared.mode_range, base, 1);

    var cursor: usize = 1;
    for (modes, 0..) |mode, index| {
        const len = descriptionLen(Support, mode);
        if (len == 0) {
            try std.testing.expect(prepared.descriptions[index] == null);
        } else {
            try expectRange(prepared.descriptions[index].?, base + cursor, len);
            cursor += len;
        }
    }
    try expectRange(prepared.table_descriptions, base + 1, cursor - 1);
    try expectRange(prepared.bitstream, base + cursor, payload_len - cursor);
    try std.testing.expectEqual(base + cursor, prepared.tables_end);
    try std.testing.expectEqual(@as(u64, @intCast(cursor)), prepared.source_reads);
    try std.testing.expectEqual(@as(u64, @intCast(cursor)), prepared.source_bytes);
    try std.testing.expectEqual(@as(usize, 1), prepared.max_request);
}

fn allModeTuples(comptime Support: type) !void {
    var previous = try Support.previousTables();
    for (0..4) |literal_index| {
        for (0..4) |offset_index| {
            for (0..4) |match_index| {
                const modes = [3]Support.Mode{
                    @enumFromInt(literal_index),
                    @enumFromInt(offset_index),
                    @enumFromInt(match_index),
                };
                var payload: [32]u8 = undefined;
                const payload_len = try Support.emitFixture(modes, &payload);
                const before = previous;
                const expected = try Support.parseSlice(payload[0..payload_len], 17, &previous);
                var source = TrackingSource{ .bytes = payload[0..payload_len] };
                const range = try source_input.Range.init(source.source(7), 0, payload_len);
                const layout = try layoutFor(range, 17);
                var scratch_storage: [3]u8 = @splat(0xa5);
                const prepared = (try source_sequences.prepare(
                    Support.Codec,
                    layout,
                    &previous,
                    scratch_storage[1..2],
                )).?;
                try std.testing.expectEqual(expected.mode_byte, prepared.mode_byte);
                try std.testing.expectEqual(expected.wire_modes, prepared.wire_modes);
                try std.testing.expectEqual(expected.repeat_mask, prepared.repeat_mask);
                try std.testing.expectEqual(
                    @as(u64, @intCast(expected.bitstream_offset)),
                    prepared.tables_end,
                );
                try Support.expectTablesEqual(&expected.tables, &prepared.tables);
                try Support.expectTablesEqual(&before, &previous);
                try expectPreparedGeometry(Support, &prepared, modes, payload_len, 0, 17);
                try std.testing.expectEqual(@as(u8, 0xa5), scratch_storage[0]);
                try std.testing.expectEqual(@as(u8, 0xa5), scratch_storage[2]);
                try std.testing.expectEqual(
                    prepared.source_reads,
                    @as(u64, @intCast(source.calls)),
                );
                try std.testing.expectEqual(
                    prepared.source_bytes,
                    @as(u64, @intCast(source.bytes_returned)),
                );
            }
        }
    }
}

fn mixedWireOrder(comptime Support: type) !void {
    const modes = [3]Support.Mode{ .compressed, .rle, .compressed };
    var payload: [32]u8 = undefined;
    const payload_len = try Support.emitFixture(modes, &payload);
    var source = TrackingSource{ .bytes = payload[0..payload_len] };
    const range = try source_input.Range.init(source.source(4), 0, payload_len);
    const layout = try layoutFor(range, 3);
    var scratch: [1]u8 = undefined;
    const prepared = (try source_sequences.prepare(Support.Codec, layout, null, &scratch)).?;
    try expectRange(prepared.descriptions[0].?, 1, 2);
    try expectRange(prepared.descriptions[1].?, 3, 1);
    try expectRange(prepared.descriptions[2].?, 4, 2);
    try expectRange(prepared.table_descriptions, 1, 5);
    try expectRange(prepared.bitstream, 6, payload_len - 6);
    const expected = try Support.parseSlice(payload[0..payload_len], 3, null);
    try Support.expectTablesEqual(&expected.tables, &prepared.tables);
}

fn compressedDescriptionsUseOneByteReads(comptime Support: type) !void {
    const modes: [3]Support.Mode = @splat(.compressed);
    var payload: [32]u8 = undefined;
    const payload_len = try Support.emitFixture(modes, &payload);
    for (1..4) |short_len| {
        var source = TrackingSource{
            .bytes = payload[0..payload_len],
            .max_chunk = short_len,
        };
        const range = try source_input.Range.init(source.source(short_len), 0, payload_len);
        const layout = try layoutFor(range, 9);
        var scratch: [1]u8 = undefined;
        const prepared = (try source_sequences.prepare(Support.Codec, layout, null, &scratch)).?;
        try expectPreparedGeometry(Support, &prepared, modes, payload_len, 0, 9);
        try std.testing.expectEqual(@as(u64, 7), prepared.source_reads);
        try std.testing.expectEqual(@as(u64, 7), prepared.source_bytes);
        try std.testing.expectEqual(@as(usize, 1), prepared.max_request);
        try std.testing.expectEqual(@as(usize, 7), source.calls);
    }
}

fn invalidRleSymbols(comptime Support: type) !void {
    const cases = [_]struct {
        modes: [3]Support.Mode,
        invalid_code: u8,
    }{
        .{ .modes = .{ .rle, .predefined, .predefined }, .invalid_code = 36 },
        .{ .modes = .{ .predefined, .rle, .predefined }, .invalid_code = 32 },
        .{ .modes = .{ .predefined, .predefined, .rle }, .invalid_code = 53 },
    };
    for (cases) |case| {
        const payload = [_]u8{ modeByte(Support, case.modes), case.invalid_code, 1 };
        var source = TrackingSource{ .bytes = &payload };
        const range = try source_input.Range.init(source.source(1), 0, payload.len);
        const layout = try layoutFor(range, 1);
        var scratch: [1]u8 = undefined;
        try std.testing.expectError(
            error.CorruptFrame,
            source_sequences.prepare(Support.Codec, layout, null, &scratch),
        );
    }

    for (cases) |case| {
        const payload = [_]u8{modeByte(Support, case.modes)};
        var source = TrackingSource{ .bytes = &payload };
        const range = try source_input.Range.init(source.source(1), 0, payload.len);
        const layout = try layoutFor(range, 1);
        var scratch: [1]u8 = undefined;
        try std.testing.expectError(
            error.TruncatedFrame,
            source_sequences.prepare(Support.Codec, layout, null, &scratch),
        );
    }
}

fn repeatContracts(comptime Support: type) !void {
    const modes = [3]Support.Mode{ .repeat, .predefined, .repeat };
    var payload: [16]u8 = undefined;
    const payload_len = try Support.emitFixture(modes, &payload);
    var missing_source = TrackingSource{ .bytes = payload[0..payload_len] };
    const missing_range = try source_input.Range.init(missing_source.source(1), 0, payload_len);
    const missing_layout = try layoutFor(missing_range, 1);
    var scratch: [1]u8 = undefined;
    try std.testing.expectError(
        error.CorruptFrame,
        source_sequences.prepare(Support.Codec, missing_layout, null, &scratch),
    );

    var previous = try Support.previousTables();
    const before = previous;
    var source = TrackingSource{ .bytes = payload[0..payload_len] };
    const range = try source_input.Range.init(source.source(1), 0, payload_len);
    const layout = try layoutFor(range, 1);
    const prepared = (try source_sequences.prepare(Support.Codec, layout, &previous, &scratch)).?;
    const expected = try Support.parseSlice(payload[0..payload_len], 1, &previous);
    try Support.expectTablesEqual(&expected.tables, &prepared.tables);
    try Support.expectTablesEqual(&before, &previous);
    try std.testing.expectEqual(@as(u3, 5), prepared.repeat_mask);

    const priority_modes = [3]Support.Mode{ .repeat, .compressed, .predefined };
    var priority_payload: [16]u8 = undefined;
    const priority_len = try Support.emitFixture(priority_modes, &priority_payload);
    for (1..priority_len) |len| {
        var priority_source = TrackingSource{ .bytes = priority_payload[0..len] };
        const priority_range = try source_input.Range.init(priority_source.source(1), 0, len);
        const priority_layout = try layoutFor(priority_range, 1);
        try std.testing.expectError(
            error.TruncatedFrame,
            source_sequences.prepare(Support.Codec, priority_layout, null, &scratch),
        );
    }
}

fn zeroCountAndEmptyBitstream(comptime Support: type) !void {
    const empty_bytes = [_]u8{};
    var empty_source = TrackingSource{ .bytes = &empty_bytes };
    const empty_range = try source_input.Range.init(empty_source.source(1), 0, 0);
    const empty_layout = try layoutFor(empty_range, 0);
    var no_scratch: [0]u8 = .{};
    try std.testing.expect((try source_sequences.prepare(
        Support.Codec,
        empty_layout,
        null,
        &no_scratch,
    )) == null);
    try std.testing.expectEqual(@as(usize, 0), empty_source.calls);

    const trailing_bytes = [_]u8{0};
    var trailing_source = TrackingSource{ .bytes = &trailing_bytes };
    const trailing_range = try source_input.Range.init(trailing_source.source(1), 0, 1);
    const trailing_layout = try layoutFor(trailing_range, 0);
    try std.testing.expectError(
        error.CorruptFrame,
        source_sequences.prepare(Support.Codec, trailing_layout, null, &no_scratch),
    );
    try std.testing.expectEqual(@as(usize, 0), trailing_source.calls);

    const modes: [3]Support.Mode = @splat(.compressed);
    var payload: [32]u8 = undefined;
    const payload_len = try Support.emitFixture(modes, &payload);
    var short_source = TrackingSource{ .bytes = payload[0 .. payload_len - 1] };
    const short_range = try source_input.Range.init(short_source.source(1), 0, payload_len - 1);
    const short_layout = try layoutFor(short_range, 1);
    var scratch: [1]u8 = undefined;
    try std.testing.expectError(
        error.TruncatedFrame,
        source_sequences.prepare(Support.Codec, short_layout, null, &scratch),
    );
}

fn forbiddenBitstreamAndZeroMarker(comptime Support: type) !void {
    const modes = [3]Support.Mode{ .compressed, .rle, .predefined };
    var payload: [32]u8 = undefined;
    const payload_len = try Support.emitFixture(modes, &payload);
    payload[payload_len - 1] = 0;
    const forbidden = [_]Span{.{ .offset = payload_len - 1, .len = 1 }};
    var source = TrackingSource{
        .bytes = payload[0..payload_len],
        .forbidden = &forbidden,
    };
    const range = try source_input.Range.init(source.source(4), 0, payload_len);
    const layout = try layoutFor(range, 4);
    var scratch: [1]u8 = undefined;
    const prepared = (try source_sequences.prepare(Support.Codec, layout, null, &scratch)).?;
    try std.testing.expect(!source.forbidden_read);
    try std.testing.expectEqual(@as(u8, 0), payload[payload_len - 1]);
    try expectRange(prepared.bitstream, prepared.tables_end, 1);
}

fn callbackFailures(comptime Support: type) !void {
    const modes: [3]Support.Mode = @splat(.compressed);
    var payload: [32]u8 = undefined;
    const payload_len = try Support.emitFixture(modes, &payload);
    const metadata_reads = payload_len - 1;
    inline for (.{
        .{ SourceMode.zero, error.TruncatedFrame },
        .{ SourceMode.excessive, error.SourceReadFailed },
        .{ SourceMode.fail, error.SourceReadFailed },
    }) |case| {
        for (1..metadata_reads + 1) |fault_call| {
            var source = TrackingSource{
                .bytes = payload[0..payload_len],
                .mode = case[0],
                .fault_call = fault_call,
            };
            const range = try source_input.Range.init(source.source(3), 0, payload_len);
            const layout = try layoutFor(range, 2);
            var scratch: [1]u8 = undefined;
            try std.testing.expectError(
                case[1],
                source_sequences.prepare(Support.Codec, layout, null, &scratch),
            );
            try std.testing.expectEqual(fault_call, source.calls);
        }
    }
}

fn compressedDescriptionPrefixes(comptime Support: type) !void {
    const modes: [3]Support.Mode = @splat(.compressed);
    var payload: [32]u8 = undefined;
    const payload_len = try Support.emitFixture(modes, &payload);
    for (0..payload_len) |len| {
        var source = TrackingSource{ .bytes = payload[0..len] };
        const range = try source_input.Range.init(source.source(1), 0, len);
        const layout = try layoutFor(range, 1);
        var scratch: [1]u8 = undefined;
        try std.testing.expectError(
            error.TruncatedFrame,
            source_sequences.prepare(Support.Codec, layout, null, &scratch),
        );
    }
}

fn wideBaseAndScratch(comptime Support: type) !void {
    const modes: [3]Support.Mode = @splat(.compressed);
    var payload: [32]u8 = undefined;
    const payload_len = try Support.emitFixture(modes, &payload);
    const base = (@as(u64, 1) << 32) + 0x56_789;
    var source = TrackingSource{
        .bytes = payload[0..payload_len],
        .base_offset = base,
    };
    const range = try source_input.Range.init(source.source(2), base, payload_len);
    const layout = try layoutFor(range, 6);
    var scratch_storage: [3]u8 = @splat(0x6d);
    const prepared = (try source_sequences.prepare(
        Support.Codec,
        layout,
        null,
        scratch_storage[1..2],
    )).?;
    try expectPreparedGeometry(Support, &prepared, modes, payload_len, base, 6);
    try std.testing.expect(source.min_observed_offset.? >= base);
    try std.testing.expect(source.max_observed_offset > std.math.maxInt(u32));
    try std.testing.expectEqual(@as(u8, 0x6d), scratch_storage[0]);
    try std.testing.expectEqual(@as(u8, 0x6d), scratch_storage[2]);

    var rejected_source = TrackingSource{ .bytes = payload[0..payload_len] };
    const rejected_range = try source_input.Range.init(
        rejected_source.source(1),
        0,
        payload_len,
    );
    const rejected_layout = try layoutFor(rejected_range, 1);
    var too_small: [0]u8 = .{};
    try std.testing.expectError(
        error.OutputTooSmall,
        source_sequences.prepare(Support.Codec, rejected_layout, null, &too_small),
    );
    try std.testing.expectEqual(@as(usize, 0), rejected_source.calls);
}

fn invalidModeLowBits(comptime Support: type) !void {
    for (1..4) |low_bits| {
        const payload = [_]u8{ @intCast(low_bits), 0x01 };
        var source = TrackingSource{ .bytes = &payload };
        const range = try source_input.Range.init(source.source(1), 0, payload.len);
        const layout = try layoutFor(range, 1);
        var scratch: [1]u8 = undefined;
        try std.testing.expectError(
            error.CorruptFrame,
            source_sequences.prepare(Support.Codec, layout, null, &scratch),
        );
    }
}

pub fn contracts(comptime Support: type) !void {
    try allModeTuples(Support);
    try mixedWireOrder(Support);
    try compressedDescriptionsUseOneByteReads(Support);
    try invalidRleSymbols(Support);
    try repeatContracts(Support);
    try zeroCountAndEmptyBitstream(Support);
    try forbiddenBitstreamAndZeroMarker(Support);
    try callbackFailures(Support);
    try compressedDescriptionPrefixes(Support);
    try wideBaseAndScratch(Support);
    try invalidModeLowBits(Support);
}
