const std = @import("std");
const serialized_dictionary = @import("serialized_dictionary.zig");

pub const max_prefix_len: usize = 1_073_741_823;

pub const WordListSpec = struct {
    size_bits_by_length: [32]u8,
    data: []const u8,

    pub fn fromParsed(words: serialized_dictionary.WordList) WordListSpec {
        return .{
            .size_bits_by_length = words.size_bits_by_length,
            .data = words.data,
        };
    }
};

/// Prefix/suffix and transform triplets use the serialized representation:
/// length-prefixed stringlets ending in one empty stringlet, then packed
/// `{ prefix_id, kind, suffix_id }` triplets. `params`, when present, contains
/// one little-endian u16 per transform and is required iff any transform is a
/// SHIFT kind.
pub const TransformListSpec = struct {
    prefix_suffix: []const u8,
    transforms: []const u8,
    params: ?[]const u8 = null,

    pub fn fromParsed(transforms: serialized_dictionary.TransformList) TransformListSpec {
        return .{
            .prefix_suffix = transforms.prefix_suffix,
            .transforms = transforms.transforms,
            .params = transforms.params,
        };
    }
};

pub const Spec = struct {
    raw_prefix: []const u8 = "",
    word_lists: []const WordListSpec = &.{},
    transform_lists: []const TransformListSpec = &.{},
    /// Required and non-empty when either custom-list slice is non-empty.
    /// Index equal to the corresponding list count selects the RFC built-in
    /// table, matching the parser's `DictionaryChoice` convention.
    dictionaries: []const serialized_dictionary.DictionaryChoice = &.{},
    /// Null disables contextual selection. A present map contains one
    /// dictionary ID for each RFC literal context.
    context_map: ?*const [serialized_dictionary.max_contexts]u6 = null,
};

pub const Error = serialized_dictionary.Error || error{
    InvalidSpecification,
};

const Validated = struct {
    encoded_size: usize,
    custom_static: bool,
    transform_has_params: [serialized_dictionary.max_contexts]bool,
};

pub fn encodedSize(spec: Spec) Error!usize {
    return (try validate(spec)).encoded_size;
}

/// Write one canonical serialized dictionary without partial output mutation.
/// `output` may be larger than required; the returned length identifies the
/// initialized prefix.
pub fn serializeInto(spec: Spec, output: []u8) Error!usize {
    const validated = try validate(spec);
    if (output.len < validated.encoded_size) return error.OutputTooSmall;
    var cursor: usize = 0;
    output[cursor] = 0x91;
    output[cursor + 1] = 0;
    cursor += 2;
    cursor += writeVarint32(output[cursor..], @intCast(spec.raw_prefix.len));
    @memcpy(output[cursor..][0..spec.raw_prefix.len], spec.raw_prefix);
    cursor += spec.raw_prefix.len;

    output[cursor] = @intCast(spec.word_lists.len);
    cursor += 1;
    for (spec.word_lists) |words| {
        @memcpy(
            output[cursor..][0 .. serialized_dictionary.max_word_len -
                serialized_dictionary.min_word_len + 1],
            words.size_bits_by_length[serialized_dictionary.min_word_len .. serialized_dictionary.max_word_len + 1],
        );
        cursor += serialized_dictionary.max_word_len -
            serialized_dictionary.min_word_len + 1;
        @memcpy(output[cursor..][0..words.data.len], words.data);
        cursor += words.data.len;
    }

    output[cursor] = @intCast(spec.transform_lists.len);
    cursor += 1;
    for (spec.transform_lists, 0..) |transforms, index| {
        std.mem.writeInt(
            u16,
            output[cursor..][0..2],
            @intCast(transforms.prefix_suffix.len),
            .little,
        );
        cursor += 2;
        @memcpy(
            output[cursor..][0..transforms.prefix_suffix.len],
            transforms.prefix_suffix,
        );
        cursor += transforms.prefix_suffix.len;
        output[cursor] = @intCast(transforms.transforms.len / 3);
        cursor += 1;
        @memcpy(
            output[cursor..][0..transforms.transforms.len],
            transforms.transforms,
        );
        cursor += transforms.transforms.len;
        if (validated.transform_has_params[index]) {
            const params = transforms.params.?;
            @memcpy(output[cursor..][0..params.len], params);
            cursor += params.len;
        }
    }

    if (validated.custom_static) {
        output[cursor] = @intCast(spec.dictionaries.len);
        cursor += 1;
        for (spec.dictionaries) |choice| {
            output[cursor] = choice.word_list_index;
            output[cursor + 1] = choice.transform_list_index;
            cursor += 2;
        }
        output[cursor] = @intFromBool(spec.context_map != null);
        cursor += 1;
        if (spec.context_map) |context_map| {
            for (context_map) |dictionary_id| {
                output[cursor] = dictionary_id;
                cursor += 1;
            }
        }
    }
    std.debug.assert(cursor == validated.encoded_size);
    return cursor;
}

