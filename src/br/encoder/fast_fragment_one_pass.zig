const std = @import("std");
const huffman = @import("../../huffman.zig");
const command_lut = @import("../command_lut.zig");
const command_plan = @import("command_plan.zig");
const encoder_distance = @import("distance.zig");

/// q0 emits one compact command/distance event at a time using trees learned
/// from the preceding fragment. Extra bits are explicit because q0's hot
/// symbol order differs from q1's temporary two-pass order.
pub const Event = struct {
    code: u7,
    extra: u32 = 0,
    extra_bits: u5 = 0,

    fn validate(self: Event) !void {
        if (self.extra_bits < 32 and self.extra >= (@as(u32, 1) << self.extra_bits))
            return error.InvalidBlockPlan;
    }
};

pub const WalkResult = struct {
    literal_count: usize,
    event_count: usize,
    explicit_distance_count: usize,
};

/// Command and distance code lengths used for the next q0 fragment. The
/// initial values are Brotli's fixed first-fragment model. Later values are
/// derived from the seeded histogram collected while emitting one fragment.
pub const State = struct {
    command_lengths: [64]u4 = default_depths[0..64].*,
    distance_lengths: [64]u4 = default_depths[64..128].*,

    pub fn reset(self: *State) void {
        self.* = .{};
    }

    pub fn update(self: *State, histogram: *const [128]u32) void {
        var command_frequencies: [64]u32 = undefined;
        var distance_frequencies: [64]u32 = undefined;
        @memcpy(&command_frequencies, histogram[0..64]);
        @memcpy(&distance_frequencies, histogram[64..128]);
        self.command_lengths = huffman.treeCodeLengths(64, &command_frequencies, 15);
        self.distance_lengths = huffman.treeCodeLengths(64, &distance_frequencies, 14);
    }
};

const default_depths = [128]u4{
    0,  4,  4,  5,  6,  6,  7,  7,  7,  7,  7,  8,  8,  8,  8,  8,
    0,  0,  0,  4,  4,  4,  4,  4,  5,  5,  6,  6,  6,  6,  7,  7,
    7,  7,  10, 10, 10, 10, 10, 10, 0,  4,  4,  5,  5,  5,  6,  6,
    7,  8,  8,  9,  10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
    5,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,
    6,  6,  6,  6,  6,  6,  5,  5,  5,  5,  5,  5,  4,  4,  4,  4,
    4,  4,  4,  5,  5,  5,  5,  5,  5,  6,  6,  7,  7,  7,  8,  10,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 0,  0,  0,  0,
};

const histogram_seed = [128]u32{
    0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
};

pub fn initialHistogram() [128]u32 {
    return histogram_seed;
}

/// Map q0's compact command order into the RFC 704-symbol alphabet.
pub fn commandSymbol(code: u6) u16 {
    return if (code < 8)
        code
    else if (code < 16)
        64 + @as(u16, code - 8)
    else if (code < 24)
        128 + @as(u16, code - 16)
    else if (code < 32)
        192 + @as(u16, code - 24)
    else if (code < 40)
        384 + @as(u16, code - 32)
    else if (code < 48)
        128 + @as(u16, code - 40) * 8
    else if (code < 56)
        256 + @as(u16, code - 48) * 8
    else
        448 + @as(u16, code - 56) * 8;
}

pub fn expandCommandLengths(compact: *const [64]u4) [704]u4 {
    var result: [704]u4 = @splat(0);
    for (compact, 0..) |bits, code| {
        if (bits != 0) result[commandSymbol(@intCast(code))] = bits;
    }
    return result;
}

pub fn commandAlphabet(state: *const State) command_plan.PrefixAlphabet {
    var result: command_plan.PrefixAlphabet = undefined;
    result.len = 0;
    for (state.command_lengths, 0..) |bits, code| {
        if (bits == 0) continue;
        result.symbols[result.len] = commandSymbol(@intCast(code));
        result.len += 1;
    }
    return result;
}

pub fn distanceAlphabet(state: *const State) command_plan.PrefixAlphabetFor(64) {
    var result: command_plan.PrefixAlphabetFor(64) = undefined;
    result.len = 0;
    for (state.distance_lengths, 0..) |bits, symbol| {
        if (bits == 0) continue;
        result.symbols[result.len] = @intCast(symbol);
        result.len += 1;
    }
    return result;
}

