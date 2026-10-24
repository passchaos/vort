//! Block-bounded incremental decoder for standard LZF `ZV` streams.

const std = @import("std");
const core = @import("../core.zig");
const block = @import("block.zig");
const frame = @import("frame.zig");

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .header,
    header: [7]u8 = undefined,
    header_len: usize = 0,
    header_expected: usize = 3,
    kind: Kind = .stored,
    payload_expected: usize = 0,
    payload_read: usize = 0,
    decoded_expected: usize = 0,
    compressed: std.ArrayList(u8) = .empty,
    decoded: std.ArrayList(u8) = .empty,
    decoded_offset: usize = 0,
    total_input: usize = 0,
    total_output: usize = 0,
    block_count: usize = 0,
    stored_block_count: usize = 0,
    compressed_block_count: usize = 0,
    input_finished: bool = false,
    saw_eof_marker: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .header,

    const Kind = enum { stored, compressed };

    pub const Error = frame.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        max_compressed_block_len: usize = frame.max_block_size,
        max_decoded_block_len: usize = frame.max_block_size,
        expected_output_len: ?usize = null,
        /// Stop immediately after the optional zero EOF marker and preserve
        /// following caller input for an outer container.
        stop_after_eof_marker: bool = false,
    };
    pub const Phase = enum { header, payload, output, after_eof, done };
    pub const Snapshot = struct {
        phase: Phase,
        header_received: usize,
        header_expected: usize,
        payload_received: usize,
        payload_expected: usize,
        pending_output: usize,
        input_read: usize,
        output_written: usize,
        block_count: usize,
        stored_block_count: usize,
        compressed_block_count: usize,
        retained_compressed_capacity: usize,
        retained_decoded_capacity: usize,
        input_finished: bool,
        saw_eof_marker: bool,
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
            .header_received = self.header_len,
            .header_expected = self.header_expected,
            .payload_received = self.payload_read,
            .payload_expected = self.payload_expected,
            .pending_output = self.decoded.items.len - self.decoded_offset,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .block_count = self.block_count,
            .stored_block_count = self.stored_block_count,
            .compressed_block_count = self.compressed_block_count,
            .retained_compressed_capacity = self.compressed.capacity,
            .retained_decoded_capacity = self.decoded.capacity,
            .input_finished = self.input_finished,
            .saw_eof_marker = self.saw_eof_marker,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = @tagName(snap.phase),
            .header_received = snap.header_received,
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

    /// Declares EOF. Pending decoded bytes may still be drained through
    /// `step("", output)` before `.done` is returned.
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
            .header => {
                if (self.header_len == 0 and input_read < input.len and input[input_read] == 0) {
                    input_read += 1;
                    try self.recordInput(1);
                    self.saw_eof_marker = true;
                    self.phase = if (self.options.stop_after_eof_marker)
                        .done
                    else
                        .after_eof;
                    continue;
                }
                const take = @min(
                    self.header_expected - self.header_len,
                    input.len - input_read,
                );
                @memcpy(
                    self.header[self.header_len..][0..take],
                    input[input_read..][0..take],
                );
                self.header_len += take;
                input_read += take;
                try self.recordInput(take);
                if (self.header_len != self.header_expected) {
                    if (self.input_finished) {
                        if (self.header_len == 0) {
                            try self.complete();
                            return result(input_read, output_written, .done);
                        }
                        return error.TruncatedFrame;
                    }
                    return result(input_read, output_written, .need_input);
                }
                if (self.header_expected == 3) {
                    if (!std.mem.eql(u8, self.header[0..2], "ZV"))
                        return error.InvalidMagic;
                    self.kind = switch (self.header[2]) {
                        0 => .stored,
                        1 => .compressed,
                        else => return error.UnsupportedLzfFeature,
                    };
                    self.header_expected = if (self.kind == .stored) 5 else 7;
                    continue;
                }
                try self.acceptHeader();
                self.phase = .payload;
            },
            .payload => switch (self.kind) {
                .stored => {
                    const remaining = self.payload_expected - self.payload_read;
                    const take = @min(
                        @min(remaining, input.len - input_read),
                        output.len - output_written,
                    );
                    @memcpy(
                        output[output_written..][0..take],
                        input[input_read..][0..take],
                    );
                    input_read += take;
                    output_written += take;
                    self.payload_read += take;
                    try self.recordInput(take);
                    try self.recordOutput(take);
                    if (self.payload_read != self.payload_expected) {
                        if (output_written == output.len)
                            return result(input_read, output_written, .need_output);
                        if (self.input_finished) return error.TruncatedFrame;
                        return result(input_read, output_written, .need_input);
                    }
                    try self.completeBlock();
                },
                .compressed => {
                    const take = @min(
                        self.payload_expected - self.payload_read,
                        input.len - input_read,
                    );
                    try self.compressed.appendSlice(
                        self.allocator,
                        input[input_read..][0..take],
                    );
                    input_read += take;
                    self.payload_read += take;
                    try self.recordInput(take);
                    if (self.payload_read != self.payload_expected) {
                        if (self.input_finished) return error.TruncatedFrame;
                        return result(input_read, output_written, .need_input);
                    }
                    try self.decodeCompressedBlock();
                    self.phase = .output;
                },
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
                try self.completeBlock();
            },
            .after_eof => {
                if (input_read != input.len) return error.TrailingData;
                if (!self.input_finished)
                    return result(input_read, output_written, .need_input);
                try self.complete();
                return result(input_read, output_written, .done);
            },
            .done => return result(input_read, output_written, .done),
        };
    }

    fn acceptHeader(self: *Decoder) Error!void {
        self.payload_expected = std.mem.readInt(u16, self.header[3..5], .big);
        self.decoded_expected = switch (self.kind) {
            .stored => self.payload_expected,
            .compressed => std.mem.readInt(u16, self.header[5..7], .big),
        };
        if (self.kind == .compressed and
            (self.payload_expected == 0 or self.decoded_expected == 0))
            return error.InvalidLzfStream;
        if (self.payload_expected > self.options.max_compressed_block_len or
            self.decoded_expected > self.options.max_decoded_block_len)
            return error.OutputLimitExceeded;
        try self.checkOutputAddition(self.decoded_expected);
        self.payload_read = 0;
        self.compressed.clearRetainingCapacity();
        if (self.kind == .compressed)
            try self.compressed.ensureTotalCapacityPrecise(
                self.allocator,
                self.payload_expected,
            );
    }

    fn decodeCompressedBlock(self: *Decoder) Error!void {
        const actual = try block.decodedSizeLimited(
            self.compressed.items,
            self.options.max_decoded_block_len,
        );
        if (actual != self.decoded_expected) return error.SizeMismatch;
        try self.decoded.resize(self.allocator, self.decoded_expected);
        errdefer self.decoded.clearRetainingCapacity();
        const written = try block.decodeInto(self.compressed.items, self.decoded.items);
        if (written != self.decoded.items.len) return error.SizeMismatch;
        self.compressed.clearRetainingCapacity();
        self.decoded_offset = 0;
    }

    fn completeBlock(self: *Decoder) Error!void {
        self.block_count = std.math.add(usize, self.block_count, 1) catch
            return error.IntegerOverflow;
        switch (self.kind) {
            .stored => self.stored_block_count = std.math.add(
                usize,
                self.stored_block_count,
                1,
            ) catch return error.IntegerOverflow,
            .compressed => self.compressed_block_count = std.math.add(
                usize,
                self.compressed_block_count,
                1,
            ) catch return error.IntegerOverflow,
        }
        self.header_len = 0;
        self.header_expected = 3;
        self.payload_expected = 0;
        self.payload_read = 0;
        self.decoded_expected = 0;
        self.phase = .header;
    }

    fn checkOutputAddition(self: *const Decoder, additional: usize) Error!void {
        const next = std.math.add(usize, self.total_output, additional) catch
            return error.IntegerOverflow;
        if (next > self.options.max_output_len) return error.OutputLimitExceeded;
        if (self.options.expected_output_len) |expected|
            if (next > expected) return error.SizeMismatch;
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
