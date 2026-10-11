const std = @import("std");
const core = @import("../core.zig");
const adaptive = @import("adaptive_huffman.zig");
const tables = @import("tables.zig");
const x86 = @import("x86.zig");

pub const Error = core.Error || adaptive.Error || std.mem.Allocator.Error || error{
    InvalidLzms,
};

const probability_bits = 6;
const probability_denominator = 1 << probability_bits;
const initial_probability = 48;
const initial_recent_bits: u64 = 0x0000_0000_5555_5555;

const ProbabilityEntry = struct {
    zero_count: u32 = initial_probability,
    recent_bits: u64 = initial_recent_bits,

    fn probability(self: ProbabilityEntry) u32 {
        return if (self.zero_count == 0)
            1
        else if (self.zero_count == probability_denominator)
            probability_denominator - 1
        else
            self.zero_count;
    }

    fn update(self: *ProbabilityEntry, bit: u1) void {
        const oldest: u1 = @truncate(self.recent_bits >> 63);
        if (oldest > bit) {
            self.zero_count += 1;
        } else if (oldest < bit) {
            self.zero_count -= 1;
        }
        self.recent_bits = (self.recent_bits << 1) | bit;
    }
};

const Probabilities = struct {
    main: [16]ProbabilityEntry,
    match: [32]ProbabilityEntry,
    lz: [64]ProbabilityEntry,
    delta: [64]ProbabilityEntry,
    lz_rep: [2][64]ProbabilityEntry,
    delta_rep: [2][64]ProbabilityEntry,

    fn init() Probabilities {
        const entry = ProbabilityEntry{};
        return .{
            .main = @splat(entry),
            .match = @splat(entry),
            .lz = @splat(entry),
            .delta = @splat(entry),
            .lz_rep = @splat(@splat(entry)),
            .delta_rep = @splat(@splat(entry)),
        };
    }
};

const RangeDecoder = struct {
    input: []const u8,
    range: u32 = std.math.maxInt(u32),
    code: u32,
    next: usize = 4,

    fn init(input: []const u8) RangeDecoder {
        return .{
            .input = input,
            .code = (@as(u32, readU16(input, 0)) << 16) | readU16(input, 2),
        };
    }

    fn decodeBit(
        self: *RangeDecoder,
        state: *u32,
        probabilities: []ProbabilityEntry,
    ) u1 {
        const entry = &probabilities[state.*];
        state.* = (state.* << 1) & @as(u32, @intCast(probabilities.len - 1));
        if (self.range & 0xffff_0000 == 0) {
            self.range <<= 16;
            self.code <<= 16;
            if (self.next < self.input.len) {
                self.code |= readU16(self.input, self.next);
                self.next += 2;
            }
        }
        const bound = (self.range >> probability_bits) * entry.probability();
        if (self.code < bound) {
            self.range = bound;
            entry.update(0);
            return 0;
        }
        self.range -= bound;
        self.code -= bound;
        entry.update(1);
        state.* |= 1;
        return 1;
    }
};

const BackwardBitReader = struct {
    input: []const u8,
    next: usize,
    word: u16 = 0,
    bits_left: u5 = 0,

    fn init(input: []const u8) BackwardBitReader {
        return .{ .input = input, .next = input.len };
    }

    pub fn readBits(
        self: *BackwardBitReader,
        comptime T: type,
        count: u6,
    ) core.Error!T {
        if (count > @bitSizeOf(T) or count > 30) return error.CorruptFrame;
        var result: T = 0;
        var remaining: u6 = count;
        while (remaining != 0) {
            if (self.bits_left == 0) {
                if (self.next >= 2) {
                    self.next -= 2;
                    self.word = readU16(self.input, self.next);
                } else {
                    self.word = 0;
                }
                self.bits_left = 16;
            }
            const take: u5 = @intCast(@min(remaining, self.bits_left));
            const shift: u4 = @intCast(self.bits_left - take);
            const mask: u16 = if (take == 16)
                std.math.maxInt(u16)
            else
                (@as(u16, 1) << @intCast(take)) - 1;
            const part = (self.word >> shift) & mask;
            result = (result << @intCast(take)) | @as(T, @intCast(part));
            self.bits_left -= take;
            remaining -= take;
        }
        return result;
    }
};

