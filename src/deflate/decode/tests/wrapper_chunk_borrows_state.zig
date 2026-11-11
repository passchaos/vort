const std = @import("std");
const testing = std.testing;
const S = @import("wrapper_chunk_borrows_support.zig");

const Mode = enum { plain, options, exact, options_exact, concatenated, concatenated_options, concatenated_exact, concatenated_options_exact };

fn reset(comptime C: type, comptime mode: Mode, comptime dictionary: bool, self: *C, chunks: []const []const u8, scratch: []u8, output: []u8, dict: []const u8) !void {
    if (dictionary) return switch (mode) {
        .plain => self.resetFromChunksWithDictionary(chunks, dict, scratch, output),
        .options => self.resetFromChunksWithDictionaryAndOptions(chunks, dict, scratch, output, .{}),
        .exact => self.resetFromChunksWithDictionaryExactSize(chunks, dict, scratch, output, S.plain.len),
        .options_exact => self.resetFromChunksWithDictionaryAndOptionsExactSize(chunks, dict, scratch, output, .{}, S.plain.len),
        .concatenated => self.resetConcatenatedFromChunksWithDictionary(chunks, dict, scratch, output),
        .concatenated_options => self.resetConcatenatedFromChunksWithDictionaryAndOptions(chunks, dict, scratch, output, .{}),
        .concatenated_exact => self.resetConcatenatedFromChunksWithDictionaryExactSize(chunks, dict, scratch, output, S.plain.len),
        .concatenated_options_exact => self.resetConcatenatedFromChunksWithDictionaryAndOptionsExactSize(chunks, dict, scratch, output, .{}, S.plain.len),
    };
    return switch (mode) {
        .plain => self.resetFromChunks(chunks, scratch, output),
        .options => self.resetFromChunksWithOptions(chunks, scratch, output, .{}),
        .exact => self.resetFromChunksExactSize(chunks, scratch, output, S.plain.len),
        .options_exact => self.resetFromChunksWithOptionsExactSize(chunks, scratch, output, .{}, S.plain.len),
        .concatenated => self.resetConcatenatedFromChunks(chunks, scratch, output),
        .concatenated_options => self.resetConcatenatedFromChunksWithOptions(chunks, scratch, output, .{}),
        .concatenated_exact => self.resetConcatenatedFromChunksExactSize(chunks, scratch, output, S.plain.len),
        .concatenated_options_exact => self.resetConcatenatedFromChunksWithOptionsExactSize(chunks, scratch, output, .{}, S.plain.len),
    };
}

fn init(comptime C: type, comptime mode: Mode, comptime dictionary: bool, chunks: []const []const u8, scratch: []u8, output: []u8) !C {
    if (dictionary) return switch (mode) {
        .plain => C.initFromChunksWithDictionary(chunks, S.dictionary, scratch, output),
        .options => C.initFromChunksWithDictionaryAndOptions(chunks, S.dictionary, scratch, output, .{}),
        .exact => C.initFromChunksWithDictionaryExactSize(chunks, S.dictionary, scratch, output, S.plain.len),
        .options_exact => C.initFromChunksWithDictionaryAndOptionsExactSize(chunks, S.dictionary, scratch, output, .{}, S.plain.len),
        .concatenated => C.initConcatenatedFromChunksWithDictionary(chunks, S.dictionary, scratch, output),
        .concatenated_options => C.initConcatenatedFromChunksWithDictionaryAndOptions(chunks, S.dictionary, scratch, output, .{}),
        .concatenated_exact => C.initConcatenatedFromChunksWithDictionaryExactSize(chunks, S.dictionary, scratch, output, S.plain.len),
        .concatenated_options_exact => C.initConcatenatedFromChunksWithDictionaryAndOptionsExactSize(chunks, S.dictionary, scratch, output, .{}, S.plain.len),
    };
    return switch (mode) {
        .plain => C.initFromChunks(chunks, scratch, output),
        .options => C.initFromChunksWithOptions(chunks, scratch, output, .{}),
        .exact => C.initFromChunksExactSize(chunks, scratch, output, S.plain.len),
        .options_exact => C.initFromChunksWithOptionsExactSize(chunks, scratch, output, .{}, S.plain.len),
        .concatenated => C.initConcatenatedFromChunks(chunks, scratch, output),
        .concatenated_options => C.initConcatenatedFromChunksWithOptions(chunks, scratch, output, .{}),
        .concatenated_exact => C.initConcatenatedFromChunksExactSize(chunks, scratch, output, S.plain.len),
        .concatenated_options_exact => C.initConcatenatedFromChunksWithOptionsExactSize(chunks, scratch, output, .{}, S.plain.len),
    };
}

