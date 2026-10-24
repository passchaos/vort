const std = @import("std");
const format = @import("../format.zig");
const input_module = @import("input.zig");

pub const Error = format.Error || input_module.Error;

pub fn read(input: input_module.Input) Error!format.Superblock {
    var buffer: [64 * 1024]u8 = undefined;
    const base_end = format.super_offset + format.super_base_size;
    try input.read(0, buffer[0..base_end]);
    if (format.readU32(buffer[format.super_offset..], 0) != format.magic) return error.InvalidMagic;
    const bits = buffer[format.super_offset + 12];
    if (bits < 9 or bits > 16) return error.InvalidErofs;
    const block_size: usize = @as(usize, 1) << @intCast(bits);
    // Preserve the shared parser's ordering for unsupported superblock sizes.
    const extra_size = @as(usize, buffer[format.super_offset + 13]) * 16;
    const super_size = format.super_base_size + extra_size;
    if (super_size > block_size -| format.super_offset) return error.InvalidErofs;
    const super_end = base_end + extra_size;
    try input.read(base_end, buffer[base_end..super_end]);
    const checksum = format.readU32(buffer[format.super_offset..], 8) & 1 != 0;
    // Validate features, addresses and image size before fetching checksum
    // bytes, retaining the slice parser's malformed-header error precedence.
    const preliminary = format.parseSuperblockWithLength(buffer[0..super_end], input.len());
    if (preliminary) |super| return super else |err| {
        if (err != error.TruncatedFrame or !checksum) return err;
    }
    const required = @max(super_end, block_size);
    try input.read(super_end, buffer[super_end..required]);
    return format.parseSuperblockWithLength(buffer[0..required], input.len());
}

test "EROFS source superblock reads only its header and verifies declared image length" {
    const Context = struct {
        header: [4096]u8 = @splat(0),
        requested: usize = 0,
        fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw));
            const start: usize = @intCast(offset);
            if (start > self.header.len or output.len > self.header.len - start) return error.SourceReadFailed;
            self.requested += output.len;
            @memcpy(output, self.header[start..][0..output.len]);
            return output.len;
        }
    };
    var context = Context{};
    std.mem.writeInt(u32, context.header[1024..1028], format.magic, .little);
    std.mem.writeInt(u32, context.header[1032..1036], 1, .little);
    context.header[1036] = 12;
    std.mem.writeInt(u64, context.header[1040..1048], 1, .little);
    std.mem.writeInt(u32, context.header[1060..1064], 1024, .little);
    std.mem.writeInt(u32, context.header[1028..1032], format.computeSuperblockChecksum(context.header[1024..]), .little);
    var source = input_module.Input{ .source = .{ .context = &context, .len = 4 * 1024 * 1024, .read_at = Context.readAt } };
    const super = try read(source);
    try std.testing.expectEqual(@as(u64, 4 * 1024 * 1024), try super.imageSize64());
    try std.testing.expectEqual(@as(usize, 4096), context.requested);
    source.source.len -= 1;
    try std.testing.expectError(error.TruncatedFrame, read(source));
    source.source.len += 1;
    context.header[2048] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, read(source));
}
