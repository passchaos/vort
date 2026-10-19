const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

const max_raw_attachments = 15;
const qualities = [_]u4{ 0, 5, 9, 11 };
const fixture = [_]u8{ 0xa1, 0xa8, 0x00, 0xc0, 0x2f, 0x01, 0x10, 0xc4, 0x44, 0x09, 0x00 };
const fixture_dictionary_output = "Kot lomom kolol slona!";
const fixture_without_dictionary_output = "alternate\" type=\"appli";

const MatrixCase = struct {
    raw_dictionaries: []const []const u8,
    input: []const u8,
    expect_dictionary_copy: bool,
};

const VortEncodeCounts = struct {
    one_shot: usize = 0,
    reusable: usize = 0,
    chunked: usize = 0,
    incremental: usize = 0,
};

const streaming_options: libbrotli.Runtime.StreamingOptions = .{
    .quality = 11,
    .lgwin = 22,
    .lgblock = 0,
};

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    defer stdout.interface.flush() catch {};

    const fixture_one = [_][]const u8{fixture_dictionary_output};
    const fixture_two = [_][]const u8{
        fixture_dictionary_output[0..13],
        fixture_dictionary_output[13..],
    };
    var fixture_fifteen: [max_raw_attachments][]const u8 = @splat("");
    fixture_fifteen[0] = fixture_dictionary_output[0..4];
    fixture_fifteen[5] = fixture_dictionary_output[4..13];
    fixture_fifteen[14] = fixture_dictionary_output[13..];

    var dictionary_payload: [1024]u8 = undefined;
    fillDictionaryPayload(&dictionary_payload);
    const dictionary_one = [_][]const u8{&dictionary_payload};
    const dictionary_two = [_][]const u8{
        dictionary_payload[0..417],
        dictionary_payload[417..],
    };
    var dictionary_fifteen: [max_raw_attachments][]const u8 = @splat("");
    dictionary_fifteen[0] = dictionary_payload[0..173];
    dictionary_fifteen[5] = dictionary_payload[173..691];
    dictionary_fifteen[14] = dictionary_payload[691..];
    const cases = [_]MatrixCase{
        .{
            .raw_dictionaries = &.{},
            .input = "zero attachment payload",
            .expect_dictionary_copy = false,
        },
        .{
            .raw_dictionaries = &dictionary_one,
            .input = &dictionary_payload,
            .expect_dictionary_copy = true,
        },
        .{
            .raw_dictionaries = &dictionary_two,
            .input = &dictionary_payload,
            .expect_dictionary_copy = true,
        },
        .{
            .raw_dictionaries = &dictionary_fifteen,
            .input = &dictionary_payload,
            .expect_dictionary_copy = true,
        },
    };

    try validateVortFixtureDecode(
        init.gpa,
        &.{},
        fixture_without_dictionary_output,
        false,
    );
    try validateVortFixtureDecode(
        init.gpa,
        &fixture_one,
        fixture_dictionary_output,
        true,
    );
    try validateVortFixtureDecode(
        init.gpa,
        &fixture_two,
        fixture_dictionary_output,
        true,
    );
    try validateVortFixtureDecode(
        init.gpa,
        &fixture_fifteen,
        fixture_dictionary_output,
        true,
    );
    try validateDescriptorErrors();

    var runtime = libbrotli.Runtime.open() catch {
        try stdout.interface.writeAll(
            "br_compound_dictionary_diff=ok fixture_cases=4 descriptor_errors=3 " ++
                "shared_dictionary_matrix=skipped reason=libbrotli_unavailable " ++
                "reference_encode=skipped vort_encode=skipped " ++
                "runtime_regressions=skipped serialized_cases=skipped\n",
        );
        return;
    };
    defer runtime.deinit();

    if (!runtime.supportsSharedDictionary()) {
        try expectError(
            error.ReferenceUnavailable,
            runtime.encodeWithRawDictionariesAlloc(
                init.gpa,
                fixture_dictionary_output,
                &fixture_one,
                streaming_options,
            ),
        );
        try stdout.interface.print(
            "br_compound_dictionary_diff=ok fixture_cases=4 descriptor_errors=3 " ++
                "shared_dictionary_matrix=skipped reason=libbrotli_missing_symbols " ++
                "reference_version={x} reference_encode=skipped vort_encode=skipped " ++
                "runtime_regressions=skipped serialized_cases=skipped\n",
            .{runtime.version()},
        );
        return;
    }

    const reference_encode_cases = try validateReferenceEncodeMatrix(
        init.gpa,
        runtime,
        &cases,
    );
    try validateReferenceAttachmentLimit(init.gpa, runtime);

    const vort_counts = try validateVortEncodeMatrix(
        init.gpa,
        runtime,
        &cases,
    );
    const runtime_regression_cases = try validateRuntimeRegressionMatrix(
        init.gpa,
        runtime,
    );
    const serialized_cases = try validateSerializedDictionaryMatrix(
        init.gpa,
        runtime,
    );
    try writeSuccess(
        &stdout.interface,
        runtime.version(),
        reference_encode_cases,
        vort_counts,
        runtime_regression_cases,
        serialized_cases,
    );
}

fn writeSuccess(
    writer: *std.Io.Writer,
    reference_version: u32,
    reference_encode_cases: usize,
    vort_counts: VortEncodeCounts,
    runtime_regression_cases: usize,
    serialized_cases: ?usize,
) !void {
    try writer.print(
        "br_compound_dictionary_diff=ok fixture_cases=4 descriptor_errors=3 " ++
            "attachment_cases=4 quality_cases=4 reference_encode_cases={d} " ++
            "runtime_regression_cases={d} reference_version={x}",
        .{ reference_encode_cases, runtime_regression_cases, reference_version },
    );
    if (serialized_cases) |count|
        try writer.print(" serialized_cases={d}", .{count})
    else
        try writer.writeAll(" serialized_cases=skipped reason=experimental_disabled");

    if (vort_counts.one_shot == 0) {
        try writer.writeAll(
            " vort_encode=skipped " ++
                "reason=public_encoder_shared_dictionary_not_exposed\n",
        );
        return;
    }

    try writer.print(
        " vort_one_shot_cases={d} vort_reusable_cases={d}",
        .{ vort_counts.one_shot, vort_counts.reusable },
    );
    if (vort_counts.chunked == 0) {
        try writer.writeAll(
            " vort_chunked=skipped " ++
                "reason=public_chunked_shared_dictionary_not_exposed",
        );
    } else {
        try writer.print(" vort_chunked_cases={d}", .{vort_counts.chunked});
    }
    if (vort_counts.incremental == 0) {
        try writer.writeAll(
            " vort_incremental=skipped " ++
                "reason=public_incremental_shared_dictionary_not_exposed",
        );
    } else {
        try writer.print(
            " vort_incremental_cases={d}",
            .{vort_counts.incremental},
        );
    }
    try writer.writeByte('\n');
}

