//! Allocation-free preflight and replay over borrowed chunks or a paged source.
const std = @import("std");
const core = @import("../../core.zig");
const count = core.stream_count;
const byte_source = @import("../../io/source.zig");
const SourceCursor = @import("../../io/source_page.zig").Cursor;
const budget = @import("budget.zig");
const borrow = @import("chunk_join.zig");

const ChunkCursor = struct {
    chunks: []const []const u8,
    index: usize = 0,
    used: usize = 0,
    offset: u64 = 0,

    pub const Error = error{InvalidStreamState};

    fn current(self: *ChunkCursor) Error![]const u8 {
        while (self.index < self.chunks.len and self.used == self.chunks[self.index].len) {
            self.index += 1;
            self.used = 0;
        }
        return if (self.index < self.chunks.len) self.chunks[self.index][self.used..] else &.{};
    }

    fn advance(self: *ChunkCursor, amount: usize) Error!void {
        if (amount == 0) return;
        if (self.index == self.chunks.len or amount > self.chunks[self.index].len - self.used)
            return error.InvalidStreamState;
        self.used += amount;
        // The total chunk length was checked before either pass.
        self.offset += amount;
    }
};

pub fn Workspace(comptime Codec: type) type {
    return struct {
        decoder: Codec.Decoder = undefined,
        discard: [4096]u8 = undefined,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const SourceError = Error || SourceCursor.Error;
        pub const Options = struct {
            preflight: Codec.PreflightOptions,
            /// Optional replacement for the decoder's embedded header buffer.
            compressed_header_scratch: []u8 = &.{},
        };
        pub const SourceRange = struct {
            source: byte_source.Source,
            offset: u64 = 0,
            /// Null reads through the end of the source.
            length: ?u64 = null,

            fn endOffset(self: SourceRange) SourceError!u64 {
                if (self.offset > self.source.len) return error.RangeOutOfBounds;
                const remaining = self.source.len - self.offset;
                const len = self.length orelse remaining;
                if (len > remaining) return error.RangeOutOfBounds;
                return self.offset + len;
            }
        };
        pub const SourcePrefixSize = struct {
            /// Compressed bytes through padding, relative to SourceRange.offset.
            input_read: u64,
            decoded_bytes: core.StreamCount,
        };
        pub const SourcePrefixResult = struct {
            input_read: u64,
            output_written: usize,
        };
        const Sink = struct {
            bytes: []u8,
            full_error: Error,
        };

        pub fn decodedSize(self: *Self, chunks: []const []const u8, options: Options) Error!core.StreamCount {
            return (try self.preflightChunks(chunks, &.{}, options, false)).decoded_bytes;
        }

        pub fn decodedPrefixSize(self: *Self, chunks: []const []const u8, options: Options) Error!Codec.PrefixSize {
            const measured = try self.preflightChunks(chunks, &.{}, options, true);
            return .{ .input_read = @intCast(measured.input_read), .decoded_bytes = measured.decoded_bytes };
        }

        pub fn decodeInto(self: *Self, chunks: []const []const u8, output: []u8, options: Options) Error!usize {
            return (try self.decodeChunks(chunks, output, options, false)).output_written;
        }

        pub fn decodePrefixInto(self: *Self, chunks: []const []const u8, output: []u8, options: Options) Error!Codec.PrefixResult {
            return self.decodeChunks(chunks, output, options, true);
        }

        pub fn decodedSourceSize(self: *Self, range: SourceRange, input_page: []u8, options: Options) SourceError!core.StreamCount {
            return (try self.preflightSource(range, input_page, &.{}, options, false)).decoded_bytes;
        }

        pub fn decodedSourcePrefixSize(self: *Self, range: SourceRange, input_page: []u8, options: Options) SourceError!SourcePrefixSize {
            return self.preflightSource(range, input_page, &.{}, options, true);
        }

        pub fn decodeSourceInto(self: *Self, range: SourceRange, output: []u8, input_page: []u8, options: Options) SourceError!usize {
            return (try self.decodeSource(range, output, input_page, options, false)).output_written;
        }

        pub fn decodeSourcePrefixInto(self: *Self, range: SourceRange, output: []u8, input_page: []u8, options: Options) SourceError!SourcePrefixResult {
            return self.decodeSource(range, output, input_page, options, true);
        }

        /// Decode once into disjoint caller scratch. Output is untouched on error.
        pub fn decodeVerifiedSourceInto(self: *Self, range: SourceRange, output: []u8, input_page: []u8, plaintext_scratch: []u8, options: Options) SourceError!usize {
            return (try self.decodeVerifiedSource(range, output, input_page, plaintext_scratch, options, false)).output_written;
        }

        /// As above, but validate and publish only the first stream in the range.
        pub fn decodeVerifiedSourcePrefixInto(self: *Self, range: SourceRange, output: []u8, input_page: []u8, plaintext_scratch: []u8, options: Options) SourceError!SourcePrefixResult {
            return self.decodeVerifiedSource(range, output, input_page, plaintext_scratch, options, true);
        }

        fn decodeVerifiedSource(self: *Self, range: SourceRange, output: []u8, input_page: []u8, plaintext_scratch: []u8, options: Options, prefix: bool) SourceError!SourcePrefixResult {
            const end = try range.endOffset();
            try self.admit(&.{}, output, input_page, plaintext_scratch, options);
            var reader = try SourceCursor.init(range.source, input_page, range.offset, end);
            const stage = plaintext_scratch[0..@min(plaintext_scratch.len, output.len)];
            budget.noHeap(options.preflight.decode);
            const measured = try self.drive(&reader, .{ .bytes = stage, .full_error = error.OutputTooSmall }, options);
            try validateMeasured(measured, end - range.offset, options, prefix);
            const len = try count.toLocal(measured.decoded_bytes);
            @memcpy(output[0..len], stage[0..len]);
            return .{ .input_read = measured.input_read, .output_written = len };
        }

        fn decodeChunks(self: *Self, chunks: []const []const u8, output: []u8, options: Options, prefix: bool) Error!Codec.PrefixResult {
            const measured = try self.preflightChunks(chunks, output, options, prefix);
            var reader: ChunkCursor = .{ .chunks = chunks };
            const verified = try self.replay(&reader, output, options, measured);
            return .{ .input_read = @intCast(verified.input_read), .output_written = verified.output_written };
        }

        fn decodeSource(self: *Self, range: SourceRange, output: []u8, input_page: []u8, options: Options, prefix: bool) SourceError!SourcePrefixResult {
            const measured = try self.preflightSource(range, input_page, output, options, prefix);
            // The first pass can read ahead. Replay only the validated prefix.
            var reader = try SourceCursor.init(range.source, input_page, range.offset, range.offset + measured.input_read);
            return self.replay(&reader, output, options, measured);
        }

        fn replay(self: *Self, reader: anytype, output: []u8, options: Options, measured: SourcePrefixSize) (Error || @TypeOf(reader.*).Error)!SourcePrefixResult {
            const len = try count.toLocal(measured.decoded_bytes);
            if (output.len < len) return error.OutputTooSmall;
            const replayed = try self.drive(reader, .{ .bytes = output[0..len], .full_error = error.SizeMismatch }, options);
            if (replayed.input_read != measured.input_read or replayed.decoded_bytes != measured.decoded_bytes)
                return error.SizeMismatch;
            return .{ .input_read = measured.input_read, .output_written = len };
        }

        fn preflightChunks(self: *Self, chunks: []const []const u8, output: []u8, options: Options, prefix: bool) Error!SourcePrefixSize {
            try self.admit(chunks, output, &.{}, &.{}, options);
            var total: usize = 0;
            for (chunks) |chunk| total = std.math.add(usize, total, chunk.len) catch return error.IntegerOverflow;
            var reader: ChunkCursor = .{ .chunks = chunks };
            return self.measure(&reader, total, options, prefix);
        }

        fn preflightSource(self: *Self, range: SourceRange, input_page: []u8, output: []u8, options: Options, prefix: bool) SourceError!SourcePrefixSize {
            const end = try range.endOffset();
            try self.admit(&.{}, output, input_page, &.{}, options);
            var reader = try SourceCursor.init(range.source, input_page, range.offset, end);
            return self.measure(&reader, end - range.offset, options, prefix);
        }

        fn measure(self: *Self, reader: anytype, total: u64, options: Options, prefix: bool) (Error || @TypeOf(reader.*).Error)!SourcePrefixSize {
            budget.noHeap(options.preflight.decode);
            const measured = try self.drive(reader, null, options);
            try validateMeasured(measured, total, options, prefix);
            return measured;
        }

        fn validateMeasured(measured: SourcePrefixSize, total: u64, options: Options, prefix: bool) Error!void {
            if (!prefix and measured.input_read != total) return error.TrailingData;
            if (options.preflight.expected_output_len) |expected| {
                if (measured.decoded_bytes != expected) return error.SizeMismatch;
            }
        }

        fn admit(self: *Self, chunks: []const []const u8, output: []u8, input_page: []u8, plaintext_scratch: []u8, options: Options) Error!void {
            const policy = options.preflight.decode;
            const borrows: borrow.PreflightBorrows = .{
                .history = options.preflight.history,
                .output = output,
                .profile = if (policy.memory_profile) |profile| std.mem.asBytes(profile) else &.{},
                .decoder = std.mem.asBytes(self),
            };
            try borrow.validatePreflight(chunks, &.{}, policy.shared_dictionary, borrows);
            const residents = [_][]const u8{ borrows.history, borrows.output, borrows.profile, borrows.decoder };
            try borrow.validateObserver(chunks, &.{}, &(residents ++ .{ input_page, plaintext_scratch }), policy.shared_dictionary, options.compressed_header_scratch);
            try borrow.validateObserver(chunks, &.{}, &(residents ++ .{plaintext_scratch}), policy.shared_dictionary, input_page);
            try borrow.validateObserver(chunks, &.{}, &residents, policy.shared_dictionary, plaintext_scratch);
        }

        fn drive(self: *Self, reader: anytype, destination: ?Sink, options: Options) (Error || @TypeOf(reader.*).Error)!SourcePrefixSize {
            var policy = options.preflight.decode;
            // The caller supplies every buffer. Observe the whole operation
            // above, rather than passing a one-shot heap policy to step().
            policy.memory_profile = null;
            policy.max_total_working_memory = null;
            self.decoder = Codec.Decoder.initWithOptions(options.preflight.history, .{
                .max_output_len = options.preflight.max_output_len,
                .decode = policy,
                .compressed_header_scratch = options.compressed_header_scratch,
                .allow_trailing_data = true,
            });

            const start = reader.offset;
            var written: core.StreamCount = 0;
            while (true) {
                const input = try reader.current();
                const output: []u8 = if (destination) |into| blk: {
                    const tail = into.bytes[try count.toLocal(written)..];
                    break :blk tail[0..@min(tail.len, self.discard.len)];
                } else &self.discard;
                const step = self.decoder.step(input, output) catch |err| {
                    if (self.decoder.history_capacity_exceeded or
                        (err == error.OutputTooSmall and options.preflight.history.len == 0))
                        return error.PreflightHistoryTooSmall;
                    return err;
                };
                const consumed = step.progress.input_read;
                const produced = step.progress.output_written;
                if (consumed > input.len or produced > output.len) return error.InvalidStreamState;
                try reader.advance(consumed);
                written = try count.addLocal(written, produced);
                if (step.status == .done) {
                    try self.decoder.finish();
                    const accepted = reader.offset - start;
                    const retained_suffix = self.decoder.trailingInput().len;
                    if (retained_suffix > accepted) return error.InvalidStreamState;
                    return .{ .input_read = accepted - retained_suffix, .decoded_bytes = written };
                }
                if (consumed == 0 and produced == 0) {
                    if (step.status == .need_input and input.len == 0) try self.decoder.finish();
                    if (step.status == .need_output and output.len == 0) {
                        return if (destination) |sink| sink.full_error else error.InvalidStreamState;
                    }
                    return error.InvalidStreamState;
                }
            }
        }
    };
}
