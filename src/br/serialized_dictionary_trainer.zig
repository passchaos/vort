const std = @import("std");
const dictionary_train = @import("../dictionary.zig");
const serialized_dictionary = @import("serialized_dictionary.zig");
const builder = @import("serialized_dictionary_builder.zig");
const literal_context = @import("encoder/literal_context.zig");

pub const DictionaryId = dictionary_train.DictionaryId;
pub const TransformProfile = enum { identity, ascii_case };

pub const Options = struct {
    min_word_len: u5 = 4,
    max_word_len: u5 = 16,
    /// Upper bound per length. The trainer selects the largest power of two not
    /// exceeding this value and the number of retained phrases.
    max_words_per_length: u16 = 64,
    /// Bounded heavy-hitter workspace passed to the shared phrase collector.
    max_phrases_per_length: usize = 256,
    train_context_map: bool = true,
    context_cutoff: u6 = 32,
    max_context_positions_per_group: usize = 16 * 1024,
};

pub const Candidate = struct {
    encoded: []u8,
    bucket_count: usize,
    word_count: usize,
    id: DictionaryId,
    context_based: bool = false,
    context_mode: ?u2 = null,
    context_cutoff: ?u6 = null,
    transform_profile: TransformProfile = .identity,

    pub fn deinit(self: Candidate, allocator: std.mem.Allocator) void {
        allocator.free(self.encoded);
    }
};

pub fn withCaseTransformsAlloc(
    allocator: std.mem.Allocator,
    source: *const Candidate,
) (Error || std.mem.Allocator.Error)!Candidate {
    const parsed = try serialized_dictionary.parse(source.encoded);
    var word_lists: [serialized_dictionary.max_contexts]builder.WordListSpec =
        undefined;
    for (word_lists[0..parsed.word_list_count], parsed.word_lists[0..parsed.word_list_count]) |*destination, words|
        destination.* = builder.WordListSpec.fromParsed(words);
    const transform_lists = [_]builder.TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{
            0, 0, 0, // identity
            0, 10, 0, // uppercase first
            0, 11, 0, // uppercase all
        },
    }};
    const encoded = try builder.serializeAlloc(allocator, .{
        .raw_prefix = parsed.raw_prefix,
        .word_lists = word_lists[0..parsed.word_list_count],
        .transform_lists = &transform_lists,
        .dictionaries = parsed.dictionaries[0..parsed.dictionary_count],
        .context_map = if (parsed.context_based) &parsed.context_map else null,
    });
    return .{
        .encoded = encoded,
        .bucket_count = source.bucket_count,
        .word_count = source.word_count,
        .id = .fromBytes(encoded),
        .context_based = source.context_based,
        .context_mode = source.context_mode,
        .context_cutoff = source.context_cutoff,
        .transform_profile = .ascii_case,
    };
}

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
    try validateOptions(options);
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

const OwnedWordList = struct {
    data: []u8,
    size_bits_by_length: [32]u8,
    bucket_count: usize,
    word_count: usize,

    fn deinit(self: OwnedWordList, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

pub fn trainContextCandidateAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    options: Options,
    mode: u2,
) (Error || std.mem.Allocator.Error)!?Candidate {
    try validateOptions(options);
    if (!options.train_context_map) return null;
    if (samples.len == 0) return null;
    var lists: [2]OwnedWordList = undefined;
    {
        var initialized: usize = 0;
        errdefer for (lists[0..initialized]) |list| list.deinit(allocator);
        for (&lists, 0..) |*list, group| {
            list.* = try trainContextWordListAlloc(
                allocator,
                samples,
                options,
                mode,
                group == 1,
            );
            initialized += 1;
        }
    }
    defer for (lists) |list| list.deinit(allocator);
    const word_count = std.math.add(
        usize,
        lists[0].word_count,
        lists[1].word_count,
    ) catch return error.IntegerOverflow;
    if (word_count == 0) return null;
    const word_lists = [_]builder.WordListSpec{
        .{
            .size_bits_by_length = lists[0].size_bits_by_length,
            .data = lists[0].data,
        },
        .{
            .size_bits_by_length = lists[1].size_bits_by_length,
            .data = lists[1].data,
        },
    };
    const transform_lists = [_]builder.TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{ 0, 0, 0 },
    }};
    const choices = [_]serialized_dictionary.DictionaryChoice{
        .{ .word_list_index = 0, .transform_list_index = 0 },
        .{ .word_list_index = 1, .transform_list_index = 0 },
    };
    var context_map: [64]u6 = undefined;
    for (&context_map, 0..) |*dictionary_id, context|
        dictionary_id.* = @intFromBool(context >= options.context_cutoff);
    const encoded = try builder.serializeAlloc(allocator, .{
        .word_lists = &word_lists,
        .transform_lists = &transform_lists,
        .dictionaries = &choices,
        .context_map = &context_map,
    });
    return .{
        .encoded = encoded,
        .bucket_count = lists[0].bucket_count + lists[1].bucket_count,
        .word_count = word_count,
        .id = .fromBytes(encoded),
        .context_based = true,
        .context_mode = mode,
        .context_cutoff = options.context_cutoff,
    };
}

