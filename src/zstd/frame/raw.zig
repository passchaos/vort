const std = @import("std");
const builtin = @import("builtin");

const tiny_text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_tiny_raw",
    .macho => "__TEXT,__vort_zstd_traw",
    .coff => ".text$vort_zstd_tiny_raw",
    else => ".text",
};

pub const Error = error{
    CorruptFrame,
    OutputTooSmall,
    SizeMismatch,
    TruncatedFrame,
};

const frame_magic: u32 = 0xfd2f_b528;
const block_size_max: usize = 128 * 1024;
const vector_copy_min_len: usize = 4 * 1024;

const Plan = struct {
    payload_offset: usize,
    content_size: usize,
};

/// Decode a common single-segment, checksum-free, dictionary-free frame whose
/// blocks are raw and/or RLE.
///
/// Returns `null` for any other valid/unsupported shape without mutating
/// output. The production facade can therefore fall back to its general parser
/// while using this bounded two-pass scan for large incompressible frames.
pub fn tryDecode(frame: []const u8, output: []u8) Error!?usize {
    // The general decoder's fixed setup cost is already appropriate for tiny
    // payloads; this two-pass scanner exists to amortize frame parsing across
    // medium/large raw blocks.
    if (output.len < 256) return try decodeTinySingleRaw(frame, output);
    const plan = (try scan(frame)) orelse return null;
    if (output.len < plan.content_size) return error.OutputTooSmall;

    var input_offset = plan.payload_offset;
    var output_offset: usize = 0;
    while (true) {
        const header = std.mem.readInt(
            u24,
            frame[input_offset..][0..3],
            .little,
        );
        input_offset += 3;
        const len: usize = @intCast(header >> 3);
        const block_type = (header >> 1) & 0x03;
        if (block_type == 0) {
            copyRawBlock(
                output[output_offset..][0..len],
                frame[input_offset..][0..len],
            );
            input_offset += len;
        } else {
            std.debug.assert(block_type == 1);
            @memset(
                output[output_offset..][0..len],
                frame[input_offset],
            );
            input_offset += 1;
        }
        output_offset += len;
        if ((header & 1) != 0) break;
    }
    std.debug.assert(input_offset == frame.len);
    std.debug.assert(output_offset == plan.content_size);
    return output_offset;
}

/// Copy a validated raw block without the generic libc dispatch used by
/// `@memcpy` for runtime-sized spans. On AArch64, Zstd's full 128 KiB raw
/// blocks are faster with a compact 128-byte paired-vector loop. Keep this out
/// of line so compressed frames and small raw blocks do not inherit its code.
noinline fn copyRawBlock(destination: []u8, source: []const u8) align(256) void {
    std.debug.assert(destination.len == source.len);
    if (comptime builtin.cpu.arch == .aarch64) {
        if (source.len >= vector_copy_min_len) {
            const Vector = @Vector(32, u8);
            const vectors_per_loop = 4;
            const loop_bytes = @sizeOf(Vector) * vectors_per_loop;
            var offset: usize = 0;
            while (source.len - offset >= loop_bytes) : (offset += loop_bytes) {
                inline for (0..vectors_per_loop) |vector_index| {
                    const vector_offset = offset + vector_index * @sizeOf(Vector);
                    const value: Vector = source[vector_offset..][0..@sizeOf(Vector)].*;
                    destination[vector_offset..][0..@sizeOf(Vector)].* = value;
                }
            }
            if (offset != source.len) {
                @memcpy(destination[offset..], source[offset..]);
            }
            return;
        }
    }
    @memcpy(destination, source);
}

/// Decode a complete one-byte-content-size, one-block raw frame in one pass.
/// Every structural field and the exact frame length are validated before the
/// output copy, preserving the no-mutation-on-miss contract.
noinline fn decodeTinySingleRaw(frame: []const u8, output: []u8) linksection(tiny_text_section) Error!?usize {
    if (frame.len < 9 or std.mem.readInt(u32, frame[0..4], .little) != frame_magic) return null;
    const descriptor = frame[4];
    const payload_offset: usize = 9;
    const content_size: ?usize = if (descriptor == 0)
        null
    else if ((descriptor & 0xe0) == 0x20 and (descriptor & 0x0f) == 0)
        frame[5]
    else
        return null;
    const header = std.mem.readInt(u24, frame[6..payload_offset], .little);
    if ((header & 0x07) != 0x01) return null;
    const block_len: usize = @intCast(header >> 3);
    if ((content_size != null and block_len != content_size.?) or frame.len != payload_offset + block_len) return null;
    if (output.len < block_len) return error.OutputTooSmall;
    @memcpy(output[0..block_len], frame[payload_offset..]);
    return block_len;
}

