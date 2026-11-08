//! Numeric layout for one- and four-stream Huffman literal payloads.
const std = @import("std");
const core = @import("../../core.zig");

pub const Error = core.Error;

pub const Span = struct {
    offset: usize,
    len: usize,
};

pub const Layout = union(enum) {
    one: Span,
    four: [4]Span,
};

pub fn parse(size_format: u2, stream_data_len: usize, jump: ?*const [6]u8) Error!Layout {
    if (size_format == 0) return .{ .one = .{ .offset = 0, .len = stream_data_len } };
    if (stream_data_len < 6) return error.CorruptFrame;
    const bytes = jump orelse return error.TruncatedFrame;
    const lengths = [3]usize{
        std.mem.readInt(u16, bytes[0..2], .little),
        std.mem.readInt(u16, bytes[2..4], .little),
        std.mem.readInt(u16, bytes[4..6], .little),
    };
    const starts = [4]usize{
        6,
        std.math.add(usize, 6, lengths[0]) catch return error.IntegerOverflow,
        0,
        0,
    };
    var resolved = starts;
    resolved[2] = std.math.add(usize, resolved[1], lengths[1]) catch return error.IntegerOverflow;
    resolved[3] = std.math.add(usize, resolved[2], lengths[2]) catch return error.IntegerOverflow;
    if (resolved[3] > stream_data_len) return error.CorruptFrame;
    return .{ .four = .{
        .{ .offset = resolved[0], .len = lengths[0] },
        .{ .offset = resolved[1], .len = lengths[1] },
        .{ .offset = resolved[2], .len = lengths[2] },
        .{ .offset = resolved[3], .len = stream_data_len - resolved[3] },
    } };
}

test "Zstd four-stream layout preserves zero-length fourth stream" {
    const jump = [_]u8{ 2, 0, 3, 0, 4, 0 };
    const layout = (try parse(1, 15, &jump)).four;
    try std.testing.expectEqual(Span{ .offset = 6, .len = 2 }, layout[0]);
    try std.testing.expectEqual(Span{ .offset = 8, .len = 3 }, layout[1]);
    try std.testing.expectEqual(Span{ .offset = 11, .len = 4 }, layout[2]);
    try std.testing.expectEqual(Span{ .offset = 15, .len = 0 }, layout[3]);
}
