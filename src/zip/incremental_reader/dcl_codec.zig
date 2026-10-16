const std = @import("std");
const checksum = @import("../../checksum.zig");
const core = @import("../../core.zig");
const descriptor = @import("descriptor.zig");
const dcl_implode = @import("../dcl_implode.zig");

pub const Error = dcl_implode.Error || error{ InvalidZipArchive, SizeMismatch };

pub const State = struct {
    decoder: dcl_implode.IncrementalDecoder,
    descriptor_layout: ?descriptor.Layout,
    expected_compressed_size: ?usize,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: usize = 0,
    uncompressed_size: usize = 0,

    const Self = @This();

    pub fn init(
        entry_limit: usize,
        expected_compressed_size: ?usize,
        expected_uncompressed_size: ?usize,
        descriptor_layout: ?descriptor.Layout,
    ) Self {
        return .{
            .decoder = dcl_implode.IncrementalDecoder.initWithOptions(.{
                .max_output_len = entry_limit,
                .expected_output_len = expected_uncompressed_size,
                .allow_trailing_data = true,
            }),
            .descriptor_layout = descriptor_layout,
            .expected_compressed_size = expected_compressed_size,
        };
    }

    pub fn deinit(_: *Self) void {}

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        var progress: core.Progress = .{};
        const drained = try self.decoder.step("", output);
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
        const supplied = try self.decoder.step(input[0..offer_len], output[output_offset..]);
        try self.account(supplied.progress, output[output_offset..], &progress);
        return .{ .progress = progress, .status = supplied.status };
    }

    pub fn layout(self: *const Self) ?descriptor.Layout {
        return self.descriptor_layout;
    }
    pub fn trailingInput(_: *const Self) []const u8 {
        return &.{};
    }
    pub fn actualCompressedSize(self: *const Self) Error!usize {
        return self.compressed_size;
    }
    pub fn outputSize(self: *const Self) usize {
        return self.uncompressed_size;
    }
    pub fn crc32(self: *const Self) u32 {
        return self.crc.digest();
    }

    fn account(self: *Self, progress: core.Progress, output: []const u8, aggregate: *core.Progress) Error!void {
        self.compressed_size = std.math.add(usize, self.compressed_size, progress.input_read) catch return error.IntegerOverflow;
        self.uncompressed_size = std.math.add(usize, self.uncompressed_size, progress.output_written) catch return error.IntegerOverflow;
        self.crc.update(output[0..progress.output_written]);
        aggregate.input_read = std.math.add(usize, aggregate.input_read, progress.input_read) catch return error.IntegerOverflow;
        aggregate.output_written = std.math.add(usize, aggregate.output_written, progress.output_written) catch return error.IntegerOverflow;
    }
};

fn inputOffer(
    layout: ?descriptor.Layout,
    expected_compressed_size: ?usize,
    accepted_input: usize,
    available_input: usize,
) Error!usize {
    if (layout) |descriptor_layout|
        return @min(available_input, descriptor_layout.unsignedLen());
    const expected = expected_compressed_size orelse return available_input;
    if (accepted_input > expected) return error.SizeMismatch;
    return @min(available_input, expected - accepted_input);
}
