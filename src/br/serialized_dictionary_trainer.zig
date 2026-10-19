const std = @import("std");
const dictionary_train = @import("../dictionary.zig");
const serialized_dictionary = @import("serialized_dictionary.zig");
const builder = @import("serialized_dictionary_builder.zig");

pub const DictionaryId = dictionary_train.DictionaryId;

pub const Options = struct {
    min_word_len: u5 = 4,
    max_word_len: u5 = 16,
    /// Upper bound per length. The trainer selects the largest power of two not
    /// exceeding this value and the number of retained phrases.
    max_words_per_length: u16 = 64,
    /// Bounded heavy-hitter workspace passed to the shared phrase collector.
    max_phrases_per_length: usize = 256,
};

pub const Candidate = struct {
    encoded: []u8,
    bucket_count: usize,
    word_count: usize,
    id: DictionaryId,

    pub fn deinit(self: Candidate, allocator: std.mem.Allocator) void {
        allocator.free(self.encoded);
    }
};

pub const Error = builder.Error || error{
    InvalidTrainingOptions,
};

const OwnedBucket = struct {
    allocation: []u8,
    used_len: usize,
    word_len: usize,
    size_bits: u8,
};

/// Build one deterministic identity-transform custom static dictionary.
/// Final codec-level profitability is intentionally evaluated by `br.zig`,
/// which can measure complete Brotli wires on held-out samples.
pub fn trainCandidateAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    options: Options,
) (Error || std.mem.Allocator.Error)!?Candidate {
    if (options.min_word_len < serialized_dictionary.min_word_len or
        options.max_word_len > serialized_dictionary.max_word_len or
        options.min_word_len > options.max_word_len or
        options.max_words_per_length < 2 or
        options.max_words_per_length > (@as(u16, 1) << serialized_dictionary.max_size_bits) or
        options.max_phrases_per_length < options.max_words_per_length)
    {
        return error.InvalidTrainingOptions;
    }
    if (samples.len == 0) return null;

    var buckets: std.ArrayList(OwnedBucket) = .empty;
    defer {
        for (buckets.items) |bucket| allocator.free(bucket.allocation);
        buckets.deinit(allocator);
    }
    var word_count: usize = 0;
    var total_data_len: usize = 0;
    for (options.min_word_len..options.max_word_len + 1) |word_len| {
        const target_size = std.math.mul(
            usize,
            word_len,
            options.max_words_per_length,
        ) catch return error.IntegerOverflow;
        const allocation = dictionary_train.trainAlloc(allocator, samples, .{
            .target_size = target_size,
            .min_phrase_len = word_len,
            .max_phrase_len = word_len,
            .max_phrases = options.max_phrases_per_length,
        }) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.InvalidTrainingOptions,
        };
        errdefer allocator.free(allocation);
        const available_words = allocation.len / word_len;
        const selected_words = floorPowerOfTwo(@min(
            available_words,
            options.max_words_per_length,
        ));
        if (selected_words < 2) {
            allocator.free(allocation);
            continue;
        }
        const size_bits: u8 = @intCast(std.math.log2_int(usize, selected_words));
        const used_len = std.math.mul(usize, selected_words, word_len) catch
            return error.IntegerOverflow;
        try buckets.append(allocator, .{
            .allocation = allocation,
            .used_len = used_len,
            .word_len = word_len,
            .size_bits = size_bits,
        });
        word_count = std.math.add(usize, word_count, selected_words) catch
            return error.IntegerOverflow;
        total_data_len = std.math.add(usize, total_data_len, used_len) catch
            return error.IntegerOverflow;
    }
    if (buckets.items.len == 0) return null;

    const data = try allocator.alloc(u8, total_data_len);
    defer allocator.free(data);
    var size_bits_by_length: [32]u8 = @splat(0);
    var cursor: usize = 0;
    for (buckets.items) |bucket| {
        size_bits_by_length[bucket.word_len] = bucket.size_bits;
        @memcpy(
            data[cursor..][0..bucket.used_len],
            bucket.allocation[0..bucket.used_len],
        );
        cursor += bucket.used_len;
    }
    std.debug.assert(cursor == data.len);
    const word_lists = [_]builder.WordListSpec{.{
        .size_bits_by_length = size_bits_by_length,
        .data = data,
    }};
    const transform_lists = [_]builder.TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{ 0, 0, 0 },
    }};
    const choices = [_]serialized_dictionary.DictionaryChoice{.{
        .word_list_index = 0,
        .transform_list_index = 0,
    }};
    const encoded = try builder.serializeAlloc(allocator, .{
        .word_lists = &word_lists,
        .transform_lists = &transform_lists,
        .dictionaries = &choices,
    });
    return .{
        .encoded = encoded,
        .bucket_count = buckets.items.len,
        .word_count = word_count,
        .id = .fromBytes(encoded),
    };
}

fn floorPowerOfTwo(value: usize) usize {
    if (value == 0) return 0;
    return @as(usize, 1) << @intCast(std.math.log2_int(usize, value));
}

test "serialized trainer is deterministic and emits power-of-two buckets" {
    const samples = [_][]const u8{
        "alpha-record beta-record gamma-record alpha-record beta-record",
        "beta-record gamma-record delta-record beta-record gamma-record",
        "alpha-record gamma-record delta-record alpha-record gamma-record",
    };
    const options = Options{
        .min_word_len = 6,
        .max_word_len = 12,
        .max_words_per_length = 16,
        .max_phrases_per_length = 64,
    };
    const first = (try trainCandidateAlloc(
        std.testing.allocator,
        &samples,
        options,
    )).?;
    defer first.deinit(std.testing.allocator);
    const second = (try trainCandidateAlloc(
        std.testing.allocator,
        &samples,
        options,
    )).?;
    defer second.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, first.encoded, second.encoded);
    try std.testing.expectEqual(first.bucket_count, second.bucket_count);
    try std.testing.expectEqual(first.word_count, second.word_count);
    try std.testing.expectEqual(
        DictionaryId.fromBytes(first.encoded),
        first.id,
    );

    const parsed = try serialized_dictionary.parse(first.encoded);
    try std.testing.expectEqual(@as(u7, 1), parsed.word_list_count);
    for (serialized_dictionary.min_word_len..serialized_dictionary.max_word_len + 1) |word_len| {
        const bits = parsed.word_lists[0].size_bits_by_length[word_len];
        if (bits != 0)
            try std.testing.expect(parsed.word_lists[0].wordCount(word_len) >= 2);
    }
}

test "serialized trainer validates bounds and handles empty corpora" {
    try std.testing.expectEqual(
        @as(?Candidate, null),
        try trainCandidateAlloc(std.testing.allocator, &.{}, .{}),
    );
    try std.testing.expectError(
        error.InvalidTrainingOptions,
        trainCandidateAlloc(std.testing.allocator, &.{"sample"}, .{
            .min_word_len = 3,
        }),
    );
    try std.testing.expectError(
        error.InvalidTrainingOptions,
        trainCandidateAlloc(std.testing.allocator, &.{"sample"}, .{
            .max_words_per_length = 32,
            .max_phrases_per_length = 16,
        }),
    );
}

test "serialized trainer releases every allocation failure path" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const samples = [_][]const u8{
                "allocation-failure-record allocation-failure-record",
                "allocation-failure-record second-allocation-record",
            };
            const candidate = (try trainCandidateAlloc(allocator, &samples, .{
                .min_word_len = 4,
                .max_word_len = 8,
                .max_words_per_length = 8,
                .max_phrases_per_length = 32,
            })) orelse return error.TestUnexpectedResult;
            defer candidate.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{},
    );
}
