const std = @import("std");
const core = @import("../../core.zig");
const tables = @import("tables.zig");
const tree = @import("encode_tree.zig");
const plan_mod = @import("block_plan.zig");
const words = @import("word_writer.zig");
const reference = @import("reference_encoder.zig");

pub const Error = core.Error || std.mem.Allocator.Error;
pub const encodeUncompressedBlockAlloc = reference.encodeUncompressedBlockAlloc;
pub const encodeWimReferenceChunkAlloc = reference.encodeWimChunkAlloc;
pub const BlockType = enum(u3) { verbatim = 1, aligned = 2, uncompressed = 3 };
pub const Summary = struct {
    block_type: BlockType,
    matched_bytes: usize = 0,
    repeat_matches: usize = 0,
    max_offset: usize = 0,
};
pub const EncodedBlock = struct {
    bytes: []u8,
    summary: Summary,
    pub fn deinit(self: *EncodedBlock, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

const Codes = struct {
    main: tree.Code(plan_mod.main_symbols),
    length: tree.Code(plan_mod.length_symbols),
    aligned: tree.Code(8),
    fn init(plan: *const plan_mod.Plan) Codes {
        return .{
            .main = tree.Code(plan_mod.main_symbols).init(plan.main_frequencies, 15),
            .length = tree.Code(plan_mod.length_symbols).init(plan.length_frequencies, 15),
            .aligned = tree.Code(8).init(plan.aligned_frequencies, 7),
        };
    }
};

/// Caller-owned CAB folder state. Allocation failure leaves recent offsets,
/// previous trees and the one-time header state unchanged. Input history is
/// borrowed for each call; only the selected-window suffix is indexed.
pub const CabinetEncoder = struct {
    window_bits: u5,
    started: bool = false,
    input_read: usize = 0,
    reps: [3]u32 = .{ 1, 1, 1 },
    main_lengths: [plan_mod.main_symbols]u5 = @splat(0),
    length_lengths: [plan_mod.length_symbols]u5 = @splat(0),

    pub fn init(window_bits: u5) Error!CabinetEncoder {
        try validateWindow(window_bits);
        return .{ .window_bits = window_bits };
    }

    pub fn encodeBlockAlloc(self: *CabinetEncoder, allocator: std.mem.Allocator, input: []const u8, start: usize, end: usize) Error![]u8 {
        return (try self.encodeBlockWithSummaryAlloc(allocator, input, start, end)).bytes;
    }

    pub fn encodeBlockWithSummaryAlloc(self: *CabinetEncoder, allocator: std.mem.Allocator, input: []const u8, start: usize, end: usize) Error!EncodedBlock {
        if (start != self.input_read or (self.started and self.input_read % 32768 != 0)) return error.InvalidBlockPlan;
        var plan = try plan_mod.Plan.init(allocator, input, start, end, self.window_bits, self.reps);
        defer plan.deinit(allocator);
        const codes = Codes.init(&plan);
        const raw = try self.rawAlloc(allocator, input[start..end]);
        errdefer allocator.free(raw);
        const preferred = preferAligned(&plan, &codes);
        var writer = words.Writer{};
        defer writer.bytes.deinit(allocator);
        if (!self.started) try writer.writeBits(allocator, 0, 1);
        try writeBlock(allocator, &writer, self, &plan, &codes, end - start, preferred, false);
        try writer.finish(allocator);
        var result: EncodedBlock = .{ .bytes = raw, .summary = .{ .block_type = .uncompressed } };
        if (writer.bytes.items.len < raw.len) {
            const selected = try writer.bytes.toOwnedSlice(allocator);
            allocator.free(raw);
            result = .{
                .bytes = selected,
                .summary = .{ .block_type = preferred, .matched_bytes = plan.matched_bytes, .repeat_matches = plan.repeat_matches, .max_offset = plan.max_offset },
            };
            self.commit(&plan, &codes);
        }
        self.started = true;
        self.input_read = end;
        return result;
    }

    fn commit(self: *CabinetEncoder, plan: *const plan_mod.Plan, codes: *const Codes) void {
        self.reps = plan.reps;
        self.main_lengths = codes.main.lengths;
        self.length_lengths = codes.length.lengths;
    }

    fn rawAlloc(self: *const CabinetEncoder, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        var writer = words.Writer{};
        errdefer writer.bytes.deinit(allocator);
        if (!self.started) try writer.writeBits(allocator, 0, 1);
        try writer.writeBits(allocator, @intFromEnum(BlockType.uncompressed), 3);
        try writer.writeBits(allocator, input.len >> 8, 16);
        try writer.writeBits(allocator, input.len & 255, 8);
        try writer.alignForUncompressed(allocator);
        for (self.reps) |offset| try words.appendU32(allocator, &writer.bytes, offset);
        try writer.bytes.appendSlice(allocator, input);
        if (input.len & 1 != 0) try writer.bytes.append(allocator, 0);
        return writer.bytes.toOwnedSlice(allocator);
    }
};

fn preferAligned(plan: *const plan_mod.Plan, codes: *const Codes) BlockType {
    var verbatim_cost: usize = 0;
    var aligned_cost: usize = 24;
    for (plan.aligned_frequencies, codes.aligned.lengths) |freq, bits| {
        verbatim_cost += @as(usize, freq) * 3;
        aligned_cost += @as(usize, freq) * bits;
    }
    return if (aligned_cost < verbatim_cost) .aligned else .verbatim;
}

fn writeBlock(allocator: std.mem.Allocator, writer: *words.Writer, state: *const CabinetEncoder, plan: *const plan_mod.Plan, codes: *const Codes, input_len: usize, block_type: BlockType, wim: bool) !void {
    try writer.writeBits(allocator, @intFromEnum(block_type), 3);
    if (wim) {
        try writer.writeBits(allocator, @intFromBool(input_len == 32768), 1);
        if (input_len != 32768) {
            if (state.window_bits >= 16) try writer.writeBits(allocator, input_len >> 16, 8);
            try writer.writeBits(allocator, input_len & 65535, 16);
        }
    } else {
        try writer.writeBits(allocator, input_len >> 8, 16);
        try writer.writeBits(allocator, input_len & 255, 8);
    }
    if (block_type == .aligned) for (codes.aligned.lengths) |bits| try writer.writeBits(allocator, bits, 3);
    const symbols = 256 + tables.positionSlotCount(state.window_bits) * 8;
    try tree.writeLengths(allocator, writer, state.main_lengths[0..256], codes.main.lengths[0..256]);
    try tree.writeLengths(allocator, writer, state.main_lengths[256..symbols], codes.main.lengths[256..symbols]);
    try tree.writeLengths(allocator, writer, &state.length_lengths, &codes.length.lengths);
    for (plan.items.items) |item| {
        try codes.main.write(allocator, writer, item.mainSymbol());
        if (item.len == 1) continue;
        if (item.len >= 9) try codes.length.write(allocator, writer, item.len - 9);
        const extra_bits = tables.positionExtraBits(item.slot);
        if (block_type == .aligned and extra_bits >= 3) {
            try writer.writeBits(allocator, item.extra >> 3, @intCast(extra_bits - 3));
            try codes.aligned.write(allocator, writer, item.extra & 7);
        } else try writer.writeBits(allocator, item.extra, @intCast(extra_bits));
    }
}

/// WIM uses continuous bit-packed blocks and mandatory whole-chunk E8
/// preprocessing. Each plan is limited to 32 KiB; history and trees persist
/// through a chunk of up to the selected 2 MiB window. The retained short-match
/// reference is selected if its complete wire is smaller.
pub fn encodeWimChunkAlloc(allocator: std.mem.Allocator, input: []const u8, window_bits: u5) Error![]u8 {
    var state = try CabinetEncoder.init(window_bits);
    if (input.len == 0 or input.len > @as(usize, 1) << window_bits) return error.InvalidBlockPlan;
    const transformed = try allocator.dupe(u8, input);
    defer allocator.free(transformed);
    reference.preprocessWimE8(transformed);
    var writer = words.Writer{};
    defer writer.bytes.deinit(allocator);
    var start: usize = 0;
    while (start < input.len) {
        const end = start + @min(input.len - start, 32768);
        var plan = try plan_mod.Plan.init(allocator, transformed, start, end, window_bits, state.reps);
        defer plan.deinit(allocator);
        const codes = Codes.init(&plan);
        try writeBlock(allocator, &writer, &state, &plan, &codes, end - start, preferAligned(&plan, &codes), true);
        state.commit(&plan, &codes);
        start = end;
    }
    try writer.finish(allocator);
    const fallback = try reference.encodeWimChunkAlloc(allocator, input, window_bits);
    errdefer allocator.free(fallback);
    if (writer.bytes.items.len >= fallback.len) return fallback;
    const selected = try writer.bytes.toOwnedSlice(allocator);
    allocator.free(fallback);
    return selected;
}

fn validateWindow(window_bits: u5) Error!void {
    if (window_bits < tables.min_window_bits or window_bits > tables.max_window_bits) return error.InvalidBlockPlan;
}

test {
    _ = reference;
    _ = @import("encoder_tests.zig");
}
