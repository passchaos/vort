const std = @import("std");
const static_dictionary = @import("static_dictionary.zig");

pub const max_contexts: usize = 64;
pub const min_word_len: usize = 4;
pub const max_word_len: usize = 31;
pub const max_size_bits: u8 = 15;
pub const transform_type_count: u8 = 23;
pub const max_stringlets: usize = 256;
pub const max_transformed_word_len: usize = max_word_len + 2 * 255;

pub const Error = error{
    InvalidMagic,
    TruncatedDictionary,
    InvalidVarint,
    PrefixTooLarge,
    InvalidWordList,
    InvalidTransformList,
    InvalidDictionaryMap,
    InvalidContextMap,
    TrailingDictionaryData,
    IntegerOverflow,
    DictionaryAddressOutOfBounds,
    BuiltinDictionaryRequired,
    OutputTooSmall,
};

pub const WordList = struct {
    size_bits_by_length: [32]u8,
    offsets_by_length: [32]u32,
    data: []const u8,

    pub fn wordCount(self: *const WordList, word_len: usize) usize {
        if (word_len >= self.size_bits_by_length.len) return 0;
        const bits = self.size_bits_by_length[word_len];
        return if (bits == 0) 0 else @as(usize, 1) << @intCast(bits);
    }

    pub fn word(self: *const WordList, word_len: usize, index: usize) ?[]const u8 {
        const count = self.wordCount(word_len);
        if (index >= count) return null;
        const relative = std.math.mul(usize, word_len, index) catch return null;
        const start = std.math.add(
            usize,
            self.offsets_by_length[word_len],
            relative,
        ) catch return null;
        if (start > self.data.len or word_len > self.data.len - start) return null;
        return self.data[start..][0..word_len];
    }
};

pub const Transform = struct {
    prefix_id: u8,
    kind: u8,
    suffix_id: u8,
    parameter: u16,
};

pub const TransformList = struct {
    prefix_suffix: []const u8,
    string_count: u16,
    transforms: []const u8,
    params: ?[]const u8,

    pub fn transformCount(self: *const TransformList) usize {
        return self.transforms.len / 3;
    }

    pub fn transform(self: *const TransformList, index: usize) ?Transform {
        if (index >= self.transformCount()) return null;
        const cursor = index * 3;
        return .{
            .prefix_id = self.transforms[cursor],
            .kind = self.transforms[cursor + 1],
            .suffix_id = self.transforms[cursor + 2],
            .parameter = if (self.params) |params|
                std.mem.readInt(u16, params[index * 2 ..][0..2], .little)
            else
                0,
        };
    }

    pub fn string(self: *const TransformList, id: usize) ?[]const u8 {
        if (id >= self.string_count) return null;
        var cursor: usize = 0;
        var current: usize = 0;
        while (cursor < self.prefix_suffix.len) : (current += 1) {
            const len: usize = self.prefix_suffix[cursor];
            cursor += 1;
            if (len > self.prefix_suffix.len - cursor) return null;
            if (current == id) return self.prefix_suffix[cursor..][0..len];
            cursor += len;
        }
        return null;
    }

    pub fn apply(
        self: *const TransformList,
        transform_index: usize,
        word: []const u8,
        output: []u8,
    ) Error![]const u8 {
        const spec = self.transform(transform_index) orelse
            return error.DictionaryAddressOutOfBounds;
        const prefix = self.string(spec.prefix_id) orelse
            return error.InvalidTransformList;
        const suffix = self.string(spec.suffix_id) orelse
            return error.InvalidTransformList;
        var skip: usize = 0;
        var kept = word.len;
        if (spec.kind <= 9) {
            kept -|= spec.kind;
        } else if (spec.kind >= 12 and spec.kind <= 20) {
            skip = @min(word.len, @as(usize, spec.kind - 11));
            kept -= skip;
        }
        const output_len = std.math.add(
            usize,
            std.math.add(usize, prefix.len, kept) catch
                return error.IntegerOverflow,
            suffix.len,
        ) catch return error.IntegerOverflow;
        if (output.len < output_len) return error.OutputTooSmall;
        @memcpy(output[0..prefix.len], prefix);
        @memcpy(output[prefix.len..][0..kept], word[skip..][0..kept]);
        const transformed = output[prefix.len..][0..kept];
        switch (spec.kind) {
            10 => uppercase(transformed, false),
            11 => uppercase(transformed, true),
            21 => shiftUtf8(transformed, spec.parameter, false),
            22 => shiftUtf8(transformed, spec.parameter, true),
            else => {},
        }
        @memcpy(output[prefix.len + kept .. output_len], suffix);
        return output[0..output_len];
    }
};

pub const DictionaryChoice = struct {
    /// Equal to `word_list_count` means the RFC built-in word list.
    word_list_index: u8,
    /// Equal to `transform_list_count` means the RFC built-in transforms.
    transform_list_index: u8,
};

