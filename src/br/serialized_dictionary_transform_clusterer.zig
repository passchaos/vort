const std = @import("std");
const serialized_dictionary = @import("serialized_dictionary.zig");
const builder = @import("serialized_dictionary_builder.zig");
const Matcher = @import("encoder/serialized_dictionary_matcher.zig").Matcher;
const literal_context = @import("encoder/literal_context.zig");

pub const max_profiles: usize = 8;
pub const max_dictionaries: usize = 16;
pub const max_scoring_positions: usize = 1024 * 1024;

pub const Options = struct {
    max_positions: usize = 64 * 1024,
};

pub const Error = serialized_dictionary.Error || error{
    InvalidTrainingOptions,
};

pub const Assignment = struct {
    profile_by_dictionary: [max_dictionaries]u8,
    dictionary_count: u7,
    distinct_profile_count: u7,
};

/// Use the richest enabled profile as one held-out matcher oracle, attribute
/// each winning transform kind to its resolved dictionary choice, then select
/// the smallest enabled capability superset independently for every choice.
/// Candidate/profile enumeration order breaks equal-size ties.
pub fn assignAlloc(
    allocator: std.mem.Allocator,
    candidates: []const *const serialized_dictionary.Dictionary,
    capabilities: []const u3,
    validation_samples: []const []const u8,
    context_mode: u2,
    options: Options,
) (Error || std.mem.Allocator.Error)!?Assignment {
    if (candidates.len < 2 or candidates.len > max_profiles or
        capabilities.len != candidates.len or capabilities[0] != 0 or
        validation_samples.len == 0 or
        context_mode > literal_context.mode_signed or
        options.max_positions == 0 or
        options.max_positions > max_scoring_positions)
    {
        return error.InvalidTrainingOptions;
    }
    const reference = candidates[0];
    if (!reference.context_based or reference.dictionary_count < 2 or
        reference.dictionary_count > max_dictionaries)
    {
        return null;
    }
    for (candidates[1..]) |candidate|
        try validateEquivalentWordsAndMap(reference, candidate);

    var all_capabilities: u3 = 0;
    for (capabilities) |profile| all_capabilities |= profile;
    var oracle_index: ?usize = null;
    for (capabilities, 0..) |profile, profile_index| {
        if (profile == all_capabilities) {
            oracle_index = profile_index;
            break;
        }
    }
    const oracle = candidates[
        oracle_index orelse
            return error.InvalidTrainingOptions
    ];

    var total_positions: usize = 0;
    for (validation_samples) |sample|
        total_positions = std.math.add(usize, total_positions, sample.len) catch
            return error.IntegerOverflow;
    if (total_positions == 0) return null;
    const rounded = std.math.add(
        usize,
        total_positions,
        options.max_positions - 1,
    ) catch return error.IntegerOverflow;
    const stride = @max(@as(usize, 1), rounded / options.max_positions);

    var demand: [max_dictionaries][3]u64 = @splat(@splat(0));
    var matcher = Matcher.init(allocator);
    defer matcher.deinit();
    try matcher.prepare(oracle);
    var ordinal: usize = 0;
    var sampled: usize = 0;
    outer: for (validation_samples) |sample| {
        for (0..sample.len) |position| {
            if (ordinal % stride == 0) {
                const context = trainingContext(
                    sample,
                    position,
                    context_mode,
                );
                var scratch: [serialized_dictionary.max_transformed_word_len]u8 =
                    undefined;
                if (try matcher.findLongest(
                    context,
                    sample[position..],
                    &scratch,
                )) |match| {
                    const resolved = try oracle.resolve(
                        context,
                        match.copy_len,
                        match.address,
                        &scratch,
                    );
                    const capability = try transformCapability(
                        oracle,
                        resolved.dictionary_id,
                        resolved.transform_index,
                    );
                    inline for (0..3) |bit| {
                        if (capability & (@as(u3, 1) << bit) != 0)
                            demand[resolved.dictionary_id][bit] +|=
                                match.output_len;
                    }
                }
                sampled += 1;
                if (sampled == options.max_positions) break :outer;
            }
            ordinal += 1;
        }
    }

    var result = Assignment{
        .profile_by_dictionary = @splat(0),
        .dictionary_count = reference.dictionary_count,
        .distinct_profile_count = 0,
    };
    var used: [max_profiles]bool = @splat(false);
    for (0..reference.dictionary_count) |dictionary_id| {
        var required: u3 = 0;
        inline for (0..3) |bit| {
            if (demand[dictionary_id][bit] != 0)
                required |= @as(u3, 1) << bit;
        }
        var best_profile: ?usize = null;
        var best_extra: u3 = std.math.maxInt(u3);
        for (capabilities, 0..) |profile, profile_index| {
            if (profile & required != required) continue;
            const extra: u3 = @intCast(@popCount(profile ^ required));
            if (best_profile == null or extra < best_extra) {
                best_profile = profile_index;
                best_extra = extra;
            }
        }
        const selected = best_profile orelse return error.InvalidTrainingOptions;
        result.profile_by_dictionary[dictionary_id] = @intCast(selected);
        if (!used[selected]) {
            used[selected] = true;
            result.distinct_profile_count += 1;
        }
    }
    if (result.distinct_profile_count < 2) return null;
    return result;
}

