const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const EncodeOptions = struct {
    hd_sector_shift: u8 = 9,
    wbfs_sector_shift: u8 = 21,
    sparse_zero_clusters: bool = true,
    max_hd_sector_size: usize = 64 * 1024,
    max_wbfs_sector_size: usize = 64 * 1024 * 1024,
    max_output_len: usize = std.math.maxInt(usize),
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    if (input.len < format.disc_header_size or input.len > format.logical_size)
        return error.InvalidWbfs;
    if (options.hd_sector_shift < 9 or
        options.hd_sector_shift >= @bitSizeOf(usize) or
        options.wbfs_sector_shift < format.wii_sector_shift or
        options.wbfs_sector_shift >= @bitSizeOf(usize) or
        options.wbfs_sector_shift < options.hd_sector_shift)
        return error.InvalidWbfs;
    const hd_sector_size = @as(usize, 1) << @intCast(options.hd_sector_shift);
    const wbfs_sector_size = @as(usize, 1) << @intCast(options.wbfs_sector_shift);
    if (hd_sector_size > options.max_hd_sector_size or
        wbfs_sector_size > options.max_wbfs_sector_size)
        return error.OutputLimitExceeded;
    const blocks_per_disc = try format.blocksPerDisc(wbfs_sector_size);
    const disc_info_size = try format.discInfoSize(
        blocks_per_disc,
        hd_sector_size,
    );
    if (hd_sector_size + disc_info_size > wbfs_sector_size)
        return error.InvalidWbfs;

    const input_clusters = std.math.divCeil(
        usize,
        input.len,
        wbfs_sector_size,
    ) catch return error.IntegerOverflow;
    const mappings = try allocator.alloc(u16, blocks_per_disc);
    defer allocator.free(mappings);
    @memset(mappings, 0);
    var stored_clusters: usize = 0;
    for (0..input_clusters) |cluster_index| {
        const start = cluster_index * wbfs_sector_size;
        const end = start + @min(wbfs_sector_size, input.len - start);
        const store = cluster_index == 0 or
            !options.sparse_zero_clusters or
            !std.mem.allEqual(u8, input[start..end], 0);
        if (!store) continue;
        stored_clusters += 1;
        if (stored_clusters > std.math.maxInt(u16))
            return error.OutputLimitExceeded;
        mappings[cluster_index] = @intCast(stored_clusters);
    }
    const physical_clusters = stored_clusters + 1;
    if (physical_clusters > std.math.maxInt(u16))
        return error.OutputLimitExceeded;
    const output_size = std.math.mul(
        usize,
        physical_clusters,
        wbfs_sector_size,
    ) catch return error.IntegerOverflow;
    if (output_size > options.max_output_len) return error.OutputLimitExceeded;
    if (output_size % hd_sector_size != 0) return error.InvalidWbfs;
    const hd_sector_count = output_size / hd_sector_size;
    if (hd_sector_count > std.math.maxInt(u32))
        return error.OutputLimitExceeded;

    const output = try allocator.alloc(u8, output_size);
    errdefer allocator.free(output);
    @memset(output, 0);
    @memcpy(output[0..4], format.magic);
    format.writeU32Be(output, 4, @intCast(hd_sector_count));
    output[8] = options.hd_sector_shift;
    output[9] = options.wbfs_sector_shift;
    output[format.header_prefix_size] = 1;
    const disc_info_offset = hd_sector_size;
    @memcpy(
        output[disc_info_offset..][0..format.disc_header_size],
        input[0..format.disc_header_size],
    );
    for (mappings, 0..) |mapping, index|
        format.writeU16Be(
            output,
            disc_info_offset + format.disc_header_size + index * 2,
            mapping,
        );

    for (0..input_clusters) |cluster_index| {
        const mapping = mappings[cluster_index];
        if (mapping == 0) continue;
        const start = cluster_index * wbfs_sector_size;
        const end = start + @min(wbfs_sector_size, input.len - start);
        const destination = @as(usize, mapping) * wbfs_sector_size;
        @memcpy(output[destination..][0 .. end - start], input[start..end]);
    }
    return output;
}
