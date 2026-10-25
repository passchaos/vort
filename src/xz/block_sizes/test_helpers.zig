//! Independent XZ header/VLI/LZMA2-envelope/Index reader. Entropy decoding
//! remains a separate public-library round-trip check.
const std = @import("std");
const core = @import("../../core.zig");
const xz = @import("../../xz.zig");
pub const a = std.testing.allocator;
pub const plain = "XZ block size declarations preserve payloads and caller ownership\n" ** 2;
pub const Api = enum { compressed, stored, lazy };
pub const Tracker = @import("../parallel/test_helpers.zig").TrackingAllocator;
pub const legacy = @import("../../lzma/encode_controls_helpers.zig");
pub const Vli = struct { value: u64, start: usize, width: usize };
pub fn vli(bytes: []const u8, offset: *usize, end: usize) !Vli {
    const start = offset.*;
    var value: u64 = 0;
    for (0..9) |index| {
        if (offset.* >= end or offset.* >= bytes.len) return error.TruncatedFrame;
        const byte = bytes[offset.*];
        offset.* += 1;
        value |= @as(u64, byte & 127) << @as(u6, @intCast(index * 7));
        if (byte & 128 == 0) {
            if (index != 0 and byte == 0) return error.InvalidXzStream;
            return .{ .value = value, .start = start, .width = index + 1 };
        }
    }
    return error.InvalidXzStream;
}
fn endOf(bytes: []const u8, offset: usize, count: usize) !usize {
    if (offset > bytes.len or count > bytes.len - offset) return error.TruncatedFrame;
    return offset + count;
}
pub const Header = struct { start: usize, end: usize, crc: usize, flags: u8, packed_size: ?Vli, unpacked: ?Vli, filter_ids: [4]u64, filter_properties: [4][]const u8 };
pub fn header(bytes: []const u8, start: usize) !Header {
    _ = try endOf(bytes, start, 2);
    const end = try endOf(bytes, start, (@as(usize, bytes[start]) + 1) * 4);
    const crc = end - 4;
    try std.testing.expectEqual(std.hash.Crc32.hash(bytes[start..crc]), std.mem.readInt(u32, bytes[crc..end][0..4], .little));
    const flags = bytes[start + 1];
    if (flags & 0x3c != 0) return error.InvalidXzHeader;
    var offset = start + 2;
    const packed_size = if (flags & 0x40 != 0) try vli(bytes, &offset, crc) else null;
    const unpacked = if (flags & 0x80 != 0) try vli(bytes, &offset, crc) else null;
    var ids: [4]u64 = @splat(0);
    var properties_views: [4][]const u8 = @splat(&.{});
    for (0..@as(usize, (flags & 3) + 1)) |index| {
        const id = try vli(bytes, &offset, crc);
        const properties = try vli(bytes, &offset, crc);
        const count = std.math.cast(usize, properties.value) orelse return error.IntegerOverflow;
        if (count > crc - offset) return error.TruncatedFrame;
        ids[index] = id.value;
        properties_views[index] = bytes[offset..][0..count];
        if (index == @as(usize, flags & 3)) {
            try std.testing.expectEqual(@as(u64, 0x21), id.value);
            try std.testing.expectEqual(@as(usize, 1), count);
        }
        offset += count;
    }
    for (bytes[offset..crc]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    return .{ .start = start, .end = end, .crc = crc, .flags = flags, .packed_size = packed_size, .unpacked = unpacked, .filter_ids = ids, .filter_properties = properties_views };
}
pub const Envelope = struct { end: usize, plain: usize, compressed: usize };
pub fn lzma2(bytes: []const u8, start: usize) !Envelope {
    var offset = start;
    var plain_size: usize = 0;
    var compressed: usize = 0;
    while (true) {
        _ = try endOf(bytes, offset, 1);
        const control = bytes[offset];
        offset += 1;
        if (control == 0) return .{ .end = offset, .plain = plain_size, .compressed = compressed };
        _ = try endOf(bytes, offset, 2);
        if (control == 1 or control == 2) {
            const length: usize = @as(usize, std.mem.readInt(u16, bytes[offset..][0..2], .big)) + 1;
            offset = try endOf(bytes, offset + 2, length);
            plain_size += length;
        } else {
            if (control < 0x80) return error.InvalidXzStream;
            _ = try endOf(bytes, offset, 4);
            const length: usize = (@as(usize, control & 31) << 16 | @as(usize, std.mem.readInt(u16, bytes[offset..][0..2], .big))) + 1;
            const packed_size: usize = @as(usize, std.mem.readInt(u16, bytes[offset + 2 ..][0..2], .big)) + 1;
            offset += 4;
            if (control >= 0xc0) offset = try endOf(bytes, offset, 1);
            offset = try endOf(bytes, offset, packed_size);
            plain_size += length;
            compressed += 1;
        }
    }
}
pub fn checkSize(check: xz.Check) usize {
    return switch (check) {
        .none => 0,
        .crc32 => 4,
        .crc64 => 8,
        .sha256 => 32,
        else => unreachable,
    };
}
pub const Block = struct { header: Header, data_end: usize, check_start: usize, end: usize, packed_size: usize, plain: usize, compressed: usize, unpadded: u64, index_plain: ?Vli = null };
pub fn block(bytes: []const u8, start: usize, check: xz.Check) !Block {
    const parsed = try header(bytes, start);
    const body = try lzma2(bytes, parsed.end);
    const packed_size = body.end - parsed.end;
    const padding: usize = (4 - (packed_size % 4)) % 4; // Headers are four-byte aligned.
    const check_start = try endOf(bytes, body.end, padding);
    for (bytes[body.end..check_start]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
    const end = try endOf(bytes, check_start, checkSize(check));
    if (parsed.packed_size) |size| try std.testing.expectEqual(@as(u64, packed_size), size.value);
    if (parsed.unpacked) |size| try std.testing.expectEqual(@as(u64, body.plain), size.value);
    return .{ .header = parsed, .data_end = body.end, .check_start = check_start, .end = end, .packed_size = packed_size, .plain = body.plain, .compressed = body.compressed, .unpadded = @intCast(parsed.end - start + packed_size + checkSize(check)) };
}
pub const Layout = struct {
    blocks: []Block,
    index_start: usize,
    index_crc: usize,
    pub fn deinit(self: Layout) void {
        a.free(self.blocks);
    }
};
pub fn parse(bytes: []const u8) !Layout {
    _ = try endOf(bytes, 0, 12);
    try std.testing.expectEqualSlices(u8, &.{ 0xfd, '7', 'z', 'X', 'Z', 0 }, bytes[0..6]);
    try std.testing.expectEqual(@as(u8, 0), bytes[6]);
    try std.testing.expectEqual(std.hash.Crc32.hash(bytes[6..8]), std.mem.readInt(u32, bytes[8..12], .little));
    const check: xz.Check = @enumFromInt(bytes[7]);
    var blocks: std.ArrayList(Block) = .empty;
    errdefer blocks.deinit(a);
    var offset: usize = 12;
    while (true) {
        _ = try endOf(bytes, offset, 1);
        if (bytes[offset] == 0) break;
        const parsed = try block(bytes, offset, check);
        try blocks.append(a, parsed);
        offset = parsed.end;
    }
    const index_start = offset;
    offset += 1;
    try std.testing.expectEqual(@as(u64, blocks.items.len), (try vli(bytes, &offset, bytes.len)).value);
    for (blocks.items) |*entry| {
        try std.testing.expectEqual(entry.unpadded, (try vli(bytes, &offset, bytes.len)).value);
        const unpacked = try vli(bytes, &offset, bytes.len);
        try std.testing.expectEqual(@as(u64, entry.plain), unpacked.value);
        entry.index_plain = unpacked;
    }
    while ((offset - index_start) % 4 != 0) : (offset += 1) {
        _ = try endOf(bytes, offset, 1);
        try std.testing.expectEqual(@as(u8, 0), bytes[offset]);
    }
    const index_crc = offset;
    _ = try endOf(bytes, offset, 16);
    try std.testing.expectEqual(std.hash.Crc32.hash(bytes[index_start..offset]), std.mem.readInt(u32, bytes[offset..][0..4], .little));
    offset += 4;
    try std.testing.expectEqual(std.hash.Crc32.hash(bytes[offset + 4 .. offset + 10]), std.mem.readInt(u32, bytes[offset..][0..4], .little));
    try std.testing.expectEqual(@as(u32, @intCast((offset - index_start) / 4 - 1)), std.mem.readInt(u32, bytes[offset + 4 ..][0..4], .little));
    try std.testing.expectEqualSlices(u8, bytes[6..8], bytes[offset + 8 .. offset + 10]);
    try std.testing.expectEqualSlices(u8, "YZ", bytes[offset + 10 .. offset + 12]);
    try std.testing.expectEqual(bytes.len, offset + 12);
    return .{ .blocks = try blocks.toOwnedSlice(a), .index_start = index_start, .index_crc = index_crc };
}
pub fn resignHeader(bytes: []u8, parsed: Header) void {
    std.mem.writeInt(u32, bytes[parsed.crc..][0..4], std.hash.Crc32.hash(bytes[parsed.start..parsed.crc]), .little);
}
pub fn fixture(length: usize) ![]u8 {
    const bytes = try a.alloc(u8, length);
    for (bytes, 0..) |*byte, index| byte.* = if ((index / 128) % 3 == 0) @truncate(index *% 37 +% index / 251) else plain[index % plain.len];
    return bytes;
}
pub fn options() xz.EncodeOptions {
    return .{ .block_size = 128, .chunk_size = 128, .parser = .fast, .match_options = .{ .finder = .hc4, .nice_len = 32, .depth = 8 }, .include_block_sizes = true };
}
pub fn streamOptions(opts: xz.EncodeOptions, api: Api) xz.IncrementalEncoder.Options {
    return .{ .check = opts.check, .block_size = opts.block_size, .dictionary_size = opts.dictionary_size, .chunk_size = opts.chunk_size, .filters = opts.filters, .parser = if (api == .lazy) .lazy else opts.parser, .properties = opts.properties, .match_options = opts.match_options, .payload_encoding = if (api == .stored) .stored else .compressed, .include_block_sizes = opts.include_block_sizes };
}
pub fn encode(api: Api, allocator: std.mem.Allocator, input: []const u8, opts: xz.EncodeOptions) ![]u8 {
    return switch (api) {
        .compressed => xz.encodeAlloc(allocator, input, opts),
        .stored => xz.encodeStoredAlloc(allocator, input, opts),
        .lazy => xz.encodeLazyAlloc(allocator, input, opts),
    };
}
pub fn checked(encoder: anytype, input: []const u8, output: []u8) !core.StepResult {
    @memset(output, 0xa5);
    const before = encoder.snapshot();
    const step = try encoder.step(input, output);
    const after = encoder.snapshot();
    try std.testing.expectEqual(step.progress.input_read, after.input_read - before.input_read);
    try std.testing.expectEqual(step.progress.output_written, after.output_written - before.output_written);
    try untouched(output[step.progress.output_written..]);
    return step;
}
pub fn feed(encoder: anytype, wire: *std.ArrayList(u8), input: []const u8) !void {
    var offset: usize = 0;
    for (0..input.len * 8 + 8192) |_| {
        var output: [257]u8 = undefined;
        const step = try checked(encoder, input[offset..@min(input.len, offset + 17)], &output);
        offset += step.progress.input_read;
        try wire.appendSlice(a, output[0..step.progress.output_written]);
        if (offset == input.len and step.status == .need_input) return;
    }
    return error.TestUnexpectedResult;
}
pub fn drain(encoder: anytype, wire: *std.ArrayList(u8), expected: core.StepResult.Status) !void {
    for (0..1024 * 1024) |_| {
        var output: [257]u8 = undefined;
        const step = try checked(encoder, "", &output);
        try wire.appendSlice(a, output[0..step.progress.output_written]);
        if (step.status == expected) return;
        try std.testing.expectEqual(.need_output, step.status);
    }
    return error.TestUnexpectedResult;
}
pub fn drive(encoder: anytype, input: []const u8) ![]u8 {
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(a);
    try feed(encoder, &wire, input);
    encoder.finish();
    try drain(encoder, &wire, .done);
    return wire.toOwnedSlice(a);
}
pub fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
pub fn checkWire(wire: []const u8, input: []const u8, sizes: bool) !void {
    const layout = try parse(wire);
    defer layout.deinit();
    for (layout.blocks) |entry| try std.testing.expectEqual(if (sizes) @as(u8, 0xc0) else 0, entry.header.flags & 0xc0);
    const decoded = try xz.decodeAlloc(a, wire);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expectEqual(input.len, try xz.decodedSize(a, wire));
}
pub fn parity(api: Api, input: []const u8, opts: xz.EncodeOptions) !void {
    const serial = try encode(api, a, input, opts);
    defer a.free(serial);
    try checkWire(serial, input, opts.include_block_sizes);
    const metadata = try parse(serial);
    defer metadata.deinit();
    for (metadata.blocks) |entry| {
        try std.testing.expectEqual(opts.filters.len, @as(usize, entry.header.flags & 3));
        for (opts.filters, 0..) |filter, index| {
            const id: u64 = switch (filter.kind) {
                .delta => 3,
                .x86 => 4,
                .powerpc => 5,
                .ia64 => 6,
                .arm => 7,
                .arm_thumb => 8,
                .sparc => 9,
                .arm64 => 10,
                .riscv => 11,
            };
            try std.testing.expectEqual(id, entry.header.filter_ids[index]);
            const properties = entry.header.filter_properties[index];
            if (filter.kind == .delta) {
                try std.testing.expectEqual(@as(usize, 1), properties.len);
                try std.testing.expectEqual(filter.parameter - 1, @as(u32, properties[0]));
            } else if (filter.parameter == 0) try std.testing.expectEqual(@as(usize, 0), properties.len) else {
                try std.testing.expectEqual(@as(usize, 4), properties.len);
                try std.testing.expectEqual(filter.parameter, std.mem.readInt(u32, properties[0..4], .little));
            }
        }
    }
    var parallel = opts;
    parallel.parallel = .{ .io = std.testing.io };
    const concurrent = try encode(api, a, input, parallel);
    defer a.free(concurrent);
    try std.testing.expectEqualSlices(u8, serial, concurrent);
    var encoder = try xz.IncrementalEncoder.initExactSize(a, streamOptions(opts, api), input.len);
    defer encoder.deinit();
    const streamed = try drive(&encoder, input);
    defer a.free(streamed);
    try std.testing.expectEqualSlices(u8, serial, streamed);
}
