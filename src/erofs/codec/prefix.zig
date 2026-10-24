const std = @import("std");
const core = @import("../../core.zig");
const deflate = @import("../../deflate.zig");
const lzma = @import("../../lzma.zig");
const zstd = @import("../../zstd.zig");
const lz4 = @import("lz4.zig");
const format = @import("../format.zig");
const options_module = @import("options.zig");

pub const Error = core.Error || lzma.Error || zstd.Error || std.mem.Allocator.Error || error{InvalidErofs};

/// Allocate only the requested decoded prefix; decoder state belongs to the
/// same allocator and is released even when decoding stops before format EOF.
pub fn decodeAlloc(allocator: std.mem.Allocator, algorithm: format.Compression, payload: []const u8, size: usize) Error![]u8 {
    return decodeWithOptionsAlloc(allocator, algorithm, payload, size, true, .{});
}

pub fn decodeWithOptionsAlloc(allocator: std.mem.Allocator, algorithm: format.Compression, payload: []const u8, size: usize, partial: bool, options: options_module.DecodeOptions) Error![]u8 {
    if (algorithm == .lzma) return lzma.decodeMicroAllocWithOptions(allocator, payload, size, .{
        .dictionary_size = options.lzma_dictionary_size,
        .max_output_len = size,
        .allow_partial = partial,
    });
    const output = try allocator.alloc(u8, size);
    errdefer allocator.free(output);
    switch (algorithm) {
        .lz4 => _ = try lz4.decodeWithDistance(payload, output, false, partial, options.lz4_max_distance),
        .deflate => {
            const history = try allocator.alloc(u8, deflate.RawDeflateIncrementalFixedLiteralDecoder.required_history_len);
            defer allocator.free(history);
            var decoder = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{
                .max_output_len = size,
                .stop_at_output_limit = partial,
                .allow_trailing_data = true,
                .max_distance = options.deflate_max_distance,
            }, history);
            var consumed: usize = 0;
            var written: usize = 0;
            while (written < size) {
                const progress = try decoder.step(payload[consumed..], output[written..]);
                consumed += progress.progress.input_read;
                written += progress.progress.output_written;
                if (written == size) break;
                if (progress.status == .done) return error.SizeMismatch;
                if (progress.progress.input_read == 0 and progress.progress.output_written == 0) return error.TruncatedFrame;
            }
            if (!partial) {
                const progress = try decoder.step(payload[consumed..], output[0..0]);
                if (progress.status != .done) return error.SizeMismatch;
            }
        },
        .zstandard => {
            const header = try zstd.inspectNativeFrameHeader(payload);
            if (header.window_size > options.zstandard_max_window_size) return error.InvalidErofs;
            var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
                .max_compressed_buffer_len = payload.len,
                .stop_after_first_frame = true,
            });
            defer decoder.deinit();
            var consumed: usize = 0;
            var written: usize = 0;
            while (written < size) {
                const progress = try decoder.step(payload[consumed..], output[written..]);
                consumed += progress.progress.input_read;
                written += progress.progress.output_written;
                if (written == size) break;
                if (progress.status == .done) return error.SizeMismatch;
                if (progress.progress.input_read == 0 and progress.progress.output_written == 0) return error.TruncatedFrame;
            }
        },
        .lzma => unreachable,
    }
    return output;
}
