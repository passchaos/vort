const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const lzma_decoder = @import("../lzma/decoder.zig");
const lzma_encoder = @import("../lzma/encoder.zig");
const lzma2_container = @import("../xz/container.zig");
const lzma2_writer = @import("../xz/lzma2_writer.zig");
const zstd = @import("../zstd.zig");
const format = @import("format.zig");

pub const Error = format.Error || bzip2.Error || lzma_decoder.Error ||
    lzma_encoder.Error || lzma2_container.Error || zstd.Error ||
    std.mem.Allocator.Error;

pub const Metadata = struct {
    len: u8 = 0,
    bytes: [7]u8 = @splat(0),
};

pub fn metadata(compression: format.Compression) Metadata {
    return switch (compression) {
        .lzma => .{
            .len = 5,
            .bytes = .{ 0x5d, 0x00, 0x80, 0x00, 0x00, 0, 0 },
        },
        .lzma2 => .{ .len = 1, .bytes = .{ 0, 0, 0, 0, 0, 0, 0 } },
        .none, .purge, .bzip2, .zstd => .{},
    };
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    compression: format.Compression,
    level: i32,
) Error![]u8 {
    return switch (compression) {
        .none => try allocator.dupe(u8, input),
        .purge => try encodePurgeAlloc(allocator, input, ""),
        .bzip2 => try bzip2.encodeAlloc(allocator, input, .{
            .block_size_100k = @intCast(std.math.clamp(level, 1, 9)),
        }),
        .lzma => blk: {
            var output: std.ArrayList(u8) = .empty;
            errdefer output.deinit(allocator);
            _ = try lzma_encoder.encodeChunkAppend(allocator, &output, input, .{
                .dictionary_size = 32 * 1024,
                .end_marker = true,
            });
            break :blk try output.toOwnedSlice(allocator);
        },
        .lzma2 => blk: {
            var output: std.ArrayList(u8) = .empty;
            errdefer output.deinit(allocator);
            _ = try lzma2_writer.appendCompressedPayload(
                allocator,
                &output,
                input,
            );
            break :blk try output.toOwnedSlice(allocator);
        },
        .zstd => try zstd.encodeFrameWithLevelAlloc(allocator, input, level),
    };
}

pub fn decodeAllocExact(
    allocator: std.mem.Allocator,
    input: []const u8,
    compression: format.Compression,
    compressor_data: []const u8,
    expected_size: usize,
    max_dictionary_size: usize,
) Error![]u8 {
    const decoded = switch (compression) {
        .none => try allocator.dupe(u8, input),
        .purge => try decodePurgeAlloc(allocator, input, expected_size, ""),
        .bzip2 => try bzip2.decodeAllocLimited(allocator, input, expected_size),
        .lzma => try lzma_decoder.decode7zPayloadAllocLimited(
            allocator,
            input,
            compressor_data,
            expected_size,
            max_dictionary_size,
        ),
        .lzma2 => try lzma2_container.decode7zPayloadAllocLimited(
            allocator,
            input,
            compressor_data[0],
            expected_size,
            max_dictionary_size,
        ),
        .zstd => try zstd.decodeFrameAllocExactSize(
            allocator,
            input,
            expected_size,
        ),
    };
    errdefer allocator.free(decoded);
    if (decoded.len != expected_size) return error.SizeMismatch;
    return decoded;
}

pub fn decodeAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    compression: format.Compression,
    compressor_data: []const u8,
    max_output_len: usize,
    max_dictionary_size: usize,
) Error![]u8 {
    return switch (compression) {
        .none => if (input.len <= max_output_len)
            try allocator.dupe(u8, input)
        else
            error.OutputLimitExceeded,
        .purge => error.UnsupportedWiaFeature,
        .bzip2 => try bzip2.decodeAllocLimited(
            allocator,
            input,
            max_output_len,
        ),
        .lzma => try lzma_decoder.decode7zPayloadAllocUnknownSizeLimited(
            allocator,
            input,
            compressor_data,
            max_output_len,
            max_dictionary_size,
        ),
        .lzma2 => try lzma2_container.decode7zPayloadAllocUnknownSizeLimited(
            allocator,
            input,
            compressor_data[0],
            max_output_len,
            max_dictionary_size,
        ),
        .zstd => try zstd.decodeFrameAllocLimited(
            allocator,
            input,
            max_output_len,
        ),
    };
}

pub fn encodePurgeWithHashPrefixAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    hash_prefix: []const u8,
) Error![]u8 {
    return encodePurgeAlloc(allocator, input, hash_prefix);
}

