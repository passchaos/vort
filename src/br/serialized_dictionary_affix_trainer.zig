const std = @import("std");
const serialized_dictionary = @import("serialized_dictionary.zig");

pub const max_stringlet_len: usize = 16;
pub const max_transforms: usize = 64;
pub const max_dictionary_words: usize = 64 * 1024;
pub const max_sampled_positions: usize = 1024 * 1024;

pub const Options = struct {
    max_stringlet_len: u8 = 8,
    max_transforms: u8 = 16,
    max_candidates: usize = 4096,
    max_words: usize = 4096,
    max_positions: usize = 16 * 1024,
    min_occurrences: u16 = 2,
};

pub const Error = error{
    InvalidTrainingOptions,
    IntegerOverflow,
};

/// Canonical learned stringlet table plus identity-kind transform triplets.
/// The table stores all non-empty strings first and the mandatory empty
/// stringlet last. Transform IDs therefore remain stable across rebuilds.
pub const Plan = struct {
    prefix_suffix: []u8,
    transforms: []u8,
    stringlet_count: usize,

    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.prefix_suffix);
        allocator.free(self.transforms);
    }

    pub fn transformCount(self: Plan) usize {
        return self.transforms.len / 3;
    }

    pub fn emptyStringletId(self: Plan) u8 {
        std.debug.assert(self.stringlet_count != 0);
        return @intCast(self.stringlet_count - 1);
    }
};

const AffixKey = struct {
    prefix: [max_stringlet_len]u8 = @splat(0),
    suffix: [max_stringlet_len]u8 = @splat(0),
    prefix_len: u8 = 0,
    suffix_len: u8 = 0,

    fn prefixBytes(self: *const AffixKey) []const u8 {
        return self.prefix[0..self.prefix_len];
    }

    fn suffixBytes(self: *const AffixKey) []const u8 {
        return self.suffix[0..self.suffix_len];
    }

    fn byteLen(self: *const AffixKey) usize {
        return @as(usize, self.prefix_len) + self.suffix_len;
    }
};

const RankedAffix = struct {
    key: AffixKey,
    count: usize,
    score: usize,
};

pub fn learnAlloc(
    allocator: std.mem.Allocator,
    dictionary: *const serialized_dictionary.Dictionary,
    samples: []const []const u8,
    options: Options,
) (Error || std.mem.Allocator.Error)!?Plan {
    try validateOptions(options);
    if (samples.len == 0) return null;

    var words: std.StringHashMapUnmanaged(void) = .empty;
    defer words.deinit(allocator);
    var lengths: [serialized_dictionary.max_word_len + 1]bool = @splat(false);
    word_lists: for (dictionary.word_lists[0..dictionary.word_list_count]) |*word_list| {
        for (serialized_dictionary.min_word_len..serialized_dictionary.max_word_len + 1) |word_len| {
            const word_count = word_list.wordCount(word_len);
            for (0..word_count) |word_index| {
                const word = word_list.word(word_len, word_index) orelse
                    return error.InvalidTrainingOptions;
                const entry = try words.getOrPut(allocator, word);
                if (!entry.found_existing) lengths[word_len] = true;
                if (words.count() == options.max_words) break :word_lists;
            }
        }
    }
    if (words.count() == 0) return null;

    const total_positions = try countMatchingPositions(samples, &words, &lengths);
    if (total_positions == 0) return null;
    const rounded = std.math.add(
        usize,
        total_positions,
        options.max_positions - 1,
    ) catch return error.IntegerOverflow;
    const stride = @max(@as(usize, 1), rounded / options.max_positions);

    var counts: std.AutoHashMapUnmanaged(AffixKey, usize) = .empty;
    defer counts.deinit(allocator);
    var ordinal: usize = 0;
    var sampled: usize = 0;
    outer: for (samples) |sample| {
        for (0..sample.len) |position| {
            for (serialized_dictionary.min_word_len..serialized_dictionary.max_word_len + 1) |word_len| {
                if (!lengths[word_len] or word_len > sample.len - position)
                    continue;
                if (!words.contains(sample[position..][0..word_len])) continue;
                if (ordinal % stride == 0) {
                    try observePosition(
                        allocator,
                        &counts,
                        sample,
                        position,
                        word_len,
                        options,
                    );
                    sampled += 1;
                    if (sampled == options.max_positions) break :outer;
                }
                ordinal += 1;
            }
        }
    }

    var ranked = try allocator.alloc(RankedAffix, counts.count());
    defer allocator.free(ranked);
    var ranked_count: usize = 0;
    var iterator = counts.iterator();
    while (iterator.next()) |entry| {
        const count = entry.value_ptr.*;
        if (count < options.min_occurrences) continue;
        const byte_len = entry.key_ptr.byteLen();
        ranked[ranked_count] = .{
            .key = entry.key_ptr.*,
            .count = count,
            .score = std.math.mul(usize, count, byte_len) catch
                std.math.maxInt(usize),
        };
        ranked_count += 1;
    }
    ranked = try allocator.realloc(ranked, ranked_count);
    if (ranked.len == 0) return null;
    std.mem.sort(RankedAffix, ranked, {}, rankedLessThan);
    const plan = try buildPlanAlloc(
        allocator,
        ranked[0..@min(ranked.len, options.max_transforms)],
    );
    return plan;
}

