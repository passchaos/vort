const std = @import("std");
const core = @import("../core.zig");
const filter_encoder = @import("rar29_filter_encoder.zig");

pub const Error = core.Error || filter_encoder.Error || std.mem.Allocator.Error || error{
    InvalidRar29EncodeOptions,
    MissingRar29SolidEncoderState,
    Rar29EncoderPoisoned,
};

pub const Filter = filter_encoder.Filter;
pub const validateFilter = filter_encoder.validate;

pub const Options = struct {
    dictionary_size: usize = 1024 * 1024,
    block_size: usize = 64 * 1024,
};

const main_count: usize = 299;
const distance_count: usize = 60;
const low_distance_count: usize = 17;
const length_count: usize = 28;
const level_count: usize = 20;
const table_count: usize = main_count + distance_count + low_distance_count + length_count;
const min_match: usize = 4;
const max_match: usize = 257;
const hash_size: usize = 1 << 16;
pub const max_block_size: usize = 4 * 1024 * 1024;

const length_bases = [_]usize{
    0,  1,  2,  3,  4,  5,  6,  7,  8,  10,  12,  14,  16,  20,
    24, 28, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224,
};
const length_bits = [_]u8{
    0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2,
    2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5,
};
const distance_bases = [_]usize{
    0,       1,       2,       3,       4,       6,       8,       12,      16,      24,      32,      48,      64,     96,     128,    192,
    256,     384,     512,     768,     1024,    1536,    2048,    3072,    4096,    6144,    8192,    12288,   16384,  24576,  32768,  49152,
    65536,   98304,   131072,  196608,  262144,  327680,  393216,  458752,  524288,  589824,  655360,  720896,  786432, 851968, 917504, 983040,
    1048576, 1310720, 1572864, 1835008, 2097152, 2359296, 2621440, 2883584, 3145728, 3407872, 3670016, 3932160,
};
const distance_bits = [_]u8{
    0,  0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  5,  5,  6,  6,
    7,  7,  8,  8,  9,  9,  10, 10, 11, 11, 12, 12, 13, 13, 14, 14,
    15, 15, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16, 16,
    18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
};

const Token = union(enum) {
    literal: u8,
    match: struct { length: usize, distance: usize },
};