pub fn serializeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    spec: Spec,
) (Error || std.mem.Allocator.Error)!void {
    const size = try encodedSize(spec);
    const start = output.items.len;
    const end = std.math.add(usize, start, size) catch
        return error.IntegerOverflow;
    try output.resize(allocator, end);
    errdefer output.shrinkRetainingCapacity(start);
    const written = try serializeInto(spec, output.items[start..end]);
    std.debug.assert(written == size);
}

pub fn serializeAlloc(
    allocator: std.mem.Allocator,
    spec: Spec,
) (Error || std.mem.Allocator.Error)![]u8 {
    const size = try encodedSize(spec);
    const output = try allocator.alloc(u8, size);
    errdefer allocator.free(output);
    const written = try serializeInto(spec, output);
    std.debug.assert(written == size);
    return output;
}

fn validate(spec: Spec) Error!Validated {
    if (spec.raw_prefix.len > max_prefix_len) return error.PrefixTooLarge;
    if (spec.word_lists.len > serialized_dictionary.max_contexts)
        return error.InvalidWordList;
    if (spec.transform_lists.len > serialized_dictionary.max_contexts)
        return error.InvalidTransformList;

    var size: usize = 2;
    size = try addSize(size, varint32Len(@intCast(spec.raw_prefix.len)));
    size = try addSize(size, spec.raw_prefix.len);
    size = try addSize(size, 1);
    for (spec.word_lists) |words| {
        for (words.size_bits_by_length[0..serialized_dictionary.min_word_len]) |bits|
            if (bits != 0) return error.InvalidWordList;
        if (words.size_bits_by_length[serialized_dictionary.max_word_len + 1 ..].len != 0) {
            for (words.size_bits_by_length[serialized_dictionary.max_word_len + 1 ..]) |bits|
                if (bits != 0) return error.InvalidWordList;
        }
        var expected_data_len: usize = 0;
        for (serialized_dictionary.min_word_len..serialized_dictionary.max_word_len + 1) |word_len| {
            const bits = words.size_bits_by_length[word_len];
            if (bits > serialized_dictionary.max_size_bits)
                return error.InvalidWordList;
            if (bits == 0) continue;
            const bucket_len = std.math.mul(
                usize,
                word_len,
                @as(usize, 1) << @intCast(bits),
            ) catch return error.IntegerOverflow;
            expected_data_len = try addSize(expected_data_len, bucket_len);
        }
        if (words.data.len != expected_data_len)
            return error.InvalidWordList;
        size = try addSize(
            size,
            serialized_dictionary.max_word_len -
                serialized_dictionary.min_word_len + 1,
        );
        size = try addSize(size, words.data.len);
    }

    size = try addSize(size, 1);
    var transform_has_params: [serialized_dictionary.max_contexts]bool =
        @splat(false);
    for (spec.transform_lists, 0..) |transforms, list_index| {
        if (transforms.prefix_suffix.len == 0 or
            transforms.prefix_suffix.len > std.math.maxInt(u16))
        {
            return error.InvalidTransformList;
        }
        var cursor: usize = 0;
        var string_count: usize = 0;
        while (cursor < transforms.prefix_suffix.len) {
            const string_len: usize = transforms.prefix_suffix[cursor];
            cursor += 1;
            string_count += 1;
            if (string_count > serialized_dictionary.max_stringlets or
                string_len > transforms.prefix_suffix.len - cursor)
            {
                return error.InvalidTransformList;
            }
            cursor += string_len;
            if (string_len == 0 and cursor != transforms.prefix_suffix.len)
                return error.InvalidTransformList;
        }
        if (transforms.prefix_suffix[transforms.prefix_suffix.len - 1] != 0)
            return error.InvalidTransformList;
        if (transforms.transforms.len % 3 != 0 or
            transforms.transforms.len / 3 > std.math.maxInt(u8))
        {
            return error.InvalidTransformList;
        }
        const transform_count = transforms.transforms.len / 3;
        var has_shift = false;
        for (0..transform_count) |transform_index| {
            const base = transform_index * 3;
            const prefix_id = transforms.transforms[base];
            const kind = transforms.transforms[base + 1];
            const suffix_id = transforms.transforms[base + 2];
            if (prefix_id >= string_count or
                suffix_id >= string_count or
                kind >= serialized_dictionary.transform_type_count)
            {
                return error.InvalidTransformList;
            }
            has_shift = has_shift or kind >= 21;
        }
        transform_has_params[list_index] = has_shift;
        const expected_params_len = transform_count * 2;
        if (has_shift) {
            const params = transforms.params orelse
                return error.InvalidTransformList;
            if (params.len != expected_params_len)
                return error.InvalidTransformList;
            for (0..transform_count) |transform_index| {
                const kind = transforms.transforms[transform_index * 3 + 1];
                if (kind < 21 and
                    (params[transform_index * 2] != 0 or
                        params[transform_index * 2 + 1] != 0))
                {
                    return error.InvalidTransformList;
                }
            }
        } else if (transforms.params != null) {
            return error.InvalidTransformList;
        }
        size = try addSize(size, 2);
        size = try addSize(size, transforms.prefix_suffix.len);
        size = try addSize(size, 1);
        size = try addSize(size, transforms.transforms.len);
        if (has_shift) size = try addSize(size, expected_params_len);
    }

    const custom_static = spec.word_lists.len != 0 or
        spec.transform_lists.len != 0;
    if (!custom_static) {
        if (spec.dictionaries.len != 0 or spec.context_map != null)
            return error.InvalidSpecification;
    } else {
        if (spec.dictionaries.len == 0 or
            spec.dictionaries.len > serialized_dictionary.max_contexts)
        {
            return error.InvalidDictionaryMap;
        }
        for (spec.dictionaries) |choice| {
            if (choice.word_list_index > spec.word_lists.len or
                choice.transform_list_index > spec.transform_lists.len)
            {
                return error.InvalidDictionaryMap;
            }
        }
        if (spec.context_map) |context_map|
            for (context_map) |dictionary_id|
                if (dictionary_id >= spec.dictionaries.len)
                    return error.InvalidContextMap;
        size = try addSize(size, 1);
        size = try addSize(
            size,
            std.math.mul(usize, spec.dictionaries.len, 2) catch
                return error.IntegerOverflow,
        );
        size = try addSize(size, 1);
        if (spec.context_map != null)
            size = try addSize(size, serialized_dictionary.max_contexts);
    }
    return .{
        .encoded_size = size,
        .custom_static = custom_static,
        .transform_has_params = transform_has_params,
    };
}