fn validateSerializedDictionaryMatrix(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
) !?usize {
    const dictionary_word = "abcdefghijklmnopqrstuvwxyz12345";
    const input = dictionary_word ** 8;
    var encoded_dictionary: std.ArrayList(u8) = .empty;
    defer encoded_dictionary.deinit(allocator);
    try encoded_dictionary.appendSlice(allocator, &.{ 0x91, 0, 0, 1 });
    var bits: [28]u8 = @splat(0);
    bits[dictionary_word.len - 4] = 1;
    try encoded_dictionary.appendSlice(allocator, &bits);
    try encoded_dictionary.appendSlice(allocator, dictionary_word);
    try encoded_dictionary.appendSlice(
        allocator,
        "9876543210ZYXWVUTSRQPONMLKJIHGF",
    );
    try encoded_dictionary.appendSlice(allocator, &.{
        1, 1, 0, 0, 1, 0, 0, 0, // identity transform list
        1, 0, 0, // one custom/custom dictionary choice
        0, // context map disabled
    });
    if (!runtime.supportsSerializedDictionary(encoded_dictionary.items, 5))
        return null;

    const parsed = try vort.brParseSerializedSharedDictionary(
        encoded_dictionary.items,
    );
    const shared = vort.BrotliSharedDictionary{ .serialized = &parsed };
    const decode_options = vort.BrotliDecodeOptions{
        .shared_dictionary = shared,
    };
    const vort_wire = try vort.brEncodePlannedStreamWithOptionsAlloc(
        allocator,
        input,
        .{ .quality = 5, .shared_dictionary = shared },
    );
    defer allocator.free(vort_wire);
    var reference_output: [input.len]u8 = undefined;
    try runtime.decodeWithSerializedDictionary(
        vort_wire,
        &reference_output,
        encoded_dictionary.items,
    );
    if (!std.mem.eql(u8, input, &reference_output))
        return error.ReferenceDecodeFailed;

    var reference_options = streaming_options;
    reference_options.quality = 5;
    const reference_wire = try runtime.encodeWithSerializedDictionaryAlloc(
        allocator,
        input,
        encoded_dictionary.items,
        reference_options,
    );
    defer allocator.free(reference_wire);
    const vort_output = try vort.brDecodeStreamAllocExactSizeWithOptions(
        allocator,
        reference_wire,
        input.len,
        decode_options,
    );
    defer allocator.free(vort_output);
    if (!std.mem.eql(u8, input, vort_output))
        return error.ReferenceDecodeFailed;

    var contextual_dictionary: std.ArrayList(u8) = .empty;
    defer contextual_dictionary.deinit(allocator);
    var contextual_input: std.ArrayList(u8) = .empty;
    defer contextual_input.deinit(allocator);
    try buildContextualSerializedDictionary(
        allocator,
        &contextual_dictionary,
        &contextual_input,
    );
    const contextual_parsed = try vort.brParseSerializedSharedDictionary(
        contextual_dictionary.items,
    );
    const contextual_shared = vort.BrotliSharedDictionary{
        .serialized = &contextual_parsed,
    };
    const contextual_options = vort.BrotliDecodeOptions{
        .shared_dictionary = contextual_shared,
    };
    const contextual_vort_wire = try vort.brEncodePlannedStreamWithOptionsAlloc(
        allocator,
        contextual_input.items,
        .{ .quality = 5, .shared_dictionary = contextual_shared },
    );
    defer allocator.free(contextual_vort_wire);
    const contextual_summary = try vort.brSummarizeStreamWithOptions(
        contextual_vort_wire,
        contextual_options,
    );
    if (contextual_summary.shared_dictionary_copy_count == 0 or
        contextual_summary.literal_context_mode_bytes[2] == 0)
    {
        return error.ReferenceEncodeFailed;
    }
    const contextual_reference_output = try allocator.alloc(
        u8,
        contextual_input.items.len,
    );
    defer allocator.free(contextual_reference_output);
    try runtime.decodeWithSerializedDictionary(
        contextual_vort_wire,
        contextual_reference_output,
        contextual_dictionary.items,
    );
    if (!std.mem.eql(
        u8,
        contextual_input.items,
        contextual_reference_output,
    )) return error.ReferenceDecodeFailed;

    const contextual_reference_wire = try runtime.encodeWithSerializedDictionaryAlloc(
        allocator,
        contextual_input.items,
        contextual_dictionary.items,
        reference_options,
    );
    defer allocator.free(contextual_reference_wire);
    const contextual_vort_output = try vort.brDecodeStreamAllocExactSizeWithOptions(
        allocator,
        contextual_reference_wire,
        contextual_input.items.len,
        contextual_options,
    );
    defer allocator.free(contextual_vort_output);
    if (!std.mem.eql(
        u8,
        contextual_input.items,
        contextual_vort_output,
    )) return error.ReferenceDecodeFailed;
    try validateTrainedSerializedDictionary(
        allocator,
        runtime,
        reference_options,
    );
    try validateCaseTrainedSerializedDictionary(
        allocator,
        runtime,
        reference_options,
    );
    try validateOmitTrainedSerializedDictionary(
        allocator,
        runtime,
        reference_options,
    );
    try validatePrefixSuffixTrainedSerializedDictionary(
        allocator,
        runtime,
        reference_options,
    );
    try validateClusteredTrainedSerializedDictionary(
        allocator,
        runtime,
        reference_options,
    );
    try validateTransformClusteredSerializedDictionary(
        allocator,
        runtime,
        reference_options,
    );
    try validateShiftTrainedSerializedDictionary(
        allocator,
        runtime,
        reference_options,
    );
    return 22;
}

