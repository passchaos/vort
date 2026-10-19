const std = @import("std");
const command_lut = @import("../command_lut.zig");
const command_plan = @import("command_plan.zig");
const encoder_distance = @import("distance.zig");

/// q1's temporary alphabet stores command symbols in 0...63 and distance
/// symbols in 64...127. The upper byte used by the reference implementation
/// is represented explicitly here so extra-bit validation is type-safe.
pub const Event = struct {
    code: u7,
    extra: u32 = 0,

    pub fn extraBits(self: Event) u5 {
        return extra_bits[self.code];
    }

    fn validate(self: Event) !void {
        const bits = self.extraBits();
        if (bits < 32 and self.extra >= (@as(u32, 1) << bits))
            return error.InvalidBlockPlan;
    }
};

pub const Histograms = struct {
    literals: [256]u32 = @splat(0),
    commands: [64]u32 = @splat(0),
    distances: [64]u32 = @splat(0),
    literal_count: usize = 0,
    event_count: usize = 0,
    explicit_distance_count: usize = 0,
};

pub const WalkResult = struct {
    literal_count: usize,
    event_count: usize,
    explicit_distance_count: usize,
};

const extra_bits = [128]u5{
    0,  0,  0,  0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  5,  5,
    6,  7,  8,  9,  10, 12, 14, 24, 0,  0,  0,  0,  0,  0,  0,  0,
    1,  1,  2,  2,  3,  3,  4,  4,  0,  0,  0,  0,  0,  0,  0,  0,
    1,  1,  2,  2,  3,  3,  4,  4,  5,  5,  6,  7,  8,  9,  10, 24,
    0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
    1,  1,  2,  2,  3,  3,  4,  4,  5,  5,  6,  6,  7,  7,  8,  8,
    9,  9,  10, 10, 11, 11, 12, 12, 13, 13, 14, 14, 15, 15, 16, 16,
    17, 17, 18, 18, 19, 19, 20, 20, 21, 21, 22, 22, 23, 23, 24, 24,
};

/// Map q1's hot command order into the RFC 704-symbol insert/copy alphabet.
/// Compact symbols 16 and 40 have equivalent length semantics but intentionally
/// occupy distinct RFC symbols, matching the reference tree expansion.
pub fn commandSymbol(code: u6) u16 {
    return if (code < 8)
        128 + @as(u16, code) * 8
    else if (code < 16)
        256 + @as(u16, code - 8) * 8
    else if (code < 24)
        448 + @as(u16, code - 16) * 8
    else if (code < 32)
        @as(u16, code - 24)
    else if (code < 40)
        64 + @as(u16, code - 32)
    else if (code < 48)
        128 + @as(u16, code - 40)
    else if (code < 56)
        192 + @as(u16, code - 48)
    else
        384 + @as(u16, code - 56);
}

pub fn expandCommandLengths(compact: *const [64]u4) [704]u4 {
    var result: [704]u4 = @splat(0);
    for (compact, 0..) |bits, code| {
        if (bits != 0) result[commandSymbol(@intCast(code))] = bits;
    }
    return result;
}

pub fn expandCommandAlphabet(
    compact: *const command_plan.PrefixAlphabetFor(64),
) command_plan.PrefixAlphabet {
    var result: command_plan.PrefixAlphabet = undefined;
    result.len = compact.len;
    for (compact.symbols[0..compact.len], 0..) |code, index|
        result.symbols[index] = commandSymbol(@intCast(code));
    return result;
}

fn insertEvent(insert_len: usize) !Event {
    const event: Event = if (insert_len < 6)
        .{ .code = @intCast(insert_len) }
    else if (insert_len < 130) blk: {
        const tail = insert_len - 2;
        const nbits = std.math.log2_int(usize, tail) - 1;
        const prefix = tail >> @intCast(nbits);
        break :blk .{
            .code = @intCast((nbits << 1) + prefix + 2),
            .extra = @intCast(tail - (prefix << @intCast(nbits))),
        };
    } else if (insert_len < 2114) blk: {
        const tail = insert_len - 66;
        const nbits = std.math.log2_int(usize, tail);
        break :blk .{
            .code = @intCast(nbits + 10),
            .extra = @intCast(tail - (@as(usize, 1) << @intCast(nbits))),
        };
    } else if (insert_len < 6210)
        .{ .code = 21, .extra = @intCast(insert_len - 2114) }
    else if (insert_len < 22594)
        .{ .code = 22, .extra = @intCast(insert_len - 6210) }
    else if (insert_len <= 1 << 24)
        .{ .code = 23, .extra = @intCast(insert_len - 22594) }
    else
        return error.InvalidBlockPlan;
    try event.validate();
    return event;
}

