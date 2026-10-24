const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{Invalid7zArchive};

const top_value: u32 = 1 << 24;
const probability_total: u32 = 1 << 11;
const move_bits: u5 = 5;
const relative_limit: u32 = 1 << 26;

pub fn encodeNoConversionAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
) ![]u8 {
    var encoder = NoConversionEncoder{};
    defer encoder.deinit(allocator);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try encoder.push(allocator, input, true, &output);
    return output.toOwnedSlice(allocator);
}

pub const NoConversionEncoder = struct {
    range_encoder: RangeEncoder = .{},
    context: u32 = 0,
    finished: bool = false,

    pub fn deinit(self: *NoConversionEncoder, allocator: std.mem.Allocator) void {
        self.range_encoder.bytes.deinit(allocator);
        self.* = undefined;
    }

    pub fn push(
        self: *NoConversionEncoder,
        allocator: std.mem.Allocator,
        input: []const u8,
        finish: bool,
        output: *std.ArrayList(u8),
    ) !void {
        if (self.finished) {
            if (input.len != 0 or !finish) return error.Invalid7zArchive;
            return;
        }
        for (input) |byte| {
            self.context = (self.context << 24) | byte;
            const is_marker = byte == 0xe8 or byte == 0xe9 or
                (@as(u8, @truncate(self.context >> 24)) == 0x0f and byte & 0xf0 == 0x80);
            if (!is_marker) continue;
            const c = ((self.context +% 0x17) >> 6) & 1;
            const probability_index = (((0 -% c) & (self.context >> 24)) +% c +%
                ((self.context >> 5) & 1)) & 0x1ff;
            try self.range_encoder.encodeZero(allocator, @intCast(probability_index));
        }
        if (finish) {
            for (0..5) |_| try self.range_encoder.shiftLow(allocator);
            self.finished = true;
        }
        try output.appendSlice(allocator, self.range_encoder.bytes.items);
        self.range_encoder.bytes.clearRetainingCapacity();
    }
};

pub const ConversionEncoder = struct {
    range_encoder: RangeEncoder = .{},
    pending: std.ArrayList(u8) = .empty,
    context: u32 = 0,
    ip: u32,
    convert_targets: bool,
    finished: bool = false,
    main_size: u64 = 0,

    pub fn init(start_ip: u32) ConversionEncoder {
        return .{ .ip = start_ip, .convert_targets = start_ip == 0 };
    }

    pub fn deinit(self: *ConversionEncoder, allocator: std.mem.Allocator) void {
        self.range_encoder.bytes.deinit(allocator);
        self.pending.deinit(allocator);
        self.* = undefined;
    }

    pub fn push(
        self: *ConversionEncoder,
        allocator: std.mem.Allocator,
        input: []const u8,
        finish: bool,
        main: *std.ArrayList(u8),
        call: *std.ArrayList(u8),
        jump: *std.ArrayList(u8),
        range_output: *std.ArrayList(u8),
    ) !void {
        if (self.finished) {
            if (input.len != 0 or !finish) return error.Invalid7zArchive;
            return;
        }
        try self.pending.appendSlice(allocator, input);
        var index: usize = 0;
        while (index < self.pending.items.len) {
            const byte = self.pending.items[index];
            const next_context = (self.context << 24) | byte;
            const is_marker = byte == 0xe8 or byte == 0xe9 or
                (@as(u8, @truncate(next_context >> 24)) == 0x0f and byte & 0xf0 == 0x80);
            if (self.convert_targets and is_marker and
                self.pending.items.len - index < 5 and !finish) break;

            try main.append(allocator, byte);
            self.main_size = std.math.add(u64, self.main_size, 1) catch
                return error.IntegerOverflow;
            self.ip +%= 1;
            self.context = next_context;
            if (!is_marker) {
                index += 1;
                continue;
            }

            const probability_index = markerProbabilityIndex(self.context);
            if (!self.convert_targets or self.pending.items.len - index < 5) {
                try self.range_encoder.encodeZero(allocator, probability_index);
                index += 1;
                continue;
            }

            const relative = std.mem.readInt(u32, self.pending.items[index + 1 ..][0..4], .little);
            if ((relative +% relative_limit) >> 1 >= relative_limit) {
                try self.range_encoder.encodeZero(allocator, probability_index);
                index += 1;
                continue;
            }
            try self.range_encoder.encodeOne(allocator, probability_index);
            const absolute = relative +% (self.ip +% 4);
            var target: [4]u8 = undefined;
            std.mem.writeInt(u32, &target, absolute, .big);
            if (byte == 0xe8)
                try call.appendSlice(allocator, &target)
            else
                try jump.appendSlice(allocator, &target);
            self.ip +%= 4;
            self.context = relative >> 24;
            index += 5;
        }
        if (index != 0) {
            const remaining = self.pending.items.len - index;
            std.mem.copyForwards(
                u8,
                self.pending.items[0..remaining],
                self.pending.items[index..],
            );
            self.pending.items.len = remaining;
        }
        if (finish) {
            std.debug.assert(self.pending.items.len == 0);
            for (0..5) |_| try self.range_encoder.shiftLow(allocator);
            self.finished = true;
        }
        try range_output.appendSlice(allocator, self.range_encoder.bytes.items);
        self.range_encoder.bytes.clearRetainingCapacity();
    }
};

