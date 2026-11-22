const std = @import("std");
const fixtures = @import("fixtures.zig");
const counts = @import("malformed_count.zig");
const t = std.testing;

fn rejectRaw(comptime C: type, raw: []const u8) !void {
    const input = try t.allocator.dupe(u8, raw);
    defer t.allocator.free(input);
    const before = try t.allocator.dupe(u8, input);
    defer t.allocator.free(before);
    try t.expectError(error.InvalidPuffinStream, C.puffDeflatePaddedAlloc(t.allocator, input, 0, input.len * 8, 65536));
    try t.expectEqualSlices(u8, before, input);
}

fn rejectPuff(comptime C: type, puff: []const u8) !void {
    const input = try t.allocator.dupe(u8, puff);
    defer t.allocator.free(input);
    const before = try t.allocator.dupe(u8, input);
    defer t.allocator.free(before);
    try t.expectError(error.InvalidPuffinStream, C.huffDeflateAlloc(t.allocator, input, 0, 4096));
    try t.expectEqualSlices(u8, before, input);
}

pub fn contracts(comptime C: type) !void {
    try rejectRaw(C, &counts.raw);
    const raw_overrun = try fixtures.rawRepeatOverrun();
    defer t.allocator.free(raw_overrun);
    try rejectRaw(C, raw_overrun);
    const puff_overrun = try fixtures.puffRepeatOverrun();
    defer t.allocator.free(puff_overrun);
    try rejectPuff(C, puff_overrun);
    inline for (.{ @as(u8, 30), @as(u8, 31) }) |raw| {
        const first = try fixtures.rawInvalidFields(raw, 0);
        defer t.allocator.free(first);
        try rejectRaw(C, first);
        const second = try fixtures.rawInvalidFields(0, raw);
        defer t.allocator.free(second);
        try rejectRaw(C, second);
        const puff_first = try fixtures.invalidFields(raw, 0, 0);
        defer t.allocator.free(puff_first);
        try rejectPuff(C, puff_first);
        const puff_second = try fixtures.invalidFields(0, raw, 0);
        defer t.allocator.free(puff_second);
        try rejectPuff(C, puff_second);
    }
    const bad_hclen = try fixtures.invalidFields(0, 0, 16);
    defer t.allocator.free(bad_hclen);
    try rejectPuff(C, bad_hclen);
    inline for (.{ fixtures.Mode.empty_codes, fixtures.Mode.empty_literal, fixtures.Mode.empty_distance_use }) |mode| {
        var fixture = try fixtures.make(mode, 0);
        defer fixture.deinit();
        try rejectRaw(C, fixture.raw);
        try rejectPuff(C, fixture.puff);
    }
    var assigned = try fixtures.make(.match, 0);
    defer assigned.deinit();
    const token_start = assigned.puff.len - 5;
    // Reject an out-of-range encoded distance before its u16 + 1 can wrap.
    inline for (.{ @as(u16, 0x8000), @as(u16, 0xffff) }) |distance| {
        const bad = try t.allocator.dupe(u8, assigned.puff);
        defer t.allocator.free(bad);
        std.mem.writeInt(u16, bad[token_start + 1 ..][0..2], distance, .big);
        try rejectPuff(C, bad);
    }
    try t.expectError(error.InvalidPuffinStream, C.huffDeflateAlloc(t.allocator, assigned.puff[0 .. token_start + 2], 0, 4096));
}
