const std = @import("std");
const memo = @import("memo");
export fn verifyHashReuse() u32 {
    var old: memo.Cache = .{};
    var reused: memo.Cache = .{};
    var pool: [16][256]u32 = @splat(@splat(0));
    for (&pool, 0..) |*hist, i| {
        hist[17] = @intCast(i + 1);
        while (memo.histogramHash(hist) & 31 != 7) hist[0] += 1;
    }
    var state: u32 = 0x243f6a88;
    for (0..1024) |request| {
        state = state *% 1664525 +% 1013904223;
        const idx = if (request % 3 == 0) 0 else state >> 28;
        const hist = &pool[idx];
        const hash = memo.histogramHash(hist);
        const expected = old.get(true, hist);
        const actual = reused.getHashed(true, hist, hash);
        if (!std.meta.eql(expected, actual)) return 1;
        if (expected == null) {
            old.put(hist, 100 + idx, @intCast(request % 4));
            reused.putHashed(hist, hash, 100 + idx, @intCast(request % 4));
        }
    }
    if (!std.meta.eql(old, reused)) return 2;
    if (old.hits == 0 or old.conflict_misses == 0) return 3;
    return 0;
}