pub const EncodedStreams = struct {
    allocator: std.mem.Allocator,
    main: []u8,
    call: []u8,
    jump: []u8,
    range: []u8,

    pub fn deinit(self: *EncodedStreams) void {
        self.allocator.free(self.main);
        self.allocator.free(self.call);
        self.allocator.free(self.jump);
        self.allocator.free(self.range);
        self.* = undefined;
    }
};

pub fn encodeConvertedAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    start_ip: u32,
) !EncodedStreams {
    var encoder = ConversionEncoder.init(start_ip);
    defer encoder.deinit(allocator);
    var main: std.ArrayList(u8) = .empty;
    defer main.deinit(allocator);
    var call: std.ArrayList(u8) = .empty;
    defer call.deinit(allocator);
    var jump: std.ArrayList(u8) = .empty;
    defer jump.deinit(allocator);
    var range: std.ArrayList(u8) = .empty;
    defer range.deinit(allocator);
    try encoder.push(allocator, input, true, &main, &call, &jump, &range);
    const main_owned = try main.toOwnedSlice(allocator);
    errdefer allocator.free(main_owned);
    const call_owned = try call.toOwnedSlice(allocator);
    errdefer allocator.free(call_owned);
    const jump_owned = try jump.toOwnedSlice(allocator);
    errdefer allocator.free(jump_owned);
    return .{
        .allocator = allocator,
        .main = main_owned,
        .call = call_owned,
        .jump = jump_owned,
        .range = try range.toOwnedSlice(allocator),
    };
}

const RangeEncoder = struct {
    bytes: std.ArrayList(u8) = .empty,
    probabilities: [258]u16 = @splat(probability_total / 2),
    range: u32 = std.math.maxInt(u32),
    low: u64 = 0,
    cache: u8 = 0,
    cache_size: u64 = 1,

    fn encodeZero(
        self: *RangeEncoder,
        allocator: std.mem.Allocator,
        probability_index: usize,
    ) !void {
        if (probability_index >= self.probabilities.len) return error.Invalid7zArchive;
        if (self.range < top_value) {
            try self.shiftLow(allocator);
            self.range <<= 8;
        }
        const probability = self.probabilities[probability_index];
        self.range = (self.range >> 11) * probability;
        self.probabilities[probability_index] = @intCast(
            probability + ((probability_total - probability) >> move_bits),
        );
    }

    fn encodeOne(
        self: *RangeEncoder,
        allocator: std.mem.Allocator,
        probability_index: usize,
    ) !void {
        if (probability_index >= self.probabilities.len) return error.Invalid7zArchive;
        if (self.range < top_value) {
            try self.shiftLow(allocator);
            self.range <<= 8;
        }
        const probability = self.probabilities[probability_index];
        const bound = (self.range >> 11) * probability;
        self.low += bound;
        self.range -= bound;
        self.probabilities[probability_index] = @intCast(
            probability - (probability >> move_bits),
        );
    }

    fn shiftLow(self: *RangeEncoder, allocator: std.mem.Allocator) !void {
        const low32: u32 = @truncate(self.low);
        const high: u8 = @truncate(self.low >> 32);
        if (low32 < 0xff00_0000 or high != 0) {
            var remaining = self.cache_size;
            while (remaining != 0) : (remaining -= 1) {
                try self.bytes.append(allocator, self.cache +% high);
                self.cache = 0xff;
            }
            self.cache_size = 0;
            self.cache = @truncate(low32 >> 24);
        }
        self.cache_size += 1;
        self.low = @as(u32, low32 << 8);
    }
};

