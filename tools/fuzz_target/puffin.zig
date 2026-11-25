const std = @import("std");
const vort = @import("vort");
const seed = @import("puffin_seed.zig");

pub const max_input_len: usize = 64 * 1024;
pub const max_output_len: usize = 64 * 1024;

fn expected(err: anyerror) bool {
    return switch (err) {
        error.InvalidPuffinStream,
        error.TruncatedFrame,
        error.TrailingData,
        error.SizeMismatch,
        error.OutputTooSmall,
        error.OutputLimitExceeded,
        error.IntegerOverflow,
        => true,
        else => false,
    };
}

fn ownedBitsEqual(raw: []const u8, restored: []const u8, offset: u3, bits: u64) bool {
    const available = @as(u64, @intCast(raw.len)) * 8;
    if (offset > available or bits > available - offset) return false;
    const end = @as(u64, offset) + bits;
    if (restored.len != (end + 7) / 8) return false;
    for (restored, 0..) |byte, i| {
        var mask: u8 = 0xff;
        if (i == 0) mask &= @as(u8, 0xff) << offset;
        if (i == restored.len - 1 and end % 8 != 0)
            mask &= (@as(u8, 1) << @as(u3, @intCast(end % 8))) - 1;
        if (raw[i] & mask != byte & mask) return false;
    }
    return true;
}

fn fuzzRaw(allocator: std.mem.Allocator, raw: []const u8, offset: u3, cap: usize) !bool {
    const total_bits = @as(u64, @intCast(raw.len)) * 8;
    if (offset > total_bits) return false;
    if (vort.puffAndroidDeflatePaddedAlloc(allocator, raw, offset, total_bits - offset, cap)) |puff| {
        defer allocator.free(puff.bytes);
        const restored = vort.huffAndroidDeflateAlloc(allocator, puff.bytes, offset, puff.consumed_bits) catch |err| {
            if (err == error.OutOfMemory) return err;
            return error.PuffinRoundtripMismatch;
        };
        defer allocator.free(restored);
        if (!ownedBitsEqual(raw, restored, offset, puff.consumed_bits))
            return error.PuffinRoundtripMismatch;
        return true;
    } else |err| {
        if (!expected(err)) return err;
        return false;
    }
}

fn fuzzHuff(allocator: std.mem.Allocator, puff: []const u8, bits: u64) !void {
    if (vort.huffAndroidDeflateAlloc(allocator, puff, 0, bits)) |raw| {
        allocator.free(raw);
    } else |err| {
        if (!expected(err)) return err;
    }
}

pub fn fuzzOne(allocator: std.mem.Allocator, data: []const u8) !void {
    // Converter output is serialized tokens, not inflated history. Both the
    // source prefix and the huffer's requested allocation are explicitly small.
    const view = data[0..@min(data.len, max_input_len)];
    _ = try fuzzRaw(allocator, view, 0, max_output_len);
    if (view.len != 0) {
        const offset: u3 = @truncate(view[0]);
        const cap = if (view.len >= 2) @as(usize, std.mem.readInt(u16, view[0..2], .little)) else 16;
        _ = try fuzzRaw(allocator, view, offset, cap);
    }
    const bytes = @min(view.len, max_output_len / 4);
    try fuzzHuff(allocator, view, @as(u64, @intCast(bytes)) * 32);
    if (view.len != 0) try fuzzHuff(allocator, view, 0);
}

pub fn smoke(allocator: std.mem.Allocator, comptime visit: anytype) !usize {
    const fixtures = [_][]const u8{
        &.{ 3, 0 },
        &.{ 1, 0, 0, 0xff, 0xff },
        &seed.raw,
        &.{ 0x9a, 0x30, 0x61, 0xc2, 0x04, 0x40, 0x3e, 0, 0, 0xff, 0xff },
        &.{ 0x9a, 0x30, 0x61, 0xc2, 0x84, 0x09, 0x80, 0x7c, 0, 0, 0xff, 0xff },
    };
    var roundtrips: usize = 0;
    for (fixtures) |raw| {
        if (!try fuzzRaw(allocator, raw, 0, max_output_len)) return error.PuffinSeedRefused;
        try visit(allocator, raw);
        roundtrips += 1;
    }
    const puff = try vort.puffAndroidDeflateAlloc(allocator, &seed.raw, 0, seed.exact_bits, seed.puff.len);
    defer allocator.free(puff);
    if (!std.mem.eql(u8, &seed.puff, puff)) return error.PuffinSeedMismatch;
    try visit(allocator, puff);
    try fuzzHuff(allocator, puff, seed.exact_bits);

    // Prefix bits belong to the enclosing byte stream. Give them nonzero
    // values and compare only the converter's owned interval at all offsets.
    for (0..8) |start| {
        const offset: u3 = @intCast(start);
        var raw: [3]u8 = @splat(0);
        if (start != 0) raw[0] = @intCast((@as(u16, 1) << @as(u4, @intCast(start))) - 1);
        for (0..2) |bit| raw[(start + bit) / 8] |= @as(u8, 1) << @as(u3, @intCast((start + bit) % 8));
        const wire = raw[0 .. (start + 10 + 7) / 8];
        if (!try fuzzRaw(allocator, wire, offset, max_output_len)) return error.PuffinSeedRefused;
        try visit(allocator, wire);
        roundtrips += 1;
    }
    try visit(allocator, &.{ 0xfd, 0x1f, 0x80, 0xc0, 0xdf, 0x5f, 0x08 });
    try visit(allocator, &.{ 0x9a, 0x30, 0x61, 0xc2, 0x04, 0x40, 0x40, 0, 0, 0xff, 0xff });
    try visit(allocator, &.{ 0, 0, 0xa0, 0x80, 0xff, 0xff, 0xff, 0x81 });
    return roundtrips;
}
