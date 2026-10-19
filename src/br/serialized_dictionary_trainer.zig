const std = @import("std");
const dictionary_train = @import("../dictionary.zig");
const serialized_dictionary = @import("serialized_dictionary.zig");
const builder = @import("serialized_dictionary_builder.zig");
const affix_trainer = @import("serialized_dictionary_affix_trainer.zig");
const context_clusterer = @import("serialized_dictionary_context_clusterer.zig");
const literal_context = @import("encoder/literal_context.zig");

pub const DictionaryId = dictionary_train.DictionaryId;
pub const TransformProfile = enum {
    identity,
    ascii_case,
    omit,
    ascii_case_omit,
    prefix_suffix,
    ascii_case_prefix_suffix,
    omit_prefix_suffix,
    ascii_case_omit_prefix_suffix,
    clustered,
};

pub const PrefixSuffixOptions = affix_trainer.Options;
pub const PrefixSuffixPlan = affix_trainer.Plan;
pub const max_learned_stringlet_len = affix_trainer.max_stringlet_len;
pub const max_learned_prefix_suffix_transforms = affix_trainer.max_transforms;
pub const max_learned_prefix_suffix_words = affix_trainer.max_dictionary_words;
pub const max_learned_prefix_suffix_positions = affix_trainer.max_sampled_positions;

pub const ContextProfile = enum {
    global,
    cutoff,
    clustered,
};

pub const max_context_signature_positions =
    context_clusterer.max_positions_per_context;
pub const max_context_training_positions_per_group: usize = 1024 * 1024;

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
    max_context_signature_positions: usize = 4096,
};

pub const Candidate = struct {
    encoded: []u8,
    bucket_count: usize,
    word_count: usize,
    id: DictionaryId,
    context_based: bool = false,
    context_mode: ?u2 = null,
    context_cutoff: ?u6 = null,
    context_profile: ContextProfile = .global,
    context_cluster_count: u7 = 1,
    transform_profile: TransformProfile = .identity,
    transform_list_count: u7 = 1,
    learned_stringlet_count: usize = 0,
    learned_prefix_suffix_transform_count: usize = 0,

    pub fn deinit(self: Candidate, allocator: std.mem.Allocator) void {
        allocator.free(self.encoded);
    }
};

pub fn learnPrefixSuffixPlanAlloc(
    allocator: std.mem.Allocator,
    source: *const Candidate,
    samples: []const []const u8,
    options: PrefixSuffixOptions,
) (Error || std.mem.Allocator.Error)!?PrefixSuffixPlan {
    const parsed = try serialized_dictionary.parse(source.encoded);
    return affix_trainer.learnAlloc(allocator, &parsed, samples, options) catch |err|
        switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            error.IntegerOverflow => return error.IntegerOverflow,
            else => return error.InvalidTrainingOptions,
        };
}

