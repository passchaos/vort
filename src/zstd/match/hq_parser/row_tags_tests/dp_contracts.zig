const std = @import("std");
const h = @import("helpers.zig");

pub fn contracts() !void {
    var random: [64]u8 = undefined;
    h.random(&random);
    const patterns = [_][]const u8{ "", "x", "abcabcXabcabcY", "abca" ** 20, &random };
    inline for (.{ false, true }) |whole| {
        inline for (.{ false, true }) |complete| {
            for ([_]h.Options{ .{}, .{ .strategy = .btultra } }) |selected| {
                for ([_]u8{ 3, 7 }) |minimum| {
                    for (patterns) |input| {
                        const sources = [_]h.source_mod.Source{
                            h.source_mod.Source.init("", "", input, 1024),
                            h.source_mod.Source.init("abca", "abcabcXY", input, 1024),
                        };
                        for (sources) |source| {
                            const result = try h.compare(source, .{
                                .strategy = selected.strategy,
                                .whole = whole,
                                .complete = complete,
                                .minimum = minimum,
                                .repeats = .{ 4, 4, 8 },
                            });
                            try std.testing.expectEqual(@as(?anyerror, null), result.failure);
                        }
                    }
                }
            }
        }
    }
    // With LL0, rep0=1 produces a zero candidate distance. The other two
    // repeats exceed the current window; DP filters them before Cache calls.
    const filtered = try h.compare(h.source_mod.Source.init("", "", "abcabcXabcabcY", 1024), .{ .repeats = .{ 1, 1025, 65535 } });
    try std.testing.expectEqual(@as(?anyerror, null), filtered.failure);
    var multi: [4108]u8 = undefined;
    h.random(&multi);
    @memcpy(multi[4094..4102], multi[40..48]);
    inline for (.{ false, true }) |whole| {
        inline for (.{ false, true }) |complete| {
            const result = try h.compare(h.source_mod.Source.init("", "", &multi, 8192), .{ .whole = whole, .complete = complete });
            try std.testing.expectEqual(@as(?anyerror, null), result.failure);
        }
    }
    try @import("budgets.zig").contracts();
}