pub const ResolvedWord = struct {
    bytes: []const u8,
    dictionary_id: u6,
    word_index: u16,
    transform_index: u8,
};

pub const Match = struct {
    output_len: u16,
    copy_len: u5,
    address: usize,
    dictionary_id: u6,
};

pub const CandidateShape = struct {
    word_count: usize,
    transform_count: usize,

    pub fn capacity(self: CandidateShape) Error!usize {
        return std.math.mul(
            usize,
            self.word_count,
            self.transform_count,
        ) catch error.IntegerOverflow;
    }
};

/// Borrowed zero-copy view of one serialized Brotli shared dictionary.
/// All nested slices remain valid only while `encoded` remains alive.
pub const Dictionary = struct {
    encoded: []const u8,
    raw_prefix: []const u8,
    word_lists: [max_contexts]WordList,
    word_list_count: u7,
    transform_lists: [max_contexts]TransformList,
    transform_list_count: u7,
    dictionaries: [max_contexts]DictionaryChoice,
    dictionary_count: u7,
    context_based: bool,
    context_map: [max_contexts]u6,

    pub fn dictionaryForContext(self: *const Dictionary, context: usize) Error!u6 {
        if (context >= max_contexts) return error.InvalidContextMap;
        return if (self.context_based) self.context_map[context] else 0;
    }

    pub fn choice(self: *const Dictionary, dictionary_id: usize) ?DictionaryChoice {
        if (dictionary_id >= self.dictionary_count) return null;
        return self.dictionaries[dictionary_id];
    }

    pub fn candidateShape(
        self: *const Dictionary,
        dictionary_id: usize,
        word_len: usize,
    ) ?CandidateShape {
        const selected = self.choice(dictionary_id) orelse return null;
        if (word_len < min_word_len or word_len > max_word_len) return null;
        return .{
            .word_count = self.wordCount(selected, word_len),
            .transform_count = self.transformCount(selected),
        };
    }

    pub fn materializeCandidate(
        self: *const Dictionary,
        dictionary_id: usize,
        word_len: usize,
        word_index: usize,
        transform_index: usize,
        output: []u8,
    ) Error![]const u8 {
        const selected = self.choice(dictionary_id) orelse
            return error.DictionaryAddressOutOfBounds;
        const shape = self.candidateShape(dictionary_id, word_len) orelse
            return error.DictionaryAddressOutOfBounds;
        if (word_index >= shape.word_count or
            transform_index >= shape.transform_count)
        {
            return error.DictionaryAddressOutOfBounds;
        }
        const word_bytes = self.wordForChoice(
            selected,
            word_len,
            word_index,
        ) orelse return error.DictionaryAddressOutOfBounds;
        return self.applyTransform(
            selected,
            transform_index,
            word_bytes,
            output,
        );
    }

    pub fn resolveCustom(
        self: *const Dictionary,
        context: usize,
        word_len: usize,
        address: usize,
        output: []u8,
    ) Error!ResolvedWord {
        if (word_len < min_word_len or word_len > max_word_len)
            return error.DictionaryAddressOutOfBounds;
        const preferred = try self.dictionaryForContext(context);
        var remaining = address;
        var visit_index: usize = 0;
        while (visit_index < self.dictionary_count) : (visit_index += 1) {
            const dictionary_id: usize = if (visit_index == 0)
                preferred
            else blk: {
                var candidate = visit_index - 1;
                if (candidate >= preferred) candidate += 1;
                break :blk candidate;
            };
            if (dictionary_id >= self.dictionary_count) break;
            const selected = self.dictionaries[dictionary_id];
            if (selected.word_list_index >= self.word_list_count or
                selected.transform_list_index >= self.transform_list_count)
            {
                return error.BuiltinDictionaryRequired;
            }
            const words = &self.word_lists[selected.word_list_index];
            const transforms = &self.transform_lists[selected.transform_list_index];
            const word_count = words.wordCount(word_len);
            const capacity = std.math.mul(
                usize,
                word_count,
                transforms.transformCount(),
            ) catch return error.IntegerOverflow;
            if (remaining >= capacity) {
                remaining -= capacity;
                continue;
            }
            const word_index = remaining % word_count;
            const transform_index = remaining / word_count;
            const word = words.word(word_len, word_index) orelse
                return error.DictionaryAddressOutOfBounds;
            const transformed = try transforms.apply(transform_index, word, output);
            return .{
                .bytes = transformed,
                .dictionary_id = @intCast(dictionary_id),
                .word_index = @intCast(word_index),
                .transform_index = @intCast(transform_index),
            };
        }
        return error.DictionaryAddressOutOfBounds;
    }

    /// Resolve the complete serialized static-dictionary address space.
    ///
    /// Each dictionary choice may independently select custom or RFC built-in
    /// words and transforms. The context-selected choice is visited first,
    /// followed by every other choice in ascending dictionary ID order.
    pub fn resolve(
        self: *const Dictionary,
        context: usize,
        word_len: usize,
        address: usize,
        output: []u8,
    ) Error!ResolvedWord {
        if (word_len < min_word_len or word_len > max_word_len)
            return error.DictionaryAddressOutOfBounds;
        const preferred = try self.dictionaryForContext(context);
        var remaining = address;
        for (0..self.dictionary_count) |visit_index| {
            const dictionary_id = visitDictionaryId(visit_index, preferred);
            const selected = self.dictionaries[dictionary_id];
            const word_count = self.wordCount(selected, word_len);
            const transform_count = self.transformCount(selected);
            const capacity = std.math.mul(
                usize,
                word_count,
                transform_count,
            ) catch return error.IntegerOverflow;
            if (remaining >= capacity) {
                remaining -= capacity;
                continue;
            }
            const word_index = remaining % word_count;
            const transform_index = remaining / word_count;
            const word = self.wordForChoice(selected, word_len, word_index) orelse
                return error.DictionaryAddressOutOfBounds;
            const transformed = try self.applyTransform(
                selected,
                transform_index,
                word,
                output,
            );
            return .{
                .bytes = transformed,
                .dictionary_id = @intCast(dictionary_id),
                .word_index = @intCast(word_index),
                .transform_index = @intCast(transform_index),
            };
        }
        return error.DictionaryAddressOutOfBounds;
    }

    fn wordCount(
        self: *const Dictionary,
        selected: DictionaryChoice,
        word_len: usize,
    ) usize {
        if (selected.word_list_index < self.word_list_count)
            return self.word_lists[selected.word_list_index].wordCount(word_len);
        const bits = static_dictionary.sizeBits(word_len) orelse return 0;
        return @as(usize, 1) << bits;
    }

    fn transformCount(
        self: *const Dictionary,
        selected: DictionaryChoice,
    ) usize {
        if (selected.transform_list_index < self.transform_list_count)
            return self.transform_lists[selected.transform_list_index].transformCount();
        return static_dictionary.transform_count;
    }

    fn wordForChoice(
        self: *const Dictionary,
        selected: DictionaryChoice,
        word_len: usize,
        word_index: usize,
    ) ?[]const u8 {
        if (selected.word_list_index < self.word_list_count)
            return self.word_lists[selected.word_list_index].word(word_len, word_index);
        return static_dictionary.baseWord(word_len, word_index);
    }

    fn applyTransform(
        self: *const Dictionary,
        selected: DictionaryChoice,
        transform_index: usize,
        word_bytes: []const u8,
        output: []u8,
    ) Error![]const u8 {
        if (selected.transform_list_index < self.transform_list_count)
            return self.transform_lists[selected.transform_list_index].apply(
                transform_index,
                word_bytes,
                output,
            );
        return static_dictionary.transformWord(
            transform_index,
            word_bytes,
            output,
        ) orelse error.DictionaryAddressOutOfBounds;
    }

    /// Exhaustive correctness matcher for the complete serialized descriptor,
    /// including independently mixed custom and RFC built-in word/transform
    /// tables. Production indexing may replace the search strategy but must
    /// preserve this address ordering and tie break.
    pub fn findLongest(
        self: *const Dictionary,
        context: usize,
        input: []const u8,
        transformed_scratch: []u8,
    ) Error!?Match {
        if (input.len < min_word_len) return null;
        const preferred = try self.dictionaryForContext(context);
        var best: ?Match = null;
        for (min_word_len..max_word_len + 1) |word_len| {
            var address_base: usize = 0;
            for (0..self.dictionary_count) |visit_index| {
                const dictionary_id = visitDictionaryId(visit_index, preferred);
                const selected = self.dictionaries[dictionary_id];
                const word_count = self.wordCount(selected, word_len);
                const transform_count = self.transformCount(selected);
                const capacity = std.math.mul(
                    usize,
                    word_count,
                    transform_count,
                ) catch return error.IntegerOverflow;
                for (0..transform_count) |transform_index| {
                    for (0..word_count) |word_index| {
                        const word_bytes = self.wordForChoice(
                            selected,
                            word_len,
                            word_index,
                        ).?;
                        const transformed = try self.applyTransform(
                            selected,
                            transform_index,
                            word_bytes,
                            transformed_scratch,
                        );
                        if (transformed.len < min_word_len or
                            transformed.len > input.len or
                            !std.mem.eql(u8, transformed, input[0..transformed.len]))
                        {
                            continue;
                        }
                        const local_address = std.math.add(
                            usize,
                            std.math.mul(
                                usize,
                                transform_index,
                                word_count,
                            ) catch return error.IntegerOverflow,
                            word_index,
                        ) catch return error.IntegerOverflow;
                        const address = std.math.add(
                            usize,
                            address_base,
                            local_address,
                        ) catch return error.IntegerOverflow;
                        if (best == null or transformed.len > best.?.output_len or
                            (transformed.len == best.?.output_len and
                                address < best.?.address))
                        {
                            best = .{
                                .output_len = @intCast(transformed.len),
                                .copy_len = @intCast(word_len),
                                .address = address,
                                .dictionary_id = @intCast(dictionary_id),
                            };
                        }
                    }
                }
                address_base = std.math.add(
                    usize,
                    address_base,
                    capacity,
                ) catch return error.IntegerOverflow;
            }
        }
        return best;
    }

    /// Exhaustive correctness matcher for custom-only dictionary combinations.
    /// Production indexing is intentionally a later layer; this reference path
    /// establishes address ordering and context semantics first.
    pub fn findLongestCustom(
        self: *const Dictionary,
        context: usize,
        input: []const u8,
        transformed_scratch: []u8,
    ) Error!?Match {
        if (input.len < min_word_len) return null;
        const preferred = try self.dictionaryForContext(context);
        var best: ?Match = null;
        // Omit transforms can make a 31-byte dictionary word match an input
        // shorter than the source word, so every encoded word length remains
        // a candidate regardless of `input.len`.
        for (min_word_len..max_word_len + 1) |word_len| {
            var address_base: usize = 0;
            for (0..self.dictionary_count) |visit_index| {
                const dictionary_id: usize = if (visit_index == 0)
                    preferred
                else blk: {
                    var candidate = visit_index - 1;
                    if (candidate >= preferred) candidate += 1;
                    break :blk candidate;
                };
                const selected = self.dictionaries[dictionary_id];
                if (selected.word_list_index >= self.word_list_count or
                    selected.transform_list_index >= self.transform_list_count)
                {
                    return error.BuiltinDictionaryRequired;
                }
                const words = &self.word_lists[selected.word_list_index];
                const transforms = &self.transform_lists[selected.transform_list_index];
                const word_count = words.wordCount(word_len);
                const capacity = std.math.mul(
                    usize,
                    word_count,
                    transforms.transformCount(),
                ) catch return error.IntegerOverflow;
                for (0..transforms.transformCount()) |transform_index| {
                    for (0..word_count) |word_index| {
                        const word = words.word(word_len, word_index).?;
                        const transformed = try transforms.apply(
                            transform_index,
                            word,
                            transformed_scratch,
                        );
                        if (transformed.len < min_word_len or transformed.len > input.len or
                            !std.mem.eql(u8, transformed, input[0..transformed.len]))
                        {
                            continue;
                        }
                        const local_address = std.math.add(
                            usize,
                            std.math.mul(
                                usize,
                                transform_index,
                                word_count,
                            ) catch return error.IntegerOverflow,
                            word_index,
                        ) catch return error.IntegerOverflow;
                        const address = std.math.add(
                            usize,
                            address_base,
                            local_address,
                        ) catch return error.IntegerOverflow;
                        if (best == null or transformed.len > best.?.output_len or
                            (transformed.len == best.?.output_len and address < best.?.address))
                        {
                            best = .{
                                .output_len = @intCast(transformed.len),
                                .copy_len = @intCast(word_len),
                                .address = address,
                                .dictionary_id = @intCast(dictionary_id),
                            };
                        }
                    }
                }
                address_base = std.math.add(usize, address_base, capacity) catch
                    return error.IntegerOverflow;
            }
        }
        return best;
    }
};