pub fn withPrefixSuffixTransformsAlloc(
    allocator: std.mem.Allocator,
    source: *const Candidate,
    plan: *const PrefixSuffixPlan,
) (Error || std.mem.Allocator.Error)!Candidate {
    if (plan.transformCount() == 0 or plan.stringlet_count < 2)
        return error.InvalidTrainingOptions;
    const transform_profile = prefixSuffixProfile(source.transform_profile) orelse
        return error.InvalidTrainingOptions;
    const parsed = try serialized_dictionary.parse(source.encoded);
    if (parsed.transform_list_count != 1)
        return error.InvalidTrainingOptions;
    const source_transforms = &parsed.transform_lists[0];
    if (source_transforms.prefix_suffix.len != 1 or
        source_transforms.prefix_suffix[0] != 0 or
        source_transforms.params != null)
    {
        return error.InvalidTrainingOptions;
    }
    const transform_count = std.math.add(
        usize,
        source_transforms.transformCount(),
        plan.transformCount(),
    ) catch return error.IntegerOverflow;
    if (transform_count > std.math.maxInt(u8))
        return error.InvalidTrainingOptions;
    const transform_len = std.math.mul(usize, transform_count, 3) catch
        return error.IntegerOverflow;
    const transform_bytes = try allocator.alloc(u8, transform_len);
    defer allocator.free(transform_bytes);
    const empty_id = plan.emptyStringletId();
    for (0..source_transforms.transformCount()) |transform_index| {
        const source_transform = source_transforms.transform(transform_index) orelse
            return error.InvalidTrainingOptions;
        if (source_transform.prefix_id != 0 or source_transform.suffix_id != 0 or
            source_transform.kind >= 21)
        {
            return error.InvalidTrainingOptions;
        }
        const base = transform_index * 3;
        transform_bytes[base] = empty_id;
        transform_bytes[base + 1] = source_transform.kind;
        transform_bytes[base + 2] = empty_id;
    }
    @memcpy(
        transform_bytes[source_transforms.transforms.len..],
        plan.transforms,
    );
    var word_lists: [serialized_dictionary.max_contexts]builder.WordListSpec =
        undefined;
    for (word_lists[0..parsed.word_list_count], parsed.word_lists[0..parsed.word_list_count]) |*destination, words|
        destination.* = builder.WordListSpec.fromParsed(words);
    const transform_lists = [_]builder.TransformListSpec{.{
        .prefix_suffix = plan.prefix_suffix,
        .transforms = transform_bytes,
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
        .context_profile = source.context_profile,
        .context_cluster_count = source.context_cluster_count,
        .transform_profile = transform_profile,
        .transform_list_count = 1,
        .learned_stringlet_count = plan.stringlet_count - 1,
        .learned_prefix_suffix_transform_count = plan.transformCount(),
    };
}

fn prefixSuffixProfile(profile: TransformProfile) ?TransformProfile {
    return switch (profile) {
        .identity => .prefix_suffix,
        .ascii_case => .ascii_case_prefix_suffix,
        .omit => .omit_prefix_suffix,
        .ascii_case_omit => .ascii_case_omit_prefix_suffix,
        else => null,
    };
}

pub fn withCaseTransformsAlloc(
    allocator: std.mem.Allocator,
    source: *const Candidate,
) (Error || std.mem.Allocator.Error)!Candidate {
    return withTransformProfileAlloc(allocator, source, .ascii_case);
}

pub fn withOmitTransformsAlloc(
    allocator: std.mem.Allocator,
    source: *const Candidate,
    include_case: bool,
) (Error || std.mem.Allocator.Error)!Candidate {
    return withTransformProfileAlloc(
        allocator,
        source,
        if (include_case) .ascii_case_omit else .omit,
    );
}

fn withTransformProfileAlloc(
    allocator: std.mem.Allocator,
    source: *const Candidate,
    profile: TransformProfile,
) (Error || std.mem.Allocator.Error)!Candidate {
    if (profile == .identity) return error.InvalidTrainingOptions;
    const parsed = try serialized_dictionary.parse(source.encoded);
    var word_lists: [serialized_dictionary.max_contexts]builder.WordListSpec =
        undefined;
    for (word_lists[0..parsed.word_list_count], parsed.word_lists[0..parsed.word_list_count]) |*destination, words|
        destination.* = builder.WordListSpec.fromParsed(words);
    var transform_bytes: [3 * 21]u8 = undefined;
    var transform_count: usize = 0;
    appendTransform(&transform_bytes, &transform_count, 0);
    if (profile == .ascii_case or profile == .ascii_case_omit) {
        appendTransform(&transform_bytes, &transform_count, 10);
        appendTransform(&transform_bytes, &transform_count, 11);
    }
    if (profile == .omit or profile == .ascii_case_omit) {
        for (1..10) |kind|
            appendTransform(&transform_bytes, &transform_count, @intCast(kind));
        for (12..21) |kind|
            appendTransform(&transform_bytes, &transform_count, @intCast(kind));
    }
    const transform_lists = [_]builder.TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = transform_bytes[0 .. transform_count * 3],
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
        .context_profile = source.context_profile,
        .context_cluster_count = source.context_cluster_count,
        .transform_profile = profile,
        .transform_list_count = 1,
    };
}

