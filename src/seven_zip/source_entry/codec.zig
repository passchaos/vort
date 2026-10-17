//! Incremental primary-coder adapters used by the source-backed 7z entry state.

const std = @import("std");
const archive_mod = @import("../archive.zig");
const bzip2 = @import("../../bzip2.zig");
const core = @import("../../core.zig");
const deflate = @import("../../deflate.zig");
const lzma = @import("../../lzma.zig");
const streams_mod = @import("../streams.zig");
const xz = @import("../../xz.zig");

pub const Error = archive_mod.Error || deflate.Error || bzip2.Error ||
    lzma.Error || xz.Error;

pub const Codec = union(enum) {
    copy: Copy,
    deflate: Deflate,
    bzip2: bzip2.IncrementalDecoder,
    lzma: Lzma7z,
    lzma2: xz.RawLzma2IncrementalDecoder,

    pub fn init(
        allocator: std.mem.Allocator,
        coder: streams_mod.Coder,
        expected_size: usize,
        max_dictionary_size: usize,
    ) Error!Codec {
        return switch (coder.method) {
            .copy => .{ .copy = .{ .expected = expected_size } },
            .deflate => blk: {
                const history = try allocator.alloc(
                    u8,
                    deflate.RawDeflateIncrementalFixedLiteralDecoder.required_history_len,
                );
                errdefer allocator.free(history);
                break :blk .{ .deflate = .{
                    .history = history,
                    .decoder = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(
                        .{
                            .max_output_len = expected_size,
                            .expected_output_len = expected_size,
                        },
                        history,
                    ),
                } };
            },
            .bzip2 => .{ .bzip2 = bzip2.IncrementalDecoder.initWithOptions(allocator, .{
                .max_output_len = expected_size,
                .max_decoded_block_len = @min(expected_size, 64 * 1024 * 1024),
                .expected_output_len = expected_size,
                .stop_after_first_stream = true,
            }) },
            .lzma => .{ .lzma = try Lzma7z.init(
                allocator,
                coder.propertyBytes(),
                expected_size,
                max_dictionary_size,
            ) },
            .lzma2 => .{ .lzma2 = try xz.RawLzma2IncrementalDecoder.init(allocator, .{
                .dictionary_property = coder.propertyBytes()[0],
                .max_dictionary_size = max_dictionary_size,
                .max_output_len = expected_size,
                .expected_output_len = expected_size,
            }) },
            else => error.Unsupported7zFeature,
        };
    }

    pub fn deinit(self: *Codec, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .copy => {},
            .deflate => |state| allocator.free(state.history),
            .bzip2 => |*state| state.deinit(),
            .lzma => |*state| state.deinit(),
            .lzma2 => |*state| state.deinit(),
        }
        self.* = undefined;
    }

    pub fn step(self: *Codec, input: []const u8, output: []u8) Error!core.StepResult {
        return switch (self.*) {
            .copy => |*state| state.step(input, output),
            .deflate => |*state| state.decoder.step(input, output),
            .bzip2 => |*state| state.step(input, output),
            .lzma => |*state| state.step(input, output),
            .lzma2 => |*state| state.step(input, output),
        };
    }

    pub fn finish(self: *Codec) Error!void {
        switch (self.*) {
            .copy => |*state| try state.finish(),
            .deflate => |*state| try state.decoder.finish(),
            .bzip2 => |*state| state.finish(),
            .lzma => |*state| state.finish(),
            .lzma2 => |*state| state.finish(),
        }
    }

    pub fn name(self: *const Codec) []const u8 {
        return switch (self.*) {
            .copy => "copy",
            .deflate => "deflate",
            .bzip2 => "bzip2",
            .lzma => "lzma",
            .lzma2 => "lzma2",
        };
    }
};

const Deflate = struct {
    history: []u8,
    decoder: deflate.RawDeflateIncrementalFixedLiteralDecoder,
};

const Copy = struct {
    expected: usize,
    written: usize = 0,

    fn step(self: *Copy, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.written == self.expected) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        const count = @min(
            self.expected - self.written,
            @min(input.len, output.len),
        );
        @memcpy(output[0..count], input[0..count]);
        self.written += count;
        if (self.written == self.expected) {
            if (count != input.len) return error.TrailingData;
            return result(count, count, .done);
        }
        if (count == output.len and output.len != 0)
            return result(count, count, .need_output);
        if (output.len == 0 and input.len != 0)
            return result(0, 0, .need_output);
        return result(count, count, .need_input);
    }

    fn finish(self: *Copy) Error!void {
        if (self.written != self.expected) return error.TruncatedFrame;
    }
};

const Lzma7z = struct {
    decoder: lzma.IncrementalDecoder,
    header: [13]u8,
    header_offset: usize = 0,

    fn init(
        allocator: std.mem.Allocator,
        properties: []const u8,
        expected_size: usize,
        max_dictionary_size: usize,
    ) Error!Lzma7z {
        if (properties.len != 5) return error.Invalid7zArchive;
        const dictionary_size = std.mem.readInt(u32, properties[1..5], .little);
        if (dictionary_size > max_dictionary_size) return error.OutputLimitExceeded;
        var header: [13]u8 = undefined;
        @memcpy(header[0..5], properties);
        std.mem.writeInt(u64, header[5..13], expected_size, .little);
        return .{
            .decoder = lzma.IncrementalDecoder.initWithOptions(allocator, .{
                .max_output_len = expected_size,
                .max_dictionary_size = max_dictionary_size,
                .expected_output_len = expected_size,
            }),
            .header = header,
        };
    }

    fn deinit(self: *Lzma7z) void {
        self.decoder.deinit();
    }

    fn finish(self: *Lzma7z) void {
        self.decoder.finish();
    }

    fn step(self: *Lzma7z, input: []const u8, output: []u8) Error!core.StepResult {
        var output_written: usize = 0;
        while (self.header_offset < self.header.len) {
            const stepped = try self.decoder.step(
                self.header[self.header_offset..],
                output[output_written..],
            );
            self.header_offset += stepped.progress.input_read;
            output_written += stepped.progress.output_written;
            if (stepped.status == .need_output)
                return result(0, output_written, .need_output);
            if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
                return error.Invalid7zArchive;
        }
        const stepped = try self.decoder.step(input, output[output_written..]);
        return result(
            stepped.progress.input_read,
            output_written + stepped.progress.output_written,
            stepped.status,
        );
    }
};

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
