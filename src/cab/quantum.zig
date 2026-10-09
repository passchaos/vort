const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidQuantumStream,
    UnsupportedCabinetFeature,
};

const min_window_bits: u5 = 10;
const max_window_bits: u5 = 21;
const frame_size: usize = 32 * 1024;
const max_model_entries: usize = 64;

const position_base = [_]usize{
    0,      1,      2,      3,      4,      6,       8,
    12,     16,     24,     32,     48,     64,      96,
    128,    192,    256,    384,    512,    768,     1024,
    1536,   2048,   3072,   4096,   6144,   8192,    12288,
    16384,  24576,  32768,  49152,  65536,  98304,   131072,
    196608, 262144, 393216, 524288, 786432, 1048576, 1572864,
};

const position_extra = [_]u5{
    0,  0,  0,  0,  1,  1,  2,  2,  3,  3,  4,  4,  5,  5,
    6,  6,  7,  7,  8,  8,  9,  9,  10, 10, 11, 11, 12, 12,
    13, 13, 14, 14, 15, 15, 16, 16, 17, 17, 18, 18, 19, 19,
};

const length_base = [_]usize{
    0,  1,  2,  3,   4,   5,   6,   8,   10,
    12, 14, 18, 22,  26,  30,  38,  46,  54,
    62, 78, 94, 110, 126, 158, 190, 222, 254,
};

const length_extra = [_]u5{
    0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
};

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

    var decoder = Decoder.init(input, output, window_bits);
    try decoder.decode();
    if (decoder.written != output.len) return error.SizeMismatch;
    return output;
}

const BitReader = struct {
    input: []const u8,
    byte_offset: usize = 0,
    bit_offset: u4 = 0,

    fn readBits(self: *BitReader, count: u5) !u32 {
        if (count > 24) return error.InvalidQuantumStream;
        var value: u32 = 0;
        var remaining: u5 = count;
        while (remaining != 0) : (remaining -= 1) {
            if (self.byte_offset >= self.input.len) return error.TruncatedFrame;
            value = (value << 1) |
                ((self.input[self.byte_offset] >> @intCast(7 - self.bit_offset)) & 1);
            self.bit_offset += 1;
            if (self.bit_offset == 8) {
                self.bit_offset = 0;
                self.byte_offset += 1;
            }
        }
        return value;
    }

    fn alignToByte(self: *BitReader) void {
        if (self.bit_offset == 0) return;
        self.bit_offset = 0;
        self.byte_offset += 1;
    }

    fn readAlignedByte(self: *BitReader) !u8 {
        if (self.bit_offset != 0) return error.InvalidQuantumStream;
        if (self.byte_offset >= self.input.len) return error.TruncatedFrame;
        const value = self.input[self.byte_offset];
        self.byte_offset += 1;
        return value;
    }
};

const ModelSymbol = struct {
    symbol: u16 = 0,
    cumulative: u16 = 0,
};

const Model = struct {
    shifts_left: u8 = 4,
    entries: usize,
    symbols: [max_model_entries + 1]ModelSymbol = @splat(.{}),

    fn init(start: u16, entries: usize) Model {
        std.debug.assert(entries > 0 and entries <= max_model_entries);
        var model = Model{ .entries = entries };
        for (model.symbols[0 .. entries + 1], 0..) |*item, index| {
            item.* = .{
                .symbol = start + @as(u16, @intCast(index)),
                .cumulative = @intCast(entries - index),
            };
        }
        return model;
    }

    fn record(self: *Model, boundary_index: usize) void {
        var index = boundary_index;
        while (index != 0) {
            index -= 1;
            self.symbols[index].cumulative += 8;
        }
        if (self.symbols[0].cumulative > 3800) self.update();
    }

    fn update(self: *Model) void {
        self.shifts_left -= 1;
        if (self.shifts_left != 0) {
            var index = self.entries;
            while (index != 0) {
                index -= 1;
                self.symbols[index].cumulative >>= 1;
                if (self.symbols[index].cumulative <= self.symbols[index + 1].cumulative)
                    self.symbols[index].cumulative = self.symbols[index + 1].cumulative + 1;
            }
            return;
        }

        self.shifts_left = 50;
        for (0..self.entries) |index| {
            self.symbols[index].cumulative -= self.symbols[index + 1].cumulative;
            self.symbols[index].cumulative = (self.symbols[index].cumulative + 1) >> 1;
        }

        for (0..self.entries - 1) |index| {
            for (index + 1..self.entries) |candidate| {
                if (self.symbols[index].cumulative < self.symbols[candidate].cumulative)
                    std.mem.swap(ModelSymbol, &self.symbols[index], &self.symbols[candidate]);
            }
        }

        var index = self.entries;
        while (index != 0) {
            index -= 1;
            self.symbols[index].cumulative += self.symbols[index + 1].cumulative;
        }
    }
};