pub fn withClusteredTransformProfilesAlloc(
    allocator: std.mem.Allocator,
    sources: []const *const Candidate,
    profile_by_dictionary: []const u8,
) (Error || std.mem.Allocator.Error)!Candidate {
    if (sources.len < 2 or sources.len > 8)
        return error.InvalidTrainingOptions;
    var parsed_sources: [8]serialized_dictionary.Dictionary = undefined;
    for (sources, 0..) |source, source_index|
        parsed_sources[source_index] = try serialized_dictionary.parse(source.encoded);
    const base = &parsed_sources[0];
    if (!base.context_based or base.dictionary_count < 2 or
        profile_by_dictionary.len != base.dictionary_count)
    {
        return error.InvalidTrainingOptions;
    }
    var used: [8]bool = @splat(false);
    for (profile_by_dictionary) |profile_index| {
        if (profile_index >= sources.len) return error.InvalidTrainingOptions;
        used[profile_index] = true;
    }
    var transform_specs: [8]builder.TransformListSpec = undefined;
    var transform_index_by_source: [8]u8 = @splat(0);
    var transform_list_count: usize = 0;
    for (parsed_sources[0..sources.len], 0..) |*parsed, source_index| {
        if (!used[source_index]) continue;
        if (parsed.transform_list_count != 1 or
            parsed.dictionary_count != base.dictionary_count or
            parsed.word_list_count != base.word_list_count or
            parsed.context_based != base.context_based or
            !std.mem.eql(u6, &parsed.context_map, &base.context_map))
        {
            return error.InvalidTrainingOptions;
        }
        for (0..base.dictionary_count) |dictionary_id| {
            if (parsed.dictionaries[dictionary_id].word_list_index !=
                base.dictionaries[dictionary_id].word_list_index)
            {
                return error.InvalidTrainingOptions;
            }
        }
        transform_index_by_source[source_index] = @intCast(transform_list_count);
        transform_specs[transform_list_count] =
            builder.TransformListSpec.fromParsed(parsed.transform_lists[0]);
        transform_list_count += 1;
    }
    if (transform_list_count < 2) return error.InvalidTrainingOptions;

    var word_lists: [serialized_dictionary.max_contexts]builder.WordListSpec =
        undefined;
    for (word_lists[0..base.word_list_count], base.word_lists[0..base.word_list_count]) |*destination, words|
        destination.* = builder.WordListSpec.fromParsed(words);
    var choices: [serialized_dictionary.max_contexts]serialized_dictionary.DictionaryChoice =
        undefined;
    for (choices[0..base.dictionary_count], base.dictionaries[0..base.dictionary_count], profile_by_dictionary) |*destination, source_choice, profile_index| {
        destination.* = .{
            .word_list_index = source_choice.word_list_index,
            .transform_list_index = transform_index_by_source[profile_index],
        };
    }
    const encoded = try builder.serializeAlloc(allocator, .{
        .raw_prefix = base.raw_prefix,
        .word_lists = word_lists[0..base.word_list_count],
        .transform_lists = transform_specs[0..transform_list_count],
        .dictionaries = choices[0..base.dictionary_count],
        .context_map = &base.context_map,
    });
    var learned_stringlet_count: usize = 0;
    var learned_transform_count: usize = 0;
    for (sources, 0..) |source, source_index| {
        if (!used[source_index]) continue;
        learned_stringlet_count = @max(
            learned_stringlet_count,
            source.learned_stringlet_count,
        );
        learned_transform_count = @max(
            learned_transform_count,
            source.learned_prefix_suffix_transform_count,
        );
    }
    return .{
        .encoded = encoded,
        .bucket_count = sources[0].bucket_count,
        .word_count = sources[0].word_count,
        .id = .fromBytes(encoded),
        .context_based = sources[0].context_based,
        .context_mode = sources[0].context_mode,
        .context_cutoff = sources[0].context_cutoff,
        .context_profile = sources[0].context_profile,
        .context_cluster_count = sources[0].context_cluster_count,
        .transform_profile = .clustered,
        .transform_list_count = @intCast(transform_list_count),
        .learned_stringlet_count = learned_stringlet_count,
        .learned_prefix_suffix_transform_count = learned_transform_count,
    };
}

