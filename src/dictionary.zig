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

pub const TrainOptions = struct {
    target_size: usize,
    min_phrase_len: usize = 4,
    max_phrase_len: usize = 16,
    max_phrases: usize = 256,
};

const Phrase = struct {
    bytes: []const u8,
    score: usize,
};

pub fn trainAlloc(allocator: std.mem.Allocator, samples: []const []const u8, options: TrainOptions) ![]u8 {
    if (options.target_size == 0) return allocator.alloc(u8, 0);
    if (options.min_phrase_len == 0 or options.min_phrase_len > options.max_phrase_len) return error.InvalidDictionaryTraining;

    var phrases: std.ArrayList(Phrase) = .empty;
    defer phrases.deinit(allocator);

    for (samples) |sample| {
        if (sample.len < options.min_phrase_len) continue;
        var start: usize = 0;
        while (start + options.min_phrase_len <= sample.len) : (start += 1) {
            const max_len = @min(options.max_phrase_len, sample.len - start);
            var len = options.min_phrase_len;
            while (len <= max_len) : (len += 1) {
                const phrase = sample[start..][0..len];
                if (findPhrase(phrases.items, phrase)) |idx| {
                    phrases.items[idx].score += len;
                } else if (phrases.items.len < options.max_phrases) {
                    try phrases.append(allocator, .{ .bytes = phrase, .score = len });
                }
            }
        }
    }

    std.sort.heap(Phrase, phrases.items, {}, phraseBetter);

    var dict: std.ArrayList(u8) = .empty;
    errdefer dict.deinit(allocator);
    for (phrases.items) |phrase| {
        if (dict.items.len >= options.target_size) break;
        if (containsSlice(dict.items, phrase.bytes)) continue;
        const remaining = options.target_size - dict.items.len;
        try dict.appendSlice(allocator, phrase.bytes[0..@min(remaining, phrase.bytes.len)]);
    }
    return dict.toOwnedSlice(allocator);
}

fn findPhrase(phrases: []const Phrase, bytes: []const u8) ?usize {
    for (phrases, 0..) |phrase, i| {
        if (std.mem.eql(u8, phrase.bytes, bytes)) return i;
    }
    return null;
}

fn phraseBetter(_: void, lhs: Phrase, rhs: Phrase) bool {
    if (lhs.score != rhs.score) return lhs.score > rhs.score;
    if (lhs.bytes.len != rhs.bytes.len) return lhs.bytes.len > rhs.bytes.len;
    return std.mem.lessThan(u8, lhs.bytes, rhs.bytes);
}

fn containsSlice(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

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

test "dictionary trainer is deterministic and extracts repeated phrases" {
    const samples = [_][]const u8{
        "alpha beta alpha beta alpha beta",
        "gamma alpha beta gamma alpha beta",
    };
    const dict1 = try trainAlloc(std.testing.allocator, &samples, .{ .target_size = 32, .min_phrase_len = 5, .max_phrase_len = 10 });
    defer std.testing.allocator.free(dict1);
    const dict2 = try trainAlloc(std.testing.allocator, &samples, .{ .target_size = 32, .min_phrase_len = 5, .max_phrase_len = 10 });
    defer std.testing.allocator.free(dict2);
    try std.testing.expectEqualSlices(u8, dict1, dict2);
    try std.testing.expect(std.mem.indexOf(u8, dict1, "alpha") != null);
    try std.testing.expect(dict1.len <= 32);
    const meta = Metadata.fromBytes(dict1, 32 * 1024);
    try std.testing.expectEqual(dict1.len, meta.content_len);
}

test "dictionary trainer handles empty target" {
    const samples = [_][]const u8{"sample"};
    const dict = try trainAlloc(std.testing.allocator, &samples, .{ .target_size = 0 });
    defer std.testing.allocator.free(dict);
    try std.testing.expectEqual(@as(usize, 0), dict.len);
}