fn visitDictionaryId(visit_index: usize, preferred: usize) usize {
    if (visit_index == 0) return preferred;
    const candidate = visit_index - 1;
    return if (candidate >= preferred) candidate + 1 else candidate;
}

const Reader = struct {
    bytes: []const u8,
    cursor: usize = 0,

    fn readByte(self: *Reader) Error!u8 {
        if (self.cursor >= self.bytes.len) return error.TruncatedDictionary;
        defer self.cursor += 1;
        return self.bytes[self.cursor];
    }

    fn readU16(self: *Reader) Error!u16 {
        if (self.cursor > self.bytes.len or self.bytes.len - self.cursor < 2)
            return error.TruncatedDictionary;
        defer self.cursor += 2;
        return std.mem.readInt(u16, self.bytes[self.cursor..][0..2], .little);
    }

    fn readSlice(self: *Reader, len: usize) Error![]const u8 {
        if (self.cursor > self.bytes.len or len > self.bytes.len - self.cursor)
            return error.TruncatedDictionary;
        defer self.cursor += len;
        return self.bytes[self.cursor..][0..len];
    }

    fn readVarint32(self: *Reader) Error!u32 {
        var result: u32 = 0;
        for (0..5) |index| {
            const byte = try self.readByte();
            if (index == 4 and byte > 15) return error.InvalidVarint;
            result |= @as(u32, byte & 0x7f) << @intCast(index * 7);
            if (byte < 0x80) return result;
        }
        return error.InvalidVarint;
    }
};