/// q0 chooses its literal tree before LZ emission. Short fragments count every
/// input byte and triple the first eleven occurrences; long fragments sample
/// every 29th byte and keep every symbol reachable.
pub fn literalFrequencies(input: []const u8) ![256]u32 {
    if (input.len == 0 or input.len > 1 << 24) return error.InvalidBlockPlan;
    var frequencies: [256]u32 = @splat(0);
    if (input.len < 1 << 15) {
        for (input) |byte| frequencies[byte] += 1;
        for (&frequencies) |*frequency| {
            const capped: u32 = @min(frequency.*, 11);
            const adjust: u32 = capped * 2;
            frequency.* += adjust;
        }
    } else {
        var position: usize = 0;
        while (position < input.len) : (position += 29)
            frequencies[input[position]] += 1;
        for (&frequencies) |*frequency| {
            const capped: u32 = @min(frequency.*, 11);
            const adjust: u32 = 1 + capped * 2;
            frequency.* += adjust;
        }
    }
    return frequencies;
}

fn insertEvent(insert_len: usize) !Event {
    const event: Event = if (insert_len < 6)
        .{ .code = @intCast(insert_len + 40) }
    else if (insert_len < 130) blk: {
        const tail = insert_len - 2;
        // log2_int returns a pointer-width-dependent shift type; symbol
        // arithmetic needs room for its alphabet offsets on 32-bit targets.
        const nbits: usize = std.math.log2_int(usize, tail) - 1;
        const prefix = tail >> @intCast(nbits);
        break :blk .{
            .code = @intCast((nbits << 1) + prefix + 42),
            .extra = @intCast(tail - (prefix << @intCast(nbits))),
            .extra_bits = @intCast(nbits),
        };
    } else if (insert_len < 2114) blk: {
        const tail = insert_len - 66;
        const nbits: usize = std.math.log2_int(usize, tail);
        break :blk .{
            .code = @intCast(nbits + 50),
            .extra = @intCast(tail - (@as(usize, 1) << @intCast(nbits))),
            .extra_bits = @intCast(nbits),
        };
    } else if (insert_len < 6210)
        .{ .code = 61, .extra = @intCast(insert_len - 2114), .extra_bits = 12 }
    else if (insert_len < 22594)
        .{ .code = 62, .extra = @intCast(insert_len - 6210), .extra_bits = 14 }
    else if (insert_len <= 1 << 24)
        .{ .code = 63, .extra = @intCast(insert_len - 22594), .extra_bits = 24 }
    else
        return error.InvalidBlockPlan;
    try event.validate();
    return event;
}

fn copyEvent(copy_len: usize) !Event {
    if (copy_len < 2 or copy_len > 1 << 24) return error.InvalidBlockPlan;
    const event: Event = if (copy_len < 10)
        .{ .code = @intCast(copy_len + 14) }
    else if (copy_len < 134) blk: {
        const tail = copy_len - 6;
        const nbits: usize = std.math.log2_int(usize, tail) - 1;
        const prefix = tail >> @intCast(nbits);
        break :blk .{
            .code = @intCast((nbits << 1) + prefix + 20),
            .extra = @intCast(tail - (prefix << @intCast(nbits))),
            .extra_bits = @intCast(nbits),
        };
    } else if (copy_len < 2118) blk: {
        const tail = copy_len - 70;
        const nbits: usize = std.math.log2_int(usize, tail);
        break :blk .{
            .code = @intCast(nbits + 28),
            .extra = @intCast(tail - (@as(usize, 1) << @intCast(nbits))),
            .extra_bits = @intCast(nbits),
        };
    } else .{ .code = 39, .extra = @intCast(copy_len - 2118), .extra_bits = 24 };
    try event.validate();
    return event;
}

fn emitCopyLast(visitor: anytype, copy_len: usize) !void {
    if (copy_len < 2 or copy_len > 1 << 24) return error.InvalidBlockPlan;
    const event: Event = if (copy_len < 12)
        .{ .code = @intCast(copy_len - 4) }
    else if (copy_len < 72) blk: {
        const tail = copy_len - 8;
        const nbits: usize = std.math.log2_int(usize, tail) - 1;
        const prefix = tail >> @intCast(nbits);
        break :blk .{
            .code = @intCast((nbits << 1) + prefix + 4),
            .extra = @intCast(tail - (prefix << @intCast(nbits))),
            .extra_bits = @intCast(nbits),
        };
    } else if (copy_len < 136) blk: {
        const tail = copy_len - 8;
        break :blk .{
            .code = @intCast((tail >> 5) + 30),
            .extra = @intCast(tail & 31),
            .extra_bits = 5,
        };
    } else if (copy_len < 2120) blk: {
        const tail = copy_len - 72;
        const nbits: usize = std.math.log2_int(usize, tail);
        break :blk .{
            .code = @intCast(nbits + 28),
            .extra = @intCast(tail - (@as(usize, 1) << @intCast(nbits))),
            .extra_bits = @intCast(nbits),
        };
    } else .{ .code = 39, .extra = @intCast(copy_len - 2120), .extra_bits = 24 };
    try event.validate();
    try visitor.event(event);
    if (copy_len >= 72) try visitor.event(.{ .code = 64 });
}