const MatchState = struct {
    distances: [4]usize = @splat(0),
    last_distance: usize = 0,
    last_length: usize = 0,

    fn repeatIndex(self: MatchState, distance: usize) ?usize {
        for (self.distances, 0..) |old, index|
            if (old == distance and old != 0) return index;
        return null;
    }

    fn remember(self: *MatchState, length: usize, distance: usize) void {
        if (distance == self.last_distance and length == self.last_length and
            self.last_length != 0) return;
        if (self.repeatIndex(distance)) |index| {
            var current = index;
            while (current != 0) : (current -= 1)
                self.distances[current] = self.distances[current - 1];
            self.distances[0] = distance;
        } else {
            self.distances[3] = self.distances[2];
            self.distances[2] = self.distances[1];
            self.distances[1] = self.distances[0];
            self.distances[0] = distance;
        }
        self.last_distance = distance;
        self.last_length = length;
    }
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
) Error![]u8 {
    var encoder = Encoder.init(allocator, options);
    defer encoder.deinit();
    return encoder.encodeMemberAlloc(input, false);
}

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    state: MatchState = .{},
    history: std.ArrayList(u8) = .empty,
    initialized: bool = false,
    poisoned: bool = false,

    pub fn init(allocator: std.mem.Allocator, options: Options) Encoder {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Encoder) void {
        self.history.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Encoder) void {
        self.state = .{};
        self.history.clearRetainingCapacity();
        self.initialized = false;
        self.poisoned = false;
    }

    pub fn canContinue(self: *const Encoder) bool {
        return self.initialized and !self.poisoned;
    }

    pub fn encodeMemberAlloc(self: *Encoder, input: []const u8, solid: bool) Error![]u8 {
        return self.encodeMemberInternal(input, solid, null);
    }

    /// Encodes one member with RAR VM records. In solid mode, dictionary and
    /// repeat-distance state continue over the pre-filter byte stream while VM
    /// offsets restart at zero for the new member.
    pub fn encodeFilteredMemberAlloc(
        self: *Encoder,
        input: []const u8,
        filter: Filter,
        solid: bool,
    ) Error![]u8 {
        try validateOptions(self.options);
        if (input.len == 0) return error.InvalidRar29FilterOptions;
        const block_size = try filter_encoder.blockSize(filter, self.options.block_size);
        if (!filter_encoder.canApply(filter, @min(input.len, block_size)))
            return error.InvalidRar29FilterOptions;
        return self.encodeMemberInternal(input, solid, filter);
    }

    fn encodeMemberInternal(
        self: *Encoder,
        input: []const u8,
        solid: bool,
        filter: ?Filter,
    ) Error![]u8 {
        try validateOptions(self.options);
        if (filter != null and input.len == 0) return error.InvalidRar29FilterOptions;
        if (!solid)
            self.reset()
        else {
            if (self.poisoned) return error.Rar29EncoderPoisoned;
            if (!self.initialized) return error.MissingRar29SolidEncoderState;
        }
        errdefer self.poisoned = true;

        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(self.allocator);
        if (input.len == 0) {
            try encodeBlock(
                self.allocator,
                &output,
                self.history.items,
                &self.state,
                self.options,
                true,
                input,
                null,
            );
        } else {
            var start: usize = 0;
            const block_size = if (filter) |active|
                try filter_encoder.blockSize(active, self.options.block_size)
            else
                self.options.block_size;
            var filter_program_initialized = false;
            var filter_applied = false;
            while (start < input.len) {
                const end = @min(input.len, start +| block_size);
                const block = input[start..end];
                if (filter) |active| {
                    if (filter_encoder.canApply(active, block.len)) {
                        var prepared = try filter_encoder.prepareBlockAlloc(
                            self.allocator,
                            block,
                            active,
                            start,
                            !filter_program_initialized,
                        );
                        defer prepared.deinit();
                        try encodeBlock(
                            self.allocator,
                            &output,
                            self.history.items,
                            &self.state,
                            self.options,
                            end == input.len,
                            prepared.data,
                            prepared.record,
                        );
                        try self.history.appendSlice(self.allocator, prepared.data);
                        filter_program_initialized = true;
                        filter_applied = true;
                    } else {
                        try encodeBlock(
                            self.allocator,
                            &output,
                            self.history.items,
                            &self.state,
                            self.options,
                            end == input.len,
                            block,
                            null,
                        );
                        try self.history.appendSlice(self.allocator, block);
                    }
                } else {
                    try encodeBlock(
                        self.allocator,
                        &output,
                        self.history.items,
                        &self.state,
                        self.options,
                        end == input.len,
                        block,
                        null,
                    );
                    try self.history.appendSlice(self.allocator, block);
                }
                self.trimHistory();
                start = end;
            }
            if (filter != null and !filter_applied) return error.InvalidRar29FilterOptions;
            self.initialized = true;
        }
        const owned = try output.toOwnedSlice(self.allocator);
        self.poisoned = false;
        return owned;
    }

    fn trimHistory(self: *Encoder) void {
        if (self.history.items.len <= self.options.dictionary_size) return;
        const discard = self.history.items.len - self.options.dictionary_size;
        @memmove(
            self.history.items[0..self.options.dictionary_size],
            self.history.items[discard..],
        );
        self.history.items.len = self.options.dictionary_size;
    }
};

pub fn validateOptions(options: Options) Error!void {
    if (options.block_size == 0 or options.block_size > max_block_size)
        return error.InvalidRar29EncodeOptions;
    switch (options.dictionary_size) {
        64 * 1024,
        128 * 1024,
        256 * 1024,
        512 * 1024,
        1024 * 1024,
        2 * 1024 * 1024,
        4 * 1024 * 1024,
        => {},
        else => return error.InvalidRar29EncodeOptions,
    }
}

