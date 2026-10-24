const std = @import("std");
const serialized_dictionary = @import("serialized_dictionary.zig");
const static_dictionary = @import("static_dictionary.zig");

/// The stable upstream shared-dictionary container and prepared encoder accept
/// at most fifteen RAW attachments. Empty attachments still consume a
/// container/encoder slot, although the lower-level decoder attach API treats
/// an empty attachment as an uncounted no-op. Vort deliberately exposes the
/// narrower common descriptor so the same value remains valid for decode and
/// future encode surfaces.
pub const max_raw_prefixes: usize = 15;
pub const max_static_output_len: usize = serialized_dictionary.max_transformed_word_len;

/// SHARED_BROTLI_MAX_RAW_DICT_SIZE from upstream Brotli. `@sizeOf(usize)` is
/// measured in bytes, just as C's `sizeof(size_t)` is.
pub const max_raw_size: usize = @as(usize, 1) << (23 + @sizeOf(usize));

pub const ValidationError = error{
    TooManyRawPrefixes,
    RawDictionaryTooLarge,
    IntegerOverflow,
};

pub const CursorError = ValidationError || error{
    CompoundDictionaryOutOfBounds,
};

pub const DistanceError = error{
    InvalidDistance,
};

/// A borrowing descriptor for Brotli RAW prefixes and one parsed serialized
/// shared dictionary.
///
/// Prefix bytes, the outer slice, the serialized view, and its encoded backing
/// bytes must remain alive and unchanged while the dictionary or any cursor
/// made from it is in use. Explicit RAW prefixes are logically followed by the
/// serialized dictionary's optional RAW prefix; no bytes are copied or owned.
pub const Dictionary = struct {
    raw_prefixes: []const []const u8 = &.{},
    serialized: ?*const serialized_dictionary.Dictionary = null,

    pub fn validate(self: Dictionary) ValidationError!void {
        _ = try self.totalSize();
    }

    pub fn totalSize(self: Dictionary) ValidationError!usize {
        const serialized_prefix = self.serializedPrefix();
        const prefix_count = std.math.add(
            usize,
            self.raw_prefixes.len,
            @intFromBool(serialized_prefix.len != 0),
        ) catch return error.IntegerOverflow;
        if (prefix_count > max_raw_prefixes) {
            return error.TooManyRawPrefixes;
        }

        var total: usize = 0;

        for (self.raw_prefixes) |prefix| {
            if (prefix.len == 0) continue;
            total = std.math.add(usize, total, prefix.len) catch
                return error.IntegerOverflow;
        }
        total = std.math.add(usize, total, serialized_prefix.len) catch
            return error.IntegerOverflow;

        if (total > max_raw_size) return error.RawDictionaryTooLarge;
        return total;
    }

    pub fn compoundChunkCount(self: Dictionary) usize {
        return self.raw_prefixes.len + @intFromBool(self.serializedPrefix().len != 0);
    }

    pub fn compoundChunk(self: Dictionary, index: usize) ?[]const u8 {
        if (index < self.raw_prefixes.len) return self.raw_prefixes[index];
        if (index == self.raw_prefixes.len) {
            const prefix = self.serializedPrefix();
            if (prefix.len != 0) return prefix;
        }
        return null;
    }

    pub fn staticWord(
        self: Dictionary,
        context: usize,
        address: usize,
        copy_len: usize,
        output: []u8,
    ) serialized_dictionary.Error![]const u8 {
        if (self.hasSerializedStatic()) {
            const dictionary = self.serialized.?;
            return (try dictionary.resolve(context, copy_len, address, output)).bytes;
        }
        return static_dictionary.transform(address, copy_len, output) orelse
            error.DictionaryAddressOutOfBounds;
    }

    pub fn hasSerializedStatic(self: Dictionary) bool {
        const dictionary = self.serialized orelse return false;
        return dictionary.word_list_count != 0 or
            dictionary.transform_list_count != 0;
    }

    fn serializedPrefix(self: Dictionary) []const u8 {
        return if (self.serialized) |dictionary| dictionary.raw_prefix else "";
    }

    /// Begin a bounded copy from a logical compound-dictionary address.
    ///
    /// A zero-length copy may start exactly at the end. Every non-empty copy
    /// must be wholly contained in the dictionary.
    pub fn cursor(self: Dictionary, address: usize, copy_len: usize) CursorError!Cursor {
        return Cursor.init(self, address, copy_len);
    }

    /// One-shot counterpart to `cursor`; `output.len` is the requested copy
    /// length.
    pub fn copyInto(self: Dictionary, address: usize, output: []u8) CursorError!void {
        var source = try self.cursor(address, output.len);
        const copied = source.copyInto(output);
        std.debug.assert(copied == output.len);
        std.debug.assert(source.isDone());
    }

    /// Classify a Brotli distance using this descriptor's validated size.
    pub fn classifyDistance(
        self: Dictionary,
        distance: usize,
        max_history: usize,
    ) (ValidationError || DistanceError)!DistanceTarget {
        return classifyDistanceWithSize(distance, max_history, try self.totalSize());
    }
};