pub fn contracts(comptime D: type) !void {
    try wrapper(D, D.ZlibDecoder, false, .zlib);
    try wrapper(D, D.ZlibDecoder, true, .zlib_dictionary);
    try wrapper(D, D.GzipDecoder, false, .gzip);
    try pngBindings(D);
}

fn wrapper(comptime D: type, comptime C: type, comptime dictionary: bool, comptime wire_mode: S.Mode) !void {
    const wire = try S.encode(D, wire_mode);
    defer testing.allocator.free(wire);
    const chunks = S.split(wire);
    inline for (comptime std.meta.tags(Mode)) |mode| {
        errdefer std.debug.print("wrapper state chunk borrow mode: {s}, {s}, dictionary={}\n", .{ @typeName(C), @tagName(mode), dictionary });
        var output: [80]u8 = @splat(0xa5);
        const output_before = output;
        try testing.expectError(error.InvalidBlockPlan, init(C, mode, dictionary, &chunks, &output, &output));
        try testing.expectEqualSlices(u8, &output_before, &output);
        var independent: [80]u8 = undefined;
        const initialized = try init(C, mode, dictionary, &chunks, &independent, &output);
        try testing.expectEqualSlices(u8, S.plain, initialized.decoded);

        const Holder = struct { decoder: C, tail: [96]u8 };
        var holder: Holder = undefined;
        @memset(std.mem.asBytes(&holder), 0xa5);
        holder.decoder = .{};
        // Written scratch includes a valid decoder object, not a forged pointer.
        const before = S.copyBytes(Holder, &holder);
        try testing.expectError(error.InvalidBlockPlan, reset(C, mode, dictionary, &holder.decoder, &chunks, std.mem.asBytes(&holder), &output, S.dictionary));
        try testing.expectEqualSlices(u8, &before, std.mem.asBytes(&holder));
        try reset(C, mode, dictionary, &holder.decoder, &chunks, &independent, &output, S.dictionary);
        try testing.expectEqualSlices(u8, S.plain, holder.decoder.decoded);

        // A rejected reset preserves the previously decoded history binding.
        var history: [80]u8 = @splat(0xa5);
        @memcpy(history[0..S.plain.len], S.plain);
        holder.decoder.decoded = history[0..S.plain.len];
        const state_before = S.copyBytes(C, &holder.decoder);
        const history_before = history;
        try testing.expectError(error.InvalidBlockPlan, reset(C, mode, dictionary, &holder.decoder, &chunks, &history, &output, S.dictionary));
        try testing.expectEqualSlices(u8, &state_before, std.mem.asBytes(&holder.decoder));
        try testing.expectEqualSlices(u8, &history_before, &history);
        try reset(C, mode, dictionary, &holder.decoder, &chunks, &independent, &output, S.dictionary);
        try testing.expectEqualSlices(u8, S.plain, holder.decoder.decoded);

        // Single-source borrowing can safely ignore scratch even inside self.
        const single = [_][]const u8{ "", wire, "" };
        try reset(C, mode, dictionary, &holder.decoder, &single, std.mem.asBytes(&holder), &output, S.dictionary);
        try testing.expectEqualSlices(u8, S.plain, holder.decoder.decoded);
        const before_output_self = S.copyBytes(C, &holder.decoder);
        try testing.expectError(error.InvalidBlockPlan, reset(C, mode, dictionary, &holder.decoder, &single, &.{}, std.mem.asBytes(&holder.decoder), S.dictionary));
        try testing.expectEqualSlices(u8, &before_output_self, std.mem.asBytes(&holder.decoder));

        if (dictionary) {
            var dict_scratch: [80]u8 = @splat(0xa5);
            @memcpy(dict_scratch[0..S.dictionary.len], S.dictionary);
            const dict_before = dict_scratch;
            const decoder_before = S.copyBytes(C, &holder.decoder);
            try testing.expectError(error.InvalidBlockPlan, reset(C, mode, true, &holder.decoder, &chunks, &dict_scratch, &output, dict_scratch[0..S.dictionary.len]));
            try testing.expectEqualSlices(u8, &dict_before, &dict_scratch);
            try testing.expectEqualSlices(u8, &decoder_before, std.mem.asBytes(&holder.decoder));
            // Arbitrary dictionary bytes may be a real object's representation.
            // Encode their correct DICTID so admission, not malformed data, rejects.
            const self_dictionary = std.mem.asBytes(&holder.decoder);
            const self_dictionary_wire = try D.encodeZlibStoredWithDictionaryAlloc(testing.allocator, S.plain, self_dictionary);
            defer testing.allocator.free(self_dictionary_wire);
            const self_dictionary_chunks = S.split(self_dictionary_wire);
            const self_dictionary_output_before = output;
            try testing.expectError(error.InvalidBlockPlan, reset(C, mode, true, &holder.decoder, &self_dictionary_chunks, &independent, &output, self_dictionary));
            try testing.expectEqualSlices(u8, &decoder_before, std.mem.asBytes(&holder.decoder));
            try testing.expectEqualSlices(u8, &self_dictionary_output_before, &output);
        }
    }
}

