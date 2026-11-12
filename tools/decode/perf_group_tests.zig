//! Pure CI contracts. These tests never open a PMU or change system settings.
const std = @import("std");
const builtin = @import("builtin");
const perf = @import("perf_group.zig");

const ids = [_]u64{ 701, 902, 1103 };
const valid = [_]u64{ 3, 6000, 6000, 101, 701, 203, 902, 37, 1103 };

fn encode(words: [9]u64) [72]u8 {
    var bytes: [72]u8 = undefined;
    for (words, 0..) |word, index|
        std.mem.writeInt(u64, bytes[index * 8 ..][0..8], word, builtin.target.cpu.arch.endian());
    return bytes;
}

test "PMU group parser retains all raw words and uses IDs for semantic order" {
    const shuffled = [_]u64{ 3, 6000, 6000, 37, 1103, 101, 701, 203, 902 };
    const counts = try perf.parseWords(ids, shuffled);
    try std.testing.expectEqual(@as(u64, 101), counts.cycles);
    try std.testing.expectEqual(@as(u64, 203), counts.instructions);
    try std.testing.expectEqual(@as(u64, 37), counts.third_event);
    try std.testing.expectEqual(@as(u64, 6000), counts.time_enabled);
    try std.testing.expectEqual(@as(u64, 6000), counts.time_running);
    try std.testing.expectEqual(shuffled, counts.raw_words);
    try std.testing.expectEqual(ids, counts.event_ids);
    const bytes = encode(shuffled);
    try std.testing.expectEqualDeep(counts, try perf.parseRead(ids, &bytes));
}

test "PMU group parser rejects every short payload and extra bytes" {
    const bytes = encode(valid);
    for (0..bytes.len) |length|
        try std.testing.expectError(error.PerfReadTruncated, perf.parseRead(ids, bytes[0..length]));
    const oversized = bytes ++ [_]u8{0} ** 8;
    try std.testing.expectError(error.PerfReadSizeMismatch, perf.parseRead(ids, &oversized));
}

test "PMU group parser validates nr and all expected and returned IDs" {
    for ([_]u64{ 0, 1, 2, 4, std.math.maxInt(u64) }) |nr| {
        var words = valid;
        words[0] = nr;
        try std.testing.expectError(error.PerfEventCountMismatch, perf.parseWords(ids, words));
    }
    try std.testing.expectError(error.PerfInvalidExpectedIds, perf.parseWords(.{ 0, 902, 1103 }, valid));
    try std.testing.expectError(error.PerfInvalidExpectedIds, perf.parseWords(.{ 701, 701, 1103 }, valid));
    for ([_]usize{ 4, 6, 8 }) |position| {
        var zero = valid;
        zero[position] = 0;
        try std.testing.expectError(error.PerfInvalidReadId, perf.parseWords(ids, zero));
        var unknown = valid;
        unknown[position] = 9999;
        try std.testing.expectError(error.PerfUnknownReadId, perf.parseWords(ids, unknown));
    }
    var duplicate = valid;
    duplicate[6] = duplicate[4];
    try std.testing.expectError(error.PerfDuplicateReadId, perf.parseWords(ids, duplicate));
}

test "PMU group requires nonzero core counts and full running time without scaling" {
    for ([_]usize{ 3, 5 }) |position| {
        var words = valid;
        words[position] = 0;
        try std.testing.expectError(error.PerfZeroCoreCounts, perf.parseWords(ids, words));
    }
    for ([_]usize{ 1, 2 }) |position| {
        var words = valid;
        words[position] = 0;
        try std.testing.expectError(error.PerfZeroTime, perf.parseWords(ids, words));
    }
    var partial = valid;
    partial[2] = 5999;
    try std.testing.expectError(error.PerfGroupNotFullyRunning, perf.parseWords(ids, partial));
    partial[2] = 6001;
    try std.testing.expectError(error.PerfInvalidRunningTime, perf.parseWords(ids, partial));
    var no_misses = valid;
    no_misses[7] = 0;
    const zero = try perf.parseWords(ids, no_misses);
    try std.testing.expectEqual(@as(u64, 0), zero.third_event);
    try std.testing.expectEqual(no_misses, zero.raw_words);
    var large = valid;
    large[3] = std.math.maxInt(u64);
    large[5] = std.math.maxInt(u64);
    try std.testing.expectEqual(std.math.maxInt(u64), (try perf.parseWords(ids, large)).cycles);
}

test "PMU group metadata separates three-event groups and states raw cumulative scope" {
    const branches = perf.metadata(.branches);
    const misses = perf.metadata(.branch_misses);
    try std.testing.expectEqual([_]u64{ 0, 1, 4 }, branches.hardware_configs);
    try std.testing.expectEqual([_]u64{ 0, 1, 5 }, misses.hardware_configs);
    try std.testing.expectEqualStrings("branches", branches.events[2]);
    try std.testing.expectEqualStrings("branch-misses", misses.events[2]);
    try std.testing.expectEqual(@as(u64, 15), branches.read_format);
    try std.testing.expectEqual(@as(i32, 0), branches.pid_argument);
    try std.testing.expectEqual(@as(i32, -1), branches.cpu_argument);
    try std.testing.expect(branches.disabled_at_open and branches.exclude_kernel and branches.exclude_hv);
    try std.testing.expect(!branches.inherit and !branches.values_scaled and branches.strict_full_running_time);
    try std.testing.expect(std.mem.indexOf(u8, branches.time_scope, "cumulative") != null);
    try std.testing.expectEqual(@as(usize, 72), perf.read_byte_count);
}