fn encodeBlock(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    history: []const u8,
    state: *MatchState,
    options: Options,
    is_last: bool,
    input: []const u8,
    filter_record: ?[]const u8,
) Error!void {
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(allocator);
    try tokenize(allocator, &tokens, history, input, options.dictionary_size);

    const level_lengths = fixedLevelLengths();
    const table_lengths = fixedTableLengths();
    const main_codes = try Codes(main_count).init(table_lengths[0..main_count]);
    const distance_codes = try Codes(distance_count).init(
        table_lengths[main_count .. main_count + distance_count],
    );
    const low_distance_codes = try Codes(low_distance_count).init(
        table_lengths[main_count + distance_count .. main_count + distance_count + low_distance_count],
    );
    const match_length_codes = try Codes(length_count).init(
        table_lengths[main_count + distance_count + low_distance_count ..],
    );
    const level_codes = try Codes(level_count).init(&level_lengths);

    var writer = BitWriter{ .allocator = allocator };
    defer writer.bytes.deinit(allocator);
    try writer.writeBits(0, 1); // LZ block.
    try writer.writeBits(0, 1); // Code lengths are absolute, not table deltas.
    for (level_lengths) |length| try writer.writeBits(length, 4);
    try writeTableRuns(&writer, &level_codes, &table_lengths);

    if (filter_record) |record| {
        try writer.writeCode(&main_codes, 257);
        for (record) |byte| try writer.writeBits(byte, 8);
    }

    for (tokens.items) |token| switch (token) {
        .literal => |byte| try writer.writeCode(&main_codes, byte),
        .match => |match| {
            if (match.distance == state.last_distance and match.length == state.last_length and
                state.last_length != 0)
            {
                try writer.writeCode(&main_codes, 258);
            } else if (state.repeatIndex(match.distance)) |index| {
                const length = try repeatLengthSlot(match.length);
                try writer.writeCode(&main_codes, 259 + index);
                try writer.writeCode(&match_length_codes, length.slot);
                try writer.writeBits(length.extra, length.extra_bits);
            } else {
                const adjusted_length = match.length - matchLengthBonus(match.distance);
                const length = try freshLengthSlot(adjusted_length);
                const distance = try distanceSlot(match.distance);
                try writer.writeCode(&main_codes, 271 + length.slot);
                try writer.writeBits(length.extra, length.extra_bits);
                try writer.writeCode(&distance_codes, distance.slot);
                if (distance.slot > 9) {
                    if (distance.extra_bits > 4)
                        try writer.writeBits(distance.extra >> 4, distance.extra_bits - 4);
                    try writer.writeCode(&low_distance_codes, distance.extra & 0x0f);
                } else {
                    try writer.writeBits(distance.extra, distance.extra_bits);
                }
            }
            state.remember(match.length, match.distance);
        },
    };
    try writer.writeCode(&main_codes, 256);
    if (is_last) {
        try writer.writeBits(1, 2); // New file, read new tables in a solid successor.
    } else {
        try writer.writeBits(1, 1); // Same file, another table follows.
    }
    try output.appendSlice(allocator, writer.bytes.items);
}

fn tokenize(
    allocator: std.mem.Allocator,
    tokens: *std.ArrayList(Token),
    history: []const u8,
    input: []const u8,
    dictionary_size: usize,
) Error!void {
    const combined_len = std.math.add(usize, history.len, input.len) catch
        return error.IntegerOverflow;
    const combined = try allocator.alloc(u8, combined_len);
    defer allocator.free(combined);
    @memcpy(combined[0..history.len], history);
    @memcpy(combined[history.len..], input);

    const heads = try allocator.alloc(usize, hash_size);
    defer allocator.free(heads);
    @memset(heads, std.math.maxInt(usize));
    var seed: usize = 0;
    while (seed < history.len) : (seed += 1) {
        if (seed + min_match <= combined.len)
            heads[hashAt(combined, seed)] = seed;
    }

    var position = history.len;
    while (position < combined.len) {
        var best_length: usize = 0;
        var best_distance: usize = 0;
        if (position + min_match <= combined.len) {
            const hash = hashAt(combined, position);
            const previous = heads[hash];
            heads[hash] = position;
            if (previous != std.math.maxInt(usize)) {
                const distance = position - previous;
                if (distance <= dictionary_size) {
                    const length = matchLength(
                        combined,
                        position,
                        distance,
                        @min(max_match, combined.len - position),
                    );
                    const required = @max(min_match, 3 + matchLengthBonus(distance));
                    if (length >= required) {
                        best_length = length;
                        best_distance = distance;
                    }
                }
            }
        }
        if (best_length < min_match) {
            try tokens.append(allocator, .{ .literal = combined[position] });
            position += 1;
            continue;
        }
        try tokens.append(allocator, .{ .match = .{
            .length = best_length,
            .distance = best_distance,
        } });
        const match_end = position + best_length;
        position += 1;
        while (position < match_end) : (position += 1) {
            if (position + min_match <= combined.len)
                heads[hashAt(combined, position)] = position;
        }
    }
}