pub fn parse(encoded: []const u8) Error!Dictionary {
    var reader = Reader{ .bytes = encoded };
    if (try reader.readByte() != 0x91 or try reader.readByte() != 0)
        return error.InvalidMagic;
    const prefix_len = try reader.readVarint32();
    if (prefix_len > 1_073_741_823) return error.PrefixTooLarge;
    const raw_prefix = try reader.readSlice(prefix_len);

    var result: Dictionary = undefined;
    result.encoded = encoded;
    result.raw_prefix = raw_prefix;
    const word_list_count = try reader.readByte();
    if (word_list_count > max_contexts) return error.InvalidWordList;
    result.word_list_count = @intCast(word_list_count);
    for (0..result.word_list_count) |index|
        result.word_lists[index] = try parseWordList(&reader);

    const transform_list_count = try reader.readByte();
    if (transform_list_count > max_contexts)
        return error.InvalidTransformList;
    result.transform_list_count = @intCast(transform_list_count);
    for (0..result.transform_list_count) |index|
        result.transform_lists[index] = try parseTransformList(&reader);

    if (result.word_list_count != 0 or result.transform_list_count != 0) {
        const dictionary_count = try reader.readByte();
        if (dictionary_count == 0 or dictionary_count > max_contexts)
            return error.InvalidDictionaryMap;
        result.dictionary_count = @intCast(dictionary_count);
        for (0..result.dictionary_count) |index| {
            const words = try reader.readByte();
            const transforms = try reader.readByte();
            if (words > result.word_list_count or
                transforms > result.transform_list_count)
            {
                return error.InvalidDictionaryMap;
            }
            result.dictionaries[index] = .{
                .word_list_index = words,
                .transform_list_index = transforms,
            };
        }
        const context_enabled = try reader.readByte();
        if (context_enabled > 1) return error.InvalidContextMap;
        result.context_based = context_enabled != 0;
        result.context_map = @splat(0);
        if (result.context_based) {
            for (&result.context_map) |*dictionary_id| {
                const value = try reader.readByte();
                if (value >= result.dictionary_count) return error.InvalidContextMap;
                dictionary_id.* = @intCast(value);
            }
        }
    } else {
        result.context_based = false;
        result.dictionary_count = 1;
        result.dictionaries[0] = .{
            .word_list_index = 0,
            .transform_list_index = 0,
        };
        result.context_map = @splat(0);
    }
    if (reader.cursor != encoded.len) return error.TrailingDictionaryData;
    return result;
}

