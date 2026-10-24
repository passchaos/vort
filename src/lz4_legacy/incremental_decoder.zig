//! Block-bounded incremental decoder for the legacy LZ4 stream format.

const std = @import("std");
const core = @import("../core.zig");
const lz4 = @import("../lz4.zig");

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .magic,
    magic_bytes: [4]u8 = undefined,
    magic_len: usize = 0,
    block_header: [4]u8 = undefined,
    block_header_len: usize = 0,
    compressed_expected: usize = 0,
    compressed: std.ArrayList(u8) = .empty,
    decoded: std.ArrayList(u8) = .empty,
    decoded_offset: usize = 0,
    total_input: usize = 0,
    total_output: usize = 0,
    block_count: usize = 0,
    input_finished: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .magic,

    const magic = [_]u8{ 0x02, 0x21, 0x4c, 0x18 };
    const format_max_block_size: usize = 8 * 1024 * 1024;
    const format_max_compressed_block_size: usize = format_max_block_size +
        format_max_block_size / 255 + 16;

    pub const Error = core.Error || lz4.Error || std.mem.Allocator.Error || error{
        InvalidLz4LegacyStream,
    };
    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        max_compressed_block_len: usize = format_max_compressed_block_size,
        max_decoded_block_len: usize = format_max_block_size,
        expected_output_len: ?usize = null,
    };
    pub const Phase = enum { magic, block_header, payload, output, done };
    pub const Snapshot = struct {
        phase: Phase,
        magic_received: usize,
        block_header_received: usize,
        block_payload_received: usize,
        block_payload_expected: usize,
        pending_output: usize,
        input_read: usize,
        output_written: usize,
        block_count: usize,
        retained_compressed_capacity: usize,
        retained_decoded_capacity: usize,
        input_finished: bool,
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
        self.compressed.deinit(self.allocator);
        self.decoded.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Decoder) void {
        self.resetWithOptions(self.options);
    }

    pub fn resetWithOptions(self: *Decoder, options: Options) void {
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

    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .magic_received = self.magic_len,
            .block_header_received = self.block_header_len,
            .block_payload_received = self.compressed.items.len,
            .block_payload_expected = self.compressed_expected,
            .pending_output = self.decoded.items.len - self.decoded_offset,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .block_count = self.block_count,
            .retained_compressed_capacity = self.compressed.capacity,
            .retained_decoded_capacity = self.decoded.capacity,
            .input_finished = self.input_finished,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = @tagName(snap.phase),
            .header_received = if (snap.phase == .magic)
                snap.magic_received
            else
                snap.block_header_received,
            .frame_input_read = snap.input_read,
            .output_written = snap.output_written,
            .expected_output_len = core.stream_count.fromOptionalLocal(self.options.expected_output_len),
            .payload_remaining = snap.pending_output,
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0)
                ""
            else
                @tagName(snap.last_error_phase),
        };
    }

    /// Legacy LZ4 has no terminal marker; EOF is valid only immediately after
    /// the magic or a complete block.
    pub fn finish(self: *Decoder) void {
        self.input_finished = true;
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        return self.stepInner(input, output) catch |err| {
            self.last_error_name = @errorName(err);
            self.last_error_phase = self.phase;
            return err;
        };
    }

    fn stepInner(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.TrailingData;
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .magic => {
                const take = @min(magic.len - self.magic_len, input.len - input_read);
                @memcpy(
                    self.magic_bytes[self.magic_len..][0..take],
                    input[input_read..][0..take],
                );
                self.magic_len += take;
                input_read += take;
                try self.recordInput(take);
                if (self.magic_len != magic.len) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                if (!std.mem.eql(u8, &self.magic_bytes, &magic))
                    return error.InvalidMagic;
                self.phase = .block_header;
            },
            .block_header => {
                const take = @min(
                    self.block_header.len - self.block_header_len,
                    input.len - input_read,
                );
                @memcpy(
                    self.block_header[self.block_header_len..][0..take],
                    input[input_read..][0..take],
                );
                self.block_header_len += take;
                input_read += take;
                try self.recordInput(take);
                if (self.block_header_len != self.block_header.len) {
                    if (self.input_finished) {
                        if (self.block_header_len == 0) {
                            try self.complete();
                            return result(input_read, output_written, .done);
                        }
                        return error.TruncatedFrame;
                    }
                    return result(input_read, output_written, .need_input);
                }
                self.compressed_expected = std.mem.readInt(
                    u32,
                    &self.block_header,
                    .little,
                );
                if (self.compressed_expected == 0 or
                    self.compressed_expected > format_max_compressed_block_size)
                    return error.InvalidLz4LegacyStream;
                if (self.compressed_expected > self.options.max_compressed_block_len)
                    return error.OutputLimitExceeded;
                self.compressed.clearRetainingCapacity();
                try self.compressed.ensureTotalCapacityPrecise(
                    self.allocator,
                    self.compressed_expected,
                );
                self.phase = .payload;
            },
            .payload => {
                const take = @min(
                    self.compressed_expected - self.compressed.items.len,
                    input.len - input_read,
                );
                try self.compressed.appendSlice(
                    self.allocator,
                    input[input_read..][0..take],
                );
                input_read += take;
                try self.recordInput(take);
                if (self.compressed.items.len != self.compressed_expected) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                try self.decodeBlock();
                self.phase = .output;
            },
            .output => {
                const remaining = self.decoded.items[self.decoded_offset..];
                const take = @min(remaining.len, output.len - output_written);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.decoded_offset += take;
                output_written += take;
                try self.recordOutput(take);
                if (self.decoded_offset != self.decoded.items.len)
                    return result(input_read, output_written, .need_output);
                self.decoded.clearRetainingCapacity();
                self.decoded_offset = 0;
                self.compressed.clearRetainingCapacity();
                self.block_count = std.math.add(usize, self.block_count, 1) catch
                    return error.IntegerOverflow;
                self.block_header_len = 0;
                self.compressed_expected = 0;
                self.phase = .block_header;
            },
            .done => return result(input_read, output_written, .done),
        };
    }

    fn decodeBlock(self: *Decoder) Error!void {
        const remaining_limit = @min(
            self.options.max_decoded_block_len,
            self.options.max_output_len -| self.total_output,
        );
        const decoded_len = lz4.decodedBlockSizeLimited(
            self.compressed.items,
            remaining_limit,
        ) catch |err| switch (err) {
            error.OutputLimitExceeded => return error.OutputLimitExceeded,
            else => |decode_error| return decode_error,
        };
        if (decoded_len == 0 or decoded_len > format_max_block_size)
            return error.InvalidLz4LegacyStream;
        if (decoded_len > self.options.max_decoded_block_len)
            return error.OutputLimitExceeded;
        const next_output = std.math.add(usize, self.total_output, decoded_len) catch
            return error.IntegerOverflow;
        if (next_output > self.options.max_output_len) return error.OutputLimitExceeded;
        if (self.options.expected_output_len) |expected|
            if (next_output > expected) return error.SizeMismatch;
        try self.decoded.resize(self.allocator, decoded_len);
        errdefer self.decoded.clearRetainingCapacity();
        const written = try lz4.decodeBlockIntoSlice(
            self.compressed.items,
            self.decoded.items,
            decoded_len,
        );
        if (written != decoded_len) return error.SizeMismatch;
        self.decoded_offset = 0;
    }

    fn complete(self: *Decoder) Error!void {
        if (self.options.expected_output_len) |expected|
            if (self.total_output != expected) return error.SizeMismatch;
        self.phase = .done;
    }

    fn recordInput(self: *Decoder, count: usize) Error!void {
        self.total_input = std.math.add(usize, self.total_input, count) catch
            return error.IntegerOverflow;
    }

    fn recordOutput(self: *Decoder, count: usize) Error!void {
        self.total_output = std.math.add(usize, self.total_output, count) catch
            return error.IntegerOverflow;
        std.debug.assert(self.total_output <= self.options.max_output_len);
    }

    fn result(
        input_read: usize,
        output_written: usize,
        status: core.StepResult.Status,
    ) core.StepResult {
        return .{
            .progress = .{
                .input_read = input_read,
                .output_written = output_written,
            },
            .status = status,
        };
    }
};