fn trainContextWordListAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    options: Options,
    mode: u2,
    upper_group: bool,
) (Error || std.mem.Allocator.Error)!OwnedWordList {
    var buckets: std.ArrayList(OwnedBucket) = .empty;
    defer {
        for (buckets.items) |bucket| allocator.free(bucket.allocation);
        buckets.deinit(allocator);
    }
    var word_count: usize = 0;
    var total_data_len: usize = 0;
    for (options.min_word_len..options.max_word_len + 1) |word_len| {
        const position_samples = try collectContextPositionSamplesAlloc(
            allocator,
            samples,
            word_len,
            mode,
            options.context_cutoff,
            upper_group,
            options.max_context_positions_per_group,
        );
        defer allocator.free(position_samples);
        if (position_samples.len == 0) continue;
        const target_size = std.math.mul(
            usize,
            word_len,
            options.max_words_per_length,
        ) catch return error.IntegerOverflow;
        const allocation = dictionary_train.trainAlloc(
            allocator,
            position_samples,
            .{
                .target_size = target_size,
                .min_phrase_len = word_len,
                .max_phrase_len = word_len,
                .max_phrases = options.max_phrases_per_length,
            },
        ) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.InvalidTrainingOptions,
        };
        errdefer allocator.free(allocation);
        const selected_words = floorPowerOfTwo(@min(
            allocation.len / word_len,
            options.max_words_per_length,
        ));
        if (selected_words < 2) {
            allocator.free(allocation);
            continue;
        }
        const used_len = std.math.mul(usize, selected_words, word_len) catch
            return error.IntegerOverflow;
        try buckets.append(allocator, .{
            .allocation = allocation,
            .used_len = used_len,
            .word_len = word_len,
            .size_bits = @intCast(std.math.log2_int(usize, selected_words)),
        });
        word_count = std.math.add(usize, word_count, selected_words) catch
            return error.IntegerOverflow;
        total_data_len = std.math.add(usize, total_data_len, used_len) catch
            return error.IntegerOverflow;
    }
    const data = try allocator.alloc(u8, total_data_len);
    errdefer allocator.free(data);
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
    return .{
        .data = data,
        .size_bits_by_length = size_bits_by_length,
        .bucket_count = buckets.items.len,
        .word_count = word_count,
    };
}

fn collectContextPositionSamplesAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    word_len: usize,
    mode: u2,
    cutoff: u6,
    upper_group: bool,
    limit: usize,
) (Error || std.mem.Allocator.Error)![][]const u8 {
    var eligible: usize = 0;
    for (samples) |sample| {
        if (sample.len < word_len) continue;
        for (0..sample.len - word_len + 1) |position| {
            const context = trainingContext(sample, position, mode);
            if ((context >= cutoff) == upper_group)
                eligible = std.math.add(usize, eligible, 1) catch
                    return error.IntegerOverflow;
        }
    }
    if (eligible == 0) return allocator.alloc([]const u8, 0);
    const rounded = std.math.add(usize, eligible, limit - 1) catch
        return error.IntegerOverflow;
    const stride = @max(@as(usize, 1), rounded / limit);
    const capacity = @min(eligible, limit);
    const result = try allocator.alloc([]const u8, capacity);
    errdefer allocator.free(result);
    var ordinal: usize = 0;
    var written: usize = 0;
    for (samples) |sample| {
        if (sample.len < word_len) continue;
        for (0..sample.len - word_len + 1) |position| {
            const context = trainingContext(sample, position, mode);
            if ((context >= cutoff) != upper_group) continue;
            if (ordinal % stride == 0 and written < result.len) {
                result[written] = sample[position..][0..word_len];
                written += 1;
            }
            ordinal += 1;
        }
    }
    return allocator.realloc(result, written);
}

fn trainingContext(sample: []const u8, position: usize, mode: u2) usize {
    const previous = if (position == 0) 0 else sample[position - 1];
    const second_previous = if (position < 2) 0 else sample[position - 2];
    return literal_context.value(mode, previous, second_previous);
}

fn floorPowerOfTwo(value: usize) usize {
    if (value == 0) return 0;
    return @as(usize, 1) << @intCast(std.math.log2_int(usize, value));
}

