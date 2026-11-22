const std = @import("std");
const fixtures = @import("fixtures.zig");
const real = @import("real_sample.zig");
const t = std.testing;

fn protectedRoundtrip(comptime C: type, raw: []const u8, expected_puff: []const u8, offset: u3, bits: u64) !void {
    const storage = try t.allocator.alloc(u8, raw.len + 32);
    defer t.allocator.free(storage);
    @memset(storage, 0xa5);
    @memcpy(storage[16..][0..raw.len], raw);
    const before = try t.allocator.dupe(u8, storage);
    defer t.allocator.free(before);
    const source = storage[16..][0..raw.len];
    const result = try C.puffDeflatePaddedAlloc(t.allocator, source, offset, raw.len * 8 - offset, 65536);
    defer t.allocator.free(result.bytes);
    try t.expectEqual(bits, result.consumed_bits);
    try t.expectEqualSlices(u8, expected_puff, result.bytes);
    const restored = try C.huffDeflateAlloc(t.allocator, result.bytes, offset, bits);
    defer t.allocator.free(restored);
    try t.expectEqualSlices(u8, source, restored);
    const exact = try C.puffDeflateAlloc(t.allocator, source, offset, bits, expected_puff.len);
    defer t.allocator.free(exact);
    try t.expectEqualSlices(u8, expected_puff, exact);
    try t.expectEqualSlices(u8, before, storage);
}

pub fn contracts(comptime C: type) !void {
    try protectedRoundtrip(C, &real.raw, &real.puff, 0, real.exact_bits);
    inline for (.{
        fixtures.Mode.empty_distance, fixtures.Mode.incomplete, fixtures.Mode.incomplete_codes, fixtures.Mode.singleton_eob,
        fixtures.Mode.max_counts,     fixtures.Mode.match,
    }) |mode| {
        for (0..8) |offset| {
            var fixture = try fixtures.make(mode, @intCast(offset));
            defer fixture.deinit();
            try protectedRoundtrip(C, fixture.raw, fixture.puff, fixture.offset, fixture.exact_bits);
        }
    }
    // The incomplete and match-first vectors intentionally do not promise
    // inflate-tree completeness or history semantics. Puffin conversion only
    // reads assigned canonical codes and preserves the supplied metadata.
}