fn validateTrainedSerializedDictionary(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    reference_options: libbrotli.Runtime.StreamingOptions,
) !void {
    const phrases = [_][]const u8{
        "A1b2C3d4E5f6G7h8",
        "J9k0L1m2N3p4Q5r6",
        "S7t8U9v0W1x2Y3z4",
        "B5c6D7e8F9g0H1i2",
    };
    var training_storage: [8][68]u8 = undefined;
    var training_samples: [training_storage.len][]const u8 = undefined;
    for (&training_storage, &training_samples, 0..) |*storage, *sample, index|
        sample.* = fillSerializedTrainingSample(storage, index, &phrases);
    var validation_storage: [64][68]u8 = undefined;
    var validation_samples: [validation_storage.len][]const u8 = undefined;
    for (&validation_storage, &validation_samples, 0..) |*storage, *sample, index|
        sample.* = fillSerializedTrainingSample(storage, 0x1000 + index, &phrases);
    const trained = (try vort.brTrainSerializedSharedDictionaryAlloc(
        allocator,
        &training_samples,
        &validation_samples,
        .{
            .min_word_len = 16,
            .max_word_len = 16,
            .max_words_per_length = 8,
            .max_phrases_per_length = 64,
            .train_context_clustering = false,
            .train_prefix_suffix_transforms = false,
            .train_shift_transforms = false,
            .quality = 5,
        },
    )) orelse return error.ReferenceEncodeFailed;
    defer trained.deinit(allocator);
    try validateOwnedTrainedDictionaryInterop(
        allocator,
        runtime,
        reference_options,
        &trained,
        validation_samples[0],
    );
}

fn validateOwnedTrainedDictionaryInterop(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    reference_options: libbrotli.Runtime.StreamingOptions,
    trained: *const vort.BrotliOwnedTrainedSerializedSharedDictionary,
    sample: []const u8,
) !void {
    const parsed = try trained.parse();
    const shared = vort.BrotliSharedDictionary{ .serialized = &parsed };
    const decode_options = vort.BrotliDecodeOptions{ .shared_dictionary = shared };

    const vort_wire = try vort.brEncodePlannedStreamWithOptionsAlloc(
        allocator,
        sample,
        .{ .quality = 5, .shared_dictionary = shared },
    );
    defer allocator.free(vort_wire);
    const reference_output = try allocator.alloc(u8, sample.len);
    defer allocator.free(reference_output);
    try runtime.decodeWithSerializedDictionary(
        vort_wire,
        reference_output,
        trained.bytes,
    );
    if (!std.mem.eql(u8, sample, reference_output))
        return error.ReferenceDecodeFailed;

    const reference_wire = try runtime.encodeWithSerializedDictionaryAlloc(
        allocator,
        sample,
        trained.bytes,
        reference_options,
    );
    defer allocator.free(reference_wire);
    const vort_output = try vort.brDecodeStreamAllocExactSizeWithOptions(
        allocator,
        reference_wire,
        sample.len,
        decode_options,
    );
    defer allocator.free(vort_output);
    if (!std.mem.eql(u8, sample, vort_output))
        return error.ReferenceDecodeFailed;
}

fn validateCaseTrainedSerializedDictionary(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    reference_options: libbrotli.Runtime.StreamingOptions,
) !void {
    const phrases = [_][]const u8{
        "azbycxdwevfugths",
        "qwertyuiopasdfgh",
        "mnbvcxzlkjhgfdsa",
        "plmoknijbuhvygct",
    };
    var training_storage: [8][68]u8 = undefined;
    var training_samples: [training_storage.len][]const u8 = undefined;
    for (&training_storage, &training_samples, 0..) |*storage, *sample, index|
        sample.* = fillCaseTrainingSample(storage, index, &phrases, false);
    var validation_storage: [64][68]u8 = undefined;
    var validation_samples: [validation_storage.len][]const u8 = undefined;
    for (&validation_storage, &validation_samples, 0..) |*storage, *sample, index|
        sample.* = fillCaseTrainingSample(storage, 0x2000 + index, &phrases, true);
    const trained = (try vort.brTrainSerializedSharedDictionaryAlloc(
        allocator,
        &training_samples,
        &validation_samples,
        .{
            .min_word_len = 16,
            .max_word_len = 16,
            .max_words_per_length = 8,
            .max_phrases_per_length = 64,
            .train_context_map = false,
            .train_prefix_suffix_transforms = false,
            .train_shift_transforms = false,
            .quality = 5,
        },
    )) orelse return error.ReferenceEncodeFailed;
    defer trained.deinit(allocator);
    if (trained.transform_profile != .ascii_case)
        return error.ReferenceEncodeFailed;
    try validateOwnedTrainedDictionaryInterop(
        allocator,
        runtime,
        reference_options,
        &trained,
        validation_samples[0],
    );
}

fn fillCaseTrainingSample(
    storage: *[68]u8,
    id: usize,
    phrases: *const [4][]const u8,
    uppercase: bool,
) []const u8 {
    std.mem.writeInt(u32, storage[0..4], @intCast(id), .little);
    var cursor: usize = 4;
    for (phrases) |phrase| {
        for (phrase) |byte| {
            storage[cursor] = if (uppercase) std.ascii.toUpper(byte) else byte;
            cursor += 1;
        }
    }
    return storage[0..cursor];
}

fn validateOmitTrainedSerializedDictionary(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    reference_options: libbrotli.Runtime.StreamingOptions,
) !void {
    const phrases = [_][]const u8{
        "azbycxdwevfuTAIL",
        "qwertyuiopasEND1",
        "mnbvcxzlkjhgEND2",
        "plmoknijbuhvEND3",
    };
    var training_storage: [8][68]u8 = undefined;
    var training_samples: [training_storage.len][]const u8 = undefined;
    for (&training_storage, &training_samples, 0..) |*storage, *sample, index|
        sample.* = fillOmitTrainingSample(storage, index, &phrases, false);
    var validation_storage: [64][52]u8 = undefined;
    var validation_samples: [validation_storage.len][]const u8 = undefined;
    for (&validation_storage, &validation_samples, 0..) |*storage, *sample, index|
        sample.* = fillOmitTrainingSample(storage, 0x3000 + index, &phrases, true);
    const trained = (try vort.brTrainSerializedSharedDictionaryAlloc(
        allocator,
        &training_samples,
        &validation_samples,
        .{
            .min_word_len = 16,
            .max_word_len = 16,
            .max_words_per_length = 8,
            .max_phrases_per_length = 64,
            .train_context_map = false,
            .train_prefix_suffix_transforms = false,
            .train_shift_transforms = false,
            .quality = 5,
        },
    )) orelse return error.ReferenceEncodeFailed;
    defer trained.deinit(allocator);
    if (trained.transform_profile != .omit)
        return error.ReferenceEncodeFailed;
    try validateOwnedTrainedDictionaryInterop(
        allocator,
        runtime,
        reference_options,
        &trained,
        validation_samples[0],
    );
}

