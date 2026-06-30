const std = @import("std");
const checksum = @import("checksum.zig");

pub const DictionaryId = packed struct(u64) {
    crc32: u32,
    length: u32,

    pub fn fromBytes(bytes: []const u8) DictionaryId {
        return .{ .crc32 = checksum.crc32(bytes), .length = @truncate(bytes.len) };
    }

    pub fn asInt(self: DictionaryId) u64 {
        return @bitCast(self);
    }
};

pub const Metadata = struct {
    id: DictionaryId,
    content_len: usize,
    window_len: usize,

    pub fn fromBytes(bytes: []const u8, window_len: usize) Metadata {
        return .{ .id = .fromBytes(bytes), .content_len = bytes.len, .window_len = window_len };
    }
};

pub const TrainingPlan = struct {
    target_size: usize,
    sample_count: usize,
    total_sample_bytes: usize,
};

pub fn planTraining(samples: []const []const u8, target_size: usize) TrainingPlan {
    var total: usize = 0;
    for (samples) |sample| total += sample.len;
    return .{ .target_size = target_size, .sample_count = samples.len, .total_sample_bytes = total };
}

test "dictionary IDs are stable and content sensitive" {
    const a = DictionaryId.fromBytes("dictionary contents");
    const b = DictionaryId.fromBytes("dictionary contents");
    const c = DictionaryId.fromBytes("different contents");
    try std.testing.expectEqual(a.asInt(), b.asInt());
    try std.testing.expect(a.asInt() != c.asInt());
}

test "training plan summarizes sample corpus" {
    const samples = [_][]const u8{ "alpha", "beta", "gamma" };
    const plan = planTraining(&samples, 1024);
    try std.testing.expectEqual(@as(usize, 1024), plan.target_size);
    try std.testing.expectEqual(@as(usize, 3), plan.sample_count);
    try std.testing.expectEqual(@as(usize, 14), plan.total_sample_bytes);
}