fn appendTransform(
    output: *[3 * 21]u8,
    count: *usize,
    kind: u8,
) void {
    const cursor = count.* * 3;
    output[cursor] = 0;
    output[cursor + 1] = kind;
    output[cursor + 2] = 0;
    count.* += 1;
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
    var context_map: [serialized_dictionary.max_contexts]u6 = undefined;
    for (&context_map, 0..) |*dictionary_id, context|
        dictionary_id.* = @intFromBool(context >= options.context_cutoff);
    var candidate = (try trainMappedContextCandidateAlloc(
        allocator,
        samples,
        options,
        mode,
        &context_map,
        2,
    )) orelse return null;
    candidate.context_profile = .cutoff;
    candidate.context_cutoff = options.context_cutoff;
    return candidate;
}

pub fn trainClusteredContextCandidateAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    options: Options,
    mode: u2,
    target_clusters: u7,
) (Error || std.mem.Allocator.Error)!?Candidate {
    try validateOptions(options);
    if (!options.train_context_map) return null;
    const learned = (try context_clusterer.learn(samples, mode, .{
        .phrase_len = options.min_word_len,
        .target_clusters = target_clusters,
        .max_positions_per_context = options.max_context_signature_positions,
    })) orelse return null;
    if (learned.cluster_count < 2) return null;
    var candidate = (try trainMappedContextCandidateAlloc(
        allocator,
        samples,
        options,
        mode,
        &learned.context_map,
        learned.cluster_count,
    )) orelse return null;
    candidate.context_profile = .clustered;
    candidate.context_cluster_count = learned.cluster_count;
    return candidate;
}

fn trainMappedContextCandidateAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    options: Options,
    mode: u2,
    context_map: *const [serialized_dictionary.max_contexts]u6,
    cluster_count: u7,
) (Error || std.mem.Allocator.Error)!?Candidate {
    if (cluster_count < 2 or cluster_count > serialized_dictionary.max_contexts)
        return error.InvalidTrainingOptions;
    for (context_map) |cluster_id|
        if (cluster_id >= cluster_count) return error.InvalidTrainingOptions;
    var lists: [serialized_dictionary.max_contexts]OwnedWordList = undefined;
    const active_lists = lists[0..cluster_count];
    {
        var initialized: usize = 0;
        errdefer for (active_lists[0..initialized]) |list| list.deinit(allocator);
        for (active_lists, 0..) |*list, group| {
            list.* = try trainMappedContextWordListAlloc(
                allocator,
                samples,
                options,
                mode,
                context_map,
                @intCast(group),
            );
            initialized += 1;
        }
    }
    defer for (active_lists) |list| list.deinit(allocator);
    var word_count: usize = 0;
    var bucket_count: usize = 0;
    for (active_lists) |list| {
        word_count = std.math.add(usize, word_count, list.word_count) catch
            return error.IntegerOverflow;
        bucket_count = std.math.add(usize, bucket_count, list.bucket_count) catch
            return error.IntegerOverflow;
    }
    if (word_count == 0) return null;
    var word_lists: [serialized_dictionary.max_contexts]builder.WordListSpec =
        undefined;
    var choices: [serialized_dictionary.max_contexts]serialized_dictionary.DictionaryChoice =
        undefined;
    for (active_lists, 0..) |list, group| {
        word_lists[group] = .{
            .size_bits_by_length = list.size_bits_by_length,
            .data = list.data,
        };
        choices[group] = .{
            .word_list_index = @intCast(group),
            .transform_list_index = 0,
        };
    }
    const transform_lists = [_]builder.TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{ 0, 0, 0 },
    }};
    const encoded = try builder.serializeAlloc(allocator, .{
        .word_lists = word_lists[0..cluster_count],
        .transform_lists = &transform_lists,
        .dictionaries = choices[0..cluster_count],
        .context_map = context_map,
    });
    return .{
        .encoded = encoded,
        .bucket_count = bucket_count,
        .word_count = word_count,
        .id = .fromBytes(encoded),
        .context_based = true,
        .context_mode = mode,
        .context_cluster_count = cluster_count,
    };
}

