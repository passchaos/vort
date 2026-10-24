const std = @import("std");
const core = @import("../../core.zig");
const ppmd8 = @import("../../ppmd8.zig");

pub const Error = ppmd8.Error || ppmd8.IncrementalEncoder.Error;

pub const Options = struct {
    properties: ppmd8.ZipProperties = .{},
    max_input_len: usize = std.math.maxInt(usize),
    max_pending_output_len: usize = 1024 * 1024,
};

pub fn validateOptions(options: Options, expected_size: ?u64) Error!void {
    try ppmd8.validateZipProperties(options.properties);
    if (options.max_pending_output_len == 0) return error.OutputLimitExceeded;
    if (expected_size) |expected| {
        const expected_usize = std.math.cast(usize, expected) orelse
            return error.OutputLimitExceeded;
        if (expected_usize > options.max_input_len)
            return error.OutputLimitExceeded;
    }
}

pub const State = struct {
    encoder: ppmd8.IncrementalEncoder,
    prefix: [2]u8,
    prefix_offset: usize = 0,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        options: Options,
        expected_size: ?u64,
    ) Error!Self {
        try validateOptions(options, expected_size);
        var prefix: [2]u8 = undefined;
        std.mem.writeInt(
            u16,
            &prefix,
            try ppmd8.propertyValue(options.properties),
            .little,
        );
        const encoder_options: ppmd8.IncrementalEncoder.Options = .{
            .max_input_len = options.max_input_len,
            .max_pending_output_len = options.max_pending_output_len,
        };
        const encoder = if (expected_size) |expected|
            try ppmd8.IncrementalEncoder.initExactSize(
                allocator,
                options.properties.order,
                options.properties.memory_size,
                options.properties.restore_method,
                encoder_options,
                @intCast(expected),
            )
        else
            try ppmd8.IncrementalEncoder.initWithOptions(
                allocator,
                options.properties.order,
                options.properties.memory_size,
                options.properties.restore_method,
                encoder_options,
            );
        return .{ .encoder = encoder, .prefix = prefix };
    }

    pub fn deinit(self: *Self) void {
        self.encoder.deinit();
        self.* = undefined;
    }

    pub fn finish(self: *Self) void {
        self.encoder.finish();
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        var output_written: usize = 0;
        if (self.prefix_offset != self.prefix.len) {
            const take = @min(self.prefix.len - self.prefix_offset, output.len);
            @memcpy(output[0..take], self.prefix[self.prefix_offset..][0..take]);
            self.prefix_offset += take;
            output_written += take;
            if (self.prefix_offset != self.prefix.len)
                return result(0, output_written, .need_output);
        }
        const encoded = try self.encoder.step(input, output[output_written..]);
        output_written += encoded.progress.output_written;
        return result(encoded.progress.input_read, output_written, encoded.status);
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