fn validatePrefixSuffixTrainedSerializedDictionary(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    reference_options: libbrotli.Runtime.StreamingOptions,
) !void {
    const phrases = [_][]const u8{
        "azbycxdwevfugths",
        "qwertyuiopasdfgh",
        "mnbvcxzlkjhgfdsa",
        "plmoknijbuhvygct",
    };
    var wrapped_training_storage: [32][18]u8 = undefined;
    var training_samples: [64][]const u8 = undefined;
    var training_index: usize = 0;
    for (phrases, 0..) |phrase, phrase_index| {
        for (0..8) |_| {
            training_samples[training_index] = phrase;
            training_index += 1;
        }
        for (0..8) |repeat_index| {
            const wrapped = &wrapped_training_storage[phrase_index * 8 + repeat_index];
            wrapped[0] = '<';
            @memcpy(wrapped[1..17], phrase);
            wrapped[17] = '>';
            training_samples[training_index] = wrapped;
            training_index += 1;
        }
    }
    var validation_storage: [64][76]u8 = undefined;
    var validation_samples: [validation_storage.len][]const u8 = undefined;
    for (&validation_storage, &validation_samples, 0..) |*storage, *sample, index| {
        std.mem.writeInt(u32, storage[0..4], @intCast(0x4000 + index), .little);
        var cursor: usize = 4;
        for (phrases) |phrase| {
            storage[cursor] = '<';
            cursor += 1;
            @memcpy(storage[cursor..][0..phrase.len], phrase);
            cursor += phrase.len;
            storage[cursor] = '>';
            cursor += 1;
        }
        sample.* = storage[0..cursor];
    }
    const trained = (try vort.brTrainSerializedSharedDictionaryAlloc(
        allocator,
        &training_samples,
        &validation_samples,
        .{
            .min_word_len = 16,
            .max_word_len = 16,
            .max_words_per_length = 8,
            .max_phrases_per_length = 64,
            .train_context_map = false,
            .train_case_transforms = false,
            .train_omit_transforms = false,
            .train_shift_transforms = false,
            .max_prefix_suffix_len = 1,
            .max_prefix_suffix_transforms = 1,
            .max_prefix_suffix_candidates = 16,
            .max_prefix_suffix_positions = 1024,
            .quality = 5,
        },
    )) orelse return error.ReferenceEncodeFailed;
    defer trained.deinit(allocator);
    if (trained.transform_profile != .prefix_suffix or
        trained.learned_stringlet_count != 2 or
        trained.learned_prefix_suffix_transform_count != 1)
    {
        return error.ReferenceEncodeFailed;
    }
    try validateOwnedTrainedDictionaryInterop(
        allocator,
        runtime,
        reference_options,
        &trained,
        validation_samples[0],
    );
}

fn validateClusteredTrainedSerializedDictionary(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    reference_options: libbrotli.Runtime.StreamingOptions,
) !void {
    const Fixture = struct {
        const markers = [3][2]u8{
            .{ 8, 32 },
            .{ 16, 40 },
            .{ 24, 48 },
        };

        fn word(group: usize, index: usize) [8]u8 {
            var value = (@as(u64, group + 1) << 48) |
                (@as(u64, index + 1) << 8) | 0x5b;
            value *%= 0x9e37_79b9_7f4a_7c15;
            var result: [8]u8 = undefined;
            std.mem.writeInt(u64, &result, value, .little);
            result[0] |= 0x80;
            return result;
        }

        fn fill(storage: *[9]u8, ordinal: usize) []const u8 {
            const shape = ordinal % (3 * 2 * 8);
            const group = shape / 16;
            const marker_index = (shape / 8) % 2;
            storage[0] = markers[group][marker_index];
            const bytes = word(group, shape % 8);
            @memcpy(storage[1..], &bytes);
            return storage;
        }
    };
    var training_storage: [192][9]u8 = undefined;
    var training_samples: [training_storage.len][]const u8 = undefined;
    for (&training_storage, &training_samples, 0..) |*storage, *sample, index|
        sample.* = Fixture.fill(storage, index);
    var validation_storage: [384][9]u8 = undefined;
    var validation_samples: [validation_storage.len][]const u8 = undefined;
    for (&validation_storage, &validation_samples, 0..) |*storage, *sample, index|
        sample.* = Fixture.fill(storage, index);
    const trained = (try vort.brTrainSerializedSharedDictionaryAlloc(
        allocator,
        &training_samples,
        &validation_samples,
        .{
            .min_word_len = 8,
            .max_word_len = 8,
            .max_words_per_length = 8,
            .max_phrases_per_length = 64,
            .train_case_transforms = false,
            .train_omit_transforms = false,
            .train_prefix_suffix_transforms = false,
            .train_shift_transforms = false,
            .context_cluster_counts = &.{4},
            .max_context_positions_per_group = 1024,
            .max_context_signature_positions = 1024,
            .quality = 5,
        },
    )) orelse return error.ReferenceEncodeFailed;
    defer trained.deinit(allocator);
    if (trained.context_profile != .clustered or
        trained.context_cluster_count != 4)
    {
        return error.ReferenceEncodeFailed;
    }
    try validateOwnedTrainedDictionaryInterop(
        allocator,
        runtime,
        reference_options,
        &trained,
        validation_samples[0],
    );
}