fn parseWordList(reader: *Reader) Error!WordList {
    var result: WordList = undefined;
    result.size_bits_by_length = @splat(0);
    const encoded_bits = try reader.readSlice(max_word_len - min_word_len + 1);
    @memcpy(result.size_bits_by_length[min_word_len .. max_word_len + 1], encoded_bits);
    var offset: usize = 0;
    for (&result.offsets_by_length, 0..) |*slot, word_len| {
        slot.* = std.math.cast(u32, offset) orelse return error.InvalidWordList;
        const bits = result.size_bits_by_length[word_len];
        if (bits > max_size_bits) return error.InvalidWordList;
        if (bits != 0) {
            const bytes = std.math.mul(
                usize,
                word_len,
                @as(usize, 1) << @intCast(bits),
            ) catch return error.IntegerOverflow;
            offset = std.math.add(usize, offset, bytes) catch
                return error.IntegerOverflow;
        }
    }
    result.data = try reader.readSlice(offset);
    return result;
}

fn parseTransformList(reader: *Reader) Error!TransformList {
    var result: TransformList = undefined;
    const prefix_suffix_len = try reader.readU16();
    if (prefix_suffix_len == 0) return error.InvalidTransformList;
    result.prefix_suffix = try reader.readSlice(prefix_suffix_len);
    var cursor: usize = 0;
    var string_count: usize = 0;
    while (cursor < result.prefix_suffix.len) {
        const len: usize = result.prefix_suffix[cursor];
        cursor += 1;
        string_count += 1;
        if (string_count > max_stringlets or len > result.prefix_suffix.len - cursor)
            return error.InvalidTransformList;
        cursor += len;
        if (len == 0 and cursor != result.prefix_suffix.len)
            return error.InvalidTransformList;
    }
    if (result.prefix_suffix[result.prefix_suffix.len - 1] != 0)
        return error.InvalidTransformList;
    result.string_count = @intCast(string_count);
    const transform_count = try reader.readByte();
    result.transforms = try reader.readSlice(@as(usize, transform_count) * 3);
    var has_shift = false;
    for (0..transform_count) |index| {
        const base = index * 3;
        if (result.transforms[base] >= string_count or
            result.transforms[base + 2] >= string_count or
            result.transforms[base + 1] >= transform_type_count)
        {
            return error.InvalidTransformList;
        }
        has_shift = has_shift or result.transforms[base + 1] >= 21;
    }
    result.params = if (has_shift)
        try reader.readSlice(@as(usize, transform_count) * 2)
    else
        null;
    if (result.params) |params| {
        for (0..transform_count) |index| {
            const kind = result.transforms[index * 3 + 1];
            if (kind < 21 and (params[index * 2] != 0 or params[index * 2 + 1] != 0))
                return error.InvalidTransformList;
        }
    }
    return result;
}