const State = struct {
    probabilities: Probabilities,
    literal: adaptive.AdaptiveCode(256),
    lz_offset: adaptive.AdaptiveCode(tables.max_offset_symbols),
    length: adaptive.AdaptiveCode(54),
    delta_offset: adaptive.AdaptiveCode(tables.max_offset_symbols),
    delta_power: adaptive.AdaptiveCode(8),
    x86_targets: [65_536]i32,

    fn reset(self: *State, output_len: usize) Error!void {
        const offset_symbols = tables.numOffsetSlots(output_len);
        self.probabilities = Probabilities.init();
        self.literal = try adaptive.AdaptiveCode(256).init(256, 1024);
        self.lz_offset = try adaptive.AdaptiveCode(tables.max_offset_symbols).init(
            offset_symbols,
            1024,
        );
        self.length = try adaptive.AdaptiveCode(54).init(54, 512);
        self.delta_offset = try adaptive.AdaptiveCode(tables.max_offset_symbols).init(
            offset_symbols,
            1024,
        );
        self.delta_power = try adaptive.AdaptiveCode(8).init(8, 512);
    }
};

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    state: *State,

    pub fn init(allocator: std.mem.Allocator) Error!Decoder {
        return .{
            .allocator = allocator,
            .state = try allocator.create(State),
        };
    }

    pub fn deinit(self: *Decoder) void {
        self.allocator.destroy(self.state);
        self.* = undefined;
    }

    pub fn decodeInto(
        self: *Decoder,
        input: []const u8,
        output: []u8,
    ) Error!void {
        if (output.len > tables.max_buffer_size) return error.OutputLimitExceeded;
        if (output.len == 0) {
            if (input.len != 0) return error.InvalidLzms;
            return;
        }
        if (input.len < 4 or input.len & 1 != 0) return error.InvalidLzms;
        try self.state.reset(output.len);

        var range = RangeDecoder.init(input);
        var bits = BackwardBitReader.init(input);
        var recent_lz_offsets = [4]u32{ 1, 2, 3, 4 };
        var recent_delta_pairs = [4]u64{ 1, 2, 3, 4 };
        var previous_item_type: u2 = 0;
        var main_state: u32 = 0;
        var match_state: u32 = 0;
        var lz_state: u32 = 0;
        var delta_state: u32 = 0;
        var lz_rep_states = [2]u32{ 0, 0 };
        var delta_rep_states = [2]u32{ 0, 0 };
        var output_position: usize = 0;

        while (output_position < output.len) {
            if (range.decodeBit(
                &main_state,
                &self.state.probabilities.main,
            ) == 0) {
                output[output_position] = @intCast(try self.state.literal.decode(&bits));
                output_position += 1;
                previous_item_type = 0;
                continue;
            }

            if (range.decodeBit(
                &match_state,
                &self.state.probabilities.match,
            ) == 0) {
                const offset = try decodeLzOffset(
                    self.state,
                    &range,
                    &bits,
                    &lz_state,
                    &lz_rep_states,
                    &recent_lz_offsets,
                    previous_item_type,
                );
                recent_lz_offsets[0] = offset;
                previous_item_type = 1;
                const length = try decodeLength(self.state, &bits);
                try copyLz(output, &output_position, offset, length);
            } else {
                const pair = try decodeDeltaPair(
                    self.state,
                    &range,
                    &bits,
                    &delta_state,
                    &delta_rep_states,
                    &recent_delta_pairs,
                    previous_item_type,
                );
                recent_delta_pairs[0] = pair;
                previous_item_type = 2;
                const length = try decodeLength(self.state, &bits);
                try copyDelta(output, &output_position, pair, length);
            }
        }
        x86.undo(output, &self.state.x86_targets);
    }
};

fn decodeLzOffset(
    state: *State,
    range: *RangeDecoder,
    bits: *BackwardBitReader,
    lz_state: *u32,
    repeat_states: *[2]u32,
    recent: *[4]u32,
    previous_item_type: u2,
) Error!u32 {
    if (range.decodeBit(lz_state, &state.probabilities.lz) == 0) {
        const slot = try state.lz_offset.decode(bits);
        recent[3] = recent[2];
        recent[2] = recent[1];
        recent[1] = recent[0];
        return tables.offset_slot_base[slot] +
            try bits.readBits(u32, @intCast(tables.extra_offset_bits[slot]));
    }
    const delayed: usize = previous_item_type & 1;
    if (range.decodeBit(&repeat_states[0], &state.probabilities.lz_rep[0]) == 0) {
        const index = delayed;
        const offset = recent[index];
        recent[index] = recent[0];
        return offset;
    }
    if (range.decodeBit(&repeat_states[1], &state.probabilities.lz_rep[1]) == 0) {
        const index = 1 + delayed;
        const offset = recent[index];
        recent[index] = recent[1];
        recent[1] = recent[0];
        return offset;
    }
    const index = 2 + delayed;
    const offset = recent[index];
    recent[index] = recent[2];
    recent[2] = recent[1];
    recent[1] = recent[0];
    return offset;
}