fn validateTransformClusteredSerializedDictionary(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    reference_options: libbrotli.Runtime.StreamingOptions,
) !void {
    const Fixture = struct {
        const markers = [3][2]u8{
            .{ 8, 32 },
            .{ 16, 40 },
            .{ 24, 48 },
        };

        fn word(group: usize, index: usize) [16]u8 {
            var result: [16]u8 = undefined;
            result[0] = @intCast('a' + group);
            result[1] = @intCast('a' + index);
            for (result[2..], 2..) |*byte, position|
                byte.* = @intCast('a' + (group * 7 + index * 11 + position * 3) % 26);
            return result;
        }

        fn fillTraining(storage: *[17]u8, ordinal: usize) []const u8 {
            const shape = ordinal % (3 * 2 * 8);
            const group = shape / 16;
            storage[0] = markers[group][(shape / 8) % 2];
            const bytes = word(group, shape % 8);
            @memcpy(storage[1..], &bytes);
            return storage;
        }

        fn fillValidation(storage: *[17]u8, shape: usize) []const u8 {
            const context_group = shape / 16;
            const word_group = (context_group + 1) % 3;
            storage[0] = markers[context_group][(shape / 8) % 2];
            const bytes = word(word_group, shape % 8);
            if (context_group == 0) {
                for (bytes, 0..) |byte, position|
                    storage[position + 1] = std.ascii.toUpper(byte);
                return storage;
            }
            const word_len: usize = if (context_group == 1) 12 else bytes.len;
            @memcpy(storage[1..][0..word_len], bytes[0..word_len]);
            return storage[0 .. word_len + 1];
        }
    };
    var training_storage: [192][17]u8 = undefined;
    var training_samples: [training_storage.len][]const u8 = undefined;
    for (&training_storage, &training_samples, 0..) |*storage, *sample, index|
        sample.* = Fixture.fillTraining(storage, index);
    var validation_storage: [768][17]u8 = undefined;
    var validation_samples: [validation_storage.len][]const u8 = undefined;
    for (&validation_storage, &validation_samples, 0..) |*storage, *sample, index| {
        const shape = if (index < 64)
            index % 16
        else if (index < 704)
            16 + (index - 64) % 16
        else
            32 + (index - 704) % 16;
        sample.* = Fixture.fillValidation(storage, shape);
    }
    const trained = (try vort.brTrainSerializedSharedDictionaryAlloc(
        allocator,
        &training_samples,
        &validation_samples,
        .{
            .min_word_len = 16,
            .max_word_len = 16,
            .max_words_per_length = 8,
            .max_phrases_per_length = 64,
            .train_prefix_suffix_transforms = false,
            .train_shift_transforms = false,
            .context_modes = &.{0},
            .context_cluster_counts = &.{4},
            .max_context_positions_per_group = 1024,
            .max_context_signature_positions = 1024,
            .max_transform_scoring_positions = 16 * 1024,
            .quality = 5,
        },
    )) orelse return error.ReferenceEncodeFailed;
    defer trained.deinit(allocator);
    if (trained.transform_profile != .clustered or
        trained.transform_list_count != 2)
    {
        return error.ReferenceEncodeFailed;
    }
    for ([_]usize{ 0, 64, 704 }) |sample_index|
        try validateOwnedTrainedDictionaryInterop(
            allocator,
            runtime,
            reference_options,
            &trained,
            validation_samples[sample_index],
        );
}

fn validateShiftTrainedSerializedDictionary(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    reference_options: libbrotli.Runtime.StreamingOptions,
) !void {
    const phrases = [_][]const u8{
        "ĀāĂăĄąĆć",
        "ĐđĒēĔĕĖė",
        "ĠġĢģĤĥĦħ",
        "İıĲĳĴĵĶķ",
    };
    const shifted_phrases = [_][]const u8{
        "āāĂăĄąĆć",
        "đđĒēĔĕĖė",
        "ġĢģĤĥĦħĨ",
        "ıĲĳĴĵĶķĸ",
    };
    var training_storage: [4][256]u8 = undefined;
    var training_samples: [training_storage.len][]const u8 = undefined;
    for (&training_storage, &training_samples, phrases) |*storage, *sample, phrase| {
        var cursor: usize = 0;
        for (0..16) |_| {
            @memcpy(storage[cursor..][0..phrase.len], phrase);
            cursor += phrase.len;
        }
        sample.* = storage;
    }
    var validation_storage: [64][68]u8 = undefined;
    var validation_samples: [validation_storage.len][]const u8 = undefined;
    for (&validation_storage, &validation_samples, 0..) |*storage, *sample, index| {
        std.mem.writeInt(u32, storage[0..4], @intCast(0x5000 + index), .little);
        var cursor: usize = 4;
        for (shifted_phrases) |phrase| {
            @memcpy(storage[cursor..][0..phrase.len], phrase);
            cursor += phrase.len;
        }
        sample.* = storage[0..cursor];
    }
    const trained = (try vort.brTrainSerializedSharedDictionaryAlloc(
        allocator,
        &training_samples,
        &validation_samples,
        .{
            .min_word_len = 16,
            .max_word_len = 16,
            .max_words_per_length = 8,
            .max_phrases_per_length = 64,
            .train_context_map = false,
            .train_case_transforms = false,
            .train_omit_transforms = false,
            .train_prefix_suffix_transforms = false,
            .max_shift_transforms = 2,
            .max_shift_candidates = 64,
            .max_shift_words = 16,
            .max_shift_positions = 4096,
            .quality = 5,
        },
    )) orelse return error.ReferenceEncodeFailed;
    defer trained.deinit(allocator);
    if (trained.transform_profile != .shift or
        trained.learned_shift_parameter_count != 1 or
        trained.learned_shift_transform_count != 2)
    {
        return error.ReferenceEncodeFailed;
    }
    try validateOwnedTrainedDictionaryInterop(
        allocator,
        runtime,
        reference_options,
        &trained,
        validation_samples[0],
    );
}

fn fillOmitTrainingSample(
    storage: anytype,
    id: usize,
    phrases: *const [4][]const u8,
    omit_tail: bool,
) []const u8 {
    std.mem.writeInt(u32, storage[0..4], @intCast(id), .little);
    var cursor: usize = 4;
    for (phrases) |phrase| {
        const bytes = if (omit_tail) phrase[0..12] else phrase;
        @memcpy(storage[cursor..][0..bytes.len], bytes);
        cursor += bytes.len;
    }
    return storage[0..cursor];
}

fn fillSerializedTrainingSample(
    storage: *[68]u8,
    id: usize,
    phrases: *const [4][]const u8,
) []const u8 {
    std.mem.writeInt(u32, storage[0..4], @intCast(id), .little);
    var cursor: usize = 4;
    for (phrases) |phrase| {
        @memcpy(storage[cursor..][0..phrase.len], phrase);
        cursor += phrase.len;
    }
    return storage[0..cursor];
}

fn buildContextualSerializedDictionary(
    allocator: std.mem.Allocator,
    dictionary: *std.ArrayList(u8),
    input: *std.ArrayList(u8),
) !void {
    var fallback_words: std.ArrayList(u8) = .empty;
    defer fallback_words.deinit(allocator);
    var contextual_words: std.ArrayList(u8) = .empty;
    defer contextual_words.deinit(allocator);
    for (0..256) |index| {
        var bytes = contextualSerializedWord(index);
        bytes[0] &= 0x7f;
        try fallback_words.appendSlice(allocator, &bytes);
    }
    for (0..256) |index| {
        const bytes = contextualSerializedWord(index);
        try contextual_words.appendSlice(allocator, &bytes);
    }
    var bits: [32]u8 = @splat(0);
    bits[8] = 8;
    const word_lists = [_]vort.BrotliSerializedSharedDictionaryWordListSpec{
        .{ .size_bits_by_length = bits, .data = fallback_words.items },
        .{ .size_bits_by_length = bits, .data = contextual_words.items },
    };
    const transform_lists = [_]vort.BrotliSerializedSharedDictionaryTransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{ 0, 0, 0 },
    }};
    const choices = [_]vort.BrotliSerializedSharedDictionaryChoice{
        .{ .word_list_index = 0, .transform_list_index = 0 },
        .{ .word_list_index = 1, .transform_list_index = 0 },
    };
    var context_map: [64]u6 = @splat(0);
    context_map[2] = 1; // UTF8(0x01, '0'); other modes select dictionary 0.
    try vort.brSerializeSharedDictionaryAppend(allocator, dictionary, .{
        .word_lists = &word_lists,
        .transform_lists = &transform_lists,
        .dictionaries = &choices,
        .context_map = &context_map,
    });
    for (0..64) |index| {
        try input.appendSlice(allocator, &.{ 0x30, 0x01 });
        const bytes = contextualSerializedWord(index);
        try input.appendSlice(allocator, &bytes);
    }
}