fn transformCapability(
    dictionary: *const serialized_dictionary.Dictionary,
    dictionary_id: u6,
    transform_index: u8,
) Error!u3 {
    const choice = dictionary.choice(dictionary_id) orelse
        return error.InvalidTrainingOptions;
    if (choice.transform_list_index >= dictionary.transform_list_count)
        return error.InvalidTrainingOptions;
    const list = &dictionary.transform_lists[choice.transform_list_index];
    const transform = list.transform(transform_index) orelse
        return error.InvalidTrainingOptions;
    var capability: u3 = 0;
    if (transform.kind == 10 or transform.kind == 11)
        capability |= 1;
    if ((transform.kind >= 1 and transform.kind <= 9) or
        (transform.kind >= 12 and transform.kind <= 20))
    {
        capability |= 2;
    }
    const prefix = list.string(transform.prefix_id) orelse
        return error.InvalidTrainingOptions;
    const suffix = list.string(transform.suffix_id) orelse
        return error.InvalidTrainingOptions;
    if (prefix.len != 0 or suffix.len != 0) capability |= 4;
    return capability;
}

fn validateEquivalentWordsAndMap(
    reference: *const serialized_dictionary.Dictionary,
    candidate: *const serialized_dictionary.Dictionary,
) Error!void {
    if (candidate.dictionary_count != reference.dictionary_count or
        candidate.word_list_count != reference.word_list_count or
        candidate.context_based != reference.context_based or
        !std.mem.eql(u6, &candidate.context_map, &reference.context_map))
    {
        return error.InvalidTrainingOptions;
    }
    for (0..reference.dictionary_count) |dictionary_id| {
        const reference_choice = reference.dictionaries[dictionary_id];
        const candidate_choice = candidate.dictionaries[dictionary_id];
        if (reference_choice.word_list_index != candidate_choice.word_list_index)
            return error.InvalidTrainingOptions;
    }
    for (0..reference.word_list_count) |word_list_index| {
        const reference_words = &reference.word_lists[word_list_index];
        const candidate_words = &candidate.word_lists[word_list_index];
        if (!std.mem.eql(
            u8,
            &reference_words.size_bits_by_length,
            &candidate_words.size_bits_by_length,
        ) or
            !std.mem.eql(u8, reference_words.data, candidate_words.data))
        {
            return error.InvalidTrainingOptions;
        }
    }
}

fn trainingContext(sample: []const u8, position: usize, mode: u2) usize {
    const previous = if (position == 0) 0 else sample[position - 1];
    const second_previous = if (position < 2) 0 else sample[position - 2];
    return literal_context.value(mode, previous, second_previous);
}

test "serialized transform clusterer validates bounded inputs" {
    try std.testing.expectError(
        error.InvalidTrainingOptions,
        assignAlloc(
            std.testing.allocator,
            &.{},
            &.{},
            &.{"sample"},
            literal_context.mode_lsb6,
            .{},
        ),
    );
    var dictionary: serialized_dictionary.Dictionary = undefined;
    try std.testing.expectError(
        error.InvalidTrainingOptions,
        assignAlloc(
            std.testing.allocator,
            &.{ &dictionary, &dictionary },
            &.{ 0, 1 },
            &.{"sample"},
            literal_context.mode_lsb6,
            .{ .max_positions = 0 },
        ),
    );
}

test "serialized transform clusterer assigns minimal profiles and releases failures" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var size_bits: [32]u8 = @splat(0);
            size_bits[8] = 1;
            const word_lists = [_]builder.WordListSpec{
                .{
                    .size_bits_by_length = size_bits,
                    .data = "loweronelowertwo",
                },
                .{
                    .size_bits_by_length = size_bits,
                    .data = "otheroneothertwo",
                },
            };
            const identity_transforms = [_]builder.TransformListSpec{.{
                .prefix_suffix = &.{0},
                .transforms = &.{ 0, 0, 0 },
            }};
            const case_transforms = [_]builder.TransformListSpec{.{
                .prefix_suffix = &.{0},
                .transforms = &.{ 0, 0, 0, 0, 10, 0, 0, 11, 0 },
            }};
            const choices = [_]serialized_dictionary.DictionaryChoice{
                .{ .word_list_index = 0, .transform_list_index = 0 },
                .{ .word_list_index = 1, .transform_list_index = 0 },
            };
            var context_map: [64]u6 = undefined;
            for (&context_map, 0..) |*dictionary_id, context|
                dictionary_id.* = @intFromBool(context >= 32);
            const identity_encoded = try builder.serializeAlloc(allocator, .{
                .word_lists = &word_lists,
                .transform_lists = &identity_transforms,
                .dictionaries = &choices,
                .context_map = &context_map,
            });
            defer allocator.free(identity_encoded);
            const case_encoded = try builder.serializeAlloc(allocator, .{
                .word_lists = &word_lists,
                .transform_lists = &case_transforms,
                .dictionaries = &choices,
                .context_map = &context_map,
            });
            defer allocator.free(case_encoded);
            const identity = try serialized_dictionary.parse(identity_encoded);
            const case = try serialized_dictionary.parse(case_encoded);
            const candidates = [_]*const serialized_dictionary.Dictionary{
                &identity,
                &case,
            };
            const assignment = (try assignAlloc(
                allocator,
                &candidates,
                &.{ 0, 1 },
                &.{ "\x08LOWERONE", "\x28otherone" },
                literal_context.mode_lsb6,
                .{ .max_positions = 64 },
            )) orelse return error.TestUnexpectedResult;
            try std.testing.expectEqual(@as(u7, 2), assignment.distinct_profile_count);
            try std.testing.expectEqual(@as(u8, 1), assignment.profile_by_dictionary[0]);
            try std.testing.expectEqual(@as(u8, 0), assignment.profile_by_dictionary[1]);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{},
    );
}
