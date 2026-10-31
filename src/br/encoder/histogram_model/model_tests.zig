const std = @import("std");
const model = @import("../histogram_model.zig");
const reference = @import("log_q8_tests.zig").reference;

test "histogram exact log complete cost models preserve empty sparse boundary and large totals" {
    inline for (.{ 24, 64, 256, 704 }) |size| {
        const H = model.Histogram(size);
        for (0..8) |fixture| {
            var histogram: H = .{};
            var random: u32 = 0x23910847;
            for (&histogram.counts, 0..) |*count, symbol| {
                random = random *% 1664525 +% 1013904223;
                count.* = switch (fixture) {
                    0 => 0,
                    1 => if (symbol == size - 1) 1 else 0,
                    2 => if (symbol % 17 == 0) 1024 else 0,
                    3 => @intCast(symbol % 2049),
                    4 => 4096,
                    5 => std.math.maxInt(u32),
                    6 => if (symbol & 1 == 0) std.math.maxInt(u32) else 0,
                    7 => random,
                    else => unreachable,
                };
                histogram.total += count.*;
            }
            const before = histogram;
            const actual = histogram.costModel();
            const total_log = reference(histogram.total);
            var entropy: u64 = 0;
            for (&histogram.counts, &actual.symbol_costs_q8) |count, price| {
                const expected = if (count == 0) total_log + 512 else total_log - reference(count);
                try std.testing.expectEqual(expected, price);
                entropy += @as(u64, count) * expected;
            }
            try std.testing.expectEqual(histogram.total, actual.population);
            try std.testing.expectEqual(entropy, actual.entropy_cost_q8);
            try std.testing.expectEqual(@max(entropy, histogram.total * 256), actual.population_cost_q8);
            try std.testing.expectEqualDeep(before, histogram);
        }
    }
}