fn uppercase(bytes: []u8, all: bool) void {
    var cursor: usize = 0;
    while (cursor < bytes.len) {
        const step = uppercaseScalar(bytes[cursor..]);
        if (!all) return;
        cursor += step;
    }
}

fn uppercaseScalar(bytes: []u8) usize {
    const first = bytes[0];
    if (first < 0xc0) {
        if (first >= 'a' and first <= 'z') bytes[0] ^= 32;
        return 1;
    }
    if (first < 0xe0) {
        if (bytes.len >= 2) bytes[1] ^= 32;
        return @min(bytes.len, 2);
    }
    if (bytes.len >= 3) bytes[2] ^= 5;
    return @min(bytes.len, 3);
}

fn shiftUtf8(bytes: []u8, parameter: u16, all: bool) void {
    var cursor: usize = 0;
    while (cursor < bytes.len) {
        const step = shiftScalar(bytes[cursor..], parameter);
        if (!all) return;
        cursor += step;
    }
}

fn shiftScalar(bytes: []u8, parameter: u16) usize {
    var scalar: u32 = @as(u32, parameter & 0x7fff) +
        (0x1000000 - @as(u32, parameter & 0x8000));
    const first = bytes[0];
    if (first < 0x80) {
        scalar +%= first;
        bytes[0] = @truncate(scalar & 0x7f);
        return 1;
    }
    if (first < 0xc0) return 1;
    if (first < 0xe0) {
        if (bytes.len < 2) return 1;
        scalar +%= (bytes[1] & 0x3f) | (@as(u32, first & 0x1f) << 6);
        bytes[0] = 0xc0 | @as(u8, @truncate((scalar >> 6) & 0x1f));
        bytes[1] = (bytes[1] & 0xc0) | @as(u8, @truncate(scalar & 0x3f));
        return 2;
    }
    if (first < 0xf0) {
        if (bytes.len < 3) return bytes.len;
        scalar +%= (bytes[2] & 0x3f) |
            (@as(u32, bytes[1] & 0x3f) << 6) |
            (@as(u32, first & 0x0f) << 12);
        bytes[0] = 0xe0 | @as(u8, @truncate((scalar >> 12) & 0x0f));
        bytes[1] = (bytes[1] & 0xc0) | @as(u8, @truncate((scalar >> 6) & 0x3f));
        bytes[2] = (bytes[2] & 0xc0) | @as(u8, @truncate(scalar & 0x3f));
        return 3;
    }
    if (first < 0xf8) {
        if (bytes.len < 4) return bytes.len;
        scalar +%= (bytes[3] & 0x3f) |
            (@as(u32, bytes[2] & 0x3f) << 6) |
            (@as(u32, bytes[1] & 0x3f) << 12) |
            (@as(u32, first & 0x07) << 18);
        bytes[0] = 0xf0 | @as(u8, @truncate((scalar >> 18) & 0x07));
        bytes[1] = (bytes[1] & 0xc0) | @as(u8, @truncate((scalar >> 12) & 0x3f));
        bytes[2] = (bytes[2] & 0xc0) | @as(u8, @truncate((scalar >> 6) & 0x3f));
        bytes[3] = (bytes[3] & 0xc0) | @as(u8, @truncate(scalar & 0x3f));
        return 4;
    }
    return 1;
}

