const std = @import("std");
const h = @import("helpers.zig");
const HQ = @import("../../hq_parser.zig");
const Old = @import("../../hq_parser_row_tags_reference.zig");
const a = std.testing.allocator;

pub fn contracts() !void {
    const source = h.source_mod.Source.init("abc", "", "abcabcXabcabcY", 1024);
    inline for (.{ false, true }) |whole| {
        inline for (.{ false, true }) |complete| {
            for ([_]h.Options{ .{}, .{ .strategy = .btultra2 } }) |selected| {
                var params: h.state.Parameters = .{
                    .strategy = selected.strategy,
                    .hq_options = .{
                        .search_depth = 8,
                        .nice_len = 16,
                        .parse_mode = if (whole) .whole_block else .bounded,
                        .match_lengths = if (complete) .complete else .sampled,
                    },
                };
                const old_required = try Old.requiredWorkingMemory(source, params);
                const required = try HQ.requiredWorkingMemory(source, params);
                const extra = 16 * (source.block.len + 1);
                try std.testing.expectEqual(old_required + extra, required);
                // A caller supplying the old exact cap remains subject to
                // the new public preflight; adding tags does not waive it.
                params.hq_options.max_working_memory = old_required;
                const before = try Old.planAlloc(a, source, params);
                defer before.deinit(a);
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, HQ.planAlloc(a, source, params));
                params.hq_options.max_working_memory = required;
                const after = try HQ.planAlloc(a, source, params);
                defer after.deinit(a);
                try std.testing.expectEqualDeep(before.records, after.records);
                try std.testing.expectEqualDeep(before.offset_values, after.offset_values);
                try std.testing.expectEqualDeep(before.statistics, after.statistics);
                try std.testing.expectEqual(before.estimated_cost, after.estimated_cost);
                params.hq_options.max_working_memory = 0;
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, HQ.planAlloc(a, source, params));
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, Old.planAlloc(a, source, params));
            }
        }
    }
}