const ArithmeticDecoder = struct {
    reader: BitReader,
    high: u16 = 0xffff,
    low: u16 = 0,
    code: u16 = 0,

    fn startFrame(self: *ArithmeticDecoder) !void {
        self.high = 0xffff;
        self.low = 0;
        self.code = @intCast(try self.reader.readBits(16));
    }

    fn decodeSymbol(self: *ArithmeticDecoder, model: *Model) !usize {
        if (self.high < self.low or self.code < self.low or self.code > self.high)
            return error.InvalidQuantumStream;

        const total: u32 = model.symbols[0].cumulative;
        const range: u32 = @as(u32, self.high) - self.low + 1;
        const code_range: u32 = @as(u32, self.code) - self.low + 1;
        const scaled = (code_range * total - 1) / range;
        if (scaled >= total) return error.InvalidQuantumStream;

        var boundary_index: usize = 1;
        while (boundary_index < model.entries and
            model.symbols[boundary_index].cumulative > scaled)
        {
            boundary_index += 1;
        }
        const selected = boundary_index - 1;
        const decoded_symbol: usize = model.symbols[selected].symbol;
        const next_cumulative: u32 = model.symbols[boundary_index].cumulative;
        const selected_cumulative: u32 = model.symbols[selected].cumulative;
        const new_high = @as(u32, self.low) + selected_cumulative * range / total - 1;
        const new_low = @as(u32, self.low) + next_cumulative * range / total;
        if (new_high > std.math.maxInt(u16) or new_low > new_high)
            return error.InvalidQuantumStream;
        self.high = @intCast(new_high);
        self.low = @intCast(new_low);
        model.record(boundary_index);

        while (true) {
            if ((self.low & 0x8000) != (self.high & 0x8000)) {
                if ((self.low & 0x4000) != 0 and (self.high & 0x4000) == 0) {
                    self.code ^= 0x4000;
                    self.low &= 0x3fff;
                    self.high |= 0x4000;
                } else break;
            }
            self.low = self.low << 1;
            self.high = (self.high << 1) | 1;
            self.code = (self.code << 1) | @as(u16, @intCast(try self.reader.readBits(1)));
        }
        if (self.code < self.low or self.code > self.high)
            return error.InvalidQuantumStream;
        return decoded_symbol;
    }

    fn consumeFrameTrailer(self: *ArithmeticDecoder) !void {
        self.reader.alignToByte();
        var padding: usize = 0;
        while (padding <= 4) : (padding += 1) {
            const byte = try self.reader.readAlignedByte();
            if (byte == 0xff) return;
            if (byte != 0) return error.InvalidQuantumStream;
        }
        return error.InvalidQuantumStream;
    }
};