fn addSize(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn varint32Len(value_: u32) usize {
    var value = value_;
    var len: usize = 1;
    while (value >= 0x80) : (len += 1) value >>= 7;
    return len;
}

fn writeVarint32(output: []u8, value_: u32) usize {
    var value = value_;
    var cursor: usize = 0;
    while (value >= 0x80) {
        output[cursor] = @as(u8, @truncate(value)) | 0x80;
        cursor += 1;
        value >>= 7;
    }
    output[cursor] = @truncate(value);
    return cursor + 1;
}

test "serialized builder emits canonical default and contextual dictionaries" {
    var default_output: [5]u8 = undefined;
    try std.testing.expectEqual(
        @as(usize, 5),
        try serializeInto(.{}, &default_output),
    );
    try std.testing.expectEqualSlices(
        u8,
        &.{ 0x91, 0, 0, 0, 0 },
        &default_output,
    );
    _ = try serialized_dictionary.parse(&default_output);

    var word_bits: [32]u8 = @splat(0);
    word_bits[4] = 1;
    const word_lists = [_]WordListSpec{
        .{ .size_bits_by_length = word_bits, .data = "red!xxxx" },
        .{ .size_bits_by_length = word_bits, .data = "bluezzzz" },
    };
    const transform_lists = [_]TransformListSpec{.{
        .prefix_suffix = &.{ 1, '<', 1, '>', 0 },
        .transforms = &.{ 2, 0, 2, 0, 21, 1 },
        .params = &.{ 0, 0, 1, 0 },
    }};
    const choices = [_]serialized_dictionary.DictionaryChoice{
        .{ .word_list_index = 0, .transform_list_index = 0 },
        .{ .word_list_index = 1, .transform_list_index = 0 },
        .{ .word_list_index = 2, .transform_list_index = 1 },
    };
    var context_map: [64]u6 = @splat(0);
    context_map[32] = 1;
    context_map[63] = 2;
    const spec = Spec{
        .raw_prefix = "raw",
        .word_lists = &word_lists,
        .transform_lists = &transform_lists,
        .dictionaries = &choices,
        .context_map = &context_map,
    };
    const encoded = try serializeAlloc(std.testing.allocator, spec);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqual(encoded.len, try encodedSize(spec));
    const parsed = try serialized_dictionary.parse(encoded);
    try std.testing.expectEqualSlices(u8, "raw", parsed.raw_prefix);
    try std.testing.expectEqual(@as(u7, 2), parsed.word_list_count);
    try std.testing.expectEqual(@as(u7, 1), parsed.transform_list_count);
    try std.testing.expectEqual(@as(u7, 3), parsed.dictionary_count);
    try std.testing.expectEqual(@as(u6, 1), try parsed.dictionaryForContext(32));
    var scratch: [serialized_dictionary.max_transformed_word_len]u8 = undefined;
    try std.testing.expectEqualSlices(
        u8,
        "blue",
        (try parsed.resolve(32, 4, 0, &scratch)).bytes,
    );
    try std.testing.expectEqualSlices(
        u8,
        "first",
        (try parsed.resolve(63, 5, 0, &scratch)).bytes,
    );

    var rebuilt_words: [serialized_dictionary.max_contexts]WordListSpec = undefined;
    for (rebuilt_words[0..parsed.word_list_count], parsed.word_lists[0..parsed.word_list_count]) |*destination, source|
        destination.* = WordListSpec.fromParsed(source);
    var rebuilt_transforms: [serialized_dictionary.max_contexts]TransformListSpec = undefined;
    for (rebuilt_transforms[0..parsed.transform_list_count], parsed.transform_lists[0..parsed.transform_list_count]) |*destination, source|
        destination.* = TransformListSpec.fromParsed(source);
    const rebuilt_spec = Spec{
        .raw_prefix = parsed.raw_prefix,
        .word_lists = rebuilt_words[0..parsed.word_list_count],
        .transform_lists = rebuilt_transforms[0..parsed.transform_list_count],
        .dictionaries = parsed.dictionaries[0..parsed.dictionary_count],
        .context_map = &parsed.context_map,
    };
    const rebuilt = try serializeAlloc(std.testing.allocator, rebuilt_spec);
    defer std.testing.allocator.free(rebuilt);
    try std.testing.expectEqualSlices(u8, encoded, rebuilt);
}

test "serialized builder round trips strict parsed views deterministically" {
    var bits: [32]u8 = @splat(0);
    bits[4] = 1;
    const word_lists = [_]WordListSpec{.{
        .size_bits_by_length = bits,
        .data = "wordtest",
    }};
    const transform_lists = [_]TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{ 0, 0, 0 },
    }};
    const choices = [_]serialized_dictionary.DictionaryChoice{.{
        .word_list_index = 0,
        .transform_list_index = 0,
    }};
    const original_spec = Spec{
        .raw_prefix = "prefix",
        .word_lists = &word_lists,
        .transform_lists = &transform_lists,
        .dictionaries = &choices,
    };
    const first = try serializeAlloc(std.testing.allocator, original_spec);
    defer std.testing.allocator.free(first);
    const parsed = try serialized_dictionary.parse(first);
    var parsed_words: [serialized_dictionary.max_contexts]WordListSpec = undefined;
    for (parsed_words[0..parsed.word_list_count], parsed.word_lists[0..parsed.word_list_count]) |*destination, source|
        destination.* = WordListSpec.fromParsed(source);
    var parsed_transforms: [serialized_dictionary.max_contexts]TransformListSpec = undefined;
    for (parsed_transforms[0..parsed.transform_list_count], parsed.transform_lists[0..parsed.transform_list_count]) |*destination, source|
        destination.* = TransformListSpec.fromParsed(source);
    const parsed_spec = Spec{
        .raw_prefix = parsed.raw_prefix,
        .word_lists = parsed_words[0..parsed.word_list_count],
        .transform_lists = parsed_transforms[0..parsed.transform_list_count],
        .dictionaries = parsed.dictionaries[0..parsed.dictionary_count],
        .context_map = if (parsed.context_based) &parsed.context_map else null,
    };
    const second = try serializeAlloc(std.testing.allocator, parsed_spec);
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "sentinel");
    try serializeAppend(std.testing.allocator, &appended, parsed_spec);
    try std.testing.expectEqualSlices(u8, "sentinel", appended.items[0..8]);
    try std.testing.expectEqualSlices(u8, first, appended.items[8..]);
}

