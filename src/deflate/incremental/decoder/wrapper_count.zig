//! Counter windows keep raw-decoder writes representable by wrapper totals.
const std = @import("std");
const core = @import("../../../core.zig");
const count = core.stream_count;
const Count = core.StreamCount;
const member_prefix = @import("member_prefix.zig");

pub const Before = struct {
    input: Count,
    output: Count,

    pub fn init(input: Count, output: Count) Before {
        return .{ .input = input, .output = output };
    }

    pub fn progress(self: Before, input: Count, output: Count) core.Error!core.Progress {
        return .{
            .input_read = try count.toLocal(input - self.input),
            .output_written = try count.toLocal(output - self.output),
        };
    }
};

pub fn inputWindow(total: Count, input: []const u8) []const u8 {
    return input[0..count.bounded(std.math.maxInt(Count) - total, input.len)];
}

pub fn outputWindow(total: Count, member: Count, output: []u8) []u8 {
    const remaining = std.math.maxInt(Count) - @max(total, member);
    return output[0..count.bounded(remaining, output.len)];
}

/// A valid two-byte candidate may accept its first byte at the final available
/// stream position. Rejected trailing bytes never require a counter advance.
pub fn probe(prefix: *member_prefix.Prefix, kind: member_prefix.Kind, total: *Count, input: []const u8) core.Error!member_prefix.Result {
    var next = prefix.*;
    var probed = next.probe(kind, input);
    const available = inputWindow(total.*, input).len;
    if (probed.accepted > available) {
        next = prefix.*;
        probed = next.probe(kind, input[0..available]);
        if (probed.accepted == 0) return error.IntegerOverflow;
    }
    const next_total = try count.addLocal(total.*, probed.accepted);
    prefix.* = next;
    total.* = next_total;
    if (probed.decision == .need_input and available < input.len)
        return error.IntegerOverflow;
    return probed;
}

test "wrapper counter prefix keeps the final accepted byte on overflow" {
    const maximum = std.math.maxInt(Count);
    for ([_]member_prefix.Kind{ .zlib, .gzip }) |kind| {
        const bytes: [2]u8 = if (kind == .zlib) .{ 0x78, 0x01 } else .{ 0x1f, 0x8b };
        var prefix = member_prefix.Prefix.init();
        var total: Count = maximum - 1;
        try std.testing.expectError(error.IntegerOverflow, probe(&prefix, kind, &total, &bytes));
        try std.testing.expectEqual(maximum, total);
        try std.testing.expectEqual(@as(u2, 1), prefix.received);
        try std.testing.expectEqual(bytes[0], prefix.bytes[0]);
        // Rejection consumes no new byte, even at the counter maximum.
        const rejected = try probe(&prefix, kind, &total, &.{0});
        try std.testing.expectEqual(member_prefix.Decision.trailing, rejected.decision);
        try std.testing.expectEqual(@as(usize, 0), rejected.accepted);
        try std.testing.expectEqual(maximum, total);
        try std.testing.expectEqual(@as(u2, 1), prefix.received);
        // A valid continuation cannot be accepted beyond the maximum.
        try std.testing.expectError(error.IntegerOverflow, probe(&prefix, kind, &total, bytes[1..]));
        try std.testing.expectEqual(@as(u2, 1), prefix.received);
        prefix.reset();
        try std.testing.expectError(error.IntegerOverflow, probe(&prefix, kind, &total, &bytes));
        try std.testing.expectEqual(@as(u2, 0), prefix.received);
    }
}
