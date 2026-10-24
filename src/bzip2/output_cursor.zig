const std = @import("std");
const core = @import("../core.zig");
const crc_mod = @import("crc.zig");
const randomization = @import("randomization.zig");
pub const Error = core.Error || error{InvalidBzip2Stream};
pub const Span = struct { byte: u8, count: usize };

/// Numeric cursor: transformed bytes and links are supplied during each call,
/// so decoder movement never leaves a pointer into an old inline state.
pub const Cursor = struct {
    position: usize,
    remaining: usize,
    randomized: bool,
    random_state: randomization.State = .{},
    previous: u8 = 0,
    run_length: u8 = 0,
    span_byte: u8 = 0,
    span_remaining: usize = 0,
    emitted: usize = 0,

    pub fn init(position: usize, length: usize, randomized: bool) Cursor {
        return .{ .position = position, .remaining = length, .randomized = randomized };
    }
    pub fn nextSpan(self: *Cursor, block: []const u8, links: []const u32) Error!?Span {
        while (self.remaining != 0) {
            if (self.position >= block.len or links.len != block.len) return error.InvalidBzip2Stream;
            var byte = block[self.position];
            self.position = links[self.position];
            if (self.position >= block.len) return error.InvalidBzip2Stream;
            self.remaining -= 1;
            if (self.randomized) byte = self.random_state.decode(byte);
            if (self.run_length == 4) {
                self.run_length = 0;
                if (byte != 0) return .{ .byte = self.previous, .count = byte };
                continue;
            }
            if (self.run_length != 0 and byte == self.previous) self.run_length += 1 else {
                self.previous = byte;
                self.run_length = 1;
            }
            return .{ .byte = byte, .count = 1 };
        }
        if (self.run_length == 4) return error.InvalidBzip2Stream;
        return null;
    }
    pub fn write(self: *Cursor, block: []const u8, links: []const u32, output: []u8) Error!usize {
        var written: usize = 0;
        while (written != output.len) {
            if (self.span_remaining == 0) {
                const span = (try self.nextSpan(block, links)) orelse break;
                self.span_byte = span.byte;
                self.span_remaining = span.count;
            }
            const take = @min(output.len - written, self.span_remaining);
            const next_emitted = std.math.add(usize, self.emitted, take) catch return error.IntegerOverflow;
            @memset(output[written..][0..take], self.span_byte);
            written += take;
            self.emitted = next_emitted;
            self.span_remaining -= take;
        }
        return written;
    }
};

/// Validate all RLE counts and compute plaintext length/CRC without allocating
/// plaintext. The caller retains the initial cursor for a subsequent drain.
pub fn summarize(initial: Cursor, block: []const u8, links: []const u32, limit: usize) Error!struct { length: usize, crc32: u32 } {
    var cursor = initial;
    var length: usize = 0;
    var crc = crc_mod.Crc32{};
    while (try cursor.nextSpan(block, links)) |span| {
        length = std.math.add(usize, length, span.count) catch return error.OutputLimitExceeded;
        if (length > limit) return error.OutputLimitExceeded;
        crc.updateRepeat(span.byte, span.count);
    }
    return .{ .length = length, .crc32 = crc.digest() };
}

test "Bzip2 cursor rejects missing terminal RLE count and invalid link" {
    try std.testing.expectError(error.InvalidBzip2Stream, summarize(Cursor.init(0, 4, false), "aaaa", &.{ 0, 1, 2, 3 }, 1000));
    var cursor = Cursor.init(0, 1, false);
    try std.testing.expectError(error.InvalidBzip2Stream, cursor.nextSpan("a", &.{1}));
}

test "Bzip2 cursor counts overflow before publishing a repeat span" {
    // A full four-literal run followed by a maximum RLE count.
    var cursor = Cursor.init(0, 5, false);
    const block = [_]u8{ 'a', 'a', 'a', 'a', 255 };
    const links = [_]u32{ 1, 2, 3, 4, 0 };
    try std.testing.expectError(error.OutputLimitExceeded, summarize(cursor, &block, &links, 258));
    cursor.emitted = std.math.maxInt(usize);
    var output: [1]u8 = .{0xa5};
    try std.testing.expectError(error.IntegerOverflow, cursor.write(&block, &links, &output));
    try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
}
