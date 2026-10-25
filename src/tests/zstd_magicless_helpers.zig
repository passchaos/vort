//! Independent frame bytes and progress checks; no codec-root import.
const std = @import("std");
const core = @import("../core.zig");
pub const magic = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd };
pub const plain = "magicless frames keep actual bytes and dictionary state abcdefghabcdefgh-tail";

pub const Header = struct {
    descriptor: u8,
    payload_offset: usize,
    content_size: ?u64,
    content_width: usize,
    dictionary_id: u32,
    checksum: bool,
    window: u64,
};
fn little(bytes: []const u8, offset: *usize, width: usize) !u64 {
    if (offset.* > bytes.len or width > bytes.len - offset.*) return error.TruncatedFrame;
    var value: u64 = 0;
    for (bytes[offset.*..][0..width], 0..) |byte, index| value |= @as(u64, byte) << @as(u6, @intCast(index * 8));
    offset.* += width;
    return value;
}
pub fn header(bytes: []const u8, magicless: bool) !Header {
    var offset: usize = 0;
    if (!magicless) {
        if (bytes.len < magic.len) return error.TruncatedFrame;
        if (!std.mem.eql(u8, bytes[0..4], &magic)) return error.InvalidMagic;
        offset = 4;
    }
    const descriptor: u8 = @intCast(try little(bytes, &offset, 1));
    if (descriptor & 8 != 0) return error.CorruptFrame;
    const single = descriptor & 0x20 != 0;
    var window: u64 = 0;
    if (!single) {
        const raw = try little(bytes, &offset, 1);
        const base = @as(u64, 1) << @as(u6, @intCast(10 + (raw >> 3)));
        window = base + (base / 8) * (raw & 7);
    }
    const dictionary_width: usize = switch (descriptor & 3) {
        0 => 0,
        1 => 1,
        2 => 2,
        else => 4,
    };
    const dictionary_id: u32 = @intCast(try little(bytes, &offset, dictionary_width));
    const width: usize = switch (descriptor >> 6) {
        0 => if (single) 1 else 0,
        1 => 2,
        2 => 4,
        else => 8,
    };
    const size: ?u64 = if (width == 0) null else blk: {
        const encoded = try little(bytes, &offset, width);
        break :blk encoded + if (width == 2) @as(u64, 256) else 0;
    };
    if (single) window = size.?;
    return .{ .descriptor = descriptor, .payload_offset = offset, .content_size = size, .content_width = width, .dictionary_id = dictionary_id, .checksum = descriptor & 4 != 0, .window = window };
}
pub const Scan = struct { header: Header, blocks: usize, end: usize };
pub fn scan(bytes: []const u8, magicless: bool) !Scan {
    const parsed = try header(bytes, magicless);
    var offset = parsed.payload_offset;
    var count: usize = 0;
    while (true) {
        const block = try little(bytes, &offset, 3);
        const kind = (block >> 1) & 3;
        if (kind == 3) return error.CorruptFrame;
        const length: usize = @intCast(block >> 3);
        if (length > 128 * 1024) return error.CorruptFrame;
        const stored: usize = if (kind == 1) 1 else length;
        if (stored > bytes.len - offset) return error.TruncatedFrame;
        offset += stored;
        count += 1;
        if (block & 1 != 0) break;
    }
    if (parsed.checksum) _ = try little(bytes, &offset, 4);
    return .{ .header = parsed, .blocks = count, .end = offset };
}
pub fn standardAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, magic.len + bytes.len);
    @memcpy(result[0..4], &magic);
    @memcpy(result[4..], bytes);
    return result;
}
pub fn rawAlloc(allocator: std.mem.Allocator, payload: []const u8, checksum: bool) ![]u8 {
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(allocator);
    const width: usize = if (payload.len < 256) 1 else if (payload.len <= 65791) 2 else 4;
    const flag: u8 = if (width == 1) 0 else if (width == 2) 0x40 else 0x80;
    try wire.append(allocator, 0x20 | flag | if (checksum) @as(u8, 4) else 0);
    const encoded = payload.len - if (width == 2) @as(usize, 256) else 0;
    for (0..width) |index| try wire.append(allocator, @truncate(encoded >> @as(std.math.Log2Int(usize), @intCast(index * 8))));
    var offset: usize = 0;
    while (true) {
        const length: usize = @min(payload.len - offset, 128 * 1024);
        const last = offset + length == payload.len;
        // @min narrows its result using the constant upper bound. Widen the
        // byte count before shifting; 128 KiB needs 21 bits as a block header.
        const block_header: u24 = (@as(u24, @intCast(length)) << 3) | @intFromBool(last);
        var bytes: [3]u8 = undefined;
        std.mem.writeInt(u24, &bytes, block_header, .little);
        try wire.appendSlice(allocator, &bytes);
        try wire.appendSlice(allocator, payload[offset..][0..length]);
        offset += length;
        if (last) break;
    }
    if (checksum) {
        var bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &bytes, @truncate(std.hash.XxHash64.hash(0, payload)), .little);
        try wire.appendSlice(allocator, &bytes);
    }
    return wire.toOwnedSlice(allocator);
}
pub fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
pub fn check(comptime Z: type, allocator: std.mem.Allocator, wire: []const u8, payload: []const u8, opts: Z.FrameDecodeOptions) !void {
    try std.testing.expectEqual(payload.len, try Z.decodedFrameSizeWithOptions(wire, opts));
    const decoded = try Z.decodeFrameAllocWithOptions(allocator, wire, opts);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    const guarded = try allocator.alloc(u8, payload.len + 17);
    defer allocator.free(guarded);
    @memset(guarded, 0xa5);
    const written = try Z.decodeFrameIntoWithOptions(allocator, wire, guarded[0..payload.len], opts);
    try std.testing.expectEqual(payload.len, written);
    try std.testing.expectEqualSlices(u8, payload, guarded[0..written]);
    try untouched(guarded[written..]);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "caller-prefix");
    try std.testing.expectEqual(payload.len, try Z.decodeFrameAppendWithOptions(allocator, &appended, wire, opts));
    try std.testing.expectEqualStrings("caller-prefix", appended.items[0..13]);
    try std.testing.expectEqualSlices(u8, payload, appended.items[13..]);
}
pub const Driven = struct { output: []u8, consumed: usize };
pub fn drive(allocator: std.mem.Allocator, decoder: anytype, wire: []const u8, output_bound: usize, input_quota: usize, output_quota: usize) !Driven {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    var read: usize = 0;
    for (0..(wire.len + output_bound) * 8 + 4096) |call| {
        var output: [257]u8 = @splat(0xa5);
        const before = decoder.snapshot();
        const end = @min(wire.len, read + input_quota);
        const step = try decoder.step(wire[read..end], output[0..if (call % 11 == 0) 0 else output_quota]);
        const after = decoder.snapshot();
        try std.testing.expectEqual(@as(core.StreamCount, step.progress.input_read), after.input_received - before.input_received);
        try std.testing.expectEqual(@as(core.StreamCount, step.progress.output_written), after.output_written - before.output_written);
        try untouched(output[step.progress.output_written..]);
        try result.appendSlice(allocator, output[0..step.progress.output_written]);
        read += step.progress.input_read;
        if (step.status == .done and (read == wire.len or decoder.options.stop_after_first_frame)) return .{ .output = try result.toOwnedSlice(allocator), .consumed = read };
    }
    return error.TestUnexpectedResult;
}
pub fn encodeDrive(allocator: std.mem.Allocator, encoder: anytype, input: []const u8) ![]u8 {
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(allocator);
    var offset: usize = 0;
    var finishing = false;
    for (0..input.len * 8 + 8192) |_| {
        if (offset == input.len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        var output: [31]u8 = @splat(0xa5);
        const before = encoder.snapshot();
        const step = try encoder.step(input[offset..@min(input.len, offset + 17)], &output);
        const after = encoder.snapshot();
        try std.testing.expectEqual(@as(core.StreamCount, step.progress.input_read), after.input_read - before.input_read);
        try std.testing.expectEqual(@as(core.StreamCount, step.progress.output_written), after.output_written - before.output_written);
        try untouched(output[step.progress.output_written..]);
        offset += step.progress.input_read;
        try wire.appendSlice(allocator, output[0..step.progress.output_written]);
        if (step.status == .done) {
            try std.testing.expectEqual(input.len, offset);
            return wire.toOwnedSlice(allocator);
        }
    }
    return error.TestUnexpectedResult;
}