fn validateOptions(options: Options) Error!void {
    if (options.max_stringlet_len == 0 or
        options.max_stringlet_len > max_stringlet_len or
        options.max_transforms == 0 or
        options.max_transforms > max_transforms or
        options.max_candidates < options.max_transforms or
        options.max_candidates > 64 * 1024 or
        options.max_words == 0 or
        options.max_words > max_dictionary_words or
        options.max_positions == 0 or
        options.max_positions > max_sampled_positions or
        options.min_occurrences == 0)
    {
        return error.InvalidTrainingOptions;
    }
}

fn countMatchingPositions(
    samples: []const []const u8,
    words: *const std.StringHashMapUnmanaged(void),
    lengths: *const [serialized_dictionary.max_word_len + 1]bool,
) Error!usize {
    var count: usize = 0;
    for (samples) |sample| {
        for (0..sample.len) |position| {
            for (serialized_dictionary.min_word_len..serialized_dictionary.max_word_len + 1) |word_len| {
                if (!lengths[word_len] or word_len > sample.len - position)
                    continue;
                if (words.contains(sample[position..][0..word_len]))
                    count = std.math.add(usize, count, 1) catch
                        return error.IntegerOverflow;
            }
        }
    }
    return count;
}

fn observePosition(
    allocator: std.mem.Allocator,
    counts: *std.AutoHashMapUnmanaged(AffixKey, usize),
    sample: []const u8,
    position: usize,
    word_len: usize,
    options: Options,
) (Error || std.mem.Allocator.Error)!void {
    const prefix_limit = @min(position, options.max_stringlet_len);
    const suffix_start = position + word_len;
    const suffix_limit = @min(
        sample.len - suffix_start,
        options.max_stringlet_len,
    );
    for (1..prefix_limit + 1) |prefix_len| {
        try observe(
            allocator,
            counts,
            sample[position - prefix_len .. position],
            "",
            options.max_candidates,
        );
    }
    for (1..suffix_limit + 1) |suffix_len| {
        try observe(
            allocator,
            counts,
            "",
            sample[suffix_start..][0..suffix_len],
            options.max_candidates,
        );
    }
    for (1..prefix_limit + 1) |prefix_len| {
        for (1..suffix_limit + 1) |suffix_len| {
            try observe(
                allocator,
                counts,
                sample[position - prefix_len .. position],
                sample[suffix_start..][0..suffix_len],
                options.max_candidates,
            );
        }
    }
}

