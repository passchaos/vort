//! One-shot candidate production, separated from complete-result arbitration.
const std = @import("std");

pub fn Codec(comptime C: type) type {
    return struct {
        const Format = enum { raw, zlib, gzip };

        pub fn raw(allocator: std.mem.Allocator, input: []const u8, options: C.Options) ![]u8 {
            return encode(.raw, false, allocator, input, "", options, .{});
        }
        pub fn rawDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: C.Options) ![]u8 {
            return encode(.raw, true, allocator, input, dictionary, options, .{});
        }
        pub fn zlib(allocator: std.mem.Allocator, input: []const u8, options: C.Options) ![]u8 {
            return encode(.zlib, false, allocator, input, "", options, .{});
        }
        pub fn zlibDictionary(allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: C.Options) ![]u8 {
            return encode(.zlib, true, allocator, input, dictionary, options, .{});
        }
        pub fn gzip(allocator: std.mem.Allocator, input: []const u8, header: C.GzipHeader, options: C.Options) ![]u8 {
            return encode(.gzip, false, allocator, input, "", options, header);
        }

        fn encode(comptime format: Format, comptime dictionary_present: bool, allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, options: C.Options, header: C.GzipHeader) ![]u8 {
            if (C.storedFast(input, options)) return switch (format) {
                .raw => C.rawStored(allocator, input),
                .zlib => if (dictionary_present) C.zlibDictionaryStored(allocator, input, dictionary) else C.zlibStored(allocator, input),
                .gzip => C.gzipStored(allocator, input, header),
            };
            if (!dictionary_present and options.block_selection == .stored_fixed_dynamic and C.dynamicStats(input, options)) return switch (format) {
                .raw => C.rawStats(allocator, input, options),
                .zlib => C.zlibStats(allocator, input, options),
                .gzip => C.gzipStats(allocator, input, options, header),
            };
            const plan = if (dictionary_present)
                try C.dictionaryPlan(allocator, input, dictionary, options)
            else
                try C.plan(allocator, input, options);
            defer plan.deinit(allocator);
            return switch (format) {
                .raw => blk: {
                    var writer: C.BitWriter = .{};
                    errdefer writer.deinit(allocator);
                    try C.rawTokens(allocator, &writer, input, plan.tokens, true, options);
                    break :blk try writer.toOwnedSlice(allocator);
                },
                .zlib => C.zlibTokens(allocator, input, if (dictionary_present) dictionary else null, plan.tokens, options),
                .gzip => C.gzipTokens(allocator, input, plan.tokens, options, header),
            };
        }
    };
}