const Decoder = struct {
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

    fn init(input: []const u8, output: []u8, window_bits: u5) Decoder {
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

    fn decode(self: *Decoder) !void {
        while (self.written < self.output.len) {
            try self.arithmetic.startFrame();
            const frame_start = self.written;
            const frame_end = @min(self.output.len, frame_start + frame_size);
            while (self.written < frame_end) try self.decodeItem(frame_end);
            if (frame_end - frame_start == frame_size)
                try self.arithmetic.consumeFrameTrailer();
        }
    }

    fn decodeItem(self: *Decoder, frame_end: usize) !void {
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

test "Quantum bit reader uses byte-order MSB-first bits" {
    var reader = BitReader{ .input = &.{ 0x12, 0x34, 0xab } };
    try std.testing.expectEqual(@as(u32, 1), try reader.readBits(4));
    try std.testing.expectEqual(@as(u32, 0x234), try reader.readBits(12));
    try std.testing.expectEqual(@as(u32, 0xab), try reader.readBits(8));
}

test "Quantum rejects unsupported window sizes and truncated input" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.UnsupportedCabinetFeature,
        decodeAlloc(allocator, &.{}, 1, 9),
    );
    try std.testing.expectError(
        error.UnsupportedCabinetFeature,
        decodeAlloc(allocator, &.{}, 1, 22),
    );
    try std.testing.expectError(error.TruncatedFrame, decodeAlloc(allocator, &.{}, 1, 15));
}

test "Quantum decodes the libmspack fixed-match stream" {
    const compressed = [_]u8{
        0xd6, 0x06, 0x69, 0x0b, 0xcb, 0x47, 0xf0, 0x2c, 0x2a, 0x3a,
        0x8f, 0x2c, 0xab, 0xbb, 0x3c, 0xb9, 0x33, 0x01, 0x8b, 0xd8,
        0x58, 0x4b, 0x7b, 0x01, 0xba, 0x6f, 0x6d, 0x51, 0x6e, 0x3a,
        0xc3, 0x67, 0x42, 0x4b, 0xeb, 0x02, 0x36, 0x43, 0xd6, 0x66,
        0x56, 0xca, 0x9e, 0x72, 0xcc, 0x30, 0x00, 0x00, 0xff,
    };
    var output: [59]u8 = undefined;
    var decoder = Decoder.init(&compressed, &output, 18);
    try decoder.decode();
    try std.testing.expectEqualStrings(
        "If you can read this, the Quantum decompressor is working!\n",
        &output,
    );
}

test "Quantum decodes fixed and variable match selectors" {
    const allocator = std.testing.allocator;
    var writer = TestBitWriter{};
    defer writer.bytes.deinit(allocator);
    var encoder = TestArithmeticEncoder{ .writer = &writer };
    var selector_model = Model.init(0, 7);
    var literal_models = [4]Model{
        Model.init(0, 64),
        Model.init(64, 64),
        Model.init(128, 64),
        Model.init(192, 64),
    };
    var match3_model = Model.init(0, 24);
    var match4_model = Model.init(0, 36);
    var match_model = Model.init(0, 36);
    var length_model = Model.init(0, 27);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);

    encoder.startFrame();
    for ("abcdefgh") |byte| {
        const selector = byte >> 6;
        try encoder.encodeSymbol(allocator, &selector_model, selector);
        try encoder.encodeSymbol(allocator, &literal_models[selector], byte);
        try expected.append(allocator, byte);
    }

    try encoder.encodeSymbol(allocator, &selector_model, 4);
    try encoder.encodeSymbol(allocator, &match3_model, 0);
    try testAppendMatch(allocator, &expected, 1, 3);

    try encoder.encodeSymbol(allocator, &selector_model, 5);
    try encoder.encodeSymbol(allocator, &match4_model, 3);
    try testAppendMatch(allocator, &expected, 4, 4);

    try encoder.encodeSymbol(allocator, &selector_model, 6);
    try encoder.encodeSymbol(allocator, &length_model, 5);
    try encoder.encodeSymbol(allocator, &match_model, 3);
    try testAppendMatch(allocator, &expected, 4, 10);

    try encoder.finishFrame(allocator);
    try writer.alignToByte(allocator);
    try writer.bytes.appendNTimes(allocator, 0, 4);
    const decoded = try decodeAlloc(allocator, writer.bytes.items, expected.items.len, 18);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected.items, decoded);
}

test "Quantum retains adaptive models across frames for all window sizes" {
    const allocator = std.testing.allocator;
    const expected = try allocator.alloc(u8, frame_size + 257);
    defer allocator.free(expected);
    for (expected, 0..) |*byte, index| byte.* = @truncate(index *% 73 +% index / 11);

    var encoded = try testEncodeLiterals(allocator, expected, 4);
    defer encoded.deinit(allocator);
    for (min_window_bits..max_window_bits + 1) |window_bits| {
        const decoded = try decodeAlloc(
            allocator,
            encoded.bytes,
            expected.len,
            @intCast(window_bits),
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, expected, decoded);
    }

    encoded.bytes[encoded.first_trailer_offset] = 0xfe;
    try std.testing.expectError(
        error.InvalidQuantumStream,
        decodeAlloc(allocator, encoded.bytes, expected.len, 18),
    );
}

