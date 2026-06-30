const std = @import("std");
const store = @import("store.zig");

pub const CorpusStats = struct {
    cases: usize = 0,
    valid_frames: usize = 0,
    expected_errors: usize = 0,
};

/// Deterministic malformed-input smoke harness for early frame parsers.
/// This is intentionally small and fast enough to run in `zig build test` while
/// preserving concrete regression cases that future fuzzing can extend.
pub fn runStoreSmokeCorpus(allocator: std.mem.Allocator) !CorpusStats {
    var stats = CorpusStats{};

    const malformed = [_][]const u8{
        "",
        "V",
        "VOR",
        "VORT",
        "xxxx____________________________",
        "VORT\x01\x00\x00\x00________________________",
        "VORT\x00\x01\x00\x00________________________",
    };
    for (malformed) |case| {
        stats.cases += 1;
        if (store.parseHeader(case)) |_| {
            return error.UnexpectedValidFrame;
        } else |err| switch (err) {
            error.TruncatedFrame,
            error.InvalidMagic,
            error.UnsupportedVersion,
            error.CorruptFrame,
            => stats.expected_errors += 1,
            else => return err,
        }
    }

    const payloads = [_][]const u8{ "", "a", "aaaaabbbbbccccc", "0123456789" ** 8 };
    for (payloads) |payload| {
        stats.cases += 1;
        var encoded: [256]u8 = undefined;
        const encoded_len = try store.encode(payload, &encoded);
        const decoded = try store.decodeAlloc(allocator, encoded[0..encoded_len]);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
        stats.valid_frames += 1;
    }

    return stats;
}

test "store smoke corpus covers malformed and valid frames" {
    const stats = try runStoreSmokeCorpus(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 11), stats.cases);
    try std.testing.expectEqual(@as(usize, 4), stats.valid_frames);
    try std.testing.expectEqual(@as(usize, 7), stats.expected_errors);
}