fn copyEvent(copy_len: usize) !Event {
    if (copy_len < 2 or copy_len > 1 << 24) return error.InvalidBlockPlan;
    const event: Event = if (copy_len < 10)
        .{ .code = @intCast(copy_len + 38) }
    else if (copy_len < 134) blk: {
        const tail = copy_len - 6;
        const nbits = std.math.log2_int(usize, tail) - 1;
        const prefix = tail >> @intCast(nbits);
        break :blk .{
            .code = @intCast((nbits << 1) + prefix + 44),
            .extra = @intCast(tail - (prefix << @intCast(nbits))),
        };
    } else if (copy_len < 2118) blk: {
        const tail = copy_len - 70;
        const nbits = std.math.log2_int(usize, tail);
        break :blk .{
            .code = @intCast(nbits + 52),
            .extra = @intCast(tail - (@as(usize, 1) << @intCast(nbits))),
        };
    } else .{ .code = 63, .extra = @intCast(copy_len - 2118) };
    try event.validate();
    return event;
}

fn emitCopyLast(visitor: anytype, copy_len: usize) !void {
    if (copy_len < 2 or copy_len > 1 << 24) return error.InvalidBlockPlan;
    const event: Event = if (copy_len < 12)
        .{ .code = @intCast(copy_len + 20) }
    else if (copy_len < 72) blk: {
        const tail = copy_len - 8;
        const nbits = std.math.log2_int(usize, tail) - 1;
        const prefix = tail >> @intCast(nbits);
        break :blk .{
            .code = @intCast((nbits << 1) + prefix + 28),
            .extra = @intCast(tail - (prefix << @intCast(nbits))),
        };
    } else if (copy_len < 136) blk: {
        const tail = copy_len - 8;
        break :blk .{
            .code = @intCast((tail >> 5) + 54),
            .extra = @intCast(tail & 31),
        };
    } else if (copy_len < 2120) blk: {
        const tail = copy_len - 72;
        const nbits = std.math.log2_int(usize, tail);
        break :blk .{
            .code = @intCast(nbits + 52),
            .extra = @intCast(tail - (@as(usize, 1) << @intCast(nbits))),
        };
    } else .{ .code = 63, .extra = @intCast(copy_len - 2120) };
    try event.validate();
    try visitor.event(event);
    if (copy_len >= 72) try visitor.event(.{ .code = 64 });
}

fn distanceEvent(distance: usize) !Event {
    if (distance == 0 or distance > std.math.maxInt(u32) - 3)
        return error.InvalidBlockPlan;
    const d = distance + 3;
    const nbits = std.math.log2_int(usize, d) - 1;
    const prefix = (d >> @intCast(nbits)) & 1;
    const offset = (2 + prefix) << @intCast(nbits);
    const code = 2 * (nbits - 1) + prefix + 80;
    if (code >= 128) return error.InvalidBlockPlan;
    const event = Event{
        .code = @intCast(code),
        .extra = @intCast(d - offset),
    };
    try event.validate();
    return event;
}

/// Walk a fragment command plan in the same logical order as q1's two-pass
/// temporary stream: command, its literals, optional distance, then any
/// continuation command. The visitor supplies `event`, `literals`, and
/// `distance(actual, pushes_ring)` methods.
pub fn walk(
    input: []const u8,
    commands: []const command_plan.Command,
    visitor: anytype,
) !WalkResult {
    if (commands.len == 0 or input.len == 0 or input.len > 1 << 24)
        return error.InvalidBlockPlan;
    var cursor: usize = 0;
    var last_distance: usize = 0;
    var result: WalkResult = .{
        .literal_count = 0,
        .event_count = 0,
        .explicit_distance_count = 0,
    };
    for (commands) |command| {
        if (command.source != .lz77 or command.insert_start != cursor or
            command.insert_len > input.len - cursor)
        {
            return error.InvalidBlockPlan;
        }
        if (command.insert_len != 0 or !command.has_copy) {
            try visitor.event(try insertEvent(command.insert_len));
            result.event_count += 1;
            const literals = input[cursor..][0..command.insert_len];
            try visitor.literals(literals);
            result.literal_count += literals.len;
            cursor += literals.len;
        }
        if (!command.has_copy) continue;
        if (command.copy_len < 4 or command.copy_len > input.len - cursor or
            command.distance == 0 or command.distance > cursor)
        {
            return error.InvalidBlockPlan;
        }
        if (command.insert_len == 0) {
            try visitor.event(try copyEvent(command.copy_len));
            result.event_count += 1;
            const distance = try distanceEvent(command.distance);
            try visitor.event(distance);
            try visitor.distance(command.distance, true);
            result.event_count += 1;
            result.explicit_distance_count += 1;
            last_distance = command.distance;
        } else {
            const explicit = command.distance != last_distance;
            if (explicit) {
                try visitor.event(try distanceEvent(command.distance));
                result.explicit_distance_count += 1;
                last_distance = command.distance;
            } else {
                try visitor.event(.{ .code = 64 });
            }
            try visitor.distance(command.distance, explicit);
            result.event_count += 1;
            const before = result.event_count;
            const CountingVisitor = struct {
                parent: @TypeOf(visitor),
                count: *usize,

                fn event(self: *@This(), value: Event) !void {
                    try self.parent.event(value);
                    self.count.* += 1;
                }
            };
            var counter = CountingVisitor{ .parent = visitor, .count = &result.event_count };
            try emitCopyLast(&counter, command.copy_len);
            std.debug.assert(result.event_count > before);
        }
        cursor += command.copy_len;
    }
    if (cursor != input.len) return error.InvalidBlockPlan;
    return result;
}

