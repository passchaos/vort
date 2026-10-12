const std = @import("std");
const core = @import("../core.zig");

pub const Format = enum { xerial, hadoop };

/// Build a caller-output incremental decoder for Xerial or Hadoop Snappy
/// framing. Raw Snappy chunks remain input-atomic because their decoded-size
/// varint and copy stream must be validated together, while framing headers,
/// chunk payloads, and decoded output may cross arbitrary caller boundaries.
pub fn Decoder(comptime Codec: type, comptime format: Format) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        phase: Phase = initialPhase(),
        header: [Codec.xerial_header.len]u8 = undefined,
        header_len: usize = 0,
        compressed_len: usize = 0,
        compressed: std.ArrayList(u8) = .empty,
        decoded: std.ArrayList(u8) = .empty,
        decoded_offset: usize = 0,
        saw_xerial_header: bool = false,
        hadoop_block_expected: usize = 0,
        hadoop_block_decoded: usize = 0,
        input_finished: bool = false,
        total_output: usize = 0,
        block_count: usize = 0,
        chunk_count: usize = 0,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = initialPhase(),

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_compressed_chunk_len: usize = 64 * 1024 * 1024,
            max_decoded_chunk_len: usize = 64 * 1024 * 1024,
            max_output_len: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
        };
        pub const Phase = enum { stream_header, outer_header, chunk_header, payload, output, done };
        pub const Snapshot = struct {
            phase: Phase,
            header_received: usize,
            chunk_payload_received: usize,
            chunk_payload_expected: usize,
            payload_remaining: usize,
            output_written: usize,
            block_count: usize,
            chunk_count: usize,
            hadoop_block_expected: usize,
            hadoop_block_decoded: usize,
            input_finished: bool,
            retained_compressed_capacity: usize,
            retained_decoded_capacity: usize,
            last_error_name: []const u8,
            last_error_phase: Phase,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }

        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options };
        }

        pub fn deinit(self: *Self) void {
            self.compressed.deinit(self.allocator);
            self.decoded.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn reset(self: *Self) void {
            self.resetWithOptions(self.options);
        }

        pub fn resetWithOptions(self: *Self, options: Options) void {
            const allocator = self.allocator;
            var compressed = self.compressed;
            var decoded = self.decoded;
            compressed.clearRetainingCapacity();
            decoded.clearRetainingCapacity();
            self.* = .{
                .allocator = allocator,
                .options = options,
                .compressed = compressed,
                .decoded = decoded,
            };
        }

        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .header_received = self.header_len,
                .chunk_payload_received = self.compressed.items.len,
                .chunk_payload_expected = self.compressed_len,
                .payload_remaining = self.decoded.items.len - self.decoded_offset,
                .output_written = self.total_output,
                .block_count = self.block_count,
                .chunk_count = self.chunk_count,
                .hadoop_block_expected = self.hadoop_block_expected,
                .hadoop_block_decoded = self.hadoop_block_decoded,
                .input_finished = self.input_finished,
                .retained_compressed_capacity = self.compressed.capacity,
                .retained_decoded_capacity = self.decoded.capacity,
                .last_error_name = self.last_error_name,
                .last_error_phase = self.last_error_phase,
            };
        }

        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            const snap = self.snapshot();
            return .{
                .phase_name = @tagName(snap.phase),
                .header_received = snap.header_received,
                .output_written = snap.output_written,
                .expected_output_len = self.options.expected_output_len,
                .payload_remaining = snap.payload_remaining,
                .last_error_name = snap.last_error_name,
                .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
                .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (snap.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }

        /// Both formats terminate at a framing boundary rather than with an
        /// explicit marker. Pending decoded bytes may still be drained after
        /// finish, but partial headers/blocks are rejected immediately.
        pub fn finish(self: *Self) Error!void {
            if (self.phase == .done) return;
            const valid = switch (self.phase) {
                .chunk_header => if (comptime format == .xerial)
                    self.saw_xerial_header and self.header_len == 0
                else
                    false,
                .outer_header => if (comptime format == .hadoop)
                    self.header_len == 0 and self.hadoop_block_expected == 0
                else
                    false,
                .output => if (comptime format == .xerial)
                    self.saw_xerial_header
                else
                    self.hadoop_block_expected != 0 and self.hadoop_block_decoded == self.hadoop_block_expected,
                else => false,
            };
            if (!valid) return self.fail(self.phase, error.TruncatedFrame);
            self.input_finished = true;
            if (self.phase != .output) try self.complete();
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.phase == .done) {
                if (input.len != 0) return self.fail(.done, error.TrailingData);
                return .{ .status = .done };
            }
            if (self.input_finished and input.len != 0) return self.fail(self.phase, error.TrailingData);
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.phase == .output) {
                    const remaining = self.decoded.items[self.decoded_offset..];
                    const count = @min(output.len - output_written, remaining.len);
                    @memcpy(output[output_written..][0..count], remaining[0..count]);
                    self.decoded_offset += count;
                    output_written += count;
                    self.total_output += count;
                    if (self.decoded_offset != self.decoded.items.len)
                        return result(input_read, output_written, .need_output);
                    self.decoded.clearRetainingCapacity();
                    self.decoded_offset = 0;
                    try self.advanceAfterChunk();
                    if (self.input_finished) {
                        try self.complete();
                        return result(input_read, output_written, .done);
                    }
                }

                if (self.phase == .stream_header) {
                    const header_complete = self.fillHeader(input, &input_read, Codec.xerial_header.len);
                    if (!header_complete) return result(input_read, output_written, .need_input);
                    if (!std.mem.eql(u8, self.header[0..Codec.xerial_header.len], &Codec.xerial_header))
                        return self.fail(.stream_header, error.InvalidMagic);
                    self.header_len = 0;
                    self.saw_xerial_header = true;
                    self.phase = .chunk_header;
                }

                if (self.phase == .outer_header) {
                    if (!self.fillHeader(input, &input_read, 4))
                        return result(input_read, output_written, .need_input);
                    const expected: usize = std.mem.readInt(u32, self.header[0..4], .big);
                    self.header_len = 0;
                    if (expected == 0) return self.fail(.outer_header, error.InvalidHadoopSnappyStream);
                    const stream_end = std.math.add(usize, self.total_output, expected) catch
                        return self.fail(.outer_header, error.IntegerOverflow);
                    if (stream_end > self.options.max_output_len)
                        return self.fail(.outer_header, error.OutputLimitExceeded);
                    if (self.options.expected_output_len) |pledged| if (stream_end > pledged)
                        return self.fail(.outer_header, error.SizeMismatch);
                    self.hadoop_block_expected = expected;
                    self.hadoop_block_decoded = 0;
                    self.phase = .chunk_header;
                }

                if (self.phase == .chunk_header) {
                    if (!self.fillHeader(input, &input_read, 4))
                        return result(input_read, output_written, .need_input);
                    self.compressed_len = std.mem.readInt(u32, self.header[0..4], .big);
                    self.header_len = 0;
                    if (self.compressed_len == 0) return self.fail(.chunk_header, invalidStreamError());
                    if (self.compressed_len > self.options.max_compressed_chunk_len)
                        return self.fail(.chunk_header, error.OutputLimitExceeded);
                    self.compressed.clearRetainingCapacity();
                    try self.compressed.ensureTotalCapacityPrecise(self.allocator, self.compressed_len);
                    self.phase = .payload;
                }

                if (self.phase == .payload) {
                    const count = @min(self.compressed_len - self.compressed.items.len, input.len - input_read);
                    try self.compressed.appendSlice(self.allocator, input[input_read..][0..count]);
                    input_read += count;
                    if (self.compressed.items.len != self.compressed_len)
                        return result(input_read, output_written, .need_input);
                    self.decodeChunk() catch |err| return self.fail(.payload, err);
                    self.phase = .output;
                }
            }
        }

        fn fillHeader(self: *Self, input: []const u8, input_read: *usize, expected: usize) bool {
            const count = @min(expected - self.header_len, input.len - input_read.*);
            @memcpy(self.header[self.header_len..][0..count], input[input_read.*..][0..count]);
            self.header_len += count;
            input_read.* += count;
            return self.header_len == expected;
        }

        fn decodeChunk(self: *Self) Error!void {
            const decoded_len = try Codec.decodedBlockSize(self.compressed.items);
            if (decoded_len > self.options.max_decoded_chunk_len) return error.OutputLimitExceeded;
            const next_hadoop_block_decoded = if (comptime format == .hadoop) blk: {
                const next = std.math.add(usize, self.hadoop_block_decoded, decoded_len) catch
                    return error.IntegerOverflow;
                if (next > self.hadoop_block_expected) return error.InvalidHadoopSnappyStream;
                break :blk next;
            } else 0;
            const stream_end = std.math.add(usize, self.total_output, decoded_len) catch
                return error.IntegerOverflow;
            if (stream_end > self.options.max_output_len) return error.OutputLimitExceeded;
            if (self.options.expected_output_len) |pledged| if (stream_end > pledged)
                return error.SizeMismatch;
            self.decoded.clearRetainingCapacity();
            try self.decoded.ensureTotalCapacityPrecise(self.allocator, decoded_len);
            try self.decoded.resize(self.allocator, decoded_len);
            const written = try Codec.decodeBlockIntoExactSize(self.compressed.items, self.decoded.items, decoded_len);
            if (written != decoded_len) return error.SizeMismatch;
            if (comptime format == .hadoop)
                self.hadoop_block_decoded = next_hadoop_block_decoded;
            self.compressed.clearRetainingCapacity();
            self.chunk_count = std.math.add(usize, self.chunk_count, 1) catch return error.IntegerOverflow;
        }

        fn advanceAfterChunk(self: *Self) Error!void {
            if (comptime format == .hadoop) {
                if (self.hadoop_block_decoded == self.hadoop_block_expected) {
                    self.hadoop_block_expected = 0;
                    self.hadoop_block_decoded = 0;
                    self.block_count = std.math.add(usize, self.block_count, 1) catch return error.IntegerOverflow;
                    self.phase = .outer_header;
                } else {
                    self.phase = .chunk_header;
                }
            } else {
                self.block_count = std.math.add(usize, self.block_count, 1) catch return error.IntegerOverflow;
                self.phase = .chunk_header;
            }
        }

        fn complete(self: *Self) Error!void {
            if (self.options.expected_output_len) |expected| {
                if (self.total_output != expected) return self.fail(self.phase, error.SizeMismatch);
            }
            self.phase = .done;
        }

        fn invalidStreamError() Error {
            return if (comptime format == .xerial)
                error.InvalidXerialSnappyStream
            else
                error.InvalidHadoopSnappyStream;
        }

        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            return err;
        }

        fn initialPhase() Phase {
            return if (comptime format == .xerial) .stream_header else .outer_header;
        }

        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
