const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

const seed_words: usize = 17;
const state_words: usize = 521;
const lag: usize = 32;
const state_bytes: usize = state_words * 4;

const Generator = struct {
    state: [state_words]u32 = @splat(0),
    byte_position: usize = 0,

    fn init(seed: *const [seed_words * 4]u8) Generator {
        var self: Generator = .{};
        for (0..seed_words) |index|
            self.state[index] = std.mem.readInt(
                u32,
                seed[index * 4 ..][0..4],
                .big,
            );
        for (seed_words..state_words) |index|
            self.state[index] = (self.state[index - 17] << 23) ^
                (self.state[index - 16] >> 9) ^
                self.state[index - 1];
        for (&self.state) |*word| {
            const transformed = (word.* & 0xff00_ffff) |
                ((word.* >> 2) & 0x00ff_0000);
            word.* = @byteSwap(transformed);
        }
        for (0..4) |_| self.advanceState();
        return self;
    }

    fn forward(self: *Generator, count: usize) void {
        self.byte_position += count;
        while (self.byte_position >= state_bytes) {
            self.advanceState();
            self.byte_position -= state_bytes;
        }
    }

    fn write(self: *Generator, output: []u8) void {
        for (output) |*byte| {
            const word = self.state[self.byte_position / 4];
            byte.* = @truncate(word >> @intCast((self.byte_position % 4) * 8));
            self.byte_position += 1;
            if (self.byte_position == state_bytes) {
                self.advanceState();
                self.byte_position = 0;
            }
        }
    }

    fn advanceState(self: *Generator) void {
        for (0..lag) |index|
            self.state[index] ^= self.state[index + state_words - lag];
        for (lag..state_words) |index|
            self.state[index] ^= self.state[index - lag];
    }
};

pub fn decodeAllocExact(
    allocator: std.mem.Allocator,
    packed_bytes: []const u8,
    expected_size: usize,
    data_offset: usize,
) Error![]u8 {
    const output = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var logical_offset = data_offset;
    while (input_offset < packed_bytes.len) {
        if (packed_bytes.len - input_offset < 4) return error.TruncatedFrame;
        const size_field = std.mem.readInt(
            u32,
            packed_bytes[input_offset..][0..4],
            .big,
        );
        input_offset += 4;
        const junk = size_field & 0x8000_0000 != 0;
        const size: usize = size_field & 0x7fff_ffff;
        if (size == 0 or size > output.len - output_offset)
            return error.CorruptFrame;
        if (junk) {
            if (packed_bytes.len - input_offset < seed_words * 4)
                return error.TruncatedFrame;
            const seed: *const [seed_words * 4]u8 = @ptrCast(
                packed_bytes[input_offset..][0 .. seed_words * 4].ptr,
            );
            input_offset += seed_words * 4;
            var generator = Generator.init(seed);
            generator.forward(logical_offset % format.wii_block_size);
            generator.write(output[output_offset..][0..size]);
        } else {
            if (size > packed_bytes.len - input_offset) return error.TruncatedFrame;
            @memcpy(
                output[output_offset..][0..size],
                packed_bytes[input_offset..][0..size],
            );
            input_offset += size;
        }
        output_offset += size;
        logical_offset += size;
    }
    if (output_offset != output.len) return error.SizeMismatch;
    return output;
}

test "RVZ packing decodes literal and generated segments" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try encoded.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 3 });
    try encoded.appendSlice(std.testing.allocator, "abc");
    try encoded.appendSlice(std.testing.allocator, &.{ 0x80, 0, 0, 8 });
    var seed: [seed_words * 4]u8 = undefined;
    for (&seed, 0..) |*byte, index| byte.* = @truncate(index * 7);
    try encoded.appendSlice(std.testing.allocator, &seed);
    const decoded = try decodeAllocExact(
        std.testing.allocator,
        encoded.items,
        11,
        0,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "abc", decoded[0..3]);
    try std.testing.expectEqualSlices(
        u8,
        &.{ 0x6a, 0xef, 0xe8, 0x12, 0xf9, 0xd0, 0x15, 0x20 },
        decoded[3..11],
    );
}
