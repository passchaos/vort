//! Borrowed preparation for a single immutable command/input group. Only active
//! literal trees are copied, and readiness is published after exact counting.
const std = @import("std");
const core = @import("../../core.zig");
const bit_count = @import("../../io/bit_count.zig");
const command_plan = @import("command_plan.zig");
const context = @import("literal_context_split.zig");

pub const max_trees = context.max_trees;
pub const Alphabet = command_plan.PrefixAlphabetFor(256);
pub const Key = struct {
    input_ptr: [*]const u8,
    input_len: usize,
    initial_previous: [2]u8,
    raw_context: ?context.Candidate,
    utf8: bool,
    cutoff: u6,
    mode: u2,
    optimize_wire: bool,

    pub fn init(input: []const u8, options: anytype) Key {
        return .{ .input_ptr = input.ptr, .input_len = input.len, .initial_previous = options.initial_previous, .raw_context = options.literal_context_candidate, .utf8 = options.use_utf8_text_contexts, .cutoff = options.utf8_context_cutoff, .mode = options.literal_context_mode, .optimize_wire = options.optimize_literal_tree_wire };
    }
    pub fn matches(self: *const Key, input: []const u8, options: anytype) bool {
        const other = init(input, options);
        const contexts_match = if (self.raw_context) |a|
            if (other.raw_context) |b| context.Candidate.eql(a, b) else false
        else
            other.raw_context == null;
        return self.input_ptr == other.input_ptr and self.input_len == other.input_len and
            std.mem.eql(u8, &self.initial_previous, &other.initial_previous) and contexts_match and
            self.utf8 == other.utf8 and self.cutoff == other.cutoff and self.mode == other.mode and
            self.optimize_wire == other.optimize_wire;
    }
};

pub fn supported(options: anytype) bool {
    return options.write_stream_prefix and options.final_meta_block and options.metadata.len == 0;
}

pub const State = struct {
    alphabets: [max_trees]Alphabet = undefined,
    lengths: [max_trees][256]u4 = undefined,
    key: Key = undefined,
    normalized_context: ?context.Candidate = null,
    tree_count: usize = 0,
    header_bits: bit_count.BitCount = 0,
    payload_bits: bit_count.BitCount = 0,
    wire_len: usize = 0,
    ready: bool = false,

    pub fn capture(self: *State, input: []const u8, options: anytype, normalized_context: ?context.Candidate, alphabets: []const Alphabet, lengths: []const [256]u4, header_bits: bit_count.BitCount, payload_bits: bit_count.BitCount) core.Error!void {
        self.ready = false;
        if (!supported(options) or alphabets.len == 0 or alphabets.len > max_trees or alphabets.len != lengths.len)
            return error.InvalidBlockPlan;
        const total = std.math.add(bit_count.BitCount, header_bits, payload_bits) catch return error.IntegerOverflow;
        self.wire_len = try bit_count.ceilBytes(total);
        self.key = Key.init(input, options);
        self.normalized_context = normalized_context;
        self.tree_count = alphabets.len;
        self.header_bits = header_bits;
        self.payload_bits = payload_bits;
        for (alphabets, lengths, 0..) |*alphabet, *tree_lengths, index| {
            self.alphabets[index].len = alphabet.len;
            @memcpy(self.alphabets[index].symbols[0..alphabet.len], alphabet.symbols[0..alphabet.len]);
            self.lengths[index] = tree_lengths.*;
        }
        self.ready = true;
    }
    pub fn matches(self: *const State, input: []const u8, options: anytype) bool {
        return self.ready and supported(options) and self.key.matches(input, options);
    }
    pub fn copyFrom(self: *State, other: *const State) void {
        std.debug.assert(other.ready);
        self.ready = false;
        self.key = other.key;
        self.normalized_context = other.normalized_context;
        self.tree_count = other.tree_count;
        self.header_bits = other.header_bits;
        self.payload_bits = other.payload_bits;
        self.wire_len = other.wire_len;
        for (0..other.tree_count) |index| {
            self.alphabets[index].len = other.alphabets[index].len;
            @memcpy(self.alphabets[index].symbols[0..other.alphabets[index].len], other.alphabets[index].symbols[0..other.alphabets[index].len]);
            self.lengths[index] = other.lengths[index];
        }
        self.ready = true;
    }
};
