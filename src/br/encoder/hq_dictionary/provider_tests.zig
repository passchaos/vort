const std = @import("std");
const dictionary = @import("../hq_dictionary.zig");
const options = @import("../hq_options.zig");
const types = @import("../hq_types.zig");
const static_matcher = @import("../static_dictionary_matcher.zig");
const serialized = @import("../../serialized_dictionary.zig");
const builder = @import("../../serialized_dictionary_builder.zig");

test "Brotli HQ dictionary provider preserves short static raw boundaries and failed query frontier" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var budget = dictionary.Budget.init(failing.allocator(), 64 * 1024 * 1024);
    var profile: options.HqProfile = .{};
    var provider = try dictionary.Provider.init(&budget, .{ .raw_prefixes = &.{ "hello", "world" } }, &profile);
    defer provider.deinit();
    const a = budget.allocator();
    const sentinel: dictionary.Candidate = .{ .source = .static, .copy_len = 4, .output_len = 1, .address = 999 };
    var candidates: std.ArrayList(dictionary.Candidate) = .{ .items = try a.dupe(dictionary.Candidate, &.{sentinel}), .capacity = 1 };
    defer candidates.deinit(a);
    failing.fail_index = failing.alloc_index;
    failing.resize_fail_index = 0;
    try std.testing.expectError(error.OutOfMemory, provider.appendCandidates("ime", 0, 0, 3, &candidates));
    try std.testing.expectEqual(@as(usize, 1), candidates.items.len);
    try std.testing.expectEqualDeep(sentinel, candidates.items[0]);
    try std.testing.expect(profile.static_candidates > 0);
    failing.fail_index = std.math.maxInt(usize);
    const original_limit = budget.limit;
    budget.limit = budget.live;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, provider.appendCandidates("ime", 0, 0, 3, &candidates));
    try std.testing.expectEqual(@as(usize, 1), candidates.items.len);
    try std.testing.expectEqualDeep(sentinel, candidates.items[0]);
    budget.limit = original_limit;
    try provider.appendCandidates("ime", 0, 0, 3, &candidates);
    var short_found = false;
    for (candidates.items[1..]) |candidate| {
        if (candidate.source == .static and candidate.copy_len == 4 and candidate.output_len == 3 and candidate.address == 3 * 1024) {
            short_found = true;
            const command = candidate.command(0, 0);
            try std.testing.expectEqual(@as(usize, 4), command.copy_len);
            try std.testing.expectEqual(@as(usize, 3), command.outputLen());
            try std.testing.expect(!command.updatesRecentDistance());
        }
    }
    try std.testing.expect(short_found);
    candidates.clearRetainingCapacity();
    try provider.appendCandidates("lowor", 0, 0, 5, &candidates);
    var boundary_found = false;
    const source = try types.Source.init("", "lowor", 22, 100);
    for (candidates.items) |candidate| {
        if (candidate.source == .compound and candidate.address == 3 and candidate.output_len == 5) {
            boundary_found = true;
            try std.testing.expectEqual(@as(usize, 107), try provider.wireDistance(candidate, source, 0));
        }
    }
    try std.testing.expect(boundary_found);
    try std.testing.expectEqual(@as(usize, 10), provider.dictionarySize());
    try std.testing.expect(profile.peak_working_memory <= budget.limit);
    var denied = dictionary.Budget.init(std.testing.allocator, static_matcher.CandidateIndex.requiredWorkingMemory() - 1);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, dictionary.Provider.init(&denied, .{}, null));
    try std.testing.expectEqual(@as(usize, 0), denied.peak);
}

test "Brotli HQ dictionary provider uses serialized contextual address authority and actual budgets" {
    var bits: [32]u8 = @splat(0);
    bits[4] = 1;
    var contexts: [64]u6 = undefined;
    for (&contexts, 0..) |*context, i| context.* = @intFromBool(i >= 32);
    const encoded = try builder.serializeAlloc(std.testing.allocator, .{
        .raw_prefix = "prefix",
        .word_lists = &.{ .{ .size_bits_by_length = bits, .data = "cat!dog!" }, .{ .size_bits_by_length = bits, .data = "red!blue" } },
        .transform_lists = &.{.{ .prefix_suffix = &.{0}, .transforms = &.{ 0, 0, 0 } }},
        .dictionaries = &.{ .{ .word_list_index = 0, .transform_list_index = 0 }, .{ .word_list_index = 1, .transform_list_index = 0 } },
        .context_map = &contexts,
    });
    defer std.testing.allocator.free(encoded);
    const parsed = try serialized.parse(encoded);
    var budget = dictionary.Budget.init(std.testing.allocator, 4 * 1024 * 1024);
    var provider = try dictionary.Provider.init(&budget, .{ .raw_prefixes = &.{"raw"}, .serialized = &parsed }, null);
    defer provider.deinit();
    var candidates: std.ArrayList(dictionary.Candidate) = .empty;
    defer candidates.deinit(budget.allocator());
    const source = try types.Source.init("", "red!", 22, 10);
    for ([_]usize{ 0, 32 }) |context| {
        candidates.clearRetainingCapacity();
        try provider.appendCandidates("red!", 0, context, 4, &candidates);
        var found = false;
        for (candidates.items) |candidate| {
            if (candidate.source == .static and candidate.copy_len == 4 and candidate.output_len == 4 and candidate.address == @as(usize, if (context == 0) 2 else 0)) {
                found = true;
                var scratch: [serialized.max_transformed_word_len]u8 = undefined;
                const bytes = try provider.dictionary.staticWord(context, candidate.address, candidate.copy_len, &scratch);
                try std.testing.expectEqualStrings("red!", bytes);
                try std.testing.expectEqual(@as(usize, 10 + 9 + 1) + candidate.address, try provider.wireDistance(candidate, source, 0));
            }
        }
        try std.testing.expect(found);
    }
    try std.testing.expectEqual(@as(usize, 9), provider.dictionarySize());
    try std.testing.expect(budget.peak < budget.limit);
}