fn contextualSerializedWord(index: usize) [8]u8 {
    var value: u64 = @as(u64, index) *% 0x9e37_79b9_7f4a_7c15 +%
        0xa5a5_5a5a_d3c1_b2e7;
    var result: [8]u8 = undefined;
    for (&result) |*byte| {
        value ^= value >> 12;
        value ^= value << 25;
        value ^= value >> 27;
        byte.* = @truncate(value);
    }
    result[0] |= 0x80;
    return result;
}

fn validateVortFixtureDecode(
    allocator: std.mem.Allocator,
    raw_dictionaries: []const []const u8,
    expected: []const u8,
    expect_dictionary_copy: bool,
) !void {
    const options = decodeOptions(raw_dictionaries);
    const decoded = try vort.brDecodeStreamAllocExactSizeWithOptions(
        allocator,
        &fixture,
        expected.len,
        options,
    );
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, expected, decoded)) return error.ReferenceDecodeFailed;

    const summary = try vort.brSummarizeStreamWithOptions(&fixture, options);
    if (summary.uses_shared_dictionary != expect_dictionary_copy)
        return error.ReferenceDecodeFailed;
    if (expect_dictionary_copy and
        (summary.shared_dictionary_copy_count == 0 or
            summary.shared_dictionary_bytes != expected.len))
        return error.ReferenceDecodeFailed;
}

fn validateReferenceEncodeMatrix(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    cases: []const MatrixCase,
) !usize {
    var count: usize = 0;
    for (cases) |case| {
        for (qualities) |quality| {
            try validateReferenceEncode(allocator, runtime, case, quality);
            count += 1;
        }
    }
    return count;
}

fn validateReferenceEncode(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    case: MatrixCase,
    quality: u4,
) !void {
    var options = streaming_options;
    options.quality = quality;
    const encoded = try runtime.encodeWithRawDictionariesAlloc(
        allocator,
        case.input,
        case.raw_dictionaries,
        options,
    );
    defer allocator.free(encoded);

    const decoded = try vort.brDecodeStreamAllocExactSizeWithOptions(
        allocator,
        encoded,
        case.input.len,
        decodeOptions(case.raw_dictionaries),
    );
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, case.input, decoded)) return error.ReferenceDecodeFailed;

    const reference_output = try allocator.alloc(u8, case.input.len);
    defer allocator.free(reference_output);
    try runtime.decodeWithRawDictionaries(
        encoded,
        reference_output,
        case.raw_dictionaries,
    );
    if (!std.mem.eql(u8, case.input, reference_output))
        return error.ReferenceDecodeFailed;

    const summary = try vort.brSummarizeStreamWithOptions(
        encoded,
        decodeOptions(case.raw_dictionaries),
    );
    // libbrotli 1.2 q0 accepts and prepares RAW attachments but deliberately
    // selects its stored-speed path for this incompressible payload. Keep q0
    // in the interoperability matrix without claiming that attachment means
    // the encoder must reference it; q5+ must prove an actual compound copy.
    const expect_dictionary_copy = case.expect_dictionary_copy and quality != 0;
    if ((!case.expect_dictionary_copy and summary.uses_shared_dictionary) or
        (expect_dictionary_copy and !summary.uses_shared_dictionary))
        return error.ReferenceEncodeFailed;
}

fn validateDescriptorErrors() !void {
    const too_many: [max_raw_attachments + 1][]const u8 = @splat("");
    const too_many_dictionary = vort.BrotliSharedDictionary{ .raw_prefixes = &too_many };
    try expectError(error.TooManyRawPrefixes, too_many_dictionary.validate());

    const sentinel: [*]const u8 = @ptrFromInt(1);
    const max_raw_size = @as(usize, 1) << (23 + @sizeOf(usize));
    const too_large_dictionary = vort.BrotliSharedDictionary{
        .raw_prefixes = &.{sentinel[0 .. max_raw_size + 1]},
    };
    try expectError(error.RawDictionaryTooLarge, too_large_dictionary.validate());

    const overflow_dictionary = vort.BrotliSharedDictionary{
        .raw_prefixes = &.{ sentinel[0..std.math.maxInt(usize)], "x" },
    };
    try expectError(error.IntegerOverflow, overflow_dictionary.validate());

    var output: [32]u8 = @splat(0xa5);
    try expectError(
        error.CorruptFrame,
        vort.brDecodeStreamIntoWithOptions(
            &fixture,
            &output,
            .{ .shared_dictionary = too_many_dictionary },
        ),
    );
    if (!std.mem.allEqual(u8, &output, 0xa5)) return error.OutputMutated;

    try expectError(
        error.CorruptFrame,
        vort.brDecodeStreamIntoWithOptions(
            &fixture,
            &output,
            .{ .shared_dictionary = too_large_dictionary },
        ),
    );
    if (!std.mem.allEqual(u8, &output, 0xa5)) return error.OutputMutated;

    try expectError(
        error.IntegerOverflow,
        vort.brDecodeStreamIntoWithOptions(
            &fixture,
            &output,
            .{ .shared_dictionary = overflow_dictionary },
        ),
    );
    if (!std.mem.allEqual(u8, &output, 0xa5)) return error.OutputMutated;
}

fn validateReferenceAttachmentLimit(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
) !void {
    const too_many: [max_raw_attachments + 1][]const u8 = @splat("");
    try expectError(
        error.ReferenceEncodeFailed,
        runtime.encodeWithRawDictionariesAlloc(
            allocator,
            fixture_dictionary_output,
            &too_many,
            streaming_options,
        ),
    );
    var output: [fixture_dictionary_output.len]u8 = undefined;
    try expectError(
        error.ReferenceDecodeFailed,
        runtime.decodeWithRawDictionaries(&fixture, &output, &too_many),
    );
}

