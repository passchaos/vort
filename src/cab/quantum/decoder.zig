const std = @import("std");
const tables = @import("tables.zig");
const frame_size = tables.frame_size;
const Model = @import("model.zig").Model;
const ArithmeticDecoder = @import("arithmetic.zig").Decoder;
const min_window_bits = tables.min_window_bits;
const max_window_bits = tables.max_window_bits;
const position_base = tables.position_base;
const position_extra = tables.position_extra;
const length_base = tables.length_base;
const length_extra = tables.length_extra;

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_output_len: usize,
    window_bits: u5,
) ![]u8 {
    if (window_bits < min_window_bits or window_bits > max_window_bits)
        return error.UnsupportedCabinetFeature;

    const output = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(output);
    if (output.len == 0) return output;

    try decodeInto(input, output, window_bits);
    return output;
}

/// Caller-owned exact-size output. Malformed streams may leave a decoded
/// prefix; the caller's output limit is enforced by the allocating facade.
pub fn decodeInto(input: []const u8, output: []u8, window_bits: u5) !void {
    if (window_bits < min_window_bits or window_bits > max_window_bits) return error.UnsupportedCabinetFeature;
    if (output.len == 0) return;
    var decoder = Decoder.init(input, output, window_bits);
    try decoder.decode();
    if (decoder.written != output.len) return error.SizeMismatch;
}

pub const Decoder = struct {
    arithmetic: ArithmeticDecoder,
    output: []u8,
    written: usize = 0,
    window_size: usize,
    literal_models: [4]Model,
    match3_model: Model,
    match4_model: Model,
    match_model: Model,
    length_model: Model,
    selector_model: Model,

    pub fn init(input: []const u8, output: []u8, window_bits: u5) Decoder {
        const position_entries: usize = @as(usize, window_bits) * 2;
        return .{
            .arithmetic = .{ .reader = .{ .input = input } },
            .output = output,
            .window_size = @as(usize, 1) << window_bits,
            .literal_models = .{
                Model.init(0, 64),
                Model.init(64, 64),
                Model.init(128, 64),
                Model.init(192, 64),
            },
            .match3_model = Model.init(0, @min(position_entries, 24)),
            .match4_model = Model.init(0, @min(position_entries, 36)),
            .match_model = Model.init(0, position_entries),
            .length_model = Model.init(0, 27),
            .selector_model = Model.init(0, 7),
        };
    }

    pub fn decode(self: *Decoder) !void {
        while (self.written < self.output.len) {
            try self.arithmetic.startFrame();
            const frame_start = self.written;
            const frame_end = @min(self.output.len, frame_start + frame_size);
            while (self.written < frame_end) try self.decodeItem(frame_end);
            if (frame_end - frame_start == frame_size)
                try self.arithmetic.consumeFrameTrailer();
        }
    }

    pub fn decodeItem(self: *Decoder, frame_end: usize) !void {
        const selector = try self.arithmetic.decodeSymbol(&self.selector_model);
        if (selector < 4) {
            self.output[self.written] = @intCast(try self.arithmetic.decodeSymbol(
                &self.literal_models[selector],
            ));
            self.written += 1;
            return;
        }

        var match_len: usize = switch (selector) {
            4 => 3,
            5 => 4,
            6 => blk: {
                const slot = try self.arithmetic.decodeSymbol(&self.length_model);
                if (slot >= length_base.len) return error.InvalidQuantumStream;
                const extra = try self.arithmetic.reader.readBits(length_extra[slot]);
                break :blk length_base[slot] + extra + 5;
            },
            else => return error.InvalidQuantumStream,
        };
        const position_model = switch (selector) {
            4 => &self.match3_model,
            5 => &self.match4_model,
            6 => &self.match_model,
            else => unreachable,
        };
        const slot = try self.arithmetic.decodeSymbol(position_model);
        if (slot >= position_base.len) return error.InvalidQuantumStream;
        const extra = try self.arithmetic.reader.readBits(position_extra[slot]);
        const match_offset = position_base[slot] + extra + 1;
        if (match_len > frame_end - self.written) return error.InvalidQuantumStream;
        if (match_offset == 0 or match_offset > self.window_size or match_offset > self.written)
            return error.InvalidMatch;

        while (match_len != 0) : (match_len -= 1) {
            self.output[self.written] = self.output[self.written - match_offset];
            self.written += 1;
        }
    }
};
