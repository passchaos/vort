const std = @import("std");
const bit_writer = @import("bit_writer.zig");
const bzip2_crc = @import("crc.zig");
const core = @import("../core.zig");
const encoder = @import("encoder.zig");

/// Block-bounded Bzip2 encoder. RLE1 runs and the partially filled MSB-first
/// output byte survive arbitrary caller input/output boundaries, making the
/// no-flush wire independent of how input is fragmented.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    block_limit: usize,
    rle_block: std.ArrayList(u8) = .empty,
    block_crc: bzip2_crc.Crc32 = .{},
    run_byte: ?u8 = null,
    run_len: usize = 0,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    bit_current: u8 = 0,
    bit_used: u4 = 0,
    combined_crc: u32 = 0,
    header_written: bool = false,
    footer_written: bool = false,
    flush_requested: bool = false,
    finishing: bool = false,
    done: bool = false,
    expected_input_len: ?usize = null,
    current_input: usize = 0,
    current_output: usize = 0,
    total_input: usize = 0,
    total_output: usize = 0,
    stream_count: usize = 0,
    block_count: usize = 0,

    pub const Error = encoder.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        block_size_100k: u4 = 9,
        max_input_len: usize = std.math.maxInt(usize),
        max_pending_output_len: usize = 4 * 1024 * 1024,
    };
    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        current_input: usize,
        current_output: usize,
        buffered_rle_bytes: usize,
        buffered_run_bytes: usize,
        pending_output: usize,
        block_count: usize,
        stream_count: usize,
        stream_index: usize,
        flush_requested: bool,
        finishing: bool,
        done: bool,
        retained_rle_capacity: usize,
        retained_output_capacity: usize,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Encoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Encoder {
        try validateOptions(options);
        return .{
            .allocator = allocator,
            .options = options,
            .block_limit = @as(usize, options.block_size_100k) * 100_000,
        };
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) Error!Encoder {
        var state = try initWithOptions(allocator, options);
        state.expected_input_len = expected_input_len;
        return state;
    }

    pub fn deinit(self: *Encoder) void {
        self.rle_block.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Encoder) void {
        self.total_input = 0;
        self.total_output = 0;
        self.stream_count = 0;
        self.block_count = 0;
        self.resetStream(self.options, self.expected_input_len);
    }

    pub fn nextStream(self: *Encoder, options: Options) Error!void {
        if (!self.done or self.pending_offset != self.pending.items.len)
            return error.InvalidBlockPlan;
        try validateOptions(options);
        self.resetStream(options, null);
    }

    pub fn nextStreamExactSize(
        self: *Encoder,
        options: Options,
        expected_input_len: usize,
    ) Error!void {
        if (!self.done or self.pending_offset != self.pending.items.len)
            return error.InvalidBlockPlan;
        try validateOptions(options);
        self.resetStream(options, expected_input_len);
    }

    fn resetStream(self: *Encoder, options: Options, expected_input_len: ?usize) void {
        self.options = options;
        self.block_limit = @as(usize, options.block_size_100k) * 100_000;
        self.rle_block.clearRetainingCapacity();
        self.block_crc = .{};
        self.run_byte = null;
        self.run_len = 0;
        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        self.bit_current = 0;
        self.bit_used = 0;
        self.combined_crc = 0;
        self.header_written = false;
        self.footer_written = false;
        self.flush_requested = false;
        self.finishing = false;
        self.done = false;
        self.expected_input_len = expected_input_len;
        self.current_input = 0;
        self.current_output = 0;
    }

    pub fn snapshot(self: *const Encoder) Snapshot {
        return .{
            .input_read = self.total_input,
            .output_written = self.total_output,
            .current_input = self.current_input,
            .current_output = self.current_output,
            .buffered_rle_bytes = self.rle_block.items.len,
            .buffered_run_bytes = self.run_len,
            .pending_output = self.pending.items.len - self.pending_offset,
            .block_count = self.block_count,
            .stream_count = self.stream_count,
            .stream_index = if (self.done and self.stream_count != 0) self.stream_count - 1 else self.stream_count,
            .flush_requested = self.flush_requested,
            .finishing = self.finishing,
            .done = self.done,
            .retained_rle_capacity = self.rle_block.capacity,
            .retained_output_capacity = self.pending.capacity,
        };
    }

    pub fn flush(self: *Encoder) void {
        if (!self.finishing and !self.done) self.flush_requested = true;
    }

    pub fn finish(self: *Encoder) void {
        if (!self.done) {
            self.finishing = true;
            self.flush_requested = false;
        }
    }

    pub fn step(self: *Encoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if ((self.flush_requested or self.finishing) and input.len != 0)
            return error.TrailingData;

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.pending_offset != self.pending.items.len) {
                const remaining = self.pending.items[self.pending_offset..];
                const take = @min(output.len - output_written, remaining.len);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.pending_offset += take;
                output_written += take;
                self.current_output = std.math.add(usize, self.current_output, take) catch
                    return error.IntegerOverflow;
                self.total_output = std.math.add(usize, self.total_output, take) catch
                    return error.IntegerOverflow;
                if (self.pending_offset != self.pending.items.len)
                    return result(input_read, output_written, .need_output);
                self.pending.clearRetainingCapacity();
                self.pending_offset = 0;
            }

            if (!self.header_written) {
                try self.pending.appendSlice(self.allocator, "BZh");
                try self.pending.append(self.allocator, '0' + @as(u8, self.options.block_size_100k));
                try self.checkPendingLimit();
                self.header_written = true;
                continue;
            }

            if (input_read < input.len) {
                const byte = input[input_read];
                if (self.run_byte) |run_byte| {
                    if (byte != run_byte) {
                        if (try self.commitRunGroup(true)) continue;
                        continue;
                    }
                    try self.acceptInputByte();
                    self.run_len += 1;
                    input_read += 1;
                    if (self.run_len == 259) {
                        if (try self.commitRunGroup(false)) continue;
                    }
                    continue;
                }
                try self.acceptInputByte();
                self.run_byte = byte;
                self.run_len = 1;
                input_read += 1;
                continue;
            }

            if (self.flush_requested or self.finishing) {
                if (self.expected_input_len) |expected|
                    if (self.finishing and self.current_input != expected)
                        return error.SizeMismatch;
                if (self.run_len != 0) {
                    if (try self.commitRunGroup(true)) continue;
                    continue;
                }
                if (self.rle_block.items.len != 0) {
                    try self.emitBlock();
                    continue;
                }
                if (self.flush_requested) {
                    self.flush_requested = false;
                    return result(input_read, output_written, .need_input);
                }
                if (!self.footer_written) {
                    var writer = self.bitWriter();
                    try encoder.writeStreamEnd(&writer, self.combined_crc);
                    self.saveBitWriter(writer);
                    try self.checkPendingLimit();
                    self.footer_written = true;
                    continue;
                }
                self.done = true;
                self.stream_count = std.math.add(usize, self.stream_count, 1) catch
                    return error.IntegerOverflow;
                return result(input_read, output_written, .done);
            }

            return result(input_read, output_written, .need_input);
        }
    }

    fn acceptInputByte(self: *Encoder) Error!void {
        if (self.current_input >= self.options.max_input_len)
            return error.OutputLimitExceeded;
        if (self.expected_input_len) |expected|
            if (self.current_input >= expected) return error.SizeMismatch;
        self.current_input = std.math.add(usize, self.current_input, 1) catch
            return error.IntegerOverflow;
        self.total_input = std.math.add(usize, self.total_input, 1) catch
            return error.IntegerOverflow;
    }

    /// Commit one complete 259-byte group, or the final shorter group. Returns
    /// true when the existing block had to be emitted before the run fits.
    fn commitRunGroup(self: *Encoder, final_group: bool) Error!bool {
        if (self.run_len == 0) return false;
        if (!final_group and self.run_len < 259) return false;
        const group_len = if (self.run_len >= 259) @as(usize, 259) else self.run_len;
        const encoded_len: usize = if (group_len < 4) group_len else 5;
        if (self.rle_block.items.len + encoded_len > self.block_limit) {
            if (self.rle_block.items.len == 0) return error.InvalidBzip2Stream;
            try self.emitBlock();
            return true;
        }
        try self.rle_block.ensureTotalCapacityPrecise(self.allocator, self.block_limit);
        const byte = self.run_byte orelse return error.InvalidBzip2Stream;
        if (group_len < 4) {
            for (0..group_len) |_| self.rle_block.appendAssumeCapacity(byte);
        } else {
            for (0..4) |_| self.rle_block.appendAssumeCapacity(byte);
            self.rle_block.appendAssumeCapacity(@intCast(group_len - 4));
        }
        self.block_crc.updateRepeat(byte, group_len);
        self.run_len -= group_len;
        if (self.run_len == 0) self.run_byte = null;
        return false;
    }

    fn emitBlock(self: *Encoder) Error!void {
        if (self.rle_block.items.len == 0) return error.InvalidBzip2Stream;
        const transformed = try encoder.bwtTransformAlloc(self.allocator, self.rle_block.items);
        defer transformed.deinit(self.allocator);
        const crc = self.block_crc.digest();
        var writer = self.bitWriter();
        try encoder.writeBlock(&writer, transformed, crc);
        self.saveBitWriter(writer);
        try self.checkPendingLimit();
        self.combined_crc = std.math.rotl(u32, self.combined_crc, 1) ^ crc;
        self.rle_block.clearRetainingCapacity();
        self.block_crc = .{};
        self.block_count = std.math.add(usize, self.block_count, 1) catch
            return error.IntegerOverflow;
    }

    fn bitWriter(self: *Encoder) bit_writer.BitWriter {
        var writer = bit_writer.BitWriter.init(self.allocator, &self.pending);
        writer.current = self.bit_current;
        writer.used = self.bit_used;
        return writer;
    }

    fn saveBitWriter(self: *Encoder, writer: bit_writer.BitWriter) void {
        self.bit_current = writer.current;
        self.bit_used = writer.used;
    }

    fn checkPendingLimit(self: *const Encoder) Error!void {
        if (self.pending.items.len > self.options.max_pending_output_len)
            return error.OutputLimitExceeded;
    }

    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
    }
};

fn validateOptions(options: Encoder.Options) Encoder.Error!void {
    if (options.block_size_100k < 1 or options.block_size_100k > 9)
        return error.InvalidBzip2Header;
    if (options.max_pending_output_len == 0) return error.OutputLimitExceeded;
}