fn validateVortEncodeMatrix(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    cases: []const MatrixCase,
) !VortEncodeCounts {
    if (comptime !@hasField(vort.BrotliPlannedEncodeOptions, "shared_dictionary"))
        return .{};

    var counts: VortEncodeCounts = .{};
    var encoder = vort.BrotliPlannedStreamEncoder.init(allocator);
    defer encoder.deinit();

    for (cases) |case| {
        for (qualities) |quality| {
            var options: vort.BrotliPlannedEncodeOptions = .{ .quality = quality };
            @field(options, "shared_dictionary") = .{
                .raw_prefixes = case.raw_dictionaries,
            };

            const one_shot = try vort.brEncodePlannedStreamWithOptionsAlloc(
                allocator,
                case.input,
                options,
            );
            defer allocator.free(one_shot);
            try validateVortEncoded(
                allocator,
                runtime,
                one_shot,
                case,
                // Match upstream q0's legal stored-path behavior.
                quality != 0,
            );
            counts.one_shot += 1;

            const reusable = try encoder.encodeWithOptionsAlloc(
                allocator,
                case.input,
                options,
            );
            defer allocator.free(reusable);
            try validateVortEncoded(
                allocator,
                runtime,
                reusable,
                case,
                quality != 0,
            );
            counts.reusable += 1;
        }

        if (comptime chunkedEncodeExposed()) {
            const chunks = splitInput(case.input);
            var chunked_options: vort.BrotliPlannedStreamChunksOptions = .{};
            @field(chunked_options, "shared_dictionary") = .{
                .raw_prefixes = case.raw_dictionaries,
            };
            const chunked = try vort.brEncodePlannedStreamChunksWithOptionsAlloc(
                allocator,
                &chunks,
                chunked_options,
            );
            defer allocator.free(chunked);
            try validateVortEncoded(
                allocator,
                runtime,
                chunked,
                case,
                true,
            );
            counts.chunked += 1;
        }

        if (comptime incrementalEncodeExposed()) {
            const incremental = try encodeIncremental(allocator, case);
            defer allocator.free(incremental);
            try validateVortEncoded(
                allocator,
                runtime,
                incremental,
                case,
                true,
            );
            counts.incremental += 1;
        }
    }
    return counts;
}

fn validateRuntimeRegressionMatrix(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
) !usize {
    var dictionary_bytes: [4096]u8 = undefined;
    fillRuntimeRegressionPayload(&dictionary_bytes, 0x1234_5678);
    const prefixes = [_][]const u8{
        dictionary_bytes[0..333],
        dictionary_bytes[333..2049],
        dictionary_bytes[2049..],
    };
    const dictionary = vort.BrotliSharedDictionary{ .raw_prefixes = &prefixes };
    const options = vort.BrotliDecodeOptions{ .shared_dictionary = dictionary };
    var count: usize = 0;

    // Cross the unsaturated-to-saturated WBITS=10 boundary over three
    // meta-blocks. The continuation before saturation reuses compound rep0.
    const crossing_chunks = [_][]const u8{
        dictionary_bytes[0..900],
        dictionary_bytes[900..1800],
        dictionary_bytes[1800..],
    };
    const crossing = try vort.brEncodePlannedStreamChunksWithOptionsAlloc(
        allocator,
        &crossing_chunks,
        .{
            .window_bits = 10,
            .metadata = "cross-window",
            .shared_dictionary = dictionary,
        },
    );
    defer allocator.free(crossing);
    try validateRuntimeRegressionEncoded(
        allocator,
        runtime,
        crossing,
        &dictionary_bytes,
        &prefixes,
        options,
        .{
            .require_shared_dictionary = true,
            .require_metadata = true,
        },
    );
    count += 1;

    // Roll a random first meta-block back to stored, then require the next
    // compound distance to use saturated H without inheriting candidate state.
    var filler: [32768]u8 = undefined;
    fillRuntimeRegressionPayload(&filler, 0x9e37_79b9);
    const rollback_chunks = [_][]const u8{ &filler, &dictionary_bytes };
    const expected = try allocator.alloc(u8, filler.len + dictionary_bytes.len);
    defer allocator.free(expected);
    @memcpy(expected[0..filler.len], &filler);
    @memcpy(expected[filler.len..], &dictionary_bytes);
    const rollback = try vort.brEncodePlannedStreamChunksWithOptionsAlloc(
        allocator,
        &rollback_chunks,
        .{
            .window_bits = 10,
            .metadata = "stored-rollback",
            .shared_dictionary = dictionary,
        },
    );
    defer allocator.free(rollback);
    try validateRuntimeRegressionEncoded(
        allocator,
        runtime,
        rollback,
        expected,
        &prefixes,
        options,
        .{
            .require_shared_dictionary = true,
            .require_stored = true,
            .require_metadata = true,
        },
    );
    count += 1;

    // Repeat the rollback/H transition through the progressive encoder. A
    // metadata block separates content while a small output slice forces
    // repeated backpressure and resumptions.
    var encoder = vort.BrotliIncrementalPlannedStreamEncoder.initWithOptions(
        allocator,
        .{
            .stream = .{
                .window_bits = 10,
                .shared_dictionary = dictionary,
            },
            .block_len = filler.len,
        },
    );
    defer encoder.deinit();
    var incremental: std.ArrayList(u8) = .empty;
    defer incremental.deinit(allocator);
    var scratch: [257]u8 = undefined;
    try feedRuntimeIncremental(
        &encoder,
        allocator,
        &incremental,
        &filler,
        &scratch,
    );
    try encoder.writeMetadata("between-blocks");
    try drainRuntimeIncrementalFlush(
        &encoder,
        allocator,
        &incremental,
        &scratch,
    );
    try feedRuntimeIncremental(
        &encoder,
        allocator,
        &incremental,
        &dictionary_bytes,
        &scratch,
    );
    try encoder.finish();
    try drainRuntimeIncrementalFinish(
        &encoder,
        allocator,
        &incremental,
        &scratch,
    );
    try validateRuntimeRegressionEncoded(
        allocator,
        runtime,
        incremental.items,
        expected,
        &prefixes,
        options,
        .{
            .require_shared_dictionary = true,
            .require_stored = true,
            .require_metadata = true,
        },
    );
    count += 1;

    // At saturated H, a static dictionary address begins after the complete
    // compound region even though this plan never copies from the RAW bytes.
    var static_input: [1205]u8 = @splat('a');
    @memcpy(static_input[1200..], "world");
    const static_wire = try vort.brEncodePlannedStreamWithOptionsAlloc(
        allocator,
        &static_input,
        .{
            .level = .ratio,
            .window_bits = 10,
            .extended_dictionary_probes = 4096,
            .shared_dictionary = dictionary,
        },
    );
    defer allocator.free(static_wire);
    const static_summary = try vort.brSummarizeStreamWithOptions(
        static_wire,
        options,
    );
    if (static_summary.window_bits != 10) return error.UnexpectedWindowBits;
    if (!static_summary.uses_static_dictionary) return error.MissingStaticCopy;
    if (static_summary.uses_shared_dictionary)
        return error.UnexpectedSharedDictionaryCopy;
    const static_output = try allocator.alloc(u8, static_input.len);
    defer allocator.free(static_output);
    try runtime.decodeWithRawDictionaries(
        static_wire,
        static_output,
        &prefixes,
    );
    if (!std.mem.eql(u8, &static_input, static_output))
        return error.ReferenceDecodeFailed;
    count += 1;

    return count;
}