fn hashAt(input: []const u8, position: usize) usize {
    const value = std.mem.readInt(u32, input[position..][0..4], .little);
    return @truncate((value *% 0x9e37_79b1) >> 16);
}

fn matchLength(input: []const u8, position: usize, distance: usize, limit: usize) usize {
    var length: usize = 0;
    while (length < limit and input[position + length] == input[position + length - distance])
        length += 1;
    return length;
}

const Slot = struct {
    slot: usize,
    extra: usize,
    extra_bits: u8,
};

fn freshLengthSlot(length: usize) Error!Slot {
    if (length < 3) return error.InvalidRar29EncodeOptions;
    return lengthSlot(length - 3);
}

fn repeatLengthSlot(length: usize) Error!Slot {
    if (length < 2) return error.InvalidRar29EncodeOptions;
    return lengthSlot(length - 2);
}

fn lengthSlot(value: usize) Error!Slot {
    for (length_bases, length_bits, 0..) |base, bits, slot| {
        const limit = base + ((@as(usize, 1) << @intCast(bits)) - 1);
        if (value >= base and value <= limit) return .{
            .slot = slot,
            .extra = value - base,
            .extra_bits = bits,
        };
    }
    return error.InvalidRar29EncodeOptions;
}

fn distanceSlot(distance: usize) Error!Slot {
    if (distance == 0) return error.InvalidRar29EncodeOptions;
    const value = distance - 1;
    for (distance_bases, distance_bits, 0..) |base, bits, slot| {
        const limit = base + ((@as(usize, 1) << @intCast(bits)) - 1);
        if (value >= base and value <= limit) return .{
            .slot = slot,
            .extra = value - base,
            .extra_bits = bits,
        };
    }
    return error.InvalidRar29EncodeOptions;
}

fn matchLengthBonus(distance: usize) usize {
    return @as(usize, @intFromBool(distance >= 0x2000)) +
        @as(usize, @intFromBool(distance >= 0x40000));
}

fn fixedLevelLengths() [level_count]u8 {
    var lengths: [level_count]u8 = undefined;
    @memset(lengths[0..12], 4);
    @memset(lengths[12..], 5);
    return lengths;
}

fn fixedTableLengths() [table_count]u8 {
    var lengths: [table_count]u8 = undefined;
    var start: usize = 0;
    @memset(lengths[start .. start + 213], 8);
    start += 213;
    @memset(lengths[start .. start + 86], 9);
    start += 86;
    @memset(lengths[start .. start + 4], 5);
    start += 4;
    @memset(lengths[start .. start + 56], 6);
    start += 56;
    @memset(lengths[start .. start + 15], 4);
    start += 15;
    @memset(lengths[start .. start + 2], 5);
    start += 2;
    @memset(lengths[start .. start + 4], 4);
    start += 4;
    @memset(lengths[start..], 5);
    return lengths;
}

fn writeTableRuns(
    writer: *BitWriter,
    level_codes: *const Codes(level_count),
    lengths: []const u8,
) Error!void {
    var position: usize = 0;
    while (position < lengths.len) {
        const value = lengths[position];
        var run: usize = 1;
        while (position + run < lengths.len and lengths[position + run] == value)
            run += 1;
        try writer.writeCode(level_codes, value);
        var remaining = run - 1;
        while (remaining >= 11) {
            var count = @min(remaining, 138);
            if ((remaining - count == 1 or remaining - count == 2) and count >= 14)
                count -= 3;
            try writer.writeCode(level_codes, 17);
            try writer.writeBits(count - 11, 7);
            remaining -= count;
        }
        while (remaining >= 3) {
            const count = @min(remaining, 10);
            try writer.writeCode(level_codes, 16);
            try writer.writeBits(count - 3, 3);
            remaining -= count;
        }
        while (remaining != 0) : (remaining -= 1)
            try writer.writeCode(level_codes, value);
        position += run;
    }
}

