//! Check training savings against actual public encoder and decoder calls.
const std = @import("std");

pub fn check(comptime Br: type, samples: []const []const u8, trained: anytype, minimum_savings_percent: usize) !void {
    const a = std.testing.allocator;
    const parsed = try trained.parse();
    var baseline_bytes: usize = 0;
    var trained_bytes: usize = 0;
    for (samples) |sample| {
        const baseline = try Br.encodePlannedStreamWithOptionsAlloc(a, sample, .{ .quality = 5 });
        defer a.free(baseline);
        const baseline_plain = try Br.decodeStreamAllocExactSize(a, baseline, sample.len);
        defer a.free(baseline_plain);
        try std.testing.expectEqualSlices(u8, sample, baseline_plain);
        baseline_bytes += baseline.len;

        const wire = try Br.encodePlannedStreamWithOptionsAlloc(a, sample, .{
            .quality = 5,
            .shared_dictionary = .{ .serialized = &parsed },
        });
        defer a.free(wire);
        const plain = try Br.decodeStreamAllocExactSizeWithOptions(a, wire, sample.len, .{
            .shared_dictionary = .{ .serialized = &parsed },
        });
        defer a.free(plain);
        try std.testing.expectEqualSlices(u8, sample, plain);
        trained_bytes += wire.len;
    }
    try std.testing.expectEqual(baseline_bytes, trained.baseline_frame_bytes);
    try std.testing.expectEqual(trained_bytes, trained.trained_frame_bytes);
    try std.testing.expectEqual(trained.bytes.len, trained.charged_dictionary_bytes);
    const total = trained_bytes + trained.bytes.len;
    try std.testing.expect(total < baseline_bytes);
    try std.testing.expectEqual(baseline_bytes - total, trained.total_savings_bytes);
    try std.testing.expect(trained.total_savings_bytes * 100 >= baseline_bytes * minimum_savings_percent);
}