const HistogramCollector = struct {
    histograms: Histograms = .{},

    fn event(self: *@This(), event_value: Event) !void {
        if (event_value.code < 64)
            self.histograms.commands[event_value.code] += 1
        else
            self.histograms.distances[event_value.code - 64] += 1;
    }

    fn literals(self: *@This(), bytes: []const u8) !void {
        for (bytes) |byte| self.histograms.literals[byte] += 1;
    }

    fn distance(_: *@This(), _: usize, _: bool) !void {}
};

pub fn collect(
    input: []const u8,
    commands: []const command_plan.Command,
) !Histograms {
    var collector: HistogramCollector = .{};
    const result = try walk(input, commands, &collector);
    collector.histograms.literal_count = result.literal_count;
    collector.histograms.event_count = result.event_count;
    collector.histograms.explicit_distance_count = result.explicit_distance_count;
    // Keep both compact trees non-degenerate exactly as the reference writer
    // does. The added symbols are tree-only and never enter the payload.
    collector.histograms.commands[1] += 1;
    collector.histograms.commands[2] += 1;
    collector.histograms.distances[0] += 1;
    collector.histograms.distances[20] += 1;
    return collector.histograms;
}

test "q1 compact command mapping reconstructs insert and copy lengths" {
    for (0..64 * 1024 + 1) |insert_len| {
        const event_value = try insertEvent(insert_len);
        const entry = command_lut.entries[commandSymbol(@intCast(event_value.code))];
        try std.testing.expectEqual(insert_len, entry.insert_base + event_value.extra);
        try std.testing.expectEqual(@as(u32, 2), entry.copy_base);
        try std.testing.expectEqual(entry.insert_extra_bits, event_value.extraBits());
        try std.testing.expectEqual(@as(i2, -1), entry.distance_code);
    }
    for (4..64 * 1024 + 1) |copy_len| {
        const event_value = try copyEvent(copy_len);
        const entry = command_lut.entries[commandSymbol(@intCast(event_value.code))];
        try std.testing.expectEqual(@as(u32, 0), entry.insert_base);
        try std.testing.expectEqual(copy_len, entry.copy_base + event_value.extra);
        try std.testing.expectEqual(entry.copy_extra_bits, event_value.extraBits());
        try std.testing.expectEqual(@as(i2, -1), entry.distance_code);
    }
}

test "q1 last-distance continuation reconstructs copy length minus two" {
    const Visitor = struct {
        events: [2]Event = undefined,
        len: usize = 0,

        fn event(self: *@This(), value: Event) !void {
            self.events[self.len] = value;
            self.len += 1;
        }
    };
    for (4..64 * 1024 + 1) |copy_len| {
        var visitor: Visitor = .{};
        try emitCopyLast(&visitor, copy_len);
        try std.testing.expect(visitor.len == 1 or visitor.len == 2);
        const first = visitor.events[0];
        const entry = command_lut.entries[commandSymbol(@intCast(first.code))];
        try std.testing.expectEqual(@as(u32, 0), entry.insert_base);
        try std.testing.expectEqual(copy_len - 2, entry.copy_base + first.extra);
        try std.testing.expectEqual(first.extraBits(), entry.copy_extra_bits);
        try std.testing.expectEqual(visitor.len == 1, entry.distance_code == 0);
        if (visitor.len == 2) try std.testing.expectEqual(@as(u7, 64), visitor.events[1].code);
    }
}

test "q1 compact distances match the standard Brotli distance encoder" {
    const parameters = encoder_distance.Parameters.init(0, 0);
    for (1..65521) |distance| {
        const event_value = try distanceEvent(distance);
        const expected = encoder_distance.encodeWithParameters(distance, parameters).?;
        try std.testing.expectEqual(expected.symbol, event_value.code - 64);
        try std.testing.expectEqual(expected.extra, event_value.extra);
        try std.testing.expectEqual(expected.extra_bits, event_value.extraBits());
    }
}

test "q1 two-pass histograms cover terminal inserts and repeated distances" {
    const input = "abcdXabcdYabcdZabcd";
    const commands = [_]command_plan.Command{
        .{ .insert_start = 0, .insert_len = 5, .copy_len = 4, .distance = 5, .has_copy = true },
        .{ .insert_start = 9, .insert_len = 1, .copy_len = 4, .distance = 5, .has_copy = true },
        .{ .insert_start = 14, .insert_len = 1, .copy_len = 4, .distance = 5, .has_copy = true },
    };
    const histograms = try collect(input, &commands);
    try std.testing.expectEqual(@as(usize, 7), histograms.literal_count);
    try std.testing.expectEqual(@as(usize, 1), histograms.explicit_distance_count);
    try std.testing.expect(histograms.commands[5] != 0);
    try std.testing.expect(histograms.distances[0] >= 3); // two repeats plus sentinel
    try std.testing.expect(histograms.distances[20] != 0);
}
