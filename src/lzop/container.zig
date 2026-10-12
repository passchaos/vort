const std = @import("std");
const core = @import("../core.zig");
const lzo1x = @import("../lzo1x.zig");
const block_decoder = @import("block.zig");
const header_mod = @import("header.zig");

pub const Error = core.Error || lzo1x.Error || header_mod.Error || error{
    InvalidLzopStream,
    UnsupportedLzopFeature,
};

pub const DecodeOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_block_size: usize = 64 * 1024 * 1024,
};

pub const FileInfo = struct {
    stream_count: usize,
    block_count: usize,
    stored_block_count: usize,
    compressed_block_count: usize,
    compressed_size: usize,
    uncompressed_size: u64,
    max_block_size: u32,
};

const Sink = union(enum) {
    fixed: struct { bytes: []u8, written: usize = 0 },
    dynamic: struct {
        allocator: std.mem.Allocator,
        bytes: *std.ArrayList(u8),
        limit: usize,
    },
    count: struct { written: usize = 0, limit: usize },

    fn len(self: Sink) usize {
        return switch (self) {
            .fixed => |state| state.written,
            .dynamic => |state| state.bytes.items.len,
            .count => |state| state.written,
        };
    }

    fn append(self: *Sink, bytes: []const u8) !void {
        switch (self.*) {
            .fixed => |*state| {
                const end = std.math.add(usize, state.written, bytes.len) catch
                    return error.OutputTooSmall;
                if (end > state.bytes.len) return error.OutputTooSmall;
                @memcpy(state.bytes[state.written..end], bytes);
                state.written = end;
            },
            .dynamic => |*state| {
                const end = std.math.add(usize, state.bytes.items.len, bytes.len) catch
                    return error.OutputLimitExceeded;
                if (end > state.limit) return error.OutputLimitExceeded;
                try state.bytes.appendSlice(state.allocator, bytes);
            },
            .count => |*state| {
                const end = std.math.add(usize, state.written, bytes.len) catch
                    return error.OutputLimitExceeded;
                if (end > state.limit) return error.OutputLimitExceeded;
                state.written = end;
            },
        }
    }
};

pub fn inspect(input: []const u8) !FileInfo {
    var sink = Sink{ .count = .{ .limit = std.math.maxInt(usize) } };
    return process(std.heap.page_allocator, input, .{}, &sink, false);
}

pub fn decodeInto(allocator: std.mem.Allocator, input: []const u8, output: []u8) !usize {
    var sink = Sink{ .fixed = .{ .bytes = output } };
    _ = process(allocator, input, .{ .max_output_len = output.len }, &sink, true) catch |err| switch (err) {
        error.OutputLimitExceeded => return error.OutputTooSmall,
        else => |decode_error| return decode_error,
    };
    return sink.len();
}

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeAllocWithOptions(allocator, input, .{});
}

pub fn decodeAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeAllocWithOptions(allocator, input, .{ .max_output_len = max_output_len });
}

pub fn decodeAllocWithOptions(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: DecodeOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var sink = Sink{ .dynamic = .{
        .allocator = allocator,
        .bytes = &output,
        .limit = options.max_output_len,
    } };
    _ = try process(allocator, input, options, &sink, true);
    return output.toOwnedSlice(allocator);
}

pub fn decodedSize(allocator: std.mem.Allocator, input: []const u8) !usize {
    return decodedSizeWithOptions(allocator, input, .{});
}

pub fn decodedSizeLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) !usize {
    return decodedSizeWithOptions(allocator, input, .{ .max_output_len = max_output_len });
}

pub fn decodedSizeWithOptions(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: DecodeOptions,
) !usize {
    var sink = Sink{ .count = .{ .limit = options.max_output_len } };
    _ = try process(allocator, input, options, &sink, true);
    return sink.len();
}

