//! Select existing public codec operations. The framing adapter owns no parser.
const std = @import("std");

pub const Body = struct { allocation: []u8, bytes: []const u8 };

fn literalOptions(options: anytype) @TypeOf(options) {
    var value = options;
    value.strategy = .huffman_only;
    return value;
}

pub fn legacyAlloc(comptime C: type, allocator: std.mem.Allocator, input: []const u8, options: anytype) ![]u8 {
    const dictionary = options.dictionary;
    const compression = options.compression;
    return switch (options.mode) {
        .stored => if (options.block_len) |length|
            if (dictionary) |dict| C.encodeZlibStoredSplitWithDictionaryAlloc(allocator, input, dict, length) else C.encodeZlibStoredSplitAlloc(allocator, input, length)
        else if (dictionary) |dict| C.encodeZlibStoredWithDictionaryAlloc(allocator, input, dict) else C.encodeZlibStoredAlloc(allocator, input),
        .fixed => if (options.block_len) |length|
            if (dictionary) |dict| C.encodeZlibFixedSplitWithDictionaryAlloc(allocator, input, dict, length, compression) else C.encodeZlibFixedSplitAlloc(allocator, input, length, compression)
        else if (dictionary) |dict| C.encodeZlibFixedWithDictionaryAlloc(allocator, input, dict, compression) else C.encodeZlibFixedWithOptionsAlloc(allocator, input, compression),
        .dynamic, .dynamic_literal => dynamic: {
            const settings = if (options.mode == .dynamic_literal) literalOptions(compression) else compression;
            break :dynamic if (options.block_len) |length|
                if (dictionary) |dict| C.encodeZlibDynamicSplitWithDictionaryAlloc(allocator, input, dict, length, settings) else C.encodeZlibDynamicSplitAlloc(allocator, input, length, settings)
            else if (dictionary) |dict|
                C.encodeZlibDynamicWithDictionaryAlloc(allocator, input, dict, settings)
            else if (options.mode == .dynamic_literal)
                C.encodeZlibDynamicLiteralAlloc(allocator, input)
            else
                C.encodeZlibDynamicWithOptionsAlloc(allocator, input, settings);
        },
        .best => if (options.block_len) |length|
            if (dictionary) |dict| C.encodeZlibBestSplitWithDictionaryAlloc(allocator, input, dict, length, compression) else C.encodeZlibBestSplitAlloc(allocator, input, length, compression)
        else if (dictionary) |dict| C.encodeZlibBestWithDictionaryAlloc(allocator, input, dict, compression) else C.encodeZlibBestAlloc(allocator, input, compression),
        .adaptive => if (dictionary) |dict|
            C.encodeZlibBestAdaptiveSplitWithDictionaryAlloc(allocator, input, dict, compression, options.split_options)
        else
            C.encodeZlibBestAdaptiveSplitAlloc(allocator, input, compression, options.split_options),
        .png_ultrafast => C.encodeZlibPngUltraFastAlloc(allocator, input),
    };
}

pub fn rawAlloc(comptime C: type, allocator: std.mem.Allocator, input: []const u8, options: anytype) !Body {
    const dictionary = options.dictionary;
    const compression = options.compression;
    const allocation = try switch (options.mode) {
        .stored => if (options.block_len) |length| C.encodeRawStoredSplitAlloc(allocator, input, length) else C.encodeRawStoredAlloc(allocator, input),
        .fixed => if (options.block_len) |length|
            if (dictionary) |dict| C.encodeRawFixedSplitWithDictionaryAlloc(allocator, input, dict, length, compression) else C.encodeRawFixedSplitAlloc(allocator, input, length, compression)
        else if (dictionary) |dict| C.encodeRawFixedWithDictionaryAlloc(allocator, input, dict, compression) else C.encodeRawFixedWithOptionsAlloc(allocator, input, compression),
        .dynamic, .dynamic_literal => dynamic: {
            const settings = if (options.mode == .dynamic_literal) literalOptions(compression) else compression;
            break :dynamic if (options.block_len) |length|
                if (dictionary) |dict| C.encodeRawDynamicSplitWithDictionaryAlloc(allocator, input, dict, length, settings) else C.encodeRawDynamicSplitAlloc(allocator, input, length, settings)
            else if (dictionary) |dict|
                C.encodeRawDynamicWithDictionaryAlloc(allocator, input, dict, settings)
            else if (options.mode == .dynamic_literal)
                C.encodeRawDynamicLiteralAlloc(allocator, input)
            else
                C.encodeRawDynamicWithOptionsAlloc(allocator, input, settings);
        },
        .best => if (options.block_len) |length|
            if (dictionary) |dict| C.encodeRawBestSplitWithDictionaryAlloc(allocator, input, dict, length, compression) else C.encodeRawBestSplitAlloc(allocator, input, length, compression)
        else if (dictionary) |dict| C.encodeRawBestWithDictionaryAlloc(allocator, input, dict, compression) else C.encodeRawBestAlloc(allocator, input, compression),
        .adaptive => if (dictionary) |dict|
            C.encodeRawBestAdaptiveSplitWithDictionaryAlloc(allocator, input, dict, compression, options.split_options)
        else
            C.encodeRawBestAdaptiveSplitAlloc(allocator, input, compression, options.split_options),
        .png_ultrafast => C.encodeZlibPngUltraFastAlloc(allocator, input),
    };
    // The frozen PNG codec already emits a complete zlib frame. Its raw body
    // uses only distance one; expose that body without copying or modifying it.
    return .{
        .allocation = allocation,
        .bytes = if (options.mode == .png_ultrafast) allocation[2 .. allocation.len - 4] else allocation,
    };
}