fn markerProbabilityIndex(context: u32) usize {
    const c = ((context +% 0x17) >> 6) & 1;
    return @intCast((((0 -% c) & (context >> 24)) +% c +%
        ((context >> 5) & 1)) & 0x1ff);
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    main: []const u8,
    call: []const u8,
    jump: []const u8,
    range_stream: []const u8,
    expected_size: usize,
    start_ip: u32,
) ![]u8 {
    if (call.len & 3 != 0 or jump.len & 3 != 0 or range_stream.len < 5)
        return error.Invalid7zArchive;
    const side_size = std.math.add(usize, call.len, jump.len) catch
        return error.IntegerOverflow;
    const calculated_size = std.math.add(usize, main.len, side_size) catch
        return error.IntegerOverflow;
    if (calculated_size != expected_size)
        return error.Invalid7zArchive;
    if (range_stream[0] != 0) return error.Invalid7zArchive;

    var code = std.mem.readInt(u32, range_stream[1..5], .big);
    if (code == std.math.maxInt(u32)) return error.Invalid7zArchive;
    var range: u32 = std.math.maxInt(u32);
    var probabilities: [258]u16 = @splat(probability_total / 2);
    var main_index: usize = 0;
    var call_index: usize = 0;
    var jump_index: usize = 0;
    var range_index: usize = 5;
    var ip = start_ip;
    var context: u32 = 0;

    const output = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(output);
    var output_index: usize = 0;
    while (output_index < output.len) {
        if (range < top_value) {
            if (range_index >= range_stream.len) return error.TruncatedFrame;
            range <<= 8;
            code = (code << 8) | range_stream[range_index];
            range_index += 1;
        }
        if (main_index >= main.len) return error.Invalid7zArchive;
        const byte = main[main_index];
        main_index += 1;
        output[output_index] = byte;
        output_index += 1;
        ip +%= 1;
        context = (context << 24) | byte;

        const is_marker = byte == 0xe8 or byte == 0xe9 or
            (@as(u8, @truncate(context >> 24)) == 0x0f and byte & 0xf0 == 0x80);
        if (!is_marker) continue;

        const c = ((context +% 0x17) >> 6) & 1;
        const probability_index = (((0 -% c) & (context >> 24)) +% c +%
            ((context >> 5) & 1)) & 0x1ff;
        if (probability_index >= probabilities.len) return error.Invalid7zArchive;
        const probability = probabilities[probability_index];
        const bound = (range >> 11) * probability;
        if (code < bound) {
            range = bound;
            probabilities[probability_index] = @intCast(
                probability + ((probability_total - probability) >> move_bits),
            );
            continue;
        }

        range -= bound;
        code -= bound;
        probabilities[probability_index] = @intCast(
            probability - (probability >> move_bits),
        );
        var source = jump;
        var source_index = &jump_index;
        if (byte == 0xe8) {
            source = call;
            source_index = &call_index;
        }
        if (source_index.* > source.len or source.len - source_index.* < 4 or
            output.len - output_index < 4)
            return error.Invalid7zArchive;
        const absolute = std.mem.readInt(u32, source[source_index.*..][0..4], .big);
        source_index.* += 4;
        ip +%= 4;
        const relative = absolute -% ip;
        std.mem.writeInt(u32, output[output_index..][0..4], relative, .little);
        output_index += 4;
        context = relative >> 24;
    }

    if (range < top_value and range_index < range_stream.len) {
        range <<= 8;
        code = (code << 8) | range_stream[range_index];
        range_index += 1;
    }
    if (main_index != main.len or call_index != call.len or jump_index != jump.len or
        range_index != range_stream.len or code != 0)
        return error.Invalid7zArchive;
    return output;
}

