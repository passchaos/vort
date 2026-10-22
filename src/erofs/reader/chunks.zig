const std = @import("std");
const context_module = @import("context.zig");
const types = @import("types.zig");
const devices_module = @import("devices.zig");
const format = @import("../format.zig");
const sink_module = @import("../../io/sink.zig");

pub const Error = context_module.Error;

pub fn emit(context: context_module.Context, inode: types.Inode, start: usize, size: usize, sink: sink_module.Sink, destination: u64) Error!void {
    const end = try context_module.add(start, size);
    if (end > inode.file_size) return error.InvalidErofs;
    if (size == 0) return;
    if (inode.chunk_bits >= @bitSizeOf(usize) or (inode.chunk_index_size != 4 and inode.chunk_index_size != 8)) return error.InvalidErofs;
    const metadata = try context.reader.metadataInput(inode);
    const chunk_size: usize = @as(usize, 1) << @intCast(inode.chunk_bits);
    const mask = try devices_module.idMask(context.reader.superblock.extra_devices);
    const null_block: u64 = if (inode.chunk_format & 0x40 != 0) (@as(u64, 1) << 48) - 1 else std.math.maxInt(u32);
    const first = start / chunk_size;
    const last = (end - 1) / chunk_size;
    for (first..last + 1) |index| {
        const relative = std.math.mul(usize, index, inode.chunk_index_size) catch return error.IntegerOverflow;
        const entry_start = try context_module.add(inode.chunk_index_start, relative);
        var record: [8]u8 = @splat(0);
        try metadata.read(entry_start, record[0..inode.chunk_index_size]);
        var device_id: u16 = 0;
        var block: u64 = undefined;
        if (inode.chunk_index_size == 8) {
            const hi = format.readU16(&record, 0);
            const wide = inode.chunk_format & 0x40 != 0;
            if (wide and context.reader.superblock.feature_incompat & format.feature_incompat_48bit == 0) return error.InvalidErofs;
            if (!wide and hi != 0) return error.InvalidErofs;
            device_id = format.readU16(&record, 2) & mask;
            block = @as(u64, format.readU32(&record, 4)) | (if (wide) @as(u64, hi) << 32 else 0);
        } else if (inode.chunk_index_size == 4) {
            block = format.readU32(&record, 0);
        } else return error.InvalidErofs;
        const logical = std.math.mul(usize, index, chunk_size) catch return error.IntegerOverflow;
        const logical_end = @min(inode.file_size, try context_module.add(logical, chunk_size));
        const overlap_start = @max(start, logical);
        const overlap_end = @min(end, logical_end);
        const output = try context_module.offset(destination, overlap_start - start);
        if (block == null_block) {
            try context.zeros(overlap_end - overlap_start, sink, output);
        } else {
            const region = try context.devices.resolve(device_id, block, logical_end - logical);
            try context.copy(region.input, try context_module.offset(region.start, overlap_start - logical), overlap_end - overlap_start, sink, output);
        }
    }
}