/// A resumable, allocation-free copy through the logically concatenated RAW
/// prefixes. Calls may offer arbitrarily small output slices.
pub const Cursor = struct {
    raw_prefixes: []const []const u8,
    serialized_prefix: []const u8,
    chunk_count: usize,
    chunk_index: usize,
    chunk_offset: usize,
    remaining_len: usize,

    pub fn init(dictionary: Dictionary, address: usize, copy_len: usize) CursorError!Cursor {
        const total_size = try dictionary.totalSize();
        const end = std.math.add(usize, address, copy_len) catch
            return error.IntegerOverflow;
        if (end > total_size) return error.CompoundDictionaryOutOfBounds;

        var chunk_index: usize = 0;
        var chunk_address = address;
        const chunk_count = dictionary.compoundChunkCount();
        while (chunk_index < chunk_count) : (chunk_index += 1) {
            const prefix = dictionary.compoundChunk(chunk_index).?;
            if (prefix.len == 0) continue;
            if (chunk_address < prefix.len) break;
            chunk_address -= prefix.len;
        }

        // Only a zero-byte copy at the logical end can have no source chunk.
        std.debug.assert(chunk_index < chunk_count or copy_len == 0);
        return .{
            .raw_prefixes = dictionary.raw_prefixes,
            .serialized_prefix = dictionary.serializedPrefix(),
            .chunk_count = chunk_count,
            .chunk_index = chunk_index,
            .chunk_offset = chunk_address,
            .remaining_len = copy_len,
        };
    }

    /// Copy as much as fits in `output`, returning the number of bytes written.
    /// The cursor retains its exact position for the next call.
    pub fn copyInto(self: *Cursor, output: []u8) usize {
        var written: usize = 0;
        while (written < output.len and self.remaining_len != 0) {
            self.skipExhaustedChunks();
            std.debug.assert(self.chunk_index < self.chunk_count);

            const prefix = self.chunk(self.chunk_index);
            const available = prefix.len - self.chunk_offset;
            const count = @min(@min(available, output.len - written), self.remaining_len);
            @memcpy(output[written..][0..count], prefix[self.chunk_offset..][0..count]);

            written += count;
            self.chunk_offset += count;
            self.remaining_len -= count;
        }
        return written;
    }

    pub fn remaining(self: Cursor) usize {
        return self.remaining_len;
    }

    pub fn isDone(self: Cursor) bool {
        return self.remaining_len == 0;
    }

    fn skipExhaustedChunks(self: *Cursor) void {
        while (self.chunk_index < self.chunk_count) {
            const prefix = self.chunk(self.chunk_index);
            if (self.chunk_offset < prefix.len) return;
            self.chunk_index += 1;
            self.chunk_offset = 0;
        }
    }

    fn chunk(self: Cursor, index: usize) []const u8 {
        if (index < self.raw_prefixes.len) return self.raw_prefixes[index];
        std.debug.assert(index == self.raw_prefixes.len and self.serialized_prefix.len != 0);
        return self.serialized_prefix;
    }
};

/// The interpretation of a Brotli distance after the ordinary history window
/// and optional compound dictionary are taken into account.
pub const DistanceTarget = union(enum) {
    /// An ordinary backwards distance within decoded history.
    history: usize,
    /// A zero-based address in the logical compound dictionary.
    compound: usize,
    /// A zero-based address in the transformed static dictionary address space.
    static_dictionary: usize,
};