test "serialized builder emits canonical prefix varint boundaries" {
    const prefix_127: [127]u8 = @splat(0x7f);
    const prefix_128: [128]u8 = @splat(0x80);
    const cases = [_]struct {
        prefix: []const u8,
        expected_size: usize,
        varint: []const u8,
    }{
        .{ .prefix = &prefix_127, .expected_size = 132, .varint = &.{0x7f} },
        .{ .prefix = &prefix_128, .expected_size = 134, .varint = &.{ 0x80, 0x01 } },
    };
    for (cases) |case| {
        const encoded = try serializeAlloc(
            std.testing.allocator,
            .{ .raw_prefix = case.prefix },
        );
        defer std.testing.allocator.free(encoded);
        try std.testing.expectEqual(case.expected_size, encoded.len);
        try std.testing.expectEqualSlices(
            u8,
            case.varint,
            encoded[2..][0..case.varint.len],
        );
        const parsed = try serialized_dictionary.parse(encoded);
        try std.testing.expectEqualSlices(u8, case.prefix, parsed.raw_prefix);
    }
}

test "serialized builder rejects invalid specifications before mutation" {
    var output: [32]u8 = @splat(0xa5);
    var invalid_bits: [32]u8 = @splat(0);
    invalid_bits[4] = 1;
    const invalid_words = [_]WordListSpec{.{
        .size_bits_by_length = invalid_bits,
        .data = "short",
    }};
    try std.testing.expectError(
        error.InvalidWordList,
        serializeInto(.{ .word_lists = &invalid_words }, &output),
    );
    try std.testing.expectEqual([_]u8{0xa5} ** output.len, output);

    const invalid_transforms = [_]TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{ 0, 23, 0 },
    }};
    const choice = [_]serialized_dictionary.DictionaryChoice{.{
        .word_list_index = 0,
        .transform_list_index = 0,
    }};
    try std.testing.expectError(
        error.InvalidTransformList,
        serializeInto(.{
            .transform_lists = &invalid_transforms,
            .dictionaries = &choice,
        }, &output),
    );
    try std.testing.expectEqual([_]u8{0xa5} ** output.len, output);

    const shift_without_params = [_]TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{ 0, 21, 0 },
    }};
    try std.testing.expectError(
        error.InvalidTransformList,
        encodedSize(.{
            .transform_lists = &shift_without_params,
            .dictionaries = &choice,
        }),
    );

    const redundant_params = [_]TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{ 0, 0, 0 },
        .params = &.{ 0, 0 },
    }};
    try std.testing.expectError(
        error.InvalidTransformList,
        encodedSize(.{
            .transform_lists = &redundant_params,
            .dictionaries = &choice,
        }),
    );

    try std.testing.expectError(
        error.OutputTooSmall,
        serializeInto(.{}, output[0..4]),
    );
    try std.testing.expectEqual([_]u8{0xa5} ** output.len, output);

    const sentinel: [*]const u8 = @ptrFromInt(1);
    try std.testing.expectError(
        error.PrefixTooLarge,
        encodedSize(.{ .raw_prefix = sentinel[0 .. max_prefix_len + 1] }),
    );

    const too_many_words: [serialized_dictionary.max_contexts + 1]WordListSpec =
        @splat(.{ .size_bits_by_length = @splat(0), .data = "" });
    try std.testing.expectError(
        error.InvalidWordList,
        encodedSize(.{ .word_lists = &too_many_words }),
    );

    var invalid_context_map: [64]u6 = @splat(0);
    invalid_context_map[63] = 1;
    const empty_transform = [_]TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{},
    }};
    try std.testing.expectError(
        error.InvalidContextMap,
        encodedSize(.{
            .transform_lists = &empty_transform,
            .dictionaries = &choice,
            .context_map = &invalid_context_map,
        }),
    );
}

test "serialized builder allocation failures are clean" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const encoded = try serializeAlloc(allocator, .{ .raw_prefix = "prefix" });
            defer allocator.free(encoded);
            _ = try serialized_dictionary.parse(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{},
    );
}