fn Codes(comptime count: usize) type {
    return struct {
        codes: [count]u16,
        lengths: [count]u8,

        const Self = @This();

        fn init(raw_lengths: []const u8) Error!Self {
            if (raw_lengths.len != count) return error.InvalidRar29EncodeOptions;
            var counts: [16]u16 = @splat(0);
            for (raw_lengths) |length| {
                if (length > 15) return error.InvalidRar29EncodeOptions;
                if (length != 0) counts[length] += 1;
            }
            var available: i32 = 1;
            for (counts[1..]) |symbol_count| {
                available = (available << 1) - symbol_count;
                if (available < 0) return error.InvalidRar29EncodeOptions;
            }
            var next: [16]u16 = @splat(0);
            var code: u16 = 0;
            for (1..16) |length| {
                code = (code + counts[length - 1]) << 1;
                next[length] = code;
            }
            var result = Self{ .codes = @splat(0), .lengths = undefined };
            @memcpy(&result.lengths, raw_lengths);
            for (raw_lengths, 0..) |length, symbol| {
                if (length == 0) continue;
                result.codes[symbol] = next[length];
                next[length] += 1;
            }
            return result;
        }
    };
}

const BitWriter = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,
    bit_offset: usize = 0,

    fn writeCode(self: *BitWriter, codes: anytype, symbol: usize) Error!void {
        if (symbol >= codes.lengths.len or codes.lengths[symbol] == 0)
            return error.InvalidRar29EncodeOptions;
        try self.writeBits(codes.codes[symbol], codes.lengths[symbol]);
    }

    fn writeBits(self: *BitWriter, raw_value: anytype, raw_count: anytype) Error!void {
        const count: usize = @intCast(raw_count);
        if (count == 0) return;
        const value: u64 = @intCast(raw_value);
        var index = count;
        while (index != 0) {
            index -= 1;
            if (self.bit_offset % 8 == 0) try self.bytes.append(self.allocator, 0);
            if (value & (@as(u64, 1) << @intCast(index)) != 0)
                self.bytes.items[self.bytes.items.len - 1] |=
                    @as(u8, 1) << @intCast(7 - self.bit_offset % 8);
            self.bit_offset += 1;
        }
    }
};

test "RAR29 encoder round trips literals matches repeats and multiple blocks" {
    const decoder = @import("rar29.zig");
    const allocator = std.testing.allocator;
    var random_data: [4097]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x7261723239);
    random.fill(&random_data);
    const inputs = [_][]const u8{
        "",
        "a",
        "rar29 repeated phrase alpha beta gamma\n" ** 1024,
        &random_data,
    };
    for (inputs) |input| {
        const encoded = try encodeAlloc(allocator, input, .{ .block_size = 257 });
        defer allocator.free(encoded);
        const decoded = try decoder.decodeAlloc(allocator, encoded, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        try std.testing.expectEqual(decoder.InitialMode.lz, try decoder.initialMode(encoded));
    }
}