fn process(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: DecodeOptions,
    sink: *Sink,
    decode_blocks: bool,
) !FileInfo {
    if (input.len == 0) return error.TruncatedFrame;
    var info = FileInfo{
        .stream_count = 0,
        .block_count = 0,
        .stored_block_count = 0,
        .compressed_block_count = 0,
        .compressed_size = input.len,
        .uncompressed_size = 0,
        .max_block_size = 0,
    };
    var offset: usize = 0;
    while (offset < input.len) {
        const stream_header = try header_mod.parse(input[offset..]);
        offset += stream_header.encoded_size;
        info.stream_count = std.math.add(usize, info.stream_count, 1) catch
            return error.IntegerOverflow;

        while (true) {
            const uncompressed_size_u32 = try header_mod.readU32(input, &offset);
            if (uncompressed_size_u32 == 0) break;
            if (uncompressed_size_u32 == std.math.maxInt(u32))
                return error.UnsupportedLzopFeature;
            if (uncompressed_size_u32 > 64 * 1024 * 1024)
                return error.InvalidLzopStream;
            const uncompressed_size: usize = uncompressed_size_u32;
            if (uncompressed_size > options.max_block_size) return error.OutputLimitExceeded;
            if (uncompressed_size > options.max_output_len -| sink.len())
                return error.OutputLimitExceeded;

            const compressed_size_u32 = try header_mod.readU32(input, &offset);
            if (compressed_size_u32 == 0 or compressed_size_u32 > uncompressed_size_u32)
                return error.InvalidLzopStream;
            const compressed_size: usize = compressed_size_u32;
            const compressed = compressed_size < uncompressed_size;

            const data_adler = if (stream_header.flags & header_mod.Flag.adler32_data != 0)
                try header_mod.readU32(input, &offset)
            else
                null;
            const data_crc = if (stream_header.flags & header_mod.Flag.crc32_data != 0)
                try header_mod.readU32(input, &offset)
            else
                null;
            const compressed_adler = if (compressed and stream_header.flags & header_mod.Flag.adler32_compressed != 0)
                try header_mod.readU32(input, &offset)
            else
                null;
            const compressed_crc = if (compressed and stream_header.flags & header_mod.Flag.crc32_compressed != 0)
                try header_mod.readU32(input, &offset)
            else
                null;

            const payload_end = std.math.add(usize, offset, compressed_size) catch
                return error.IntegerOverflow;
            if (payload_end > input.len) return error.TruncatedFrame;
            const payload = input[offset..payload_end];
            offset = payload_end;
            if (!decode_blocks) try block_decoder.validateCompressed(payload, .{
                .compressed_adler = compressed_adler,
                .compressed_crc = compressed_crc,
            });
            info.block_count = std.math.add(usize, info.block_count, 1) catch
                return error.IntegerOverflow;
            info.max_block_size = @max(info.max_block_size, uncompressed_size_u32);
            info.uncompressed_size = std.math.add(u64, info.uncompressed_size, uncompressed_size_u32) catch
                return error.IntegerOverflow;
            if (compressed) {
                info.compressed_block_count = std.math.add(usize, info.compressed_block_count, 1) catch
                    return error.IntegerOverflow;
            } else {
                info.stored_block_count = std.math.add(usize, info.stored_block_count, 1) catch
                    return error.IntegerOverflow;
            }
            if (!decode_blocks) {
                if (info.uncompressed_size > options.max_output_len)
                    return error.OutputLimitExceeded;
                continue;
            }

            const block = try allocator.alloc(u8, uncompressed_size);
            defer allocator.free(block);
            try block_decoder.decodeInto(payload, block, stream_header.filter, .{
                .data_adler = data_adler,
                .data_crc = data_crc,
                .compressed_adler = compressed_adler,
                .compressed_crc = compressed_crc,
            });
            try sink.append(block);
        }
    }
    return info;
}

test "LZOP decoder handles a deterministic stored stream" {
    const writer = @import("writer.zig");
    const input = "stored LZOP payload" ** 64;
    const encoded = try writer.encodeStoredAlloc(std.testing.allocator, input, .{ .block_size = 127 });
    defer std.testing.allocator.free(encoded);
    const info = try inspect(encoded);
    try std.testing.expectEqual(@as(usize, 1), info.stream_count);
    try std.testing.expectEqual((input.len + 126) / 127, info.block_count);
    try std.testing.expectEqual(info.block_count, info.stored_block_count);
    try std.testing.expectEqual(@as(usize, 0), info.compressed_block_count);
    try std.testing.expectEqual(@as(u64, input.len), info.uncompressed_size);

    const decoded = try decodeAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(std.testing.allocator, encoded, input.len - 1),
    );
    var short: [input.len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeInto(std.testing.allocator, encoded, &short));

    const second_input = "second LZOP stream";
    const second = try writer.encodeStoredAlloc(std.testing.allocator, second_input, .{ .checksum = .crc32 });
    defer std.testing.allocator.free(second);
    var concatenated: std.ArrayList(u8) = .empty;
    defer concatenated.deinit(std.testing.allocator);
    try concatenated.appendSlice(std.testing.allocator, encoded);
    try concatenated.appendSlice(std.testing.allocator, second);
    const concatenated_info = try inspect(concatenated.items);
    try std.testing.expectEqual(@as(usize, 2), concatenated_info.stream_count);
    const concatenated_decoded = try decodeAlloc(std.testing.allocator, concatenated.items);
    defer std.testing.allocator.free(concatenated_decoded);
    try std.testing.expectEqualSlices(u8, input ++ second_input, concatenated_decoded);
}

test "LZOP inspection validates compressed payload checksums" {
    const writer = @import("writer.zig");
    const input = "compressed checksum inspection" ** 64;
    const encoded = try writer.encodeAlloc(std.testing.allocator, input, .{
        .block_size = input.len,
        .compressed_checksum = true,
    });
    defer std.testing.allocator.free(encoded);
    const stream_header = try header_mod.parse(encoded);
    var offset = stream_header.encoded_size;
    _ = try header_mod.readU32(encoded, &offset);
    const compressed_len = try header_mod.readU32(encoded, &offset);
    try std.testing.expect(compressed_len < input.len);
    if (stream_header.flags & header_mod.Flag.adler32_data != 0) offset += 4;
    if (stream_header.flags & header_mod.Flag.crc32_data != 0) offset += 4;
    if (stream_header.flags & header_mod.Flag.adler32_compressed != 0) offset += 4;
    if (stream_header.flags & header_mod.Flag.crc32_compressed != 0) offset += 4;

    const corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[offset] ^= 0x80;
    try std.testing.expectError(error.ChecksumMismatch, inspect(corrupt));
    try std.testing.expectError(error.ChecksumMismatch, decodedSize(std.testing.allocator, corrupt));
}
