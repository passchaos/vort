const std = @import("std");
const edges = @import("search_edges.zig");
const h = @import("row_tags_tests/edges/helpers.zig");

const Sorted = struct {
    pub const Spill = edges.Spill;
    pub const Context = edges.SortedContext;
};

test "Zstd HQ search strict cost filter preserves target rows quotas and spills" {
    inline for (.{ false, true }) |whole| {
        inline for (.{ false, true }) |complete| {
            for ([_]usize{ 1, 8, 16 }) |width| {
                for ([_]bool{ false, true }) |tagged| {
                    for ([_]?u64{ null, 0, 1, 17, 65 }) |quota| {
                        for ([_]?u64{ null, 0, 2000 }) |full_cost| {
                            _ = try h.compare(Sorted, whole, complete, width, .{
                                .maximum = 100,
                                .limit = quota,
                                .repetitions = 2,
                                .tagged = tagged,
                                .full_cost = full_cost,
                            });
                        }
                    }
                    // Equal costs must retain the complete original key/tie
                    // comparator even when every target slot is occupied.
                    _ = try h.compare(Sorted, whole, complete, width, .{
                        .maximum = 40,
                        .cost = 0,
                        .literal_len = 0,
                        .pricing = .zero,
                        .full_cost = 0,
                        .tagged = tagged,
                    });
                    // Strict cost filtering is restricted to in-horizon rows;
                    // crossing edges still update the exact spill continuation.
                    _ = try h.compare(Sorted, whole, complete, width, .{
                        .maximum = 100,
                        .goal = if (!whole and complete) 30 else null,
                        .full_cost = 0,
                        .tagged = tagged,
                    });
                }
            }
        }
    }
}

test "Zstd HQ search strict cost filter preserves validation and overflow precedence" {
    inline for (.{ false, true }) |whole| {
        inline for (.{ false, true }) |complete| {
            for ([_]usize{ 1, 8, 16 }) |width| {
                for ([_]bool{ false, true }) |tagged| {
                    for ([_]?u64{ null, 0, 1 }) |quota| {
                        // An invalid symbol or accumulated cost must still
                        // fail even if every valid row would reject the edge.
                        _ = try h.compare(Sorted, whole, complete, width, .{
                            .maximum = 3,
                            .cost = std.math.maxInt(u64),
                            .limit = quota,
                            .full_cost = 0,
                            .tagged = tagged,
                        });
                        _ = try h.compare(Sorted, whole, complete, width, .{
                            .maximum = 3,
                            .literal_len = std.math.maxInt(u32),
                            .limit = quota,
                            .full_cost = 0,
                            .tagged = tagged,
                        });
                    }
                }
            }
        }
    }
}
