const std = @import("std");
const tables = @import("tables.zig");
const model = @import("model.zig");
const stream = @import("bit_stream.zig");
const arithmetic = @import("arithmetic.zig");
const items_mod = @import("item_stream.zig");

pub const Item = items_mod.Item;
pub const Summary = items_mod.Summary;
const Field = struct { offset: usize, value: u32, bits: u5 };
pub const Frame = struct { bytes: []u8, models: model.State, summary: Summary, input_len: usize };

/// Encode the arithmetic-only tape, replay exact symbol decisions to locate
/// extra fields beyond the 16-bit arithmetic lookahead, then interleave them.
/// A second replay validates the final wire and computes full-frame padding.
pub fn encode(allocator: std.mem.Allocator, items: []const Item, history_len: usize, window_bits: u5, initial: model.State) !Frame {
    const validated = try items_mod.validate(items, history_len, window_bits);
    var models = initial;
    var tape = stream.Writer{};
    defer tape.bytes.deinit(allocator);
    var encoder = arithmetic.Encoder{ .writer = &tape };
    encoder.startFrame();
    var iterator = items_mod.Iterator{ .items = items, .window_bits = window_bits };
    while (try iterator.next()) |token| try encoder.encodeSymbol(allocator, &models[token.alphabet], token.symbol);
    try encoder.finishFrame(allocator);
    try tape.alignToByte(allocator);
    try tape.bytes.appendNTimes(allocator, 0, 4);

    var fields: std.ArrayList(Field) = .empty;
    defer fields.deinit(allocator);
    var replay_models = initial;
    var replay = arithmetic.Decoder{ .reader = .{ .input = tape.bytes.items } };
    try replay.startFrame();
    iterator = .{ .items = items, .window_bits = window_bits };
    while (try iterator.next()) |token| {
        if (try replay.decodeSymbol(&replay_models[token.alphabet]) != token.symbol) return error.InvalidQuantumStream;
        if (token.bits != 0) try fields.append(allocator, .{
            .offset = replay.reader.byte_offset * 8 + replay.reader.bit_offset,
            .value = token.extra,
            .bits = token.bits,
        });
    }

    var stitched = stream.Writer{};
    defer stitched.bytes.deinit(allocator);
    if (fields.items.len != 0) {
        var field_index: usize = 0;
        for (0..tape.bytes.items.len * 8) |bit| {
            while (field_index < fields.items.len and fields.items[field_index].offset == bit) : (field_index += 1) {
                const field = fields.items[field_index];
                try stitched.writeBits(allocator, field.value, field.bits);
            }
            try stitched.writeBit(allocator, @truncate(tape.bytes.items[bit / 8] >> @intCast(7 - bit % 8)));
        }
        if (field_index != fields.items.len) return error.InvalidQuantumStream;
        try stitched.alignToByte(allocator);
    } else std.mem.swap(std.ArrayList(u8), &stitched.bytes, &tape.bytes);

    replay_models = initial;
    replay = .{ .reader = .{ .input = stitched.bytes.items } };
    try replay.startFrame();
    iterator = .{ .items = items, .window_bits = window_bits };
    while (try iterator.next()) |token| {
        if (try replay.decodeSymbol(&replay_models[token.alphabet]) != token.symbol or
            try replay.reader.readBits(token.bits) != token.extra) return error.InvalidQuantumStream;
    }
    if (validated.length == tables.frame_size) {
        replay.reader.alignToByte();
        if (replay.reader.byte_offset > stitched.bytes.items.len) return error.InvalidQuantumStream;
        stitched.bytes.shrinkRetainingCapacity(replay.reader.byte_offset);
        try stitched.bytes.appendNTimes(allocator, 0, 4);
    }
    return .{ .bytes = try stitched.bytes.toOwnedSlice(allocator), .models = models, .summary = validated.summary, .input_len = validated.length };
}

/// Caller-owned adaptive state for already-planned frame items. Non-final
/// frames are exactly 32 KiB; failures leave all model/progress state intact.
pub const Encoder = struct {
    window_bits: u5,
    models: model.State,
    input_read: usize = 0,

    pub fn init(window_bits: u5) !Encoder {
        if (window_bits < tables.min_window_bits or window_bits > tables.max_window_bits) return error.InvalidBlockPlan;
        return .{ .window_bits = window_bits, .models = model.initialState(window_bits) };
    }
    pub fn encodeFrameAlloc(self: *Encoder, allocator: std.mem.Allocator, items: []const Item) !Frame {
        const result = try encode(allocator, items, self.input_read, self.window_bits, self.models);
        const total = std.math.add(usize, self.input_read, result.input_len) catch {
            allocator.free(result.bytes);
            return error.IntegerOverflow;
        };
        self.models = result.models;
        self.input_read = total;
        return result;
    }
};