test "BCJ2 decoder copies marker-free main stream" {
    const allocator = std.testing.allocator;
    const decoded = try decodeAlloc(
        allocator,
        "marker-free payload",
        &.{},
        &.{},
        &.{ 0, 0, 0, 0, 0 },
        "marker-free payload".len,
        0,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("marker-free payload", decoded);
    try std.testing.expectError(
        error.Invalid7zArchive,
        decodeAlloc(allocator, "x", &.{}, &.{}, &.{ 1, 0, 0, 0, 0 }, 1, 0),
    );
}

test "BCJ2 no-conversion encoder round trips branch markers" {
    const allocator = std.testing.allocator;
    const input = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff" ++
        "\x0f\x85\x08\x00\x00\x00tail";
    const range_stream = try encodeNoConversionAlloc(allocator, input);
    defer allocator.free(range_stream);
    const decoded = try decodeAlloc(
        allocator,
        input,
        &.{},
        &.{},
        range_stream,
        input.len,
        0,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "BCJ2 no-conversion encoder is fragmentation independent" {
    const input = ("\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff" ++
        "\x0f\x85\x08\x00\x00\x00tail") ** 97;
    const expected = try encodeNoConversionAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(expected);
    for (1..24) |chunk_len| {
        var encoder = NoConversionEncoder{};
        defer encoder.deinit(std.testing.allocator);
        var actual: std.ArrayList(u8) = .empty;
        defer actual.deinit(std.testing.allocator);
        var offset: usize = 0;
        while (offset < input.len) {
            const end = @min(input.len, offset + chunk_len);
            try encoder.push(std.testing.allocator, input[offset..end], false, &actual);
            offset = end;
        }
        try encoder.push(std.testing.allocator, &.{}, true, &actual);
        try std.testing.expectEqualSlices(u8, expected, actual.items);
    }
}

test "BCJ2 conversion encoder splits and restores real branch targets" {
    const input = ("\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff" ++
        "\x0f\x85\x08\x00\x00\x00tail") ** 97;
    var expected = try encodeConvertedAlloc(std.testing.allocator, input, 0);
    defer expected.deinit();
    try std.testing.expect(expected.main.len < input.len);
    try std.testing.expect(expected.call.len != 0);
    try std.testing.expect(expected.jump.len != 0);
    const decoded = try decodeAlloc(
        std.testing.allocator,
        expected.main,
        expected.call,
        expected.jump,
        expected.range,
        input.len,
        0,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    for (1..24) |chunk_len| {
        var encoder = ConversionEncoder.init(0);
        defer encoder.deinit(std.testing.allocator);
        var main: std.ArrayList(u8) = .empty;
        defer main.deinit(std.testing.allocator);
        var call: std.ArrayList(u8) = .empty;
        defer call.deinit(std.testing.allocator);
        var jump: std.ArrayList(u8) = .empty;
        defer jump.deinit(std.testing.allocator);
        var range: std.ArrayList(u8) = .empty;
        defer range.deinit(std.testing.allocator);
        var offset: usize = 0;
        while (offset < input.len) {
            const end = @min(input.len, offset + chunk_len);
            try encoder.push(
                std.testing.allocator,
                input[offset..end],
                false,
                &main,
                &call,
                &jump,
                &range,
            );
            offset = end;
        }
        try encoder.push(
            std.testing.allocator,
            &.{},
            true,
            &main,
            &call,
            &jump,
            &range,
        );
        try std.testing.expectEqualSlices(u8, expected.main, main.items);
        try std.testing.expectEqualSlices(u8, expected.call, call.items);
        try std.testing.expectEqualSlices(u8, expected.jump, jump.items);
        try std.testing.expectEqualSlices(u8, expected.range, range.items);
    }
}
