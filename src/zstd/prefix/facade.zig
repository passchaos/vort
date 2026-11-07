//! RAW stateless prefix conveniences; advanced FULL retains WithDictionary.
const std = @import("std");
pub fn Facade(comptime Z: type) type {
    return struct {
        fn d(options: Z.FrameDecodeOptions, bytes: []const u8) Z.FrameDecodeOptions {
            var selected = options;
            selected.dictionary = Z.NativeDictionary.initRawContent(bytes);
            selected.dictionary_set = null;
            selected.dictionary_usage = .prefix;
            return selected;
        }
        fn c(options: anytype) @TypeOf(options) {
            var selected = options;
            selected.dictionary_usage = .prefix;
            return selected;
        }
        pub fn decodeAlloc(a: std.mem.Allocator, frame: []const u8, options: Z.FrameDecodeOptions, bytes: []const u8) Z.Error![]u8 {
            return Z.decodeFrameAllocWithOptions(a, frame, d(options, bytes));
        }
        pub fn decodeInto(a: std.mem.Allocator, frame: []const u8, out: []u8, options: Z.FrameDecodeOptions, bytes: []const u8) Z.Error!usize {
            return Z.decodeFrameIntoWithOptions(a, frame, out, d(options, bytes));
        }
        pub fn decodeAppend(a: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, options: Z.FrameDecodeOptions, bytes: []const u8) Z.Error!usize {
            return Z.decodeFrameAppendWithOptions(a, out, frame, d(options, bytes));
        }
        pub fn decodedSize(frame: []const u8, options: Z.FrameDecodeOptions, bytes: []const u8) Z.Error!@import("../../core.zig").StreamCount {
            return Z.decodedFrameSizeWithOptions(frame, d(options, bytes));
        }
        pub fn nativeAlloc(a: std.mem.Allocator, input: []const u8, options: Z.NativeFrameOptions, bytes: []const u8) Z.Error!Z.NativeFrameEncodeResult {
            return Z.encodeNativeFrameWithDictionaryAlloc(a, input, c(options), Z.NativeDictionary.initRawContent(bytes));
        }
        pub fn nativeAppend(a: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, options: Z.NativeFrameOptions, bytes: []const u8) Z.Error!void {
            _ = try Z.encodeNativeFrameAppendWithDictionary(a, out, input, c(options), Z.NativeDictionary.initRawContent(bytes));
        }
        pub fn nativeInto(a: std.mem.Allocator, input: []const u8, options: Z.NativeFrameOptions, bytes: []const u8, out: []u8) Z.Error!Z.NativeFrameEncodeIntoResult {
            return Z.encodeNativeFrameIntoSliceWithDictionary(a, input, c(options), Z.NativeDictionary.initRawContent(bytes), out);
        }
        pub fn nativeBound(len: usize, options: Z.NativeFrameOptions, bytes: []const u8) Z.Error!usize {
            return Z.encodedNativeFrameBoundWithDictionary(len, c(options), Z.NativeDictionary.initRawContent(bytes));
        }
        pub fn alloc(a: std.mem.Allocator, input: []const u8, bytes: []const u8) Z.Error![]u8 {
            return levelAlloc(a, input, Z.default_compression_level, .{}, bytes);
        }
        pub fn optionsAlloc(a: std.mem.Allocator, input: []const u8, options: Z.FrameOptions, bytes: []const u8) Z.Error![]u8 {
            return levelAlloc(a, input, Z.default_compression_level, options, bytes);
        }
        pub fn levelAlloc(a: std.mem.Allocator, input: []const u8, level: c_int, options: Z.FrameOptions, bytes: []const u8) Z.Error![]u8 {
            return Z.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(a, input, level, c(options), Z.NativeDictionary.initRawContent(bytes));
        }
        pub fn levelBound(len: usize, level: c_int, options: Z.FrameOptions, bytes: []const u8) Z.Error!usize {
            return Z.encodedFrameBoundWithLevelAndOptionsAndDictionary(len, level, c(options), Z.NativeDictionary.initRawContent(bytes));
        }
        pub fn levelAppend(a: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, level: c_int, options: Z.FrameOptions, bytes: []const u8) Z.Error!usize {
            return Z.encodeFrameAppendWithLevelAndOptionsAndDictionary(a, out, input, level, c(options), Z.NativeDictionary.initRawContent(bytes));
        }
        pub fn levelInto(a: std.mem.Allocator, input: []const u8, level: c_int, options: Z.FrameOptions, bytes: []const u8, out: []u8) Z.Error!usize {
            return Z.encodeFrameIntoSliceWithLevelAndOptionsAndDictionary(a, input, level, c(options), Z.NativeDictionary.initRawContent(bytes), out);
        }
    };
}