fn validateOptions(options: Options) Error!void {
    if (options.min_word_len < serialized_dictionary.min_word_len or
        options.max_word_len > serialized_dictionary.max_word_len or
        options.min_word_len > options.max_word_len or
        options.max_words_per_length < 2 or
        options.max_words_per_length > (@as(u16, 1) << serialized_dictionary.max_size_bits) or
        options.max_phrases_per_length < options.max_words_per_length or
        (options.train_context_map and
            (options.context_cutoff == 0 or
                options.context_cutoff >= 64 or
                options.max_context_positions_per_group == 0)))
    {
        return error.InvalidTrainingOptions;
    }
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
    try std.testing.expectEqual(first.id, second.id);
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

test "serialized trainer learns deterministic two-group context maps" {
    const sample = ([_]u8{24} ++ "LOWWORD!" ++ [_]u8{40} ++ "HIGHWORD") ** 16;
    const samples = [_][]const u8{sample};
    const options = Options{
        .min_word_len = 8,
        .max_word_len = 8,
        .max_words_per_length = 8,
        .max_phrases_per_length = 32,
        .context_cutoff = 32,
    };
    const first = (try trainContextCandidateAlloc(
        std.testing.allocator,
        &samples,
        options,
        literal_context.mode_lsb6,
    )).?;
    defer first.deinit(std.testing.allocator);
    const second = (try trainContextCandidateAlloc(
        std.testing.allocator,
        &samples,
        options,
        literal_context.mode_lsb6,
    )).?;
    defer second.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, first.encoded, second.encoded);
    try std.testing.expect(first.context_based);
    try std.testing.expectEqual(@as(?u2, literal_context.mode_lsb6), first.context_mode);
    try std.testing.expectEqual(@as(?u6, 32), first.context_cutoff);
    const parsed = try serialized_dictionary.parse(first.encoded);
    try std.testing.expect(parsed.context_based);
    try std.testing.expectEqual(@as(u6, 0), parsed.context_map[31]);
    try std.testing.expectEqual(@as(u6, 1), parsed.context_map[32]);
    try std.testing.expect(parsed.word_lists[0].wordCount(8) >= 2);
    try std.testing.expect(parsed.word_lists[1].wordCount(8) >= 2);
    var scratch: [serialized_dictionary.max_transformed_word_len]u8 = undefined;
    const low_word = parsed.word_lists[0].word(8, 0).?;
    const high_word = parsed.word_lists[1].word(8, 0).?;
    try std.testing.expect((try parsed.findLongest(24, low_word, &scratch)) != null);
    try std.testing.expect((try parsed.findLongest(40, high_word, &scratch)) != null);
}

test "serialized trainer derives canonical case transform families" {
    const samples = [_][]const u8{
        "lowercaseword lowercaseword lowercaseword",
        "lowercaseword anotherlowercase lowercaseword",
    };
    const identity = (try trainCandidateAlloc(
        std.testing.allocator,
        &samples,
        .{
            .min_word_len = 8,
            .max_word_len = 8,
            .max_words_per_length = 8,
            .max_phrases_per_length = 32,
        },
    )).?;
    defer identity.deinit(std.testing.allocator);
    const first = try withCaseTransformsAlloc(std.testing.allocator, &identity);
    defer first.deinit(std.testing.allocator);
    const second = try withCaseTransformsAlloc(std.testing.allocator, &identity);
    defer second.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, first.encoded, second.encoded);
    try std.testing.expectEqual(first.id, second.id);
    try std.testing.expectEqual(TransformProfile.ascii_case, first.transform_profile);
    const parsed = try serialized_dictionary.parse(first.encoded);
    try std.testing.expectEqual(@as(usize, 3), parsed.transform_lists[0].transformCount());
    const words = &parsed.word_lists[0];
    const word_count = words.wordCount(8);
    const base_word = words.word(8, 0).?;
    var expected: [8]u8 = undefined;
    for (&expected, base_word) |*destination, byte|
        destination.* = std.ascii.toUpper(byte);
    var scratch: [serialized_dictionary.max_transformed_word_len]u8 = undefined;
    try std.testing.expectEqualSlices(
        u8,
        &expected,
        (try parsed.resolve(0, 8, 2 * word_count, &scratch)).bytes,
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
            const case_candidate = try withCaseTransformsAlloc(
                allocator,
                &candidate,
            );
            defer case_candidate.deinit(allocator);
            const contextual = (try trainContextCandidateAlloc(
                allocator,
                &samples,
                .{
                    .min_word_len = 4,
                    .max_word_len = 8,
                    .max_words_per_length = 8,
                    .max_phrases_per_length = 32,
                    .max_context_positions_per_group = 64,
                },
                literal_context.mode_utf8,
            )) orelse return error.TestUnexpectedResult;
            defer contextual.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{},
    );
}