fn observe(
    allocator: std.mem.Allocator,
    counts: *std.AutoHashMapUnmanaged(AffixKey, usize),
    prefix: []const u8,
    suffix: []const u8,
    max_candidates: usize,
) std.mem.Allocator.Error!void {
    var key = AffixKey{};
    key.prefix_len = @intCast(prefix.len);
    key.suffix_len = @intCast(suffix.len);
    @memcpy(key.prefix[0..prefix.len], prefix);
    @memcpy(key.suffix[0..suffix.len], suffix);
    if (counts.getPtr(key)) |count| {
        count.* = std.math.add(usize, count.*, 1) catch
            std.math.maxInt(usize);
        return;
    }
    if (counts.count() == max_candidates) return;
    try counts.put(allocator, key, 1);
}

fn rankedLessThan(_: void, a: RankedAffix, b: RankedAffix) bool {
    if (a.score != b.score) return a.score > b.score;
    if (a.count != b.count) return a.count > b.count;
    if (a.key.byteLen() != b.key.byteLen())
        return a.key.byteLen() > b.key.byteLen();
    const prefix_order = std.mem.order(u8, a.key.prefixBytes(), b.key.prefixBytes());
    if (prefix_order != .eq) return prefix_order == .lt;
    return std.mem.order(u8, a.key.suffixBytes(), b.key.suffixBytes()) == .lt;
}

fn buildPlanAlloc(
    allocator: std.mem.Allocator,
    ranked: []const RankedAffix,
) (Error || std.mem.Allocator.Error)!Plan {
    var strings: [max_transforms * 2][]const u8 = undefined;
    var string_count: usize = 0;
    for (ranked) |*entry| {
        if (entry.key.prefix_len != 0)
            internString(&strings, &string_count, entry.key.prefixBytes());
        if (entry.key.suffix_len != 0)
            internString(&strings, &string_count, entry.key.suffixBytes());
    }
    std.debug.assert(string_count <= max_transforms * 2);
    const complete_string_count = string_count + 1;
    std.debug.assert(complete_string_count <= serialized_dictionary.max_stringlets);
    var table_len: usize = 1;
    for (strings[0..string_count]) |stringlet| {
        table_len = std.math.add(usize, table_len, 1 + stringlet.len) catch
            return error.IntegerOverflow;
    }
    const prefix_suffix = try allocator.alloc(u8, table_len);
    errdefer allocator.free(prefix_suffix);
    var cursor: usize = 0;
    for (strings[0..string_count]) |stringlet| {
        prefix_suffix[cursor] = @intCast(stringlet.len);
        cursor += 1;
        @memcpy(prefix_suffix[cursor..][0..stringlet.len], stringlet);
        cursor += stringlet.len;
    }
    prefix_suffix[cursor] = 0;
    cursor += 1;
    std.debug.assert(cursor == prefix_suffix.len);

    const transforms_len = std.math.mul(usize, ranked.len, 3) catch
        return error.IntegerOverflow;
    const transforms = try allocator.alloc(u8, transforms_len);
    errdefer allocator.free(transforms);
    const empty_id: u8 = @intCast(string_count);
    for (ranked, 0..) |*entry, transform_index| {
        const base = transform_index * 3;
        transforms[base] = if (entry.key.prefix_len == 0)
            empty_id
        else
            findStringId(strings[0..string_count], entry.key.prefixBytes());
        transforms[base + 1] = 0;
        transforms[base + 2] = if (entry.key.suffix_len == 0)
            empty_id
        else
            findStringId(strings[0..string_count], entry.key.suffixBytes());
    }
    return .{
        .prefix_suffix = prefix_suffix,
        .transforms = transforms,
        .stringlet_count = complete_string_count,
    };
}

