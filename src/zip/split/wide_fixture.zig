const std = @import("std");
const source = @import("source.zig");
const wire = @import("../wire.zig");
const Count = source.Count;

pub const tile_len = 64 * 1024;
pub const data_offset = 4 + wire.local_file_header_len + 4;
pub const central_len = wire.central_file_header_len + 4 + 16;
pub const zip64_offset = central_len;
pub const locator_offset = zip64_offset + wire.zip64_end_of_central_len;
pub const end_offset = locator_offset + wire.zip64_end_of_central_locator_len;
pub const tail_len = end_offset + wire.end_of_central_len;
pub const local_patch_offset = wire.central_file_header_len + 4 + 4;

pub fn tile() [tile_len]u8 {
    var bytes: [tile_len]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @truncate(index * 37 + index / 11);
    @memset(bytes[0..data_offset], 0);
    put(u32, &bytes, 0, wire.data_descriptor_signature);
    put(u32, &bytes, 4, wire.local_file_signature);
    put(u16, &bytes, 4 + 4, 45);
    put(u32, &bytes, 4 + 14, std.hash.Crc32.hash(bytes[data_offset..]));
    put(u32, &bytes, 4 + 18, tile_len - data_offset);
    put(u32, &bytes, 4 + 22, tile_len - data_offset);
    put(u16, &bytes, 4 + 26, 4);
    @memcpy(bytes[data_offset - 4 .. data_offset], "tile");
    return bytes;
}

pub fn tail(last_disk: u32, local_disk: u32, local_offset: Count, tile_bytes: []const u8) [tail_len]u8 {
    var bytes: [tail_len]u8 = @splat(0);
    put(u32, &bytes, 0, wire.central_file_signature);
    put(u16, &bytes, 4, 45);
    put(u16, &bytes, 6, 45);
    put(u32, &bytes, 16, std.hash.Crc32.hash(tile_bytes[data_offset..]));
    put(u32, &bytes, 20, tile_len - data_offset);
    put(u32, &bytes, 24, tile_len - data_offset);
    put(u16, &bytes, 28, 4);
    put(u16, &bytes, 30, 16);
    put(u16, &bytes, 34, std.math.maxInt(u16));
    put(u32, &bytes, 42, std.math.maxInt(u32));
    @memcpy(bytes[wire.central_file_header_len..][0..4], "tile");
    put(u16, &bytes, wire.central_file_header_len + 4, wire.zip64_extra_id);
    put(u16, &bytes, wire.central_file_header_len + 6, 12);
    put(u64, &bytes, local_patch_offset, local_offset);
    put(u32, &bytes, local_patch_offset + 8, local_disk);
    put(u32, &bytes, zip64_offset, wire.zip64_end_of_central_signature);
    put(u64, &bytes, zip64_offset + 4, 44);
    put(u16, &bytes, zip64_offset + 12, 45);
    put(u16, &bytes, zip64_offset + 14, 45);
    put(u32, &bytes, zip64_offset + 16, last_disk);
    put(u32, &bytes, zip64_offset + 20, last_disk);
    put(u64, &bytes, zip64_offset + 24, 1);
    put(u64, &bytes, zip64_offset + 32, 1);
    put(u64, &bytes, zip64_offset + 40, central_len);
    put(u32, &bytes, locator_offset, wire.zip64_end_of_central_locator_signature);
    put(u32, &bytes, locator_offset + 4, last_disk);
    put(u64, &bytes, locator_offset + 8, zip64_offset);
    put(u32, &bytes, locator_offset + 16, last_disk + 1);
    put(u32, &bytes, end_offset, wire.end_of_central_signature);
    put(u16, &bytes, end_offset + 4, std.math.maxInt(u16));
    put(u16, &bytes, end_offset + 6, std.math.maxInt(u16));
    put(u16, &bytes, end_offset + 8, 1);
    put(u16, &bytes, end_offset + 10, 1);
    put(u32, &bytes, end_offset + 12, central_len);
    put(u32, &bytes, end_offset + 16, std.math.maxInt(u32));
    return bytes;
}

/// Independent patch receipt for this fixed ZIP64 metadata layout.
pub fn normalized(raw: [tail_len]u8, base: Count, local: Count) ![tail_len]u8 {
    var bytes = raw;
    put(u64, &bytes, local_patch_offset, local);
    put(u32, &bytes, local_patch_offset + 8, 0);
    put(u32, &bytes, zip64_offset + 16, 0);
    put(u32, &bytes, zip64_offset + 20, 0);
    put(u64, &bytes, zip64_offset + 48, base);
    put(u32, &bytes, locator_offset + 4, 0);
    put(u64, &bytes, locator_offset + 8, try source.count.addLocal(base, zip64_offset));
    put(u32, &bytes, locator_offset + 16, 1);
    return bytes;
}

pub fn put(comptime T: type, bytes: []u8, offset: usize, value: T) void {
    std.mem.writeInt(T, bytes[offset..][0..@sizeOf(T)], value, .little);
}

pub const Callback = struct {
    tile_bytes: []const u8,
    tail_bytes: []const u8,
    reads: usize = 0,
    largest_offset: Count = 0,
    fail: bool = false,
    invalid_amount: bool = false,

    pub fn read(context: *anyopaque, disk: usize, offset: Count, output: []u8) error{PartSourceReadFailed}!usize {
        const self: *Callback = @ptrCast(@alignCast(context));
        self.reads += 1;
        self.largest_offset = @max(self.largest_offset, offset);
        if (self.fail) return error.PartSourceReadFailed;
        if (self.invalid_amount) return 0;
        const take = @min(output.len, 3);
        if (disk == 0) {
            for (output[0..take], 0..) |*byte, index| {
                const absolute = source.count.addLocal(offset, index) catch return error.PartSourceReadFailed;
                byte.* = self.tile_bytes[source.count.ringIndex(absolute, self.tile_bytes.len)];
            }
        } else if (disk == 1) {
            if (offset > self.tail_bytes.len or source.count.fromLocal(take) > self.tail_bytes.len - offset)
                return error.PartSourceReadFailed;
            const local: usize = @intCast(offset);
            @memcpy(output[0..take], self.tail_bytes[local..][0..take]);
        } else return error.PartSourceReadFailed;
        return take;
    }
};