test "serialized contextual dictionary parses and selects custom words" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    try bytes.appendSlice(std.testing.allocator, &.{ 0x91, 0x00, 0x00, 0x02 });
    var bits: [28]u8 = @splat(0);
    bits[0] = 1;
    try bytes.appendSlice(std.testing.allocator, &bits);
    try bytes.appendSlice(std.testing.allocator, "cat!dog!");
    try bytes.appendSlice(std.testing.allocator, &bits);
    try bytes.appendSlice(std.testing.allocator, "red!blue");
    try bytes.append(std.testing.allocator, 1); // transform lists
    try bytes.appendSlice(std.testing.allocator, &.{ 1, 0, 0, 1, 0, 0, 0 });
    try bytes.appendSlice(std.testing.allocator, &.{ 2, 0, 0, 1, 0 });
    try bytes.append(std.testing.allocator, 1); // context enabled
    for (0..64) |context|
        try bytes.append(std.testing.allocator, @intFromBool(context >= 32));

    const dictionary = try parse(bytes.items);
    try std.testing.expect(dictionary.context_based);
    try std.testing.expectEqual(@as(u6, 0), try dictionary.dictionaryForContext(31));
    try std.testing.expectEqual(@as(u6, 1), try dictionary.dictionaryForContext(32));
    var output: [64]u8 = undefined;
    const first = try dictionary.resolveCustom(0, 4, 1, &output);
    try std.testing.expectEqualSlices(u8, "dog!", first.bytes);
    const second = try dictionary.resolveCustom(32, 4, 0, &output);
    try std.testing.expectEqualSlices(u8, "red!", second.bytes);
    const local_match = (try dictionary.findLongestCustom(0, "dog!", &output)).?;
    try std.testing.expectEqual(@as(usize, 1), local_match.address);
    try std.testing.expectEqual(@as(u6, 0), local_match.dictionary_id);
    const fallback_match = (try dictionary.findLongestCustom(0, "red!", &output)).?;
    try std.testing.expectEqual(@as(usize, 2), fallback_match.address);
    try std.testing.expectEqual(@as(u6, 1), fallback_match.dictionary_id);
    const contextual_match = (try dictionary.findLongestCustom(32, "red!", &output)).?;
    try std.testing.expectEqual(@as(usize, 0), contextual_match.address);
    try std.testing.expectEqual(@as(u6, 1), contextual_match.dictionary_id);

    for (0..bytes.items.len) |end| {
        if (parse(bytes.items[0..end])) |_| return error.TestUnexpectedResult else |_| {}
    }
    const invalid_context = try std.testing.allocator.dupe(u8, bytes.items);
    defer std.testing.allocator.free(invalid_context);
    invalid_context[invalid_context.len - 1] = 2;
    try std.testing.expectError(error.InvalidContextMap, parse(invalid_context));
}

test "serialized dictionary rejects malformed maps and trailing data" {
    try std.testing.expectError(error.InvalidMagic, parse(&.{ 0x90, 0 }));
    try std.testing.expectError(error.TruncatedDictionary, parse(&.{ 0x91, 0 }));
    try std.testing.expectError(
        error.TrailingDictionaryData,
        parse(&.{ 0x91, 0, 0, 0, 0, 0xff }),
    );
    const with_prefix = try parse(&.{ 0x91, 0, 3, 'a', 'b', 'c', 0, 0 });
    try std.testing.expectEqualSlices(u8, "abc", with_prefix.raw_prefix);
}

test "serialized dictionary accepts the complete stringlet id domain" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    try bytes.appendSlice(std.testing.allocator, &.{
        0x91, 0x00, // magic
        0x00, // raw prefix length
        0x00, // custom word lists
        0x01, // custom transform lists
        0xff, 0x01, // 511-byte prefix/suffix table
    });
    for (0..255) |_| try bytes.appendSlice(std.testing.allocator, &.{ 1, 'x' });
    try bytes.append(std.testing.allocator, 0); // stringlet ID 255
    try bytes.appendSlice(std.testing.allocator, &.{
        1, // transform count
        255, 0, 255, // highest prefix/suffix ID
        1, // dictionary count
        0, 0, // built-in words plus custom transforms
        0, // context map disabled
    });

    const dictionary = try parse(bytes.items);
    const transforms = &dictionary.transform_lists[0];
    try std.testing.expectEqual(@as(u16, max_stringlets), transforms.string_count);
    try std.testing.expectEqualSlices(u8, "", transforms.string(255).?);
}

test "reference matcher considers source words longer than transformed output" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    try bytes.appendSlice(std.testing.allocator, &.{ 0x91, 0x00, 0x00, 0x01 });
    var bits: [28]u8 = @splat(0);
    bits[13 - min_word_len] = 1;
    try bytes.appendSlice(std.testing.allocator, &bits);
    try bytes.appendSlice(std.testing.allocator, "abcd123456789wxyz123456789");
    try bytes.appendSlice(std.testing.allocator, &.{
        1, // transform lists
        1, 0, // prefix/suffix table length
        0, // empty stringlet
        1, // transform count
        0, 9, 0, // omit last nine bytes
        1, // dictionary count
        0, 0, // custom word and transform lists
        0, // context map disabled
    });

    const dictionary = try parse(bytes.items);
    var output: [64]u8 = undefined;
    const match = (try dictionary.findLongestCustom(0, "abcd", &output)).?;
    try std.testing.expectEqual(@as(u5, 13), match.copy_len);
    try std.testing.expectEqual(@as(u16, 4), match.output_len);
    try std.testing.expectEqual(@as(usize, 0), match.address);
}