const RuntimeRegressionExpectations = struct {
    require_shared_dictionary: bool = false,
    require_stored: bool = false,
    require_metadata: bool = false,
};

fn validateRuntimeRegressionEncoded(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    encoded: []const u8,
    expected: []const u8,
    prefixes: []const []const u8,
    decode_options: vort.BrotliDecodeOptions,
    expectations: RuntimeRegressionExpectations,
) !void {
    const summary = try vort.brSummarizeStreamWithOptions(
        encoded,
        decode_options,
    );
    if (summary.window_bits != 10) return error.UnexpectedWindowBits;
    if (expectations.require_shared_dictionary and
        !summary.uses_shared_dictionary)
        return error.MissingSharedDictionaryCopy;
    if (expectations.require_stored and
        summary.uncompressed_meta_block_count == 0)
        return error.MissingStoredBlock;
    if (expectations.require_metadata and
        summary.metadata_meta_block_count == 0)
        return error.MissingMetadataBlock;

    const decoded = try allocator.alloc(u8, expected.len);
    defer allocator.free(decoded);
    try runtime.decodeWithRawDictionaries(encoded, decoded, prefixes);
    if (!std.mem.eql(u8, expected, decoded)) return error.ReferenceDecodeFailed;
}

fn feedRuntimeIncremental(
    encoder: *vort.BrotliIncrementalPlannedStreamEncoder,
    allocator: std.mem.Allocator,
    encoded: *std.ArrayList(u8),
    input: []const u8,
    scratch: []u8,
) !void {
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(
            allocator,
            scratch[0..result.progress.output_written],
        );
    }
}

fn drainRuntimeIncrementalFlush(
    encoder: *vort.BrotliIncrementalPlannedStreamEncoder,
    allocator: std.mem.Allocator,
    encoded: *std.ArrayList(u8),
    scratch: []u8,
) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(
            allocator,
            scratch[0..result.progress.output_written],
        );
        if (result.status == .need_input) return;
    }
}

fn drainRuntimeIncrementalFinish(
    encoder: *vort.BrotliIncrementalPlannedStreamEncoder,
    allocator: std.mem.Allocator,
    encoded: *std.ArrayList(u8),
    scratch: []u8,
) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try encoded.appendSlice(
            allocator,
            scratch[0..result.progress.output_written],
        );
        if (result.status == .done) return;
    }
}

fn chunkedEncodeExposed() bool {
    return @hasField(
        vort.BrotliPlannedStreamChunksOptions,
        "shared_dictionary",
    );
}

fn incrementalEncodeExposed() bool {
    const EncoderOptions = vort.BrotliIncrementalPlannedStreamEncoder.Options;
    const StreamOptions = @FieldType(EncoderOptions, "stream");
    return @hasField(StreamOptions, "shared_dictionary");
}

fn encodeIncremental(
    allocator: std.mem.Allocator,
    case: MatrixCase,
) ![]u8 {
    const Encoder = vort.BrotliIncrementalPlannedStreamEncoder;
    const StreamOptions = @FieldType(Encoder.Options, "stream");
    var stream_options: StreamOptions = .{};
    @field(stream_options, "shared_dictionary") = .{
        .raw_prefixes = case.raw_dictionaries,
    };
    var encoder = Encoder.initWithOptions(allocator, .{
        .stream = stream_options,
        .block_len = @max(case.input.len, 1),
    });
    defer encoder.deinit();

    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var scratch: [3]u8 = undefined;
    var offset: usize = 0;
    while (offset < case.input.len) {
        const end = @min(case.input.len, offset + 2);
        const result = try encoder.step(case.input[offset..end], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(
            allocator,
            scratch[0..result.progress.output_written],
        );
    }
    try encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(
            allocator,
            scratch[0..result.progress.output_written],
        );
        if (result.status == .done) break;
    }
    return encoded.toOwnedSlice(allocator);
}

fn splitInput(input: []const u8) [3][]const u8 {
    const first = input.len / 3;
    const second = (input.len * 2) / 3;
    return .{ input[0..first], input[first..second], input[second..] };
}

fn fillDictionaryPayload(output: []u8) void {
    var state: u32 = 0x6d2b_79f5;
    for (output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state >> 24);
    }
}

fn fillRuntimeRegressionPayload(output: []u8, initial: u32) void {
    var state = initial;
    for (output) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
}

fn validateVortEncoded(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    encoded: []const u8,
    case: MatrixCase,
    require_dictionary_copy: bool,
) !void {
    const output = try allocator.alloc(u8, case.input.len);
    defer allocator.free(output);
    try runtime.decodeWithRawDictionaries(
        encoded,
        output,
        case.raw_dictionaries,
    );
    if (!std.mem.eql(u8, case.input, output)) return error.ReferenceDecodeFailed;

    const summary = try vort.brSummarizeStreamWithOptions(
        encoded,
        decodeOptions(case.raw_dictionaries),
    );
    if ((!case.expect_dictionary_copy and summary.uses_shared_dictionary) or
        (case.expect_dictionary_copy and
            require_dictionary_copy and
            !summary.uses_shared_dictionary))
        return error.ReferenceEncodeFailed;
}

fn decodeOptions(raw_dictionaries: []const []const u8) vort.BrotliDecodeOptions {
    return .{ .shared_dictionary = .{ .raw_prefixes = raw_dictionaries } };
}

fn expectError(expected: anyerror, result: anytype) anyerror!void {
    if (result) |_| {
        return error.ExpectedFailure;
    } else |actual| {
        if (actual != expected) return actual;
    }
}