/// Classify a distance when the validated compound size is already cached.
///
/// The compound region has priority immediately after history. Its closest
/// distance addresses its last byte; the next distance after the compound
/// region maps to static dictionary address zero.
pub fn classifyDistance(
    distance: usize,
    max_history: usize,
    compound_size: usize,
) DistanceError!DistanceTarget {
    return classifyDistanceWithSize(distance, max_history, compound_size);
}

fn classifyDistanceWithSize(
    distance: usize,
    max_history: usize,
    compound_size: usize,
) DistanceError!DistanceTarget {
    if (distance == 0) return error.InvalidDistance;
    if (distance <= max_history) return .{ .history = distance };

    const dictionary_distance = distance - max_history;
    if (dictionary_distance <= compound_size) {
        return .{ .compound = compound_size - dictionary_distance };
    }
    return .{ .static_dictionary = dictionary_distance - compound_size - 1 };
}

test "RAW compound dictionary validates one, two, and fifteen attachments" {
    const one = Dictionary{ .raw_prefixes = &.{"abc"} };
    try one.validate();
    try std.testing.expectEqual(@as(usize, 3), try one.totalSize());

    const two = Dictionary{ .raw_prefixes = &.{ "", "abc", "", "de", "" } };
    try two.validate();
    try std.testing.expectEqual(@as(usize, 5), try two.totalSize());

    const prefixes: [max_raw_prefixes][]const u8 = @splat("x");
    const fifteen = Dictionary{ .raw_prefixes = &prefixes };
    try fifteen.validate();
    try std.testing.expectEqual(max_raw_prefixes, try fifteen.totalSize());
}

test "empty RAW prefixes add no bytes but consume attachment slots" {
    const empty_prefixes: [max_raw_prefixes][]const u8 = @splat("");
    const dictionary = Dictionary{ .raw_prefixes = &empty_prefixes };
    try dictionary.validate();
    try std.testing.expectEqual(@as(usize, 0), try dictionary.totalSize());

    var output: [0]u8 = .{};
    try dictionary.copyInto(0, &output);

    const too_many_empty: [max_raw_prefixes + 1][]const u8 = @splat("");
    try std.testing.expectError(
        error.TooManyRawPrefixes,
        (Dictionary{ .raw_prefixes = &too_many_empty }).validate(),
    );
}

test "RAW compound dictionary rejects sixteen chunks, excessive size, and overflow" {
    const too_many_prefixes: [max_raw_prefixes + 1][]const u8 = @splat("x");
    try std.testing.expectError(
        error.TooManyRawPrefixes,
        (Dictionary{ .raw_prefixes = &too_many_prefixes }).validate(),
    );

    const sentinel: [*]const u8 = @ptrFromInt(1);
    const maximum = sentinel[0..max_raw_size];
    try std.testing.expectEqual(
        max_raw_size,
        try (Dictionary{ .raw_prefixes = &.{maximum} }).totalSize(),
    );

    const too_large = sentinel[0 .. max_raw_size + 1];
    try std.testing.expectError(
        error.RawDictionaryTooLarge,
        (Dictionary{ .raw_prefixes = &.{too_large} }).validate(),
    );

    const almost_address_space = sentinel[0..std.math.maxInt(usize)];
    try std.testing.expectError(
        error.IntegerOverflow,
        (Dictionary{ .raw_prefixes = &.{ almost_address_space, "x" } }).validate(),
    );
}

test "cursor resumes a copy across prefix and empty-prefix boundaries" {
    const dictionary = Dictionary{ .raw_prefixes = &.{ "abc", "", "defg" } };
    var cursor = try dictionary.cursor(2, 4);
    var output: [4]u8 = undefined;

    try std.testing.expectEqual(@as(usize, 0), cursor.copyInto(output[0..0]));
    try std.testing.expectEqual(@as(usize, 1), cursor.copyInto(output[0..1]));
    try std.testing.expectEqual(@as(usize, 2), cursor.copyInto(output[1..3]));
    try std.testing.expectEqual(@as(usize, 1), cursor.copyInto(output[3..4]));
    try std.testing.expectEqualStrings("cdef", &output);
    try std.testing.expectEqual(@as(usize, 0), cursor.remaining());
    try std.testing.expect(cursor.isDone());
    try std.testing.expectEqual(@as(usize, 0), cursor.copyInto(&output));
}