fn internString(
    strings: *[max_transforms * 2][]const u8,
    count: *usize,
    stringlet: []const u8,
) void {
    for (strings[0..count.*]) |existing|
        if (std.mem.eql(u8, existing, stringlet)) return;
    strings[count.*] = stringlet;
    count.* += 1;
}

fn findStringId(strings: []const []const u8, stringlet: []const u8) u8 {
    for (strings, 0..) |existing, index|
        if (std.mem.eql(u8, existing, stringlet)) return @intCast(index);
    unreachable;
}

test "serialized affix trainer learns deterministic prefix suffix pairs" {
    var size_bits: [32]u8 = @splat(0);
    size_bits[8] = 1;
    const builder = @import("serialized_dictionary_builder.zig");
    const words = [_]builder.WordListSpec{.{
        .size_bits_by_length = size_bits,
        .data = "corewordtestword",
    }};
    const transforms = [_]builder.TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{ 0, 0, 0 },
    }};
    const choices = [_]serialized_dictionary.DictionaryChoice{.{
        .word_list_index = 0,
        .transform_list_index = 0,
    }};
    const encoded = try builder.serializeAlloc(std.testing.allocator, .{
        .word_lists = &words,
        .transform_lists = &transforms,
        .dictionaries = &choices,
    });
    defer std.testing.allocator.free(encoded);
    const dictionary = try serialized_dictionary.parse(encoded);
    const samples = [_][]const u8{
        "<coreword> <testword> <coreword>",
        "<testword> <coreword> <testword>",
    };
    const options = Options{
        .max_stringlet_len = 1,
        .max_transforms = 3,
        .max_candidates = 16,
        .max_positions = 64,
    };
    const first = (try learnAlloc(
        std.testing.allocator,
        &dictionary,
        &samples,
        options,
    )).?;
    defer first.deinit(std.testing.allocator);
    const second = (try learnAlloc(
        std.testing.allocator,
        &dictionary,
        &samples,
        options,
    )).?;
    defer second.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, first.prefix_suffix, second.prefix_suffix);
    try std.testing.expectEqualSlices(u8, first.transforms, second.transforms);
    try std.testing.expectEqual(@as(usize, 3), first.transformCount());
    try std.testing.expectEqual(@as(usize, 3), first.stringlet_count);
    try std.testing.expectEqualSlices(u8, &.{ 1, '<', 1, '>', 0 }, first.prefix_suffix);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 1 }, first.transforms[0..3]);
}

test "serialized affix trainer validates bounds and releases failures" {
    var dictionary: serialized_dictionary.Dictionary = undefined;
    try std.testing.expectError(
        error.InvalidTrainingOptions,
        learnAlloc(std.testing.allocator, &dictionary, &.{}, .{
            .max_stringlet_len = 0,
        }),
    );

    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var size_bits: [32]u8 = @splat(0);
            size_bits[8] = 1;
            const builder = @import("serialized_dictionary_builder.zig");
            const words = [_]builder.WordListSpec{.{
                .size_bits_by_length = size_bits,
                .data = "corewordtestword",
            }};
            const transforms = [_]builder.TransformListSpec{.{
                .prefix_suffix = &.{0},
                .transforms = &.{ 0, 0, 0 },
            }};
            const choices = [_]serialized_dictionary.DictionaryChoice{.{
                .word_list_index = 0,
                .transform_list_index = 0,
            }};
            const encoded = try builder.serializeAlloc(allocator, .{
                .word_lists = &words,
                .transform_lists = &transforms,
                .dictionaries = &choices,
            });
            defer allocator.free(encoded);
            const parsed = try serialized_dictionary.parse(encoded);
            const samples = [_][]const u8{"<coreword> <testword>" ** 4};
            const plan = (try learnAlloc(allocator, &parsed, &samples, .{
                .max_stringlet_len = 2,
                .max_transforms = 4,
                .max_candidates = 32,
                .max_positions = 64,
            })) orelse return error.TestUnexpectedResult;
            defer plan.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{},
    );
}
