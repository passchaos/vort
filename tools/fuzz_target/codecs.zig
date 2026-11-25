const std = @import("std");
const vort = @import("vort");

pub const max_decoded_len: usize = 1 << 20;
pub const max_codec_heap: usize = 8 << 20;

pub fn smoke(allocator: std.mem.Allocator, comptime visit: anytype) !usize {
    const br_wire = try vort.br.encodeAbabaStreamAlloc(allocator);
    defer allocator.free(br_wire);
    const br_decoded = try vort.br.decodeStreamAllocLimitedWithOptions(allocator, br_wire, max_decoded_len, .{
        .allow_large_window = true,
        .max_total_working_memory = max_codec_heap,
    });
    defer allocator.free(br_decoded);
    if (!std.mem.eql(u8, br_decoded, "ababa")) return error.CodecSeedMismatch;
    try visit(allocator, br_wire);
    const raw = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0x20, 2, 0x11, 0, 0, 'A', 'B' };
    const compressed = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0, 0, 0x1d, 0, 0, 8, 'A', 0 };
    for ([_]struct { wire: []const u8, plain: []const u8 }{
        .{ .wire = &raw, .plain = "AB" },
        .{ .wire = &compressed, .plain = "A" },
    }) |seed| {
        const decoded = try vort.zstd.decodeFrameAllocWithOptions(allocator, seed.wire, .{
            .max_output_len = max_decoded_len,
            .max_total_working_memory = max_codec_heap,
        });
        defer allocator.free(decoded);
        if (!std.mem.eql(u8, decoded, seed.plain)) return error.CodecSeedMismatch;
        try visit(allocator, seed.wire);
    }
    return 3;
}

pub fn fuzzOne(allocator: std.mem.Allocator, data: []const u8) !void {
    if (vort.decodeRawDeflateAllocLimited(allocator, data, max_decoded_len)) |decoded| {
        allocator.free(decoded);
    } else |err| switch (err) {
        error.TruncatedFrame,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.InvalidHuffmanCode,
        error.InvalidDynamicBlockHeader,
        error.InvalidMatch,
        error.UnsupportedDeflateFeature,
        error.TrailingData,
        error.OutputTooSmall,
        error.OutputLimitExceeded,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    // Limits apply to each complete one-shot operation. Large Window is
    // admitted explicitly so its parser is exercised inside the heap budget.
    if (vort.br.decodeStreamAllocLimitedWithOptions(allocator, data, max_decoded_len, .{ .allow_large_window = true, .max_total_working_memory = max_codec_heap })) |decoded| {
        allocator.free(decoded);
    } else |err| switch (err) {
        error.TruncatedFrame,
        error.CorruptFrame,
        error.InvalidHuffmanCode,
        error.InvalidMatch,
        error.NeedDictionary,
        error.DictionaryMismatch,
        error.UnsupportedBrotliFeature,
        error.TrailingData,
        error.OutputTooSmall,
        error.WorkingMemoryLimitExceeded,
        error.OutputLimitExceeded,
        error.IntegerOverflow,
        error.ChecksumMismatch,
        error.SizeMismatch,
        error.InputTooSmall,
        error.RangeOutOfBounds,
        => {},
        else => return err,
    }
    if (vort.zstd.decodeFrameAllocWithOptions(allocator, data, .{ .max_output_len = max_decoded_len, .max_total_working_memory = max_codec_heap })) |decoded| {
        allocator.free(decoded);
    } else |err| switch (err) {
        error.TruncatedFrame,
        error.CorruptFrame,
        error.InvalidHuffmanCode,
        error.InvalidMatch,
        error.NeedDictionary,
        error.DictionaryMismatch,
        error.UnsupportedZstdFeature,
        error.TrailingData,
        error.OutputTooSmall,
        error.WorkingMemoryLimitExceeded,
        error.OutputLimitExceeded,
        error.IntegerOverflow,
        error.ChecksumMismatch,
        error.SizeMismatch,
        error.InputTooSmall,
        error.RangeOutOfBounds,
        error.InvalidMagic,
        => {},
        else => return err,
    }
}
