const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const EncodeOptions = struct {
    sector_size: u32 = format.default_sector_size,
    deduplicate: bool = true,
    max_sectors: usize = 1 << 24,
    max_sector_size: usize = 64 * 1024 * 1024,
    max_output_len: usize = std.math.maxInt(usize),
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    const sector_size: usize = options.sector_size;
    if (sector_size < format.min_sector_size or
        sector_size >= format.format_max_sector_size)
        return error.InvalidWux;
    if (sector_size > options.max_sector_size)
        return error.OutputLimitExceeded;
    const sector_count = std.math.divCeil(
        usize,
        input.len,
        sector_size,
    ) catch return error.IntegerOverflow;
    if (sector_count > options.max_sectors or
        sector_count > std.math.maxInt(u32))
        return error.OutputLimitExceeded;
    const data_offset = try format.dataOffset(sector_count, sector_size);
    if (data_offset > options.max_output_len) return error.OutputLimitExceeded;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, data_offset);
    var hashes = std.AutoHashMap([32]u8, u32).init(allocator);
    defer hashes.deinit();
    const sector = try allocator.alloc(u8, sector_size);
    defer allocator.free(sector);
    var unique_count: usize = 0;
    for (0..sector_count) |logical_sector| {
        @memset(sector, 0);
        const start = logical_sector * sector_size;
        const end = start + @min(sector_size, input.len - start);
        @memcpy(sector[0 .. end - start], input[start..end]);
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(sector, &digest, .{});
        var physical_sector: ?u32 = null;
        if (options.deduplicate) {
            if (hashes.get(digest)) |candidate| {
                const stored_offset = data_offset +
                    @as(usize, candidate) * sector_size;
                if (std.mem.eql(
                    u8,
                    sector,
                    output.items[stored_offset..][0..sector_size],
                )) physical_sector = candidate;
            }
        }
        if (physical_sector == null) {
            if (unique_count > std.math.maxInt(u32))
                return error.OutputLimitExceeded;
            const next_size = std.math.add(
                usize,
                output.items.len,
                sector_size,
            ) catch return error.IntegerOverflow;
            if (next_size > options.max_output_len)
                return error.OutputLimitExceeded;
            physical_sector = @intCast(unique_count);
            try output.appendSlice(allocator, sector);
            if (options.deduplicate and !hashes.contains(digest))
                try hashes.put(digest, physical_sector.?);
            unique_count += 1;
        }
        format.writeU32Le(
            output.items,
            format.header_size + logical_sector * 4,
            physical_sector.?,
        );
    }
    @memcpy(output.items[0..4], format.magic0);
    format.writeU32Le(output.items, 4, format.magic1);
    format.writeU32Le(output.items, 8, options.sector_size);
    format.writeU32Le(output.items, 12, 0);
    format.writeU64Le(output.items, 16, input.len);
    format.writeU32Le(output.items, 24, 0);
    format.writeU32Le(output.items, 28, 0);
    return output.toOwnedSlice(allocator);
}
