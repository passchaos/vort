//! Reusable caller-owned encoding facade over the public codec operations.
const std = @import("std");
const encode_total_budget = @import("total_budget.zig");

pub fn Encoder(comptime C: type) type {
    const CompressionOptions = C.CompressionOptions;
    const AdaptiveSplitOptions = C.AdaptiveSplitOptions;
    const GzipHeaderOptions = C.GzipHeaderOptions;
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
            return try C.encodeGzipStoredAlloc(self.allocator, input);
        }

        pub fn encodeStoredWithHeaderAlloc(self: *Self, input: []const u8, header_options: GzipHeaderOptions) ![]u8 {
            return try C.encodeGzipStoredWithHeaderAlloc(self.allocator, input, header_options);
        }

        pub fn encodeStoredChunksAlloc(self: *Self, chunks: []const []const u8) ![]u8 {
            return try C.encodeGzipStoredChunksAlloc(self.allocator, chunks);
        }

        pub fn encodeStoredChunksWithHeaderAlloc(self: *Self, chunks: []const []const u8, header_options: GzipHeaderOptions) ![]u8 {
            return try C.encodeGzipStoredChunksWithHeaderAlloc(self.allocator, chunks, header_options);
        }

        pub fn encodeFixedAlloc(self: *Self, input: []const u8) ![]u8 {
            return try self.encodeFixedWithOptionsAlloc(input, .{});
        }

        pub fn encodeFixedWithOptionsAlloc(self: *Self, input: []const u8, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithOptionsAlloc, .{ self, input, options }, .alloc);
            return try self.encodeFixedWithHeaderAlloc(input, options, .{});
        }

        pub fn encodeFixedWithHeaderAlloc(self: *Self, input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithHeaderAlloc, .{ self, input, options, header_options }, .alloc);
            return try C.encodeGzipFixedWithHeaderAlloc(self.allocator, input, options, header_options);
        }

        pub fn encodeFixedSplitAlloc(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitAlloc, .{ self, input, block_len, options }, .alloc);
            return try self.encodeFixedSplitWithHeaderAlloc(input, block_len, options, .{});
        }

        pub fn encodeFixedSplitWithHeaderAlloc(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitWithHeaderAlloc, .{ self, input, block_len, options, header_options }, .alloc);
            return try C.encodeGzipFixedSplitWithHeaderAlloc(self.allocator, input, block_len, options, header_options);
        }

        pub fn encodeBestAlloc(self: *Self, input: []const u8, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAlloc, .{ self, input, options }, .alloc);
            return try self.encodeBestWithHeaderAlloc(input, options, .{});
        }

        pub fn encodeBestWithHeaderAlloc(self: *Self, input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestWithHeaderAlloc, .{ self, input, options, header_options }, .alloc);
            return try C.encodeGzipBestWithHeaderAlloc(self.allocator, input, options, header_options);
        }

        pub fn encodeBestSplitAlloc(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitAlloc, .{ self, input, block_len, options }, .alloc);
            return try self.encodeBestSplitWithHeaderAlloc(input, block_len, options, .{});
        }

        pub fn encodeBestSplitWithHeaderAlloc(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitWithHeaderAlloc, .{ self, input, block_len, options, header_options }, .alloc);
            return try C.encodeGzipBestSplitWithHeaderAlloc(self.allocator, input, block_len, options, header_options);
        }

        pub fn encodeBestAdaptiveSplitAlloc(self: *Self, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitAlloc, .{ self, input, options, split_options }, .alloc);
            return try self.encodeBestAdaptiveSplitWithHeaderAlloc(input, options, split_options, .{});
        }

        pub fn encodeBestAdaptiveSplitWithHeaderAlloc(self: *Self, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions, header_options: GzipHeaderOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitWithHeaderAlloc, .{ self, input, options, split_options, header_options }, .alloc);
            return try C.encodeGzipBestAdaptiveSplitWithHeaderAlloc(self.allocator, input, options, split_options, header_options);
        }

        pub fn encodeLevelAlloc(self: *Self, input: []const u8, level: u4) ![]u8 {
            return try self.encodeLevelWithHeaderAlloc(input, level, .{});
        }

        pub fn encodeLevelWithHeaderAlloc(self: *Self, input: []const u8, level: u4, header_options: GzipHeaderOptions) ![]u8 {
            return try C.encodeGzipLevelWithHeaderAlloc(self.allocator, input, level, header_options);
        }

        pub fn encodeDynamicLiteralAlloc(self: *Self, input: []const u8) ![]u8 {
            return try self.encodeDynamicLiteralWithHeaderAlloc(input, .{});
        }

        pub fn encodeDynamicLiteralWithHeaderAlloc(self: *Self, input: []const u8, header_options: GzipHeaderOptions) ![]u8 {
            return try C.encodeGzipDynamicLiteralWithHeaderAlloc(self.allocator, input, header_options);
        }

        pub fn encodeDynamicWithOptionsAlloc(self: *Self, input: []const u8, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithOptionsAlloc, .{ self, input, options }, .alloc);
            return try self.encodeDynamicWithHeaderAlloc(input, options, .{});
        }

        pub fn encodeDynamicWithHeaderAlloc(self: *Self, input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithHeaderAlloc, .{ self, input, options, header_options }, .alloc);
            return try C.encodeGzipDynamicWithHeaderAlloc(self.allocator, input, options, header_options);
        }

        pub fn encodeDynamicSplitAlloc(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitAlloc, .{ self, input, block_len, options }, .alloc);
            return try self.encodeDynamicSplitWithHeaderAlloc(input, block_len, options, .{});
        }

        pub fn encodeDynamicSplitWithHeaderAlloc(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions, header_options: GzipHeaderOptions) ![]u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitWithHeaderAlloc, .{ self, input, block_len, options, header_options }, .alloc);
            return try C.encodeGzipDynamicSplitWithHeaderAlloc(self.allocator, input, block_len, options, header_options);
        }

        pub fn encodeStoredScratch(self: *Self, input: []const u8) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeStoredAppend(&self.scratch, input);
            return self.scratch.items;
        }

        pub fn encodeStoredWithHeaderScratch(self: *Self, input: []const u8, header_options: GzipHeaderOptions) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeStoredWithHeaderAppend(&self.scratch, input, header_options);
            return self.scratch.items;
        }

        pub fn encodeStoredChunksScratch(self: *Self, chunks: []const []const u8) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeStoredChunksAppend(&self.scratch, chunks);
            return self.scratch.items;
        }

        pub fn encodeStoredChunksWithHeaderScratch(self: *Self, chunks: []const []const u8, header_options: GzipHeaderOptions) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeStoredChunksWithHeaderAppend(&self.scratch, chunks, header_options);
            return self.scratch.items;
        }

        pub fn encodeFixedScratch(self: *Self, input: []const u8) ![]const u8 {
            return try self.encodeFixedWithOptionsScratch(input, .{});
        }

        pub fn encodeFixedWithOptionsScratch(self: *Self, input: []const u8, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithOptionsScratch, .{ self, input, options }, .scratch);
            return try self.encodeFixedWithHeaderScratch(input, options, .{});
        }

        pub fn encodeFixedWithHeaderScratch(self: *Self, input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithHeaderScratch, .{ self, input, options, header_options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeFixedWithHeaderAppend(&self.scratch, input, options, header_options);
                return self.scratch.items;
            }
            const bytes = try self.encodeFixedWithHeaderAlloc(input, options, header_options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeFixedSplitScratch(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitScratch, .{ self, input, block_len, options }, .scratch);
            return try self.encodeFixedSplitWithHeaderScratch(input, block_len, options, .{});
        }

        pub fn encodeFixedSplitWithHeaderScratch(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions, header_options: GzipHeaderOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitWithHeaderScratch, .{ self, input, block_len, options, header_options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeFixedSplitWithHeaderAppend(&self.scratch, input, block_len, options, header_options);
                return self.scratch.items;
            }
            const bytes = try self.encodeFixedSplitWithHeaderAlloc(input, block_len, options, header_options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeBestScratch(self: *Self, input: []const u8, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestScratch, .{ self, input, options }, .scratch);
            return try self.encodeBestWithHeaderScratch(input, options, .{});
        }

        pub fn encodeBestWithHeaderScratch(self: *Self, input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestWithHeaderScratch, .{ self, input, options, header_options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeBestWithHeaderAppend(&self.scratch, input, options, header_options);
                return self.scratch.items;
            }
            const bytes = try self.encodeBestWithHeaderAlloc(input, options, header_options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeBestSplitScratch(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitScratch, .{ self, input, block_len, options }, .scratch);
            return try self.encodeBestSplitWithHeaderScratch(input, block_len, options, .{});
        }

        pub fn encodeBestSplitWithHeaderScratch(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions, header_options: GzipHeaderOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitWithHeaderScratch, .{ self, input, block_len, options, header_options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeBestSplitWithHeaderAppend(&self.scratch, input, block_len, options, header_options);
                return self.scratch.items;
            }
            const bytes = try self.encodeBestSplitWithHeaderAlloc(input, block_len, options, header_options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeBestAdaptiveSplitScratch(self: *Self, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitScratch, .{ self, input, options, split_options }, .scratch);
            return try self.encodeBestAdaptiveSplitWithHeaderScratch(input, options, split_options, .{});
        }

        pub fn encodeBestAdaptiveSplitWithHeaderScratch(self: *Self, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions, header_options: GzipHeaderOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitWithHeaderScratch, .{ self, input, options, split_options, header_options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeBestAdaptiveSplitWithHeaderAppend(&self.scratch, input, options, split_options, header_options);
                return self.scratch.items;
            }
            const bytes = try self.encodeBestAdaptiveSplitWithHeaderAlloc(input, options, split_options, header_options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeLevelScratch(self: *Self, input: []const u8, level: u4) ![]const u8 {
            return try self.encodeLevelWithHeaderScratch(input, level, .{});
        }

        pub fn encodeLevelWithHeaderScratch(self: *Self, input: []const u8, level: u4, header_options: GzipHeaderOptions) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeLevelWithHeaderAppend(&self.scratch, input, level, header_options);
            return self.scratch.items;
        }

        pub fn encodeDynamicLiteralScratch(self: *Self, input: []const u8) ![]const u8 {
            return try self.encodeDynamicLiteralWithHeaderScratch(input, .{});
        }

        pub fn encodeDynamicLiteralWithHeaderScratch(self: *Self, input: []const u8, header_options: GzipHeaderOptions) ![]const u8 {
            self.scratch.clearRetainingCapacity();
            _ = try self.encodeDynamicLiteralWithHeaderAppend(&self.scratch, input, header_options);
            return self.scratch.items;
        }

        pub fn encodeDynamicWithOptionsScratch(self: *Self, input: []const u8, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithOptionsScratch, .{ self, input, options }, .scratch);
            return try self.encodeDynamicWithHeaderScratch(input, options, .{});
        }

        pub fn encodeDynamicWithHeaderScratch(self: *Self, input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithHeaderScratch, .{ self, input, options, header_options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeDynamicWithHeaderAppend(&self.scratch, input, options, header_options);
                return self.scratch.items;
            }
            const bytes = try self.encodeDynamicWithHeaderAlloc(input, options, header_options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeDynamicSplitScratch(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitScratch, .{ self, input, block_len, options }, .scratch);
            return try self.encodeDynamicSplitWithHeaderScratch(input, block_len, options, .{});
        }

        pub fn encodeDynamicSplitWithHeaderScratch(self: *Self, input: []const u8, block_len: usize, options: CompressionOptions, header_options: GzipHeaderOptions) ![]const u8 {
            if (encode_total_budget.requested(options)) {
                if (block_len == 0) return error.InvalidBlockPlan;
            }
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitWithHeaderScratch, .{ self, input, block_len, options, header_options }, .scratch);
            if (!encode_total_budget.isTracked(self.allocator)) {
                self.scratch.clearRetainingCapacity();
                _ = try self.encodeDynamicSplitWithHeaderAppend(&self.scratch, input, block_len, options, header_options);
                return self.scratch.items;
            }
            const bytes = try self.encodeDynamicSplitWithHeaderAlloc(input, block_len, options, header_options);
            defer self.allocator.free(bytes);
            return encode_total_budget.retainScratch(self, bytes);
        }

        pub fn encodeStoredAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8) !usize {
            return try C.encodeGzipStoredAppend(self.allocator, out, input);
        }

        pub fn encodeStoredWithHeaderAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, header_options: GzipHeaderOptions) !usize {
            return try C.encodeGzipStoredWithHeaderAppend(self.allocator, out, input, header_options);
        }

        pub fn encodeStoredChunksAppend(self: *Self, out: *std.ArrayList(u8), chunks: []const []const u8) !usize {
            return try C.encodeGzipStoredChunksAppend(self.allocator, out, chunks);
        }

        pub fn encodeStoredChunksWithHeaderAppend(self: *Self, out: *std.ArrayList(u8), chunks: []const []const u8, header_options: GzipHeaderOptions) !usize {
            return try C.encodeGzipStoredChunksWithHeaderAppend(self.allocator, out, chunks, header_options);
        }

        pub fn encodeFixedAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8) !usize {
            return try self.encodeFixedWithOptionsAppend(out, input, .{});
        }

        pub fn encodeFixedWithOptionsAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithOptionsAppend, .{ self, out, input, options }, .append);
            return try self.encodeFixedWithHeaderAppend(out, input, options, .{});
        }

        pub fn encodeFixedWithHeaderAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedWithHeaderAppend, .{ self, out, input, options, header_options }, .append);
            const encoded = try self.encodeFixedWithHeaderAlloc(input, options, header_options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeFixedSplitAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, block_len: usize, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitAppend, .{ self, out, input, block_len, options }, .append);
            return try self.encodeFixedSplitWithHeaderAppend(out, input, block_len, options, .{});
        }

        pub fn encodeFixedSplitWithHeaderAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, block_len: usize, options: CompressionOptions, header_options: GzipHeaderOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeFixedSplitWithHeaderAppend, .{ self, out, input, block_len, options, header_options }, .append);
            const encoded = try self.encodeFixedSplitWithHeaderAlloc(input, block_len, options, header_options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeBestAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAppend, .{ self, out, input, options }, .append);
            return try self.encodeBestWithHeaderAppend(out, input, options, .{});
        }

        pub fn encodeBestWithHeaderAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestWithHeaderAppend, .{ self, out, input, options, header_options }, .append);
            const encoded = try self.encodeBestWithHeaderAlloc(input, options, header_options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeBestSplitAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, block_len: usize, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitAppend, .{ self, out, input, block_len, options }, .append);
            return try self.encodeBestSplitWithHeaderAppend(out, input, block_len, options, .{});
        }

        pub fn encodeBestSplitWithHeaderAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, block_len: usize, options: CompressionOptions, header_options: GzipHeaderOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestSplitWithHeaderAppend, .{ self, out, input, block_len, options, header_options }, .append);
            const encoded = try self.encodeBestSplitWithHeaderAlloc(input, block_len, options, header_options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeBestAdaptiveSplitAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) !usize {
            if (encode_total_budget.requested(options) and (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitAppend, .{ self, out, input, options, split_options }, .append);
            return try self.encodeBestAdaptiveSplitWithHeaderAppend(out, input, options, split_options, .{});
        }

        pub fn encodeBestAdaptiveSplitWithHeaderAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions, header_options: GzipHeaderOptions) !usize {
            if (encode_total_budget.requested(options) and (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeBestAdaptiveSplitWithHeaderAppend, .{ self, out, input, options, split_options, header_options }, .append);
            const encoded = try self.encodeBestAdaptiveSplitWithHeaderAlloc(input, options, split_options, header_options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeLevelAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, level: u4) !usize {
            return try self.encodeLevelWithHeaderAppend(out, input, level, .{});
        }

        pub fn encodeLevelWithHeaderAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, level: u4, header_options: GzipHeaderOptions) !usize {
            const encoded = try self.encodeLevelWithHeaderAlloc(input, level, header_options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeDynamicLiteralAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8) !usize {
            return try self.encodeDynamicLiteralWithHeaderAppend(out, input, .{});
        }

        pub fn encodeDynamicLiteralWithHeaderAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, header_options: GzipHeaderOptions) !usize {
            const encoded = try self.encodeDynamicLiteralWithHeaderAlloc(input, header_options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeDynamicWithOptionsAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithOptionsAppend, .{ self, out, input, options }, .append);
            return try self.encodeDynamicWithHeaderAppend(out, input, options, .{});
        }

        pub fn encodeDynamicWithHeaderAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, options: CompressionOptions, header_options: GzipHeaderOptions) !usize {
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicWithHeaderAppend, .{ self, out, input, options, header_options }, .append);
            const encoded = try self.encodeDynamicWithHeaderAlloc(input, options, header_options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeDynamicSplitAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, block_len: usize, options: CompressionOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitAppend, .{ self, out, input, block_len, options }, .append);
            return try self.encodeDynamicSplitWithHeaderAppend(out, input, block_len, options, .{});
        }

        pub fn encodeDynamicSplitWithHeaderAppend(self: *Self, out: *std.ArrayList(u8), input: []const u8, block_len: usize, options: CompressionOptions, header_options: GzipHeaderOptions) !usize {
            if (encode_total_budget.requested(options) and (block_len == 0)) return error.InvalidBlockPlan;
            if (encode_total_budget.requested(options)) return encode_total_budget.reusable(self, options, @This().encodeDynamicSplitWithHeaderAppend, .{ self, out, input, block_len, options, header_options }, .append);
            const encoded = try self.encodeDynamicSplitWithHeaderAlloc(input, block_len, options, header_options);
            defer self.allocator.free(encoded);
            const start = out.items.len;
            try out.appendSlice(self.allocator, encoded);
            return out.items.len - start;
        }

        pub fn encodeStoredIntoSlice(self: *Self, input: []const u8, output: []u8) !usize {
            _ = self;
            return try C.encodeGzipStored(input, output);
        }

        pub fn encodeStoredWithHeaderIntoSlice(self: *Self, input: []const u8, header_options: GzipHeaderOptions, output: []u8) !usize {
            _ = self;
            return try C.encodeGzipStoredWithHeader(input, output, header_options);
        }

        pub fn encodeStoredChunksIntoSlice(self: *Self, chunks: []const []const u8, output: []u8) !usize {
            _ = self;
            return try C.encodeGzipStoredChunks(chunks, output);
        }

        pub fn encodeStoredChunksWithHeaderIntoSlice(self: *Self, chunks: []const []const u8, header_options: GzipHeaderOptions, output: []u8) !usize {
            _ = self;
            return try C.encodeGzipStoredChunksWithHeader(chunks, output, header_options);
        }
    };
}
