const std = @import("std");
const block_decoder = @import("block.zig");
const container = @import("container.zig");
const core = @import("../core.zig");
const header = @import("header.zig");

/// Bounded, caller-output incremental LZOP decoder. Complete compressed blocks
/// are retained until their compressed and decoded checksums validate; only
/// then can bytes become visible to the caller.
pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .header,
    header_bytes: std.ArrayList(u8) = .empty,
    stream_flags: u32 = 0,
    stream_filter: ?u32 = null,
    block_header: [24]u8 = undefined,
    block_header_len: usize = 0,
    block_header_expected: usize = 4,
    block_uncompressed_len: usize = 0,
    block_payload_len: usize = 0,
    block_checksums: block_decoder.Checksums = .{},
    payload: std.ArrayList(u8) = .empty,
    decoded: std.ArrayList(u8) = .empty,
    decoded_offset: usize = 0,
    validated_output: usize = 0,
    output_written: usize = 0,
    stream_count: usize = 0,
    block_count: usize = 0,
    stored_block_count: usize = 0,
    compressed_block_count: usize = 0,
    input_finished: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .header,

    pub const Error = container.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        max_block_size: usize = 64 * 1024 * 1024,
        max_header_len: usize = 1024 * 1024,
        expected_output_len: ?usize = null,
    };
    pub const Phase = enum {
        header,
        block_header,
        payload,
        output,
        between_streams,
        done,
    };
    pub const Snapshot = struct {
        phase: Phase,
        header_received: usize,
        block_header_received: usize,
        block_header_expected: usize,
        block_payload_received: usize,
        block_payload_expected: usize,
        pending_output: usize,
        output_written: usize,
        validated_output: usize,
        stream_count: usize,
        block_count: usize,
        stored_block_count: usize,
        compressed_block_count: usize,
        retained_compressed_capacity: usize,
        retained_decoded_capacity: usize,
        last_error_name: []const u8,
        last_error_phase: Phase,
    };

    pub fn init(allocator: std.mem.Allocator) Decoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Decoder {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Decoder) void {
        self.header_bytes.deinit(self.allocator);
        self.payload.deinit(self.allocator);
        self.decoded.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Decoder) void {
        self.resetWithOptions(self.options);
    }

    pub fn resetWithOptions(self: *Decoder, options: Options) void {
        const allocator = self.allocator;
        var header_bytes = self.header_bytes;
        var payload = self.payload;
        var decoded = self.decoded;
        header_bytes.clearRetainingCapacity();
        payload.clearRetainingCapacity();
        decoded.clearRetainingCapacity();
        self.* = .{
            .allocator = allocator,
            .options = options,
            .header_bytes = header_bytes,
            .payload = payload,
            .decoded = decoded,
        };
    }

    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .header_received = self.header_bytes.items.len,
            .block_header_received = self.block_header_len,
            .block_header_expected = self.block_header_expected,
            .block_payload_received = self.payload.items.len,
            .block_payload_expected = self.block_payload_len,
            .pending_output = self.decoded.items.len - self.decoded_offset,
            .output_written = self.output_written,
            .validated_output = self.validated_output,
            .stream_count = self.stream_count,
            .block_count = self.block_count,
            .stored_block_count = self.stored_block_count,
            .compressed_block_count = self.compressed_block_count,
            .retained_compressed_capacity = self.payload.capacity,
            .retained_decoded_capacity = self.decoded.capacity,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = @tagName(snap.phase),
            .header_received = snap.header_received,
            .output_written = snap.output_written,
            .expected_output_len = self.options.expected_output_len,
            .payload_remaining = snap.pending_output,
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
            .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame)))
                "truncated_input"
            else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.OutputLimitExceeded)))
                "raise_output_limit"
            else if (snap.last_error_name.len == 0)
                "none"
            else
                "payload_corrupt",
        };
    }

    /// Declare that no more compressed input will arrive. A complete LZOP
    /// terminal marker is required; ending inside a header, block, or payload
    /// is reported immediately as truncation.
    pub fn finish(self: *Decoder) Error!void {
        if (self.phase == .done) return;
        if (self.phase != .between_streams) {
            self.recordError(self.phase, error.TruncatedFrame);
            return error.TruncatedFrame;
        }
        if (self.options.expected_output_len) |expected| {
            if (self.validated_output != expected) {
                self.recordError(.between_streams, error.SizeMismatch);
                return error.SizeMismatch;
            }
        }
        self.input_finished = true;
        self.phase = .done;
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        return self.stepInternal(input, output) catch |err| {
            self.recordError(self.phase, err);
            return err;
        };
    }

    fn stepInternal(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.TrailingData;

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .header => {
                const probe = try header.probeEncodedSize(self.header_bytes.items);
                const needed = switch (probe) {
                    .need_more => |value| value,
                    .complete => |value| {
                        const stream_header = try header.parse(self.header_bytes.items);
                        std.debug.assert(stream_header.encoded_size == value);
                        self.stream_flags = stream_header.flags;
                        self.stream_filter = stream_header.filter;
                        self.resetBlockHeader();
                        self.phase = .block_header;
                        continue;
                    },
                };
                if (needed > self.options.max_header_len) return error.OutputLimitExceeded;
                const take = @min(needed - self.header_bytes.items.len, input.len - input_read);
                try self.header_bytes.appendSlice(self.allocator, input[input_read..][0..take]);
                input_read += take;
                if (self.header_bytes.items.len != needed)
                    return result(input_read, output_written, .need_input);
            },
            .block_header => {
                const take = @min(self.block_header_expected - self.block_header_len, input.len - input_read);
                @memcpy(self.block_header[self.block_header_len..][0..take], input[input_read..][0..take]);
                self.block_header_len += take;
                input_read += take;
                if (self.block_header_len != self.block_header_expected)
                    return result(input_read, output_written, .need_input);
                try self.advanceBlockHeader();
            },
            .payload => {
                const take = @min(self.block_payload_len - self.payload.items.len, input.len - input_read);
                try self.payload.appendSlice(self.allocator, input[input_read..][0..take]);
                input_read += take;
                if (self.payload.items.len != self.block_payload_len)
                    return result(input_read, output_written, .need_input);
                try self.decodeBlock();
            },
            .output => {
                const remaining = self.decoded.items[self.decoded_offset..];
                const take = @min(output.len - output_written, remaining.len);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.decoded_offset += take;
                output_written += take;
                self.output_written += take;
                if (self.decoded_offset != self.decoded.items.len)
                    return result(input_read, output_written, .need_output);
                self.decoded.clearRetainingCapacity();
                self.decoded_offset = 0;
                self.resetBlockHeader();
                self.phase = .block_header;
            },
            .between_streams => {
                if (input_read == input.len)
                    return result(input_read, output_written, .need_input);
                self.header_bytes.clearRetainingCapacity();
                self.phase = .header;
            },
            .done => return result(input_read, output_written, .done),
        };
    }

    fn advanceBlockHeader(self: *Decoder) Error!void {
        if (self.block_header_expected == 4) {
            const uncompressed_u32 = std.mem.readInt(u32, self.block_header[0..4], .big);
            if (uncompressed_u32 == 0) {
                self.stream_count = std.math.add(usize, self.stream_count, 1) catch
                    return error.IntegerOverflow;
                self.phase = .between_streams;
                return;
            }
            if (uncompressed_u32 == std.math.maxInt(u32)) return error.UnsupportedLzopFeature;
            if (uncompressed_u32 > 64 * 1024 * 1024) return error.InvalidLzopStream;
            const uncompressed_len: usize = uncompressed_u32;
            if (uncompressed_len > self.options.max_block_size) return error.OutputLimitExceeded;
            const next_output = std.math.add(usize, self.validated_output, uncompressed_len) catch
                return error.IntegerOverflow;
            if (next_output > self.options.max_output_len) return error.OutputLimitExceeded;
            if (self.options.expected_output_len) |expected|
                if (next_output > expected) return error.SizeMismatch;
            self.block_uncompressed_len = uncompressed_len;
            self.block_header_expected = 8;
            return;
        }

        if (self.block_header_expected == 8) {
            const compressed_u32 = std.mem.readInt(u32, self.block_header[4..8], .big);
            if (compressed_u32 == 0 or compressed_u32 > self.block_uncompressed_len)
                return error.InvalidLzopStream;
            self.block_payload_len = compressed_u32;
            const compressed = self.block_payload_len < self.block_uncompressed_len;
            self.block_header_expected = 8 +
                @as(usize, if (self.stream_flags & header.Flag.adler32_data != 0) 4 else 0) +
                @as(usize, if (self.stream_flags & header.Flag.crc32_data != 0) 4 else 0) +
                @as(usize, if (compressed and self.stream_flags & header.Flag.adler32_compressed != 0) 4 else 0) +
                @as(usize, if (compressed and self.stream_flags & header.Flag.crc32_compressed != 0) 4 else 0);
            if (self.block_header_expected != 8) return;
        }

        var offset: usize = 8;
        var expected: block_decoder.Checksums = .{};
        if (self.stream_flags & header.Flag.adler32_data != 0) {
            expected.data_adler = readBlockU32(&self.block_header, &offset);
        }
        if (self.stream_flags & header.Flag.crc32_data != 0) {
            expected.data_crc = readBlockU32(&self.block_header, &offset);
        }
        const compressed = self.block_payload_len < self.block_uncompressed_len;
        if (compressed and self.stream_flags & header.Flag.adler32_compressed != 0) {
            expected.compressed_adler = readBlockU32(&self.block_header, &offset);
        }
        if (compressed and self.stream_flags & header.Flag.crc32_compressed != 0) {
            expected.compressed_crc = readBlockU32(&self.block_header, &offset);
        }
        std.debug.assert(offset == self.block_header_expected);
        self.block_checksums = expected;
        self.payload.clearRetainingCapacity();
        try self.payload.ensureTotalCapacityPrecise(self.allocator, self.block_payload_len);
        self.phase = .payload;
    }

    fn decodeBlock(self: *Decoder) Error!void {
        try self.decoded.ensureTotalCapacityPrecise(self.allocator, self.block_uncompressed_len);
        try self.decoded.resize(self.allocator, self.block_uncompressed_len);
        errdefer self.decoded.clearRetainingCapacity();
        try block_decoder.decodeInto(
            self.payload.items,
            self.decoded.items,
            self.stream_filter,
            self.block_checksums,
        );
        self.payload.clearRetainingCapacity();
        self.decoded_offset = 0;
        self.validated_output = std.math.add(usize, self.validated_output, self.decoded.items.len) catch
            return error.IntegerOverflow;
        self.block_count = std.math.add(usize, self.block_count, 1) catch
            return error.IntegerOverflow;
        if (self.block_payload_len < self.block_uncompressed_len) {
            self.compressed_block_count = std.math.add(usize, self.compressed_block_count, 1) catch
                return error.IntegerOverflow;
        } else {
            self.stored_block_count = std.math.add(usize, self.stored_block_count, 1) catch
                return error.IntegerOverflow;
        }
        self.phase = .output;
    }

    fn resetBlockHeader(self: *Decoder) void {
        self.block_header_len = 0;
        self.block_header_expected = 4;
        self.block_uncompressed_len = 0;
        self.block_payload_len = 0;
        self.block_checksums = .{};
    }

    fn recordError(self: *Decoder, phase: Phase, err: Error) void {
        self.last_error_name = @errorName(err);
        self.last_error_phase = phase;
    }

    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
    }
};

fn readBlockU32(bytes: *const [24]u8, offset: *usize) u32 {
    const value = std.mem.readInt(u32, bytes[offset.*..][0..4], .big);
    offset.* += 4;
    return value;
}