fn scan(frame: []const u8) Error!?Plan {
    if (frame.len < 6) return null;
    if (std.mem.readInt(u32, frame[0..4], .little) != frame_magic) {
        return null;
    }
    const descriptor = frame[4];
    const single_segment = (descriptor & 0x20) != 0;
    const has_checksum = (descriptor & 0x04) != 0;
    const has_dictionary = (descriptor & 0x03) != 0;
    if (!single_segment or has_checksum or has_dictionary or
        (descriptor & 0x08) != 0)
    {
        return null;
    }

    const content_size_flag = descriptor >> 6;
    const field_size: usize = @as(usize, 1) << @intCast(content_size_flag);
    if (frame.len - 5 < field_size) return error.TruncatedFrame;
    var content_size_u64: u64 = 0;
    for (frame[5..][0..field_size], 0..) |byte, index| {
        content_size_u64 |= @as(u64, byte) << @intCast(index * 8);
    }
    if (field_size == 2) content_size_u64 += 256;
    const content_size = std.math.cast(usize, content_size_u64) orelse
        return error.CorruptFrame;
    var offset = 5 + field_size;
    const payload_offset = offset;
    var decoded: usize = 0;
    while (true) {
        if (frame.len - offset < 3) return error.TruncatedFrame;
        const header = std.mem.readInt(u24, frame[offset..][0..3], .little);
        offset += 3;
        const block_type = (header >> 1) & 0x03;
        if (block_type > 1) return null;
        const len: usize = @intCast(header >> 3);
        if (len > block_size_max) return error.CorruptFrame;
        if (block_type == 1 and len == 0) return error.CorruptFrame;
        const stored_len: usize = if (block_type == 0) len else 1;
        if (frame.len - offset < stored_len) return error.TruncatedFrame;
        decoded = std.math.add(usize, decoded, len) catch
            return error.CorruptFrame;
        offset += stored_len;
        if ((header & 1) != 0) break;
    }
    if (offset != frame.len) return null;
    if (decoded != content_size) return error.SizeMismatch;
    return .{
        .payload_offset = payload_offset,
        .content_size = content_size,
    };
}

test "Zstd raw frame fast path supports RLE blocks" {
    var frame: [11]u8 = .{
        0x28, 0xb5, 0x2f, 0xfd, 0x60, 0, 0,
        0x03, 0x08, 0x00, 0x5a,
    };
    var output: [256]u8 = undefined;
    try std.testing.expectEqual(
        @as(?usize, output.len),
        try tryDecode(&frame, &output),
    );
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0x5a), byte);
    frame[10] = 0xa5;
    try std.testing.expectEqual(
        @as(?usize, output.len),
        try tryDecode(&frame, &output),
    );
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

test "Zstd raw frame fast path decodes eligible frame without mutation on miss" {
    const tiny_frame = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x05,
        0x20, 0x00, 0x00, 'a',  'b',  'c',
        'd',  0x09, 0x00, 0x00, 'e',
    };
    var tiny_output: [5]u8 = undefined;
    try std.testing.expectEqual(@as(?usize, null), try tryDecode(&tiny_frame, &tiny_output));

    const tiny_libzstd = [_]u8{
        0x28, 0xb5, 0x2f, 0xfd, 0x00, 0x48,
        0x51, 0x00, 0x00, 'h',  'e',  'l',
        'l',  'o',  ' ',  'z',  's',  't',
        'd',
    };
    var tiny_libzstd_output: [10]u8 = undefined;
    try std.testing.expectEqual(@as(?usize, 10), try tryDecode(&tiny_libzstd, &tiny_libzstd_output));
    try std.testing.expectEqualSlices(u8, "hello zstd", &tiny_libzstd_output);
    var tiny_short: [9]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutputTooSmall, tryDecode(&tiny_libzstd, &tiny_short));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** tiny_short.len), &tiny_short);
    var tiny_trailing = tiny_libzstd ++ [_]u8{0};
    var tiny_untouched: [10]u8 = @splat(0x5a);
    try std.testing.expectEqual(@as(?usize, null), try tryDecode(&tiny_trailing, &tiny_untouched));
    try std.testing.expectEqualSlices(u8, &([_]u8{0x5a} ** tiny_untouched.len), &tiny_untouched);

    var frame: [10 + 256]u8 = undefined;
    frame[0..7].* = .{ 0x28, 0xb5, 0x2f, 0xfd, 0x60, 0, 0 };
    frame[7..10].* = .{ 0x01, 0x08, 0x00 };
    for (frame[10..], 0..) |*byte, index| byte.* = @truncate(index);
    var output: [256]u8 = undefined;
    try std.testing.expectEqual(
        @as(?usize, output.len),
        try tryDecode(&frame, &output),
    );
    try std.testing.expectEqualSlices(u8, frame[10..], &output);

    var untouched: [256]u8 = @splat(0xa5);
    var unsupported = frame;
    unsupported[7] |= 0x02; // compressed block type
    try std.testing.expectEqual(@as(?usize, null), try tryDecode(&unsupported, &untouched));
    try std.testing.expectEqualSlices(
        u8,
        &([_]u8{0xa5} ** untouched.len),
        &untouched,
    );
}

test "Zstd raw frame vector copy covers tail lengths" {
    const source = try std.testing.allocator.alloc(u8, vector_copy_min_len + 37);
    defer std.testing.allocator.free(source);
    const destination = try std.testing.allocator.alloc(u8, source.len);
    defer std.testing.allocator.free(destination);
    for (source, 0..) |*byte, index| byte.* = @truncate(index *% 131);
    @memset(destination, 0);
    copyRawBlock(destination, source);
    try std.testing.expectEqualSlices(u8, source, destination);
}