fn trainMappedContextWordListAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    options: Options,
    mode: u2,
    context_map: *const [serialized_dictionary.max_contexts]u6,
    group: u6,
) (Error || std.mem.Allocator.Error)!OwnedWordList {
    var buckets: std.ArrayList(OwnedBucket) = .empty;
    defer {
        for (buckets.items) |bucket| allocator.free(bucket.allocation);
        buckets.deinit(allocator);
    }
    var word_count: usize = 0;
    var total_data_len: usize = 0;
    for (options.min_word_len..options.max_word_len + 1) |word_len| {
        const position_samples = try collectMappedContextPositionSamplesAlloc(
            allocator,
            samples,
            word_len,
            mode,
            context_map,
            group,
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

fn collectMappedContextPositionSamplesAlloc(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    word_len: usize,
    mode: u2,
    context_map: *const [serialized_dictionary.max_contexts]u6,
    group: u6,
    limit: usize,
) (Error || std.mem.Allocator.Error)![][]const u8 {
    var eligible: usize = 0;
    for (samples) |sample| {
        if (sample.len < word_len) continue;
        for (0..sample.len - word_len + 1) |position| {
            const context = trainingContext(sample, position, mode);
            if (context_map[context] == group)
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
            if (context_map[context] != group) continue;
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
                options.max_context_positions_per_group == 0 or
                options.max_context_positions_per_group > max_context_training_positions_per_group)))
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

test "serialized trainer learns deterministic non-contiguous context clusters" {
    const words_a = [_][]const u8{ "a0000000", "a1111111" };
    const words_b = [_][]const u8{ "b0000000", "b1111111" };
    const markers = [_]u8{ 8, 32, 16, 40 };
    var storage: [64][9]u8 = undefined;
    var samples: [storage.len][]const u8 = undefined;
    for (&storage, &samples, 0..) |*item, *sample, index| {
        const group = (index / 16) / 2;
        const marker_index = (index / 16) % 2;
        const words = if (group == 0) &words_a else &words_b;
        item[0] = markers[group * 2 + marker_index];
        @memcpy(item[1..], words[index % words.len]);
        sample.* = item;
    }
    const options = Options{
        .min_word_len = 8,
        .max_word_len = 8,
        .max_words_per_length = 4,
        .max_phrases_per_length = 32,
        .max_context_positions_per_group = 128,
        .max_context_signature_positions = 128,
    };
    const first = (try trainClusteredContextCandidateAlloc(
        std.testing.allocator,
        &samples,
        options,
        literal_context.mode_lsb6,
        3,
    )).?;
    defer first.deinit(std.testing.allocator);
    const second = (try trainClusteredContextCandidateAlloc(
        std.testing.allocator,
        &samples,
        options,
        literal_context.mode_lsb6,
        3,
    )).?;
    defer second.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, first.encoded, second.encoded);
    try std.testing.expectEqual(first.id, second.id);
    try std.testing.expectEqual(ContextProfile.clustered, first.context_profile);
    try std.testing.expectEqual(@as(u7, 3), first.context_cluster_count);
    try std.testing.expectEqual(@as(?u6, null), first.context_cutoff);
    const parsed = try serialized_dictionary.parse(first.encoded);
    try std.testing.expectEqual(@as(u7, 3), parsed.word_list_count);
    try std.testing.expectEqual(parsed.context_map[8], parsed.context_map[32]);
    try std.testing.expectEqual(parsed.context_map[16], parsed.context_map[40]);
    try std.testing.expect(parsed.context_map[8] != parsed.context_map[16]);
    var scratch: [serialized_dictionary.max_transformed_word_len]u8 = undefined;
    try std.testing.expect((try parsed.findLongest(8, words_a[0], &scratch)) != null);
    try std.testing.expect((try parsed.findLongest(16, words_b[0], &scratch)) != null);

    const case_candidate = try withCaseTransformsAlloc(
        std.testing.allocator,
        &first,
    );
    defer case_candidate.deinit(std.testing.allocator);
    const omit_candidate = try withOmitTransformsAlloc(
        std.testing.allocator,
        &first,
        false,
    );
    defer omit_candidate.deinit(std.testing.allocator);
    const sources = [_]*const Candidate{
        &first,
        &case_candidate,
        &omit_candidate,
    };
    const mixed = try withClusteredTransformProfilesAlloc(
        std.testing.allocator,
        &sources,
        &.{ 0, 1, 2 },
    );
    defer mixed.deinit(std.testing.allocator);
    try std.testing.expectEqual(TransformProfile.clustered, mixed.transform_profile);
    try std.testing.expectEqual(@as(u7, 3), mixed.transform_list_count);
    try std.testing.expectEqual(ContextProfile.clustered, mixed.context_profile);
    const parsed_mixed = try serialized_dictionary.parse(mixed.encoded);
    try std.testing.expectEqual(@as(u7, 3), parsed_mixed.transform_list_count);
    try std.testing.expectEqual(@as(u8, 0), parsed_mixed.dictionaries[0].transform_list_index);
    try std.testing.expectEqual(@as(u8, 1), parsed_mixed.dictionaries[1].transform_list_index);
    try std.testing.expectEqual(@as(u8, 2), parsed_mixed.dictionaries[2].transform_list_index);
}

test "serialized trainer derives canonical transform families" {
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

    const omit = try withOmitTransformsAlloc(
        std.testing.allocator,
        &identity,
        false,
    );
    defer omit.deinit(std.testing.allocator);
    const parsed_omit = try serialized_dictionary.parse(omit.encoded);
    try std.testing.expectEqual(
        @as(usize, 19),
        parsed_omit.transform_lists[0].transformCount(),
    );
    const omit_words = &parsed_omit.word_lists[0];
    const omit_word_count = omit_words.wordCount(8);
    const omit_word = omit_words.word(8, 0).?;
    try std.testing.expectEqualSlices(
        u8,
        omit_word[0..7],
        (try parsed_omit.resolve(0, 8, omit_word_count, &scratch)).bytes,
    );
    try std.testing.expectEqualSlices(
        u8,
        omit_word[1..],
        (try parsed_omit.resolve(0, 8, 10 * omit_word_count, &scratch)).bytes,
    );

    const combined = try withOmitTransformsAlloc(
        std.testing.allocator,
        &identity,
        true,
    );
    defer combined.deinit(std.testing.allocator);
    const parsed_combined = try serialized_dictionary.parse(combined.encoded);
    try std.testing.expectEqual(
        @as(usize, 21),
        parsed_combined.transform_lists[0].transformCount(),
    );
    try std.testing.expectEqual(
        TransformProfile.ascii_case_omit,
        combined.transform_profile,
    );

    var affix_sample_storage: [4 * 10]u8 = undefined;
    var affix_cursor: usize = 0;
    for (0..4) |_| {
        affix_sample_storage[affix_cursor] = '<';
        affix_cursor += 1;
        @memcpy(
            affix_sample_storage[affix_cursor..][0..base_word.len],
            base_word,
        );
        affix_cursor += base_word.len;
        affix_sample_storage[affix_cursor] = '>';
        affix_cursor += 1;
    }
    const affix_samples = [_][]const u8{affix_sample_storage[0..affix_cursor]};
    const affix_plan = (try learnPrefixSuffixPlanAlloc(
        std.testing.allocator,
        &identity,
        &affix_samples,
        .{
            .max_stringlet_len = 1,
            .max_transforms = 3,
            .max_candidates = 16,
            .max_positions = 32,
        },
    )).?;
    defer affix_plan.deinit(std.testing.allocator);
    const affix = try withPrefixSuffixTransformsAlloc(
        std.testing.allocator,
        &identity,
        &affix_plan,
    );
    defer affix.deinit(std.testing.allocator);
    try std.testing.expectEqual(TransformProfile.prefix_suffix, affix.transform_profile);
    try std.testing.expectEqual(@as(usize, 2), affix.learned_stringlet_count);
    try std.testing.expectEqual(@as(usize, 3), affix.learned_prefix_suffix_transform_count);
    const parsed_affix = try serialized_dictionary.parse(affix.encoded);
    try std.testing.expectEqual(@as(usize, 4), parsed_affix.transform_lists[0].transformCount());
    const affix_word = parsed_affix.word_lists[0].word(8, 0).?;
    var affix_expected: [10]u8 = undefined;
    affix_expected[0] = '<';
    @memcpy(affix_expected[1..9], affix_word);
    affix_expected[9] = '>';
    try std.testing.expectEqualSlices(
        u8,
        &affix_expected,
        (try parsed_affix.resolve(
            0,
            8,
            parsed_affix.word_lists[0].wordCount(8),
            &scratch,
        )).bytes,
    );
    const case_affix = try withPrefixSuffixTransformsAlloc(
        std.testing.allocator,
        &first,
        &affix_plan,
    );
    defer case_affix.deinit(std.testing.allocator);
    try std.testing.expectEqual(
        TransformProfile.ascii_case_prefix_suffix,
        case_affix.transform_profile,
    );
    const omit_affix = try withPrefixSuffixTransformsAlloc(
        std.testing.allocator,
        &omit,
        &affix_plan,
    );
    defer omit_affix.deinit(std.testing.allocator);
    try std.testing.expectEqual(
        TransformProfile.omit_prefix_suffix,
        omit_affix.transform_profile,
    );
    const combined_affix = try withPrefixSuffixTransformsAlloc(
        std.testing.allocator,
        &combined,
        &affix_plan,
    );
    defer combined_affix.deinit(std.testing.allocator);
    try std.testing.expectEqual(
        TransformProfile.ascii_case_omit_prefix_suffix,
        combined_affix.transform_profile,
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
            const omit_candidate = try withOmitTransformsAlloc(
                allocator,
                &candidate,
                false,
            );
            defer omit_candidate.deinit(allocator);
            const combined_candidate = try withOmitTransformsAlloc(
                allocator,
                &candidate,
                true,
            );
            defer combined_candidate.deinit(allocator);
            const affix_plan = (try learnPrefixSuffixPlanAlloc(
                allocator,
                &candidate,
                &samples,
                .{
                    .max_stringlet_len = 2,
                    .max_transforms = 4,
                    .max_candidates = 32,
                    .max_positions = 64,
                },
            )) orelse return error.TestUnexpectedResult;
            defer affix_plan.deinit(allocator);
            const affix_candidate = try withPrefixSuffixTransformsAlloc(
                allocator,
                &candidate,
                &affix_plan,
            );
            defer affix_candidate.deinit(allocator);
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
            const contextual_case = try withCaseTransformsAlloc(
                allocator,
                &contextual,
            );
            defer contextual_case.deinit(allocator);
            const contextual_omit = try withOmitTransformsAlloc(
                allocator,
                &contextual,
                false,
            );
            defer contextual_omit.deinit(allocator);
            const contextual_sources = [_]*const Candidate{
                &contextual,
                &contextual_case,
                &contextual_omit,
            };
            const contextual_mixed = try withClusteredTransformProfilesAlloc(
                allocator,
                &contextual_sources,
                &.{ 1, 2 },
            );
            defer contextual_mixed.deinit(allocator);
            const cluster_samples = [_][]const u8{
                "\x08a0000000",
                "\x08a1111111",
                "\x20a0000000",
                "\x20a1111111",
                "\x10b0000000",
                "\x10b1111111",
                "\x28b0000000",
                "\x28b1111111",
            };
            const clustered = (try trainClusteredContextCandidateAlloc(
                allocator,
                &cluster_samples,
                .{
                    .min_word_len = 8,
                    .max_word_len = 8,
                    .max_words_per_length = 4,
                    .max_phrases_per_length = 16,
                    .max_context_positions_per_group = 32,
                    .max_context_signature_positions = 32,
                },
                literal_context.mode_lsb6,
                3,
            )) orelse return error.TestUnexpectedResult;
            defer clustered.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{},
    );
}
