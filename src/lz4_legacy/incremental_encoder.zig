//! Block-bounded incremental encoder for the legacy LZ4 stream format.

const std = @import("std");
const core = @import("../core.zig");
const lz4 = @import("../lz4.zig");

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    block_encoder: lz4.BlockEncoder,
    plain: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    magic_written: bool = false,
    finishing: bool = false,
    done: bool = false,
    expected_input_len: ?usize = null,
    total_input: usize = 0,
    total_output: usize = 0,
    block_count: usize = 0,

    const magic = [_]u8{ 0x02, 0x21, 0x4c, 0x18 };
    const format_max_block_size: usize = 8 * 1024 * 1024;
    const format_max_compressed_block_size: usize = format_max_block_size +
        format_max_block_size / 255 + 16;

    pub const Error = core.Error || lz4.Error || std.mem.Allocator.Error || error{
        InvalidLz4LegacyStream,
    };
    pub const Options = struct {
        block_size: usize = format_max_block_size,
        max_input_len: usize = std.math.maxInt(usize),
        max_pending_output_len: usize = format_max_compressed_block_size + 4,
    };
    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        buffered_input: usize,
        pending_output: usize,
        block_count: usize,
        magic_written: bool,
        finishing: bool,
        done: bool,
        retained_input_capacity: usize,
        retained_output_capacity: usize,
        retained_block_scratch_capacity: usize,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Encoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Encoder {
        try validateOptions(options);
        return .{
            .allocator = allocator,
            .options = options,
            .block_encoder = try lz4.BlockEncoder.init(allocator),
        };
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) Error!Encoder {
        var encoder = try initWithOptions(allocator, options);
        errdefer encoder.deinit();
        if (expected_input_len > options.max_input_len)
            return error.OutputLimitExceeded;
        encoder.expected_input_len = expected_input_len;
        return encoder;
    }

    pub fn deinit(self: *Encoder) void {
        self.block_encoder.deinit();
        self.plain.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Encoder) void {
        const allocator = self.allocator;
        const options = self.options;
        const expected = self.expected_input_len;
        var block_encoder = self.block_encoder;
        var plain = self.plain;
        var pending = self.pending;
        plain.clearRetainingCapacity();
        pending.clearRetainingCapacity();
        block_encoder.output_scratch.clearRetainingCapacity();
        self.* = .{
            .allocator = allocator,
            .options = options,
            .expected_input_len = expected,
            .block_encoder = block_encoder,
            .plain = plain,
            .pending = pending,
        };
    }

    pub fn snapshot(self: *const Encoder) Snapshot {
        return .{
            .input_read = self.total_input,
            .output_written = self.total_output,
            .buffered_input = self.plain.items.len,
            .pending_output = self.pending.items.len - self.pending_offset,
            .block_count = self.block_count,
            .magic_written = self.magic_written,
            .finishing = self.finishing,
            .done = self.done,
            .retained_input_capacity = self.plain.capacity,
            .retained_output_capacity = self.pending.capacity,
            .retained_block_scratch_capacity = self.block_encoder.output_scratch.capacity,
        };
    }

    pub fn finish(self: *Encoder) void {
        if (!self.done) self.finishing = true;
    }

    pub fn step(self: *Encoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.finishing and input.len != 0) return error.TrailingData;
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.pending_offset != self.pending.items.len) {
                const remaining = self.pending.items[self.pending_offset..];
                const take = @min(remaining.len, output.len - output_written);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.pending_offset += take;
                output_written += take;
                self.total_output = try checkedAdd(self.total_output, take);
                if (self.pending_offset != self.pending.items.len)
                    return result(input_read, output_written, .need_output);
                self.pending.clearRetainingCapacity();
                self.pending_offset = 0;
                if (output_written == output.len and output.len != 0)
                    return result(input_read, output_written, .need_output);
            }
            if (!self.magic_written) {
                try self.pending.appendSlice(self.allocator, &magic);
                try self.checkPendingLimit();
                self.magic_written = true;
                continue;
            }
            if (input_read < input.len) {
                const room = self.options.block_size - self.plain.items.len;
                const take = @min(room, input.len - input_read);
                const next_input = try checkedAdd(self.total_input, take);
                if (next_input > self.options.max_input_len)
                    return error.OutputLimitExceeded;
                if (self.expected_input_len) |expected|
                    if (next_input > expected) return error.SizeMismatch;
                try self.plain.appendSlice(
                    self.allocator,
                    input[input_read..][0..take],
                );
                input_read += take;
                self.total_input = next_input;
            }
            if (self.plain.items.len == self.options.block_size) {
                try self.emitBlock();
                continue;
            }
            if (input_read != input.len) continue;
            if (self.finishing) {
                if (self.expected_input_len) |expected|
                    if (self.total_input != expected) return error.SizeMismatch;
                if (self.plain.items.len != 0) {
                    try self.emitBlock();
                    continue;
                }
                self.done = true;
                return result(input_read, output_written, .done);
            }
            return result(input_read, output_written, .need_input);
        }
    }

    fn emitBlock(self: *Encoder) Error!void {
        std.debug.assert(self.plain.items.len != 0);
        const compressed = try self.block_encoder.encodeScratch(self.plain.items);
        if (compressed.len == 0 or compressed.len > format_max_compressed_block_size)
            return error.InvalidLz4LegacyStream;
        var header: [4]u8 = undefined;
        std.mem.writeInt(
            u32,
            &header,
            std.math.cast(u32, compressed.len) orelse return error.IntegerOverflow,
            .little,
        );
        try self.pending.appendSlice(self.allocator, &header);
        try self.pending.appendSlice(self.allocator, compressed);
        try self.checkPendingLimit();
        self.block_count = try checkedAdd(self.block_count, 1);
        self.plain.clearRetainingCapacity();
    }

    fn checkPendingLimit(self: *const Encoder) Error!void {
        if (self.pending.items.len - self.pending_offset >
            self.options.max_pending_output_len)
            return error.OutputLimitExceeded;
    }

    fn validateOptions(options: Options) Error!void {
        if (options.block_size == 0 or options.block_size > format_max_block_size or
            options.max_pending_output_len == 0)
            return error.InvalidLz4LegacyStream;
    }

    fn checkedAdd(a: usize, b: usize) Error!usize {
        return std.math.add(usize, a, b) catch error.IntegerOverflow;
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