fn pngBindings(comptime D: type) !void {
    const payload = "\x00abc\x02def";
    const wire = try D.encodeZlibStoredAlloc(testing.allocator, payload);
    defer testing.allocator.free(wire);
    const chunks = S.split(wire);
    var zlib_output: [80]u8 = @splat(0xa5);
    var filtered: [80]u8 = @splat(0xa5);
    var previous: [80]u8 = @splat(0xa5);
    var independent: [80]u8 = undefined;
    const C = D.PngZlibScanlineDecoder;
    var decoder = try C.initFromChunks(&chunks, &independent, &zlib_output, &filtered, &previous, 3, 2, 1);
    inline for (.{ "filtered", "previous", "output" }) |binding| {
        const scratch = if (comptime std.mem.eql(u8, binding, "filtered")) &filtered else if (comptime std.mem.eql(u8, binding, "previous")) &previous else &zlib_output;
        const decoder_before = S.copyBytes(C, &decoder);
        const filtered_before = filtered;
        const previous_before = previous;
        const output_before = zlib_output;
        try testing.expectError(error.InvalidBlockPlan, decoder.resetFromChunks(&chunks, scratch, &zlib_output, &filtered, &previous, 3, 2, 1));
        try testing.expectEqualSlices(u8, &decoder_before, std.mem.asBytes(&decoder));
        try testing.expectEqualSlices(u8, &filtered_before, &filtered);
        try testing.expectEqualSlices(u8, &previous_before, &previous);
        try testing.expectEqualSlices(u8, &output_before, &zlib_output);
        try decoder.resetFromChunks(&chunks, &independent, &zlib_output, &filtered, &previous, 3, 2, 1);
        try testing.expectEqualSlices(u8, payload, decoder.zlib.decoded);
    }
    const before_self = S.copyBytes(C, &decoder);
    try testing.expectError(error.InvalidBlockPlan, decoder.resetFromChunks(&chunks, std.mem.asBytes(&decoder), &zlib_output, &filtered, &previous, 3, 2, 1));
    try testing.expectEqualSlices(u8, &before_self, std.mem.asBytes(&decoder));
    const single = [_][]const u8{wire};
    try decoder.resetFromChunks(&single, std.mem.asBytes(&decoder), &zlib_output, &filtered, &previous, 3, 2, 1);
    try testing.expectEqualSlices(u8, payload, decoder.zlib.decoded);
}
