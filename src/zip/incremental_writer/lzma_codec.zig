const std = @import("std");
const core = @import("../../core.zig");
const lzma = @import("../../lzma.zig");
const lzma_encoder = @import("../../lzma/encoder.zig");

pub const Options = lzma.IncrementalEncoder.Options;
pub const Error = lzma.IncrementalEncoder.Error || error{InvalidLzmaStream};

const alone_header_len: usize = 13;
const zip_prefix_len: usize = 9;

/// Convert the LZMA-Alone incremental encoder surface into a ZIP method-14
/// payload. The ZIP prefix is emitted to the caller; the equivalent Alone
/// header is generated and validated internally, then discarded.
pub const State = struct {
    encoder: lzma.IncrementalEncoder,
    prefix: [zip_prefix_len]u8,
    prefix_offset: usize = 0,
    header_primed: bool = false,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        requested_options: Options,
        expected_size: ?u64,
    ) Error!Self {
        var options = requested_options;
        options.size_mode = .end_marker;
        const property = try lzma_encoder.propertyByte(options.properties);
        if (options.dictionary_size < 4096 or options.dictionary_size > std.math.maxInt(u16))
            return error.InvalidLzmaOptions;
        const encoder = if (expected_size) |expected|
            try lzma.IncrementalEncoder.initExactSize(
                allocator,
                options,
                std.math.cast(usize, expected) orelse return error.OutputLimitExceeded,
            )
        else
            try lzma.IncrementalEncoder.initWithOptions(allocator, options);
        var prefix: [zip_prefix_len]u8 = undefined;
        prefix[0] = 9;
        prefix[1] = 4;
        std.mem.writeInt(u16, prefix[2..4], 5, .little);
        prefix[4] = property;
        std.mem.writeInt(u32, prefix[5..9], options.dictionary_size, .little);
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
        var input_read: usize = 0;
        var output_written: usize = 0;
        if (self.prefix_offset != self.prefix.len) {
            const take = @min(self.prefix.len - self.prefix_offset, output.len);
            @memcpy(output[0..take], self.prefix[self.prefix_offset..][0..take]);
            self.prefix_offset += take;
            output_written += take;
            if (self.prefix_offset != self.prefix.len)
                return result(input_read, output_written, .need_output);
        }

        if (!self.header_primed) {
            var alone_header: [alone_header_len]u8 = undefined;
            const primed = try self.encoder.step("", &alone_header);
            if (primed.progress.input_read != 0 or
                primed.progress.output_written != alone_header.len or
                (primed.status != .need_input and primed.status != .need_output) or
                alone_header[0] != self.prefix[4] or
                !std.mem.eql(u8, alone_header[1..5], self.prefix[5..9]) or
                std.mem.readInt(u64, alone_header[5..13], .little) != std.math.maxInt(u64))
                return error.InvalidLzmaStream;
            self.header_primed = true;
        }

        const encoded = try self.encoder.step(input, output[output_written..]);
        input_read += encoded.progress.input_read;
        output_written += encoded.progress.output_written;
        return result(input_read, output_written, encoded.status);
    }

    fn result(
        input_read: usize,
        output_written: usize,
        status: core.StepResult.Status,
    ) core.StepResult {
        return .{
            .progress = .{ .input_read = input_read, .output_written = output_written },
            .status = status,
        };
    }
};