test "RAR29 solid encoder and decoder reuse cross-member history" {
    const decoder = @import("rar29.zig");
    const allocator = std.testing.allocator;
    const first = try allocator.alloc(u8, 64 * 1024);
    defer allocator.free(first);
    var random = std.Random.DefaultPrng.init(0x736f6c69645f3239);
    random.fill(first);
    const second = first[16 * 1024 .. 48 * 1024];
    const options = Options{ .dictionary_size = 128 * 1024, .block_size = 4096 };

    const independent = try encodeAlloc(allocator, second, options);
    defer allocator.free(independent);
    var encoder = Encoder.init(allocator, options);
    defer encoder.deinit();
    const first_packed = try encoder.encodeMemberAlloc(first, false);
    defer allocator.free(first_packed);
    const second_packed = try encoder.encodeMemberAlloc(second, true);
    defer allocator.free(second_packed);
    try std.testing.expect(second_packed.len < independent.len);

    var session = decoder.Session.init(allocator, .{});
    defer session.deinit();
    const first_decoded = try allocator.alloc(u8, first.len);
    defer allocator.free(first_decoded);
    try session.decodeMemberInto(first_packed, first_decoded, options.dictionary_size, false);
    try std.testing.expectEqualSlices(u8, first, first_decoded);
    const second_decoded = try allocator.alloc(u8, second.len);
    defer allocator.free(second_decoded);
    try session.decodeMemberInto(second_packed, second_decoded, options.dictionary_size, true);
    try std.testing.expectEqualSlices(u8, second, second_decoded);

    var missing = decoder.Session.init(allocator, .{});
    defer missing.deinit();
    try std.testing.expectError(
        error.MissingRar29SolidState,
        missing.decodeMemberInto(second_packed, second_decoded, options.dictionary_size, true),
    );
}

test "RAR29 encoder round trips all six standard VM filters across blocks" {
    const decoder = @import("rar29.zig");
    const allocator = std.testing.allocator;
    var input: [8192]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @truncate(index *% 37 +% index / 11);
    input[16] = 0xe8;
    std.mem.writeInt(u32, input[17..21], 0x1000, .little);
    input[32] = 0xe9;
    std.mem.writeInt(u32, input[33..37], 0x2000, .little);
    const filters = [_]Filter{
        .{ .delta = 4 },
        .e8,
        .e8e9,
        .itanium,
        .{ .rgb = .{ .width = 12, .red_position = 1 } },
        .{ .audio = 2 },
    };
    for (filters) |filter| {
        var encoder = Encoder.init(allocator, .{ .block_size = 1024 });
        defer encoder.deinit();
        const encoded = try encoder.encodeFilteredMemberAlloc(&input, filter, false);
        defer allocator.free(encoded);
        var output: [input.len]u8 = undefined;
        try decoder.decodeIntoWithOptions(allocator, encoded, &output, .{});
        try std.testing.expectEqualSlices(u8, &input, &output);
    }

    var invalid = Encoder.init(allocator, .{});
    defer invalid.deinit();
    try std.testing.expectError(
        error.InvalidRar29FilterOptions,
        invalid.encodeFilteredMemberAlloc(&input, .{ .delta = 0 }, false),
    );
    try std.testing.expectError(
        error.InvalidRar29FilterOptions,
        invalid.encodeFilteredMemberAlloc(&input, .{ .rgb = .{ .width = 10 } }, false),
    );
    try std.testing.expectError(
        error.MissingRar29SolidEncoderState,
        invalid.encodeFilteredMemberAlloc(&input, .e8, true),
    );
    try std.testing.expectError(
        error.InvalidRar29FilterOptions,
        invalid.encodeFilteredMemberAlloc("", .e8, false),
    );
}

test "RAR29 encoder validates dictionary and block sizes" {
    try std.testing.expectError(
        error.InvalidRar29EncodeOptions,
        encodeAlloc(std.testing.allocator, "payload", .{ .dictionary_size = 96 * 1024 }),
    );
    try std.testing.expectError(
        error.InvalidRar29EncodeOptions,
        encodeAlloc(std.testing.allocator, "payload", .{ .block_size = 0 }),
    );
}

test "RAR29 encoder output reports truncated and malformed streams" {
    const decoder = @import("rar29.zig");
    const allocator = std.testing.allocator;
    const input = "RAR29 truncation boundary payload" ** 32;
    const encoded = try encodeAlloc(allocator, input, .{ .block_size = 127 });
    defer allocator.free(encoded);
    const output = try allocator.alloc(u8, input.len);
    defer allocator.free(output);
    try std.testing.expectError(
        error.TruncatedFrame,
        decoder.decodeInto(encoded[0 .. encoded.len - 1], output),
    );

    const malformed = try allocator.dupe(u8, encoded);
    defer allocator.free(malformed);
    malformed[0] |= 0x80;
    try std.testing.expectError(error.UnsupportedRar29Ppmd, decoder.decodeInto(malformed, output));
}
