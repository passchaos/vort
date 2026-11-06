const std = @import("std");
const api = @import("api.zig");
const checksum = @import("../../checksum.zig");
const core = @import("../../core.zig");
const terminal = @import("terminal_byte_codec.zig");
const descriptor = @import("descriptor.zig");
const ppmd8 = @import("../../ppmd8.zig");

pub const Error = ppmd8.Error || error{ InvalidZipArchive, SizeMismatch, IntegerOverflow };

pub const State = struct {
    allocator: std.mem.Allocator,
    reader_options: api.Options,
    entry_limit: core.StreamCount,
    descriptor_layout: ?descriptor.Layout,
    expected_compressed_size: ?core.StreamCount,
    expected_uncompressed_size: ?core.StreamCount,
    properties_bytes: [2]u8 = undefined,
    properties_len: usize = 0,
    decoder: ?ppmd8.IncrementalDecoder = null,
    finish_requested: bool = false,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: core.StreamCount = 0,
    uncompressed_size: core.StreamCount = 0,
    last_step_progress: core.Progress = .{},

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        reader_options: api.Options,
        entry_limit: core.StreamCount,
        expected_compressed_size: ?core.StreamCount,
        expected_uncompressed_size: ?core.StreamCount,
        descriptor_layout: ?descriptor.Layout,
    ) Self {
        return .{
            .allocator = allocator,
            .reader_options = reader_options,
            .entry_limit = entry_limit,
            .descriptor_layout = descriptor_layout,
            .expected_compressed_size = expected_compressed_size,
            .expected_uncompressed_size = expected_uncompressed_size,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.decoder) |*active| active.deinit();
        self.* = undefined;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        var progress: core.Progress = .{};
        defer self.last_step_progress = progress;
        if (self.decoder == null) {
            const limited_input = core.stream_count.bounded(std.math.maxInt(core.StreamCount) - self.compressed_size, input.len);
            const available = if (self.expected_compressed_size) |expected|
                core.stream_count.bounded(expected -| self.compressed_size, limited_input)
            else
                limited_input;
            const take = @min(self.properties_bytes.len - self.properties_len, available);
            @memcpy(self.properties_bytes[self.properties_len..][0..take], input[0..take]);
            self.properties_len += take;
            self.compressed_size = try core.stream_count.addLocal(self.compressed_size, take);
            progress.input_read += take;
            if (self.properties_len != self.properties_bytes.len) {
                if (limited_input != input.len) return error.IntegerOverflow;
                if (take == 0 and self.expected_compressed_size == self.compressed_size)
                    return error.TruncatedPpmdInput;
                return .{ .progress = progress, .status = .need_input };
            }
            const properties = try ppmd8.parseZipProperties(&self.properties_bytes);
            if (properties.memory_size > self.reader_options.max_ppmd_memory_size)
                return error.OutputLimitExceeded;
            self.decoder = try ppmd8.IncrementalDecoder.init(
                self.allocator,
                properties.order,
                properties.memory_size,
                properties.restore_method,
                .{
                    .max_output_len = core.stream_count.bounded(self.entry_limit, std.math.maxInt(usize)),
                    .max_compressed_buffer_len = self.reader_options.max_ppmd_compressed_buffer_len,
                    .expected_output_len = try terminal.toOptionalLocal(self.expected_uncompressed_size),
                },
            );
        }

        if (self.expected_compressed_size) |expected| {
            if (self.compressed_size == expected and !self.finish_requested) {
                self.decoder.?.finish();
                self.finish_requested = true;
            }
        }
        const remaining_input = input[progress.input_read..];
        const offer_len = try inputOffer(
            self.descriptor_layout,
            self.expected_compressed_size,
            self.compressed_size,
            remaining_input.len,
        );
        const stepped = try self.decode(remaining_input[0..offer_len], output, &progress);
        try self.account(stepped.progress, output, &progress);
        return .{ .progress = progress, .status = stepped.status };
    }

    pub fn layout(self: *const Self) ?descriptor.Layout {
        return self.descriptor_layout;
    }
    pub fn trailingInput(_: *const Self) []const u8 {
        return &.{};
    }
    pub fn actualCompressedSize(self: *const Self) Error!core.StreamCount {
        return self.compressed_size;
    }
    pub fn outputSize(self: *const Self) core.StreamCount {
        return self.uncompressed_size;
    }
    pub fn crc32(self: *const Self) u32 {
        return self.crc.digest();
    }

    fn decode(self: *Self, input: []const u8, output: []u8, aggregate: *core.Progress) Error!core.StepResult {
        return terminal.decode(Error, self, &self.decoder.?, input, output, aggregate, Self.account);
    }

    fn account(self: *Self, progress: core.Progress, output: []const u8, aggregate: *core.Progress) Error!void {
        self.compressed_size = try core.stream_count.addLocal(self.compressed_size, progress.input_read);
        self.uncompressed_size = try core.stream_count.addLocal(self.uncompressed_size, progress.output_written);
        self.crc.update(output[0..progress.output_written]);
        aggregate.input_read = try checkedAdd(aggregate.input_read, progress.input_read);
        aggregate.output_written = try checkedAdd(aggregate.output_written, progress.output_written);
    }
};

fn inputOffer(
    layout: ?descriptor.Layout,
    expected_compressed_size: ?core.StreamCount,
    accepted_input: core.StreamCount,
    available_input: usize,
) Error!usize {
    if (layout) |descriptor_layout|
        return @min(available_input, descriptor_layout.unsignedLen());
    const expected = expected_compressed_size orelse return available_input;
    if (accepted_input > expected) return error.SizeMismatch;
    return core.stream_count.bounded(expected - accepted_input, available_input);
}

fn checkedAdd(a: usize, b: usize) error{IntegerOverflow}!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}