fn encodePurgeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    hash_prefix: []const u8,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var position: usize = 0;
    while (position < input.len) {
        while (position < input.len and input[position] == 0) position += 1;
        if (position == input.len) break;
        const start = position;
        var last_nonzero = position + 1;
        var zero_run: usize = 0;
        position += 1;
        while (position < input.len) : (position += 1) {
            if (input[position] == 0) {
                zero_run += 1;
                if (zero_run > 8) break;
            } else {
                zero_run = 0;
                last_nonzero = position + 1;
            }
        }
        var header: [8]u8 = undefined;
        std.mem.writeInt(u32, header[0..4], @intCast(start), .big);
        std.mem.writeInt(u32, header[4..8], @intCast(last_nonzero - start), .big);
        try output.appendSlice(allocator, &header);
        try output.appendSlice(allocator, input[start..last_nonzero]);
        position = @max(position, last_nonzero);
    }
    var sha = std.crypto.hash.Sha1.init(.{});
    sha.update(hash_prefix);
    sha.update(output.items);
    var digest: [20]u8 = undefined;
    sha.final(&digest);
    try output.appendSlice(allocator, &digest);
    return output.toOwnedSlice(allocator);
}

pub fn decodePurgeWithHashPrefixAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
    hash_prefix: []const u8,
) Error![]u8 {
    return decodePurgeAlloc(
        allocator,
        input,
        expected_size,
        hash_prefix,
    );
}

fn decodePurgeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
    hash_prefix: []const u8,
) Error![]u8 {
    if (input.len < 20) return error.TruncatedFrame;
    var sha = std.crypto.hash.Sha1.init(.{});
    sha.update(hash_prefix);
    sha.update(input[0 .. input.len - 20]);
    var actual: [20]u8 = undefined;
    sha.final(&actual);
    if (!std.mem.eql(u8, &actual, input[input.len - 20 ..]))
        return error.ChecksumMismatch;
    const output = try allocator.alloc(u8, expected_size);
    errdefer allocator.free(output);
    @memset(output, 0);
    var input_offset: usize = 0;
    var previous_end: usize = 0;
    while (input_offset < input.len - 20) {
        if (input.len - 20 - input_offset < 8) return error.TruncatedFrame;
        const offset: usize = std.mem.readInt(
            u32,
            input[input_offset..][0..4],
            .big,
        );
        const size: usize = std.mem.readInt(
            u32,
            input[input_offset + 4 ..][0..4],
            .big,
        );
        input_offset += 8;
        const end = std.math.add(usize, offset, size) catch
            return error.IntegerOverflow;
        if (size == 0 or offset < previous_end or end > output.len or
            size > input.len - 20 - input_offset)
            return error.CorruptFrame;
        @memcpy(output[offset..end], input[input_offset..][0..size]);
        input_offset += size;
        previous_end = end;
    }
    return output;
}

test "WIA marker-terminated LZMA codecs honor output limits" {
    const allocator = std.testing.allocator;
    const input = "WIA partition unknown-size codec payload\n" ** 128;
    inline for (.{ format.Compression.lzma, format.Compression.lzma2 }) |compression| {
        const encoded = try encodeAlloc(allocator, input, compression, 6);
        defer allocator.free(encoded);
        const properties = metadata(compression);
        const decoded = try decodeAllocLimited(
            allocator,
            encoded,
            compression,
            properties.bytes[0..properties.len],
            input.len,
            1 << 20,
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        try std.testing.expectError(
            error.OutputLimitExceeded,
            decodeAllocLimited(
                allocator,
                encoded,
                compression,
                properties.bytes[0..properties.len],
                input.len - 1,
                1 << 20,
            ),
        );
    }
}

test "WIA purge decoder authenticates partition exception prefixes" {
    const allocator = std.testing.allocator;
    const input = ([_]u8{0} ** 64) ++ "partition purge payload" ++
        ([_]u8{0} ** 64);
    const prefix = [_]u8{ 0, 1, 0, 0 } ++ ([_]u8{0xaa} ** 20);
    const encoded = try encodePurgeWithHashPrefixAlloc(
        allocator,
        input,
        &prefix,
    );
    defer allocator.free(encoded);
    const decoded = try decodePurgeWithHashPrefixAlloc(
        allocator,
        encoded,
        input.len,
        &prefix,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    encoded[encoded.len - 1] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        decodePurgeWithHashPrefixAlloc(
            allocator,
            encoded,
            input.len,
            &prefix,
        ),
    );
}