test "complete resolver mixes custom and built-in words and transforms" {
    var custom_words: std.ArrayList(u8) = .empty;
    defer custom_words.deinit(std.testing.allocator);
    try custom_words.appendSlice(std.testing.allocator, &.{ 0x91, 0x00, 0x00, 0x01 });
    var bits: [28]u8 = @splat(0);
    bits[5 - min_word_len] = 1;
    try custom_words.appendSlice(std.testing.allocator, &bits);
    try custom_words.appendSlice(std.testing.allocator, "helloworld");
    try custom_words.appendSlice(std.testing.allocator, &.{
        0, // custom transform lists
        1, // dictionary count
        0, 0, // custom words plus built-in transforms
        0, // context map disabled
    });
    const custom_word_dictionary = try parse(custom_words.items);
    var output: [max_transformed_word_len]u8 = undefined;
    try std.testing.expectEqualSlices(
        u8,
        "hello",
        (try custom_word_dictionary.resolve(0, 5, 0, &output)).bytes,
    );
    try std.testing.expectEqualSlices(
        u8,
        "hello ",
        (try custom_word_dictionary.resolve(0, 5, 2, &output)).bytes,
    );

    var custom_transforms: std.ArrayList(u8) = .empty;
    defer custom_transforms.deinit(std.testing.allocator);
    try custom_transforms.appendSlice(std.testing.allocator, &.{
        0x91, 0x00, 0x00, // magic and empty RAW prefix
        0, // custom word lists
        1, // custom transform lists
        3, 0, // prefix/suffix table length
        1, '<', 0, // "<" and empty stringlets
        1, // transform count
        0, 0, 1, // prefix "<", identity, empty suffix
        1, // dictionary count
        0, 0, // built-in words plus custom transforms
        0, // context map disabled
    });
    const custom_transform_dictionary = try parse(custom_transforms.items);
    try std.testing.expectEqualSlices(
        u8,
        "<first",
        (try custom_transform_dictionary.resolve(0, 5, 0, &output)).bytes,
    );

    const custom_word_match = (try custom_word_dictionary.findLongest(
        0,
        "hello ",
        &output,
    )).?;
    try std.testing.expectEqual(@as(u16, 6), custom_word_match.output_len);
    try std.testing.expectEqual(@as(u5, 5), custom_word_match.copy_len);
    try std.testing.expectEqual(@as(usize, 2), custom_word_match.address);
    try std.testing.expectEqualSlices(
        u8,
        "hello ",
        (try custom_word_dictionary.resolve(
            0,
            custom_word_match.copy_len,
            custom_word_match.address,
            &output,
        )).bytes,
    );

    const custom_transform_match = (try custom_transform_dictionary.findLongest(
        0,
        "<first",
        &output,
    )).?;
    try std.testing.expectEqual(@as(u16, 6), custom_transform_match.output_len);
    try std.testing.expectEqual(@as(u5, 5), custom_transform_match.copy_len);
    try std.testing.expectEqual(@as(usize, 0), custom_transform_match.address);
}

test "custom transform replay covers every transform family" {
    const strings = [_]u8{0};
    var triplet = [3]u8{ 0, 0, 0 };
    var params = [2]u8{ 1, 0 };
    var output: [64]u8 = undefined;
    for (0..transform_type_count) |kind| {
        triplet[1] = @intCast(kind);
        const transforms = TransformList{
            .prefix_suffix = &strings,
            .string_count = 1,
            .transforms = &triplet,
            .params = if (kind >= 21) &params else null,
        };
        const actual = try transforms.apply(0, "abcd", &output);
        const expected: []const u8 = switch (kind) {
            0 => "abcd",
            1...3 => "abcd"[0 .. 4 - kind],
            4...9 => "",
            10 => "Abcd",
            11 => "ABCD",
            12...15 => "abcd"[kind - 11 ..],
            16...20 => "",
            21 => "bbcd",
            22 => "bcde",
            else => unreachable,
        };
        try std.testing.expectEqualSlices(u8, expected, actual);
    }

    triplet[1] = 21;
    const utf8_transforms = TransformList{
        .prefix_suffix = &strings,
        .string_count = 1,
        .transforms = &triplet,
        .params = &params,
    };
    try std.testing.expectEqualSlices(
        u8,
        &.{ 0xc3, 0xa1 },
        try utf8_transforms.apply(0, &.{ 0xc3, 0xa0 }, &output),
    );
}

test "custom transforms preserve prefix and suffix stringlets" {
    const strings = [_]u8{ 1, '<', 1, '>', 0 };
    const triplet = [_]u8{ 0, 0, 1 };
    const transforms = TransformList{
        .prefix_suffix = &strings,
        .string_count = 3,
        .transforms = &triplet,
        .params = null,
    };
    var output: [64]u8 = undefined;
    try std.testing.expectEqualSlices(
        u8,
        "<word>",
        try transforms.apply(0, "word", &output),
    );
}