fn distanceEvent(distance: usize) !Event {
    if (distance == 0 or distance > std.math.maxInt(u32) - 3)
        return error.InvalidBlockPlan;
    const d = distance + 3;
    const nbits: usize = std.math.log2_int(usize, d) - 1;
    const prefix = (d >> @intCast(nbits)) & 1;
    const offset = (2 + prefix) << @intCast(nbits);
    const code = 2 * (nbits - 1) + prefix + 80;
    if (code >= 128) return error.InvalidBlockPlan;
    const event = Event{
        .code = @intCast(code),
        .extra = @intCast(d - offset),
        .extra_bits = @intCast(nbits),
    };
    try event.validate();
    return event;
}

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
        if (command.copy_len < 5 or command.copy_len > input.len - cursor or
            command.distance == 0 or command.distance > cursor)
        {
            return error.InvalidBlockPlan;
        }
        if (command.insert_len == 0) {
            try visitor.event(try copyEvent(command.copy_len));
            result.event_count += 1;
            try visitor.event(try distanceEvent(command.distance));
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
        }
        cursor += command.copy_len;
    }
    if (cursor != input.len) return error.InvalidBlockPlan;
    return result;
}

test "q0 compact mappings reconstruct every fast-fragment length" {
    for (0..64 * 1024 + 1) |insert_len| {
        const event_value = try insertEvent(insert_len);
        const entry = command_lut.entries[commandSymbol(@intCast(event_value.code))];
        try std.testing.expectEqual(insert_len, entry.insert_base + event_value.extra);
        try std.testing.expectEqual(@as(u32, 2), entry.copy_base);
        try std.testing.expectEqual(entry.insert_extra_bits, event_value.extra_bits);
        try std.testing.expectEqual(@as(i2, -1), entry.distance_code);
    }
    for (5..64 * 1024 + 1) |copy_len| {
        const event_value = try copyEvent(copy_len);
        const entry = command_lut.entries[commandSymbol(@intCast(event_value.code))];
        try std.testing.expectEqual(@as(u32, 0), entry.insert_base);
        try std.testing.expectEqual(copy_len, entry.copy_base + event_value.extra);
        try std.testing.expectEqual(entry.copy_extra_bits, event_value.extra_bits);
        try std.testing.expectEqual(@as(i2, -1), entry.distance_code);
    }
    for ([_]usize{ 65537, 1 << 20, (1 << 24) - 1, 1 << 24 }) |length| {
        const insert = try insertEvent(length);
        const insert_entry = command_lut.entries[commandSymbol(@intCast(insert.code))];
        try std.testing.expectEqual(length, insert_entry.insert_base + insert.extra);
        try std.testing.expectEqual(insert_entry.insert_extra_bits, insert.extra_bits);
        const copy = try copyEvent(length);
        const copy_entry = command_lut.entries[commandSymbol(@intCast(copy.code))];
        try std.testing.expectEqual(length, copy_entry.copy_base + copy.extra);
        try std.testing.expectEqual(copy_entry.copy_extra_bits, copy.extra_bits);
    }
}

test "q0 compact distances match the standard Brotli encoder" {
    const parameters = encoder_distance.Parameters.init(0, 0);
    for (1..65521) |distance| {
        const event_value = try distanceEvent(distance);
        const expected = encoder_distance.encodeWithParameters(distance, parameters).?;
        try std.testing.expectEqual(expected.symbol, event_value.code - 64);
        try std.testing.expectEqual(expected.extra, event_value.extra);
        try std.testing.expectEqual(expected.extra_bits, event_value.extra_bits);
    }
}

test "q0 learned state retains seeded complete trees" {
    var histogram = initialHistogram();
    histogram[41] += 100;
    histogram[84] += 50;
    var state: State = .{};
    state.update(&histogram);
    var command_active: usize = 0;
    var distance_active: usize = 0;
    for (state.command_lengths) |bits| command_active += @intFromBool(bits != 0);
    for (state.distance_lengths) |bits| distance_active += @intFromBool(bits != 0);
    try std.testing.expect(command_active > 4);
    try std.testing.expect(distance_active > 4);
    const command_lengths = expandCommandLengths(&state.command_lengths);
    _ = try huffman.HuffmanTable(704).Encoder.init(&command_lengths);
    _ = try huffman.HuffmanTable(64).Encoder.init(&state.distance_lengths);
}

test "q0 literal model samples long fragments and keeps every byte reachable" {
    var input: [32 * 1024]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @intCast(index & 255);
    const frequencies = try literalFrequencies(&input);
    for (frequencies) |frequency| try std.testing.expect(frequency != 0);
}