test "serialized RAW prefix follows explicit attachments without flattening" {
    const serialized = try serialized_dictionary.parse(
        &.{ 0x91, 0x00, 3, 'a', 'b', 'c', 0, 0 },
    );
    const dictionary = Dictionary{
        .raw_prefixes = &.{"xy"},
        .serialized = &serialized,
    };
    try std.testing.expectEqual(@as(usize, 5), try dictionary.totalSize());
    var output: [4]u8 = undefined;
    try dictionary.copyInto(1, &output);
    try std.testing.expectEqualSlices(u8, "yabc", &output);

    const full: [max_raw_prefixes][]const u8 = @splat("");
    try std.testing.expectError(
        error.TooManyRawPrefixes,
        (Dictionary{ .raw_prefixes = &full, .serialized = &serialized }).validate(),
    );
}

test "one-shot copies accept first, last, and empty end addresses" {
    const dictionary = Dictionary{ .raw_prefixes = &.{ "abc", "de" } };

    var all: [5]u8 = undefined;
    try dictionary.copyInto(0, &all);
    try std.testing.expectEqualStrings("abcde", &all);

    var last: [1]u8 = undefined;
    try dictionary.copyInto(4, &last);
    try std.testing.expectEqualStrings("e", &last);

    var empty: [0]u8 = .{};
    try dictionary.copyInto(5, &empty);
}

test "cursor rejects addresses past the end, crossing copies, and arithmetic overflow" {
    const dictionary = Dictionary{ .raw_prefixes = &.{"abcde"} };
    try std.testing.expectError(
        error.CompoundDictionaryOutOfBounds,
        dictionary.cursor(5, 1),
    );
    try std.testing.expectError(
        error.CompoundDictionaryOutOfBounds,
        dictionary.cursor(6, 0),
    );
    try std.testing.expectError(
        error.CompoundDictionaryOutOfBounds,
        dictionary.cursor(3, 3),
    );
    try std.testing.expectError(
        error.IntegerOverflow,
        dictionary.cursor(std.math.maxInt(usize), 2),
    );
}

test "distance classification prioritizes compound then shifts static addresses" {
    try std.testing.expectError(error.InvalidDistance, classifyDistance(0, 10, 5));
    try std.testing.expectEqual(
        DistanceTarget{ .history = 1 },
        try classifyDistance(1, 10, 5),
    );
    try std.testing.expectEqual(
        DistanceTarget{ .history = 10 },
        try classifyDistance(10, 10, 5),
    );
    try std.testing.expectEqual(
        DistanceTarget{ .compound = 4 },
        try classifyDistance(11, 10, 5),
    );
    try std.testing.expectEqual(
        DistanceTarget{ .compound = 0 },
        try classifyDistance(15, 10, 5),
    );
    try std.testing.expectEqual(
        DistanceTarget{ .static_dictionary = 0 },
        try classifyDistance(16, 10, 5),
    );
    try std.testing.expectEqual(
        DistanceTarget{ .static_dictionary = 1 },
        try classifyDistance(17, 10, 5),
    );
    try std.testing.expectEqual(
        DistanceTarget{ .static_dictionary = 0 },
        try classifyDistance(11, 10, 0),
    );
}

test "dictionary distance helper validates and handles integer boundaries" {
    const dictionary = Dictionary{ .raw_prefixes = &.{ "ab", "cde" } };
    try std.testing.expectEqual(
        DistanceTarget{ .compound = 4 },
        try dictionary.classifyDistance(11, 10),
    );
    try std.testing.expectEqual(
        DistanceTarget{ .compound = 0 },
        try dictionary.classifyDistance(15, 10),
    );
    try std.testing.expectEqual(
        DistanceTarget{ .static_dictionary = 0 },
        try dictionary.classifyDistance(16, 10),
    );

    try std.testing.expectEqual(
        DistanceTarget{ .compound = 0 },
        try classifyDistance(std.math.maxInt(usize), std.math.maxInt(usize) - 2, 2),
    );
}
