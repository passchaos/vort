//! Reusable caller-owned encoding facade over the public codec operations.
const std = @import("std");
const encode_total_budget = @import("total_budget.zig");

pub fn Encoder(comptime C: type) type {
    const CompressionOptions = C.CompressionOptions;
    const AdaptiveSplitOptions = C.AdaptiveSplitOptions;
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        scratch: std.ArrayList(u8) = .empty,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn deinit(self: *Self) void {
            self.scratch.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn encodeStoredAlloc(self: *Self, input: []const u8) ![]u8 {
            return try C.encodeZlibStoredAlloc(self.allocator, input);
        }

        pub fn encodeStoredWithDictionaryAlloc(self: *Self, input: []const u8, dictionary: []const u8) ![]u8 {
            return try C.encodeZlibStoredWithDictionaryAlloc(self.allocator, input, dictionary);
        }

        pub fn encodeStoredChunksAlloc(self: *Self, chunks: []const []const u8) ![]u8 {
            return try C.encodeZlibStoredChunksAlloc(self.allocator, chunks);
        }

        pub fn encodeStoredChunksWithDictionaryAlloc(self: *Self, chunks: []const []const u8, dictionary: []const u8) ![]u8 {
            return try C.encodeZlibStoredWithDictionaryChunksAlloc(self.allocator, chunks, dictionary);
        }

        pub fn encodeFixedAlloc(self: *Self, input: []const u8) ![]u8 {
            return try self.encodeFixedWithOptionsAlloc(input, .{});
        }

        pub fn encodeFixedWithOptionsAlloc(self: *Self, input: []const u8, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithOptionsAlloc, .{ self, input, options }, .alloc);
            return try C.encodeZlibFixedWithOptionsAlloc(self.allocator, input, options);
        }

        pub fn encodeFixedWithDictionaryAlloc(self: *Self, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithDictionaryAlloc, .{ self, input, dictionary, options }, .alloc);
            return try C.encodeZlibFixedWithDictionaryAlloc(self.allocator, input, dictionary, options);
        }

        pub fn encodeFixedSplitAlloc(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitAlloc, .{ self, input, block_len, options }, .alloc);
            return try C.encodeZlibFixedSplitAlloc(self.allocator, input, block_len, options);
        }

        pub fn encodeFixedSplitWithDictionaryAlloc(self: *Self, input: []const u8, dictionary: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitWithDictionaryAlloc, .{ self, input, dictionary, block_len, options }, .alloc);
            return try C.encodeZlibFixedSplitWithDictionaryAlloc(self.allocator, input, dictionary, block_len, options);
        }

        pub fn encodeBestAlloc(self: *Self, input: []const u8, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAlloc, .{ self, input, options }, .alloc);
            return try C.encodeZlibBestAlloc(self.allocator, input, options);
        }

        pub fn encodeBestWithDictionaryAlloc(self: *Self, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestWithDictionaryAlloc, .{ self, input, dictionary, options }, .alloc);
            return try C.encodeZlibBestWithDictionaryAlloc(self.allocator, input, dictionary, options);
        }

        pub fn encodeBestSplitAlloc(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitAlloc, .{ self, input, block_len, options }, .alloc);
            return try C.encodeZlibBestSplitAlloc(self.allocator, input, block_len, options);
        }

        pub fn encodeBestSplitWithDictionaryAlloc(self: *Self, input: []const u8, dictionary: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitWithDictionaryAlloc, .{ self, input, dictionary, block_len, options }, .alloc);
            return try C.encodeZlibBestSplitWithDictionaryAlloc(self.allocator, input, dictionary, block_len, options);
        }

        pub fn encodeBestAdaptiveSplitAlloc(self: *Self, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitAlloc, .{ self, input, options, split_options }, .alloc);
            return try C.encodeZlibBestAdaptiveSplitAlloc(self.allocator, input, options, split_options);
        }

        pub fn encodeBestAdaptiveSplitWithDictionaryAlloc(self: *Self, input: []const u8, dictionary: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitWithDictionaryAlloc, .{ self, input, dictionary, options, split_options }, .alloc);
            return try C.encodeZlibBestAdaptiveSplitWithDictionaryAlloc(self.allocator, input, dictionary, options, split_options);
        }

        pub fn encodeLevelAlloc(self: *Self, input: []const u8, level: u4) ![]u8 {
            return try C.encodeZlibLevelAlloc(self.allocator, input, level);
        }

        pub fn encodeLevelWithDictionaryAlloc(self: *Self, input: []const u8, dictionary: []const u8, level: u4) ![]u8 {
            return try C.encodeZlibLevelWithDictionaryAlloc(self.allocator, input, dictionary, level);
        }

        pub fn encodeDynamicLiteralAlloc(self: *Self, input: []const u8) ![]u8 {
            return try C.encodeZlibDynamicLiteralAlloc(self.allocator, input);
        }

        pub fn encodeDynamicWithOptionsAlloc(self: *Self, input: []const u8, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithOptionsAlloc, .{ self, input, options }, .alloc);
            return try C.encodeZlibDynamicWithOptionsAlloc(self.allocator, input, options);
        }

        pub fn encodeDynamicWithDictionaryAlloc(self: *Self, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithDictionaryAlloc, .{ self, input, dictionary, options }, .alloc);
            return try C.encodeZlibDynamicWithDictionaryAlloc(self.allocator, input, dictionary, options);
        }

        pub fn encodeDynamicSplitAlloc(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitAlloc, .{ self, input, block_len, options }, .alloc);
            return try C.encodeZlibDynamicSplitAlloc(self.allocator, input, block_len, options);
        }

        pub fn encodeDynamicSplitWithDictionaryAlloc(self: *Self, input: []const u8, dictionary: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitWithDictionaryAlloc, .{ self, input, dictionary, block_len, options }, .alloc);
            return try C.encodeZlibDynamicSplitWithDictionaryAlloc(self.allocator, input, dictionary, block_len, options);
        }

        pub fn encodeStoredScratch(self: *Self, input: []const u8) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeStoredAppend(&self.scratch, input);
            return self.scratch.items;
        }

        pub fn encodeStoredWithDictionaryScratch(self: *Self, input: []const u8, dictionary: []const u8) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeStoredWithDictionaryAppend(&self.scratch, input, dictionary);
            return self.scratch.items;
        }

        pub fn encodeStoredChunksScratch(self: *Self, chunks: []const []const u8) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeStoredChunksAppend(&self.scratch, chunks);
            return self.scratch.items;
        }

        pub fn encodeStoredChunksWithDictionaryScratch(self: *Self, chunks: []const []const u8, dictionary: []const u8) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeStoredChunksWithDictionaryAppend(&self.scratch, chunks, dictionary);
            return self.scratch.items;
        }

        pub fn encodeFixedScratch(self: *Self, input: []const u8) ![]const u8 {
            return try self.encodeFixedWithOptionsScratch(input, .{});
        }

        pub fn encodeFixedWithOptionsScratch(self: *Self, input: []const u8, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithOptionsScratch, .{ self, input, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeFixedWithOptionsAppend(&self.scratch, input, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeFixedWithOptionsAlloc(input, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeFixedWithDictionaryScratch(self: *Self, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithDictionaryScratch, .{ self, input, dictionary, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeFixedWithDictionaryAppend(&self.scratch, input, dictionary, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeFixedWithDictionaryAlloc(input, dictionary, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeFixedSplitScratch(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitScratch, .{ self, input, block_len, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeFixedSplitAppend(&self.scratch, input, block_len, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeFixedSplitAlloc(input, block_len, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeFixedSplitWithDictionaryScratch(self: *Self, input: []const u8, dictionary: []const u8, block_len: usize, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitWithDictionaryScratch, .{ self, input, dictionary, block_len, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeFixedSplitWithDictionaryAppend(&self.scratch, input, dictionary, block_len, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeFixedSplitWithDictionaryAlloc(input, dictionary, block_len, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeBestScratch(self: *Self, input: []const u8, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestScratch, .{ self, input, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeBestAppend(&self.scratch, input, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeBestAlloc(input, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeBestWithDictionaryScratch(self: *Self, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestWithDictionaryScratch, .{ self, input, dictionary, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeBestWithDictionaryAppend(&self.scratch, input, dictionary, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeBestWithDictionaryAlloc(input, dictionary, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeBestSplitScratch(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitScratch, .{ self, input, block_len, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeBestSplitAppend(&self.scratch, input, block_len, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeBestSplitAlloc(input, block_len, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeBestSplitWithDictionaryScratch(self: *Self, input: []const u8, dictionary: []const u8, block_len: usize, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitWithDictionaryScratch, .{ self, input, dictionary, block_len, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeBestSplitWithDictionaryAppend(&self.scratch, input, dictionary, block_len, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeBestSplitWithDictionaryAlloc(input, dictionary, block_len, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeBestAdaptiveSplitScratch(self: *Self, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitScratch, .{ self, input, options, split_options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeBestAdaptiveSplitAppend(&self.scratch, input, options, split_options);
                return self.scratch.items;
            }
            const bytes = try self.encodeBestAdaptiveSplitAlloc(input, options, split_options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeBestAdaptiveSplitWithDictionaryScratch(self: *Self, input: []const u8, dictionary: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitWithDictionaryScratch, .{ self, input, dictionary, options, split_options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeBestAdaptiveSplitWithDictionaryAppend(&self.scratch, input, dictionary, options, split_options);
                return self.scratch.items;
            }
            const bytes = try self.encodeBestAdaptiveSplitWithDictionaryAlloc(input, dictionary, options, split_options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeLevelScratch(self: *Self, input: []const u8, level: u4) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeLevelAppend(&self.scratch, input, level);
            return self.scratch.items;
        }

        pub fn encodeLevelWithDictionaryScratch(self: *Self, input: []const u8, dictionary: []const u8, level: u4) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeLevelWithDictionaryAppend(&self.scratch, input, dictionary, level);
            return self.scratch.items;
        }

        pub fn encodeDynamicLiteralScratch(self: *Self, input: []const u8) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeDynamicLiteralAppend(&self.scratch, input);
            return self.scratch.items;
        }

        pub fn encodeDynamicWithOptionsScratch(self: *Self, input: []const u8, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithOptionsScratch, .{ self, input, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeDynamicWithOptionsAppend(&self.scratch, input, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeDynamicWithOptionsAlloc(input, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeDynamicWithDictionaryScratch(self: *Self, input: []const u8, dictionary: []const u8, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithDictionaryScratch, .{ self, input, dictionary, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeDynamicWithDictionaryAppend(&self.scratch, input, dictionary, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeDynamicWithDictionaryAlloc(input, dictionary, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeDynamicSplitScratch(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitScratch, .{ self, input, block_len, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeDynamicSplitAppend(&self.scratch, input, block_len, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeDynamicSplitAlloc(input, block_len, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeDynamicSplitWithDictionaryScratch(self: *Self, input: []const u8, dictionary: []const u8, block_len: usize, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitWithDictionaryScratch, .{ self, input, dictionary, block_len, options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeDynamicSplitWithDictionaryAppend(&self.scratch, input, dictionary, block_len, options);
                return self.scratch.items;
            }
            const bytes = try self.encodeDynamicSplitWithDictionaryAlloc(input, dictionary, block_len, options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeStoredAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8) !usize {
            return try C.encodeZlibStoredAppend(self.allocator, out, input);
        }

        pub fn encodeStoredWithDictionaryAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, dictionary: []const u8) !usize {
            return try C.encodeZlibStoredWithDictionaryAppend(self.allocator, out, input, dictionary);
        }

        pub fn encodeStoredChunksAppend(self: *Self, out: *std.ArrayList(u8), chunks: []const []const u8) !usize {
            return try C.encodeZlibStoredChunksAppend(self.allocator, out, chunks);
        }

        pub fn encodeStoredChunksWithDictionaryAppend(self: *Self, out: *std.ArrayList(u8), chunks: []const []const u8, dictionary: []const u8) !usize {
            return try C.encodeZlibStoredWithDictionaryChunksAppend(self.allocator, out, chunks, dictionary);
        }

        pub fn encodeFixedAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8) !usize {
            return try self.encodeFixedWithOptionsAppend(out, input, .{});
        }

        pub fn encodeFixedWithOptionsAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithOptionsAppend, .{ self, out, input, options }, .append);
            const encoded = try self.encodeFixedWithOptionsAlloc(input, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeFixedWithDictionaryAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, dictionary: []const u8, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithDictionaryAppend, .{ self, out, input, dictionary, options }, .append);
            const encoded = try self.encodeFixedWithDictionaryAlloc(input, dictionary, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeFixedSplitAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, block_len: usize, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitAppend, .{ self, out, input, block_len, options }, .append);
            const encoded = try self.encodeFixedSplitAlloc(input, block_len, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeFixedSplitWithDictionaryAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, dictionary: []const u8, block_len: usize, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitWithDictionaryAppend, .{ self, out, input, dictionary, block_len, options }, .append);
            const encoded = try self.encodeFixedSplitWithDictionaryAlloc(input, dictionary, block_len, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeBestAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAppend, .{ self, out, input, options }, .append);
            const encoded = try self.encodeBestAlloc(input, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeBestWithDictionaryAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, dictionary: []const u8, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestWithDictionaryAppend, .{ self, out, input, dictionary, options }, .append);
            const encoded = try self.encodeBestWithDictionaryAlloc(input, dictionary, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeBestSplitAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, block_len: usize, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitAppend, .{ self, out, input, block_len, options }, .append);
            const encoded = try self.encodeBestSplitAlloc(input, block_len, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeBestSplitWithDictionaryAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, dictionary: []const u8, block_len: usize, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitWithDictionaryAppend, .{ self, out, input, dictionary, block_len, options }, .append);
            const encoded = try self.encodeBestSplitWithDictionaryAlloc(input, dictionary, block_len, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeBestAdaptiveSplitAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) !usize {
            if (encode_total_budget.requested(options) and (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitAppend, .{ self, out, input, options, split_options }, .append);
            const encoded = try self.encodeBestAdaptiveSplitAlloc(input, options, split_options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeBestAdaptiveSplitWithDictionaryAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, dictionary: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) !usize {
            if (encode_total_budget.requested(options) and (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitWithDictionaryAppend, .{ self, out, input, dictionary, options, split_options }, .append);
            const encoded = try self.encodeBestAdaptiveSplitWithDictionaryAlloc(input, dictionary, options, split_options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeLevelAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, level: u4) !usize {
            const encoded = try self.encodeLevelAlloc(input, level);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeLevelWithDictionaryAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, dictionary: []const u8, level: u4) !usize {
            const encoded = try self.encodeLevelWithDictionaryAlloc(input, dictionary, level);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeDynamicLiteralAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8) !usize {
            const encoded = try self.encodeDynamicLiteralAlloc(input);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeDynamicWithOptionsAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithOptionsAppend, .{ self, out, input, options }, .append);
            const encoded = try self.encodeDynamicWithOptionsAlloc(input, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeDynamicWithDictionaryAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, dictionary: []const u8, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithDictionaryAppend, .{ self, out, input, dictionary, options }, .append);
            const encoded = try self.encodeDynamicWithDictionaryAlloc(input, dictionary, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeDynamicSplitAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, block_len: usize, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitAppend, .{ self, out, input, block_len, options }, .append);
            const encoded = try self.encodeDynamicSplitAlloc(input, block_len, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeDynamicSplitWithDictionaryAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, dictionary: []const u8, block_len: usize, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitWithDictionaryAppend, .{ self, out, input, dictionary, block_len, options }, .append);
            const encoded = try self.encodeDynamicSplitWithDictionaryAlloc(input, dictionary, block_len, options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeStoredIntoSlice(self: *Self, input: []const u8, output: []u8) !usize {
            _ = self;
            return try C.encodeZlibStored(input, output);
        }

        pub fn encodeStoredWithDictionaryIntoSlice(self: *Self, input: []const u8, dictionary: []const u8, output: []u8) !usize {
            _ = self;
            return try C.encodeZlibStoredWithDictionary(input, output, dictionary);
        }

        pub fn encodeStoredChunksIntoSlice(self: *Self, chunks: []const []const u8, output: []u8) !usize {
            _ = self;
            return try C.encodeZlibStoredChunks(chunks, output);
        }

        pub fn encodeStoredChunksWithDictionaryIntoSlice(self: *Self, chunks: []const []const u8, dictionary: []const u8, output: []u8) !usize {
            _ = self;
            return try C.encodeZlibStoredWithDictionaryChunks(chunks, output, dictionary);
        }
    };
}
