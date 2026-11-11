//! Checked destination sizing shared by direct and scoped append publication.
const std = @import("std");

pub fn appendEnd(start: usize, additional: usize) error{IntegerOverflow}!usize {
    return std.math.add(usize, start, additional) catch error.IntegerOverflow;
}

/// Scalar format/options preflight precedes an impossible exact length across
/// legacy and scoped facades. Ordinary calls do not repeat header parsing.
pub fn exactAppendEnd(comptime Codec: type, start: usize, additional: usize, stream: []const u8, options: Codec.DecodeOptions) Codec.Error!usize {
    return appendEnd(start, additional) catch |err| {
        _ = try Codec.preflight(stream, options, std.math.maxInt(Codec.Counter));
        return err;
    };
}

pub fn ensureAppendCapacity(allocator: std.mem.Allocator, out: *std.ArrayList(u8), additional: usize) (std.mem.Allocator.Error || error{IntegerOverflow})!void {
    const required = try appendEnd(out.items.len, additional);
    try out.ensureTotalCapacity(allocator, required);
}
