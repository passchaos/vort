//! Window-aware library facade over the existing one-shot raw codecs.
const std = @import("std");
const checksum = @import("../../checksum.zig");
const window = @import("window.zig");
const settings = @import("frame_options.zig");
const budget = @import("../encode/total_budget.zig");
const backends = @import("frame_backends.zig");

pub const Mode = settings.Mode;
pub const Options = settings.Options;

pub fn Encoder(comptime C: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options(C),
        /// Scratch bytes are borrowed until the next scratch operation.
        scratch: std.ArrayList(u8) = .empty,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, options: Options(C)) (C.Error || window.Error)!Self {
            _ = try options.resolved();
            return .{ .allocator = allocator, .options = options };
        }
        pub fn setOptions(self: *Self, options: Options(C)) (C.Error || window.Error)!void {
            _ = try options.resolved();
            self.options = options;
        }
        pub fn deinit(self: *Self) void {
            self.scratch.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn encodeAlloc(self: *Self, input: []const u8) ![]u8 {
            const options = try self.options.resolved();
            if (budget.requested(options)) return budget.reusable(self, options, Self.encodeAlloc, .{ self, input }, .alloc);
            // Preserve every established default-window codec choice, tie and
            // dictionary-presence rule by calling the corresponding old API.
            if (options.window_bits == window.default_bits and
                !(options.mode == .png_ultrafast and options.dictionary != null))
                return backends.legacyAlloc(C, self.allocator, input, options);
            const body = try backends.rawAlloc(C, self.allocator, input, options);
            defer self.allocator.free(body.allocation);
            return self.wrapAlloc(body.bytes, options.dictionary, options.window_bits, checksum.adler32(input));
        }

        pub fn encodeAppend(self: *Self, output: *std.ArrayList(u8), input: []const u8) !usize {
            const options = try self.options.resolved();
            if (budget.requested(options)) return budget.reusable(self, options, Self.encodeAppend, .{ self, output, input }, .append);
            const bytes = try self.encodeAlloc(input);
            defer self.allocator.free(bytes);
            try output.appendSlice(self.allocator, bytes);
            return bytes.len;
        }

        pub fn encodeInto(self: *Self, input: []const u8, output: []u8) !usize {
            const options = try self.options.resolved();
            if (options.mode == .stored and options.block_len == null) {
                const raw_size = try C.rawStoredEncodedSize(input.len);
                const required = try wrappedSize(raw_size, options.dictionary);
                if (output.len < required) return error.OutputTooSmall;
                // Direct stored emission uses only caller storage: no ledger
                // control allocation, including cap=0 and profile-only calls.
                try budget.direct(self.allocator, options, self.scratch.capacity);
                const header_len = window.headerLen(options.dictionary);
                _ = try C.encodeRawStored(input, output[header_len..][0..raw_size]);
                try window.writeHeader(output[0..header_len], options.dictionary, options.window_bits);
                std.mem.writeInt(u32, output[header_len + raw_size ..][0..4], checksum.adler32(input), .big);
                return required;
            }
            if (budget.requested(options)) return budget.reusable(self, options, Self.encodeInto, .{ self, input, output }, .into);
            const bytes = try self.encodeAlloc(input);
            defer self.allocator.free(bytes);
            if (output.len < bytes.len) return error.OutputTooSmall;
            @memcpy(output[0..bytes.len], bytes);
            return bytes.len;
        }

        pub fn encodeScratch(self: *Self, input: []const u8) ![]const u8 {
            const options = try self.options.resolved();
            if (budget.requested(options)) return budget.reusable(self, options, Self.encodeScratch, .{ self, input }, .scratch);
            const bytes = try self.encodeAlloc(input);
            defer self.allocator.free(bytes);
            return self.retainScratch(bytes);
        }

        /// Scatter-input stored encoding retains the original maximal RFC LEN
        /// policy unless an explicit block_len requests smaller stored blocks.
        pub fn encodeStoredChunksAlloc(self: *Self, chunks: []const []const u8) ![]u8 {
            var requested = self.options;
            requested.mode = .stored;
            const options = try requested.resolved();
            if (budget.requested(options)) return budget.reusable(self, options, Self.encodeStoredChunksAlloc, .{ self, chunks }, .alloc);
            const block_len = options.block_len orelse C.max_stored_block_len;
            const raw_size = try C.rawStoredChunksEncodedSizeWithBlockLen(chunks, block_len);
            const required = try wrappedSize(raw_size, options.dictionary);
            const bytes = try self.allocator.alloc(u8, required);
            errdefer self.allocator.free(bytes);
            _ = try self.encodeStoredChunksInto(chunks, bytes);
            return bytes;
        }

        pub fn encodeStoredChunksInto(self: *Self, chunks: []const []const u8, output: []u8) !usize {
            var requested = self.options;
            requested.mode = .stored;
            const options = try requested.resolved();
            const block_len = options.block_len orelse C.max_stored_block_len;
            const raw_size = try C.rawStoredChunksEncodedSizeWithBlockLen(chunks, block_len);
            const required = try wrappedSize(raw_size, options.dictionary);
            if (output.len < required) return error.OutputTooSmall;
            try budget.direct(self.allocator, options, self.scratch.capacity);
            const header_len = window.headerLen(options.dictionary);
            _ = try C.encodeRawStoredChunksWithBlockLen(chunks, output[header_len..][0..raw_size], block_len);
            try window.writeHeader(output[0..header_len], options.dictionary, options.window_bits);
            var adler = checksum.Adler32.init();
            for (chunks) |chunk| adler.update(chunk);
            std.mem.writeInt(u32, output[header_len + raw_size ..][0..4], adler.digest(), .big);
            return required;
        }

        pub fn encodeStoredChunksAppend(self: *Self, output: *std.ArrayList(u8), chunks: []const []const u8) !usize {
            const options = try self.options.resolved();
            if (budget.requested(options)) return budget.reusable(self, options, Self.encodeStoredChunksAppend, .{ self, output, chunks }, .append);
            const bytes = try self.encodeStoredChunksAlloc(chunks);
            defer self.allocator.free(bytes);
            try output.appendSlice(self.allocator, bytes);
            return bytes.len;
        }

        pub fn encodeStoredChunksScratch(self: *Self, chunks: []const []const u8) ![]const u8 {
            const options = try self.options.resolved();
            if (budget.requested(options)) return budget.reusable(self, options, Self.encodeStoredChunksScratch, .{ self, chunks }, .scratch);
            const bytes = try self.encodeStoredChunksAlloc(chunks);
            defer self.allocator.free(bytes);
            return self.retainScratch(bytes);
        }

        fn retainScratch(self: *Self, bytes: []const u8) ![]const u8 {
            // Validate/encode and reserve first, keeping the previous borrowed
            // result intact on a rejected window or backing allocation error.
            try self.scratch.ensureTotalCapacity(self.allocator, bytes.len);
            self.scratch.clearRetainingCapacity();
            self.scratch.appendSliceAssumeCapacity(bytes);
            return self.scratch.items;
        }

        fn wrapAlloc(self: *Self, body: []const u8, dictionary: ?[]const u8, bits: u8, adler: u32) ![]u8 {
            const required = try wrappedSize(body.len, dictionary);
            const bytes = try self.allocator.alloc(u8, required);
            errdefer self.allocator.free(bytes);
            const header_len = window.headerLen(dictionary);
            try window.writeHeader(bytes[0..header_len], dictionary, bits);
            @memcpy(bytes[header_len..][0..body.len], body);
            std.mem.writeInt(u32, bytes[header_len + body.len ..][0..4], adler, .big);
            return bytes;
        }
    };
}

fn wrappedSize(raw_size: usize, dictionary: ?[]const u8) error{IntegerOverflow}!usize {
    const with_header = std.math.add(usize, window.headerLen(dictionary), raw_size) catch return error.IntegerOverflow;
    return std.math.add(usize, with_header, 4) catch error.IntegerOverflow;
}
