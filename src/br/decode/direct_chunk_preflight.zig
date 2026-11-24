//! Allocation-free preflight and replay over borrowed compressed chunks.
const std = @import("std");
const core = @import("../../core.zig");
const count = core.stream_count;
const budget = @import("budget.zig");
const borrow = @import("chunk_join.zig");

pub fn Workspace(comptime Codec: type) type {
    return struct {
        decoder: Codec.Decoder = undefined,
        discard: [4096]u8 = undefined,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            preflight: Codec.PreflightOptions,
            /// Optional replacement for the decoder's embedded header buffer.
            compressed_header_scratch: []u8 = &.{},
        };

        pub fn decodedSize(self: *Self, chunks: []const []const u8, options: Options) Error!core.StreamCount {
            return (try self.preflight(chunks, &.{}, options, false)).decoded_bytes;
        }

        pub fn decodedPrefixSize(self: *Self, chunks: []const []const u8, options: Options) Error!Codec.PrefixSize {
            return self.preflight(chunks, &.{}, options, true);
        }

        pub fn decodeInto(self: *Self, chunks: []const []const u8, output: []u8, options: Options) Error!usize {
            return (try self.decode(chunks, output, options, false)).output_written;
        }

        pub fn decodePrefixInto(self: *Self, chunks: []const []const u8, output: []u8, options: Options) Error!Codec.PrefixResult {
            return self.decode(chunks, output, options, true);
        }

        fn decode(self: *Self, chunks: []const []const u8, output: []u8, options: Options, prefix: bool) Error!Codec.PrefixResult {
            const measured = try self.preflight(chunks, output, options, prefix);
            const len = try count.toLocal(measured.decoded_bytes);
            if (output.len < len) return error.OutputTooSmall;
            const replayed = try self.drive(chunks, output[0..len], options);
            if (replayed.input_read != measured.input_read or replayed.decoded_bytes != measured.decoded_bytes)
                return error.SizeMismatch;
            return .{ .input_read = measured.input_read, .output_written = len };
        }

        fn preflight(self: *Self, chunks: []const []const u8, output: []u8, options: Options, prefix: bool) Error!Codec.PrefixSize {
            const total = try self.admit(chunks, output, options);
            budget.noHeap(options.preflight.decode);
            const measured = try self.drive(chunks, null, options);
            if (!prefix and measured.input_read != total) return error.TrailingData;
            if (options.preflight.expected_output_len) |expected| {
                if (measured.decoded_bytes != expected) return error.SizeMismatch;
            }
            return measured;
        }

        fn admit(self: *Self, chunks: []const []const u8, output: []u8, options: Options) Error!usize {
            const policy = options.preflight.decode;
            const borrows: borrow.PreflightBorrows = .{
                .history = options.preflight.history,
                .output = output,
                .profile = if (policy.memory_profile) |profile| std.mem.asBytes(profile) else &.{},
                .decoder = std.mem.asBytes(self),
            };
            try borrow.validatePreflight(chunks, &.{}, policy.shared_dictionary, borrows);
            try borrow.validateObserver(chunks, &.{}, &.{ borrows.history, borrows.output, borrows.profile, borrows.decoder }, policy.shared_dictionary, options.compressed_header_scratch);
            var total: usize = 0;
            for (chunks) |chunk| total = std.math.add(usize, total, chunk.len) catch return error.IntegerOverflow;
            return total;
        }

        fn drive(self: *Self, chunks: []const []const u8, destination: ?[]u8, options: Options) Error!Codec.PrefixSize {
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

            var chunk_index: usize = 0;
            var chunk_offset: usize = 0;
            var accepted: usize = 0;
            var written: core.StreamCount = 0;
            while (true) {
                while (chunk_index < chunks.len and chunk_offset == chunks[chunk_index].len) {
                    chunk_index += 1;
                    chunk_offset = 0;
                }
                const input = if (chunk_index < chunks.len) chunks[chunk_index][chunk_offset..] else &.{};
                const output: []u8 = if (destination) |into| blk: {
                    const tail = into[try count.toLocal(written)..];
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
                chunk_offset += consumed;
                // The total offered byte count was checked before either pass.
                accepted += consumed;
                written = try count.addLocal(written, produced);
                if (step.status == .done) {
                    try self.decoder.finish();
                    const retained_suffix = self.decoder.trailingInput().len;
                    if (retained_suffix > accepted) return error.InvalidStreamState;
                    return .{ .input_read = accepted - retained_suffix, .decoded_bytes = written };
                }
                if (consumed == 0 and produced == 0) {
                    if (step.status == .need_input and input.len == 0) try self.decoder.finish();
                    if (step.status == .need_output and output.len == 0) return error.SizeMismatch;
                    return error.InvalidStreamState;
                }
            }
        }
    };
}