const TestEncoded = struct {
    bytes: []u8,
    first_trailer_offset: usize,

    fn deinit(self: *TestEncoded, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

fn testAppendMatch(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    offset: usize,
    len: usize,
) !void {
    for (0..len) |_|
        try output.append(allocator, output.items[output.items.len - offset]);
}

fn testEncodeLiterals(
    allocator: std.mem.Allocator,
    input: []const u8,
    full_frame_padding: usize,
) !TestEncoded {
    std.debug.assert(full_frame_padding <= 4);
    var writer = TestBitWriter{};
    defer writer.bytes.deinit(allocator);
    var encoder = TestArithmeticEncoder{ .writer = &writer };
    var selector_model = Model.init(0, 7);
    var literal_models = [4]Model{
        Model.init(0, 64),
        Model.init(64, 64),
        Model.init(128, 64),
        Model.init(192, 64),
    };
    var offset: usize = 0;
    var first_trailer_offset: ?usize = null;
    while (offset < input.len) {
        encoder.startFrame();
        const end = @min(input.len, offset + frame_size);
        for (input[offset..end]) |byte| {
            const selector = byte >> 6;
            try encoder.encodeSymbol(allocator, &selector_model, selector);
            try encoder.encodeSymbol(allocator, &literal_models[selector], byte);
        }
        try encoder.finishFrame(allocator);
        try writer.alignToByte(allocator);
        if (end - offset == frame_size) {
            // Arithmetic termination can leave whole unused bytes. CAB Quantum
            // stores only the bytes consumed by the completed frame, followed
            // by 0..4 alignment bytes and the injected CFDATA sentinel.
            if (offset != 0) return error.InvalidQuantumStream;
            try writer.bytes.appendNTimes(allocator, 0, 4);
            const verified = try allocator.alloc(u8, frame_size);
            defer allocator.free(verified);
            var verifier = Decoder.init(writer.bytes.items, verified, 18);
            try verifier.arithmetic.startFrame();
            while (verifier.written < verified.len)
                try verifier.decodeItem(verified.len);
            try std.testing.expectEqualSlices(u8, input[0..frame_size], verified);
            verifier.arithmetic.reader.alignToByte();
            writer.bytes.shrinkRetainingCapacity(verifier.arithmetic.reader.byte_offset);

            try writer.bytes.appendNTimes(allocator, 0, full_frame_padding);
            if (first_trailer_offset == null) first_trailer_offset = writer.bytes.items.len;
            try writer.bytes.append(allocator, 0xff);
        } else {
            try writer.bytes.appendNTimes(allocator, 0, 4);
        }
        offset = end;
    }
    return .{
        .bytes = try writer.bytes.toOwnedSlice(allocator),
        .first_trailer_offset = first_trailer_offset.?,
    };
}

const TestArithmeticEncoder = struct {
    writer: *TestBitWriter,
    low: u32 = 0,
    high: u32 = 0xffff,
    pending_bits: usize = 0,

    fn startFrame(self: *TestArithmeticEncoder) void {
        self.low = 0;
        self.high = 0xffff;
        self.pending_bits = 0;
    }

    fn encodeSymbol(
        self: *TestArithmeticEncoder,
        allocator: std.mem.Allocator,
        model: *Model,
        symbol: usize,
    ) !void {
        var selected: usize = 0;
        while (selected < model.entries and model.symbols[selected].symbol != symbol)
            selected += 1;
        if (selected == model.entries) return error.InvalidQuantumStream;

        const total: u32 = model.symbols[0].cumulative;
        const range = self.high - self.low + 1;
        self.high = self.low + @as(u32, model.symbols[selected].cumulative) * range / total - 1;
        self.low += @as(u32, model.symbols[selected + 1].cumulative) * range / total;
        model.record(selected + 1);

        while (true) {
            if (self.high < 0x8000) {
                try self.writeBitAndPending(allocator, 0);
            } else if (self.low >= 0x8000) {
                try self.writeBitAndPending(allocator, 1);
                self.low -= 0x8000;
                self.high -= 0x8000;
            } else if (self.low >= 0x4000 and self.high < 0xc000) {
                self.pending_bits += 1;
                self.low -= 0x4000;
                self.high -= 0x4000;
            } else break;
            self.low <<= 1;
            self.high = (self.high << 1) | 1;
        }
    }

    fn finishFrame(self: *TestArithmeticEncoder, allocator: std.mem.Allocator) !void {
        self.pending_bits += 1;
        try self.writeBitAndPending(allocator, @intFromBool(self.low >= 0x4000));
    }

    fn writeBitAndPending(
        self: *TestArithmeticEncoder,
        allocator: std.mem.Allocator,
        bit: u1,
    ) !void {
        try self.writer.writeBit(allocator, bit);
        while (self.pending_bits != 0) : (self.pending_bits -= 1)
            try self.writer.writeBit(allocator, bit ^ 1);
    }
};

const TestBitWriter = struct {
    bytes: std.ArrayList(u8) = .empty,
    byte: u8 = 0,
    bits_used: u4 = 0,

    fn writeBit(self: *TestBitWriter, allocator: std.mem.Allocator, bit: u1) !void {
        self.byte |= @as(u8, bit) << @intCast(7 - self.bits_used);
        self.bits_used += 1;
        if (self.bits_used == 8) {
            try self.bytes.append(allocator, self.byte);
            self.byte = 0;
            self.bits_used = 0;
        }
    }

    fn alignToByte(self: *TestBitWriter, allocator: std.mem.Allocator) !void {
        if (self.bits_used == 0) return;
        try self.bytes.append(allocator, self.byte);
        self.byte = 0;
        self.bits_used = 0;
    }
};