fn decodeLength(state: *State, bits: *BackwardBitReader) Error!u32 {
    const slot = try state.length.decode(bits);
    var length = tables.length_slot_base[slot];
    const extra = tables.extra_length_bits[slot];
    if (extra != 0) length += try bits.readBits(u32, @intCast(extra));
    return length;
}

fn decodeDeltaPair(
    state: *State,
    range: *RangeDecoder,
    bits: *BackwardBitReader,
    delta_state: *u32,
    repeat_states: *[2]u32,
    recent: *[4]u64,
    previous_item_type: u2,
) Error!u64 {
    if (range.decodeBit(delta_state, &state.probabilities.delta) == 0) {
        const power = try state.delta_power.decode(bits);
        const slot = try state.delta_offset.decode(bits);
        const raw_offset = tables.offset_slot_base[slot] +
            try bits.readBits(u32, @intCast(tables.extra_offset_bits[slot]));
        recent[3] = recent[2];
        recent[2] = recent[1];
        recent[1] = recent[0];
        return (@as(u64, power) << 32) | raw_offset;
    }
    const delayed: usize = previous_item_type >> 1;
    if (range.decodeBit(&repeat_states[0], &state.probabilities.delta_rep[0]) == 0) {
        const index = delayed;
        const pair = recent[index];
        recent[index] = recent[0];
        return pair;
    }
    if (range.decodeBit(&repeat_states[1], &state.probabilities.delta_rep[1]) == 0) {
        const index = 1 + delayed;
        const pair = recent[index];
        recent[index] = recent[1];
        recent[1] = recent[0];
        return pair;
    }
    const index = 2 + delayed;
    const pair = recent[index];
    recent[index] = recent[2];
    recent[2] = recent[1];
    recent[1] = recent[0];
    return pair;
}

fn copyLz(
    output: []u8,
    position: *usize,
    offset_u32: u32,
    length_u32: u32,
) Error!void {
    const offset: usize = offset_u32;
    const length: usize = length_u32;
    if (offset == 0 or offset > position.* or length > output.len - position.*)
        return error.InvalidLzms;
    for (0..length) |_| {
        output[position.*] = output[position.* - offset];
        position.* += 1;
    }
}

fn copyDelta(
    output: []u8,
    position: *usize,
    pair: u64,
    length_u32: u32,
) Error!void {
    const power: u6 = @intCast(pair >> 32);
    if (power > 7) return error.InvalidLzms;
    const raw_offset: u32 = @truncate(pair);
    const span: usize = @as(usize, 1) << power;
    const offset = std.math.mul(usize, raw_offset, span) catch
        return error.InvalidLzms;
    const length: usize = length_u32;
    const source_span = std.math.add(usize, offset, span) catch
        return error.InvalidLzms;
    if (raw_offset == 0 or source_span > position.* or
        length > output.len - position.*)
        return error.InvalidLzms;
    for (0..length) |_| {
        const match_position = position.* - offset;
        output[position.*] = output[match_position] +%
            output[position.* - span] -% output[match_position - span];
        position.* += 1;
    }
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

pub fn decodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
) Error!void {
    var decoder = try Decoder.init(allocator);
    defer decoder.deinit();
    return decoder.decodeInto(input, output);
}

pub fn decodeAllocExactSize(
    allocator: std.mem.Allocator,
    input: []const u8,
    decoded_size: usize,
) Error![]u8 {
    if (decoded_size > tables.max_buffer_size) return error.OutputLimitExceeded;
    const output = try allocator.alloc(u8, decoded_size);
    errdefer allocator.free(output);
    try decodeInto(allocator, input, output);
    return output;
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    decoded_size: usize,
    max_output_len: usize,
) Error![]u8 {
    if (decoded_size > max_output_len) return error.OutputLimitExceeded;
    return decodeAllocExactSize(allocator, input, decoded_size);
}
