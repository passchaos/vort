const std = @import("std");
const checksum = @import("../../checksum.zig");
const core = @import("../../core.zig");
const terminal = @import("terminal_byte_codec.zig");
const descriptor = @import("descriptor.zig");
const dcl_implode = @import("../dcl_implode.zig");

pub const Error = dcl_implode.Error || error{ InvalidZipArchive, SizeMismatch, IntegerOverflow };

pub const State = struct {
    decoder: dcl_implode.IncrementalDecoder,
    descriptor_layout: ?descriptor.Layout,
    expected_compressed_size: ?core.StreamCount,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: core.StreamCount = 0,
    uncompressed_size: core.StreamCount = 0,
    last_step_progress: core.Progress = .{},

    const Self = @This();

    pub fn init(
        entry_limit: core.StreamCount,
        expected_compressed_size: ?core.StreamCount,
        expected_uncompressed_size: ?core.StreamCount,
        descriptor_layout: ?descriptor.Layout,
    ) Error!Self {
        return .{
            .decoder = dcl_implode.IncrementalDecoder.initWithOptions(.{
                .max_output_len = core.stream_count.bounded(entry_limit, std.math.maxInt(usize)),
                .expected_output_len = try terminal.toOptionalLocal(expected_uncompressed_size),
                .allow_trailing_data = true,
            }),
            .descriptor_layout = descriptor_layout,
            .expected_compressed_size = expected_compressed_size,
        };
    }

    pub fn deinit(_: *Self) void {}

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        var progress: core.Progress = .{};
        defer self.last_step_progress = progress;
        const drained = try self.decode("", output, &progress);
        try self.account(drained.progress, output, &progress);
        if (drained.status == .done or drained.status == .need_output)
            return .{ .progress = progress, .status = drained.status };
        const offer_len = try inputOffer(
            self.descriptor_layout,
            self.expected_compressed_size,
            self.compressed_size,
            input.len,
        );
        if (offer_len == 0) {
            if (input.len == 0) return .{ .progress = progress, .status = .need_input };
            try self.decoder.finish();
            return error.TruncatedDclInput;
        }
        const output_offset = drained.progress.output_written;
        const supplied = try self.decode(input[0..offer_len], output[output_offset..], &progress);
        try self.account(supplied.progress, output[output_offset..], &progress);
        return .{ .progress = progress, .status = supplied.status };
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
        return terminal.decode(Error, self, &self.decoder, input, output, aggregate, Self.account);
    }

    fn account(self: *Self, progress: core.Progress, output: []const u8, aggregate: *core.Progress) Error!void {
        self.compressed_size = try core.stream_count.addLocal(self.compressed_size, progress.input_read);
        self.uncompressed_size = try core.stream_count.addLocal(self.uncompressed_size, progress.output_written);
        self.crc.update(output[0..progress.output_written]);
        aggregate.input_read = std.math.add(usize, aggregate.input_read, progress.input_read) catch return error.IntegerOverflow;
        aggregate.output_written = std.math.add(usize, aggregate.output_written, progress.output_written) catch return error.IntegerOverflow;
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
