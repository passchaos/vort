const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const ParseOptions = struct {
    max_blocks: usize = 1 << 20,
    max_block_decoded_bytes: usize = 256 * 1024 * 1024,
};

pub const Block = struct {
    kind: format.ChunkKind,
    decoded_offset: u64,
    decoded_size: u64,
    packed_offset: u64,
    packed_size: u64,

    pub fn decodedEnd(self: Block) Error!u64 {
        return std.math.add(u64, self.decoded_offset, self.decoded_size) catch
            error.IntegerOverflow;
    }

    pub fn packedEnd(self: Block) Error!u64 {
        return std.math.add(u64, self.packed_offset, self.packed_size) catch
            error.IntegerOverflow;
    }
};

pub const Partition = struct {
    name: []u8,
    first_sector: u64,
    sector_count: u64,
    data_start: u64,
    descriptor: i32,
    checksum: format.Checksum,
    blocks: []Block,
    decoded_size: u64,
    packed_size: u64,
    max_block_decoded_size: usize,

    pub fn deinit(self: Partition, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.blocks);
    }
};

pub fn parseAlloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    name: []const u8,
    options: ParseOptions,
) Error!Partition {
    if (bytes.len < format.mish_header_size) return error.TruncatedFrame;
    if (format.readU32Be(bytes, 0) != format.mish_magic) return error.InvalidMagic;
    if (format.readU32Be(bytes, 4) != 1) return error.UnsupportedVersion;
    const block_count: usize = format.readU32Be(bytes, 0xc8);
    if (block_count == 0) return error.InvalidDmg;
    if (block_count > options.max_blocks)
        return error.OutputLimitExceeded;
    const records_size = std.math.mul(
        usize,
        block_count,
        format.block_record_size,
    ) catch return error.IntegerOverflow;
    const expected_size = std.math.add(
        usize,
        format.mish_header_size,
        records_size,
    ) catch return error.IntegerOverflow;
    if (bytes.len < expected_size) return error.TruncatedFrame;
    if (bytes.len != expected_size) return error.TrailingData;

    const first_sector = format.readU64Be(bytes, 8);
    const sector_count = format.readU64Be(bytes, 0x10);
    const decoded_size = std.math.mul(u64, sector_count, format.sector_size) catch
        return error.IntegerOverflow;
    const checksum = format.Checksum.parse(bytes, 0x40);
    try checksum.validateSupported();

    var blocks: std.ArrayList(Block) = .empty;
    errdefer blocks.deinit(allocator);
    var decoded_position: u64 = 0;
    var packed_size: u64 = 0;
    var max_block_decoded_size: usize = 0;
    var saw_end = false;
    for (0..block_count) |index| {
        const offset = format.mish_header_size + index * format.block_record_size;
        const raw_kind = format.readU32Be(bytes, offset);
        const kind = std.enums.fromInt(format.ChunkKind, raw_kind) orelse
            return error.UnsupportedDmgChunk;
        if (kind == .comment) continue;
        if (kind == .end) {
            if (index + 1 != block_count) return error.InvalidDmg;
            const end_sector = format.readU64Be(bytes, offset + 8);
            const end_position = std.math.mul(
                u64,
                end_sector,
                format.sector_size,
            ) catch return error.IntegerOverflow;
            if (end_position != decoded_position) return error.InvalidDmg;
            saw_end = true;
            break;
        }
        const sector_offset = format.readU64Be(bytes, offset + 8);
        const sector_length = format.readU64Be(bytes, offset + 0x10);
        const block_decoded_offset = std.math.mul(
            u64,
            sector_offset,
            format.sector_size,
        ) catch return error.IntegerOverflow;
        const block_decoded_size = std.math.mul(
            u64,
            sector_length,
            format.sector_size,
        ) catch return error.IntegerOverflow;
        if (block_decoded_size == 0) continue;
        if (block_decoded_offset != decoded_position) return error.InvalidDmg;
        decoded_position = std.math.add(
            u64,
            decoded_position,
            block_decoded_size,
        ) catch return error.IntegerOverflow;
        if (decoded_position > decoded_size) return error.InvalidDmg;
        const decoded_size_usize = std.math.cast(usize, block_decoded_size) orelse
            return error.IntegerOverflow;
        if (kind.isCompressed() and
            decoded_size_usize > options.max_block_decoded_bytes)
            return error.OutputLimitExceeded;
        if (kind.isCompressed())
            max_block_decoded_size = @max(max_block_decoded_size, decoded_size_usize);

        const packed_offset = format.readU64Be(bytes, offset + 0x18);
        const block_packed_size = format.readU64Be(bytes, offset + 0x20);
        _ = std.math.add(u64, packed_offset, block_packed_size) catch
            return error.IntegerOverflow;
        if (kind.isZero()) {
            if (block_packed_size != 0) return error.InvalidDmg;
        } else if (kind == .copy) {
            if (block_packed_size != block_decoded_size) return error.SizeMismatch;
        } else if (kind.isCompressed()) {
            if (block_packed_size == 0) return error.InvalidDmg;
        } else {
            return error.UnsupportedDmgChunk;
        }
        packed_size = std.math.add(u64, packed_size, block_packed_size) catch
            return error.IntegerOverflow;
        try blocks.append(allocator, .{
            .kind = kind,
            .decoded_offset = block_decoded_offset,
            .decoded_size = block_decoded_size,
            .packed_offset = packed_offset,
            .packed_size = block_packed_size,
        });
    }
    if (!saw_end or decoded_position != decoded_size)
        return error.InvalidDmg;
    const owned_name = try allocator.dupe(u8, name);
    errdefer allocator.free(owned_name);
    return .{
        .name = owned_name,
        .first_sector = first_sector,
        .sector_count = sector_count,
        .data_start = format.readU64Be(bytes, 0x18),
        .descriptor = @bitCast(format.readU32Be(bytes, 0x24)),
        .checksum = checksum,
        .blocks = try blocks.toOwnedSlice(allocator),
        .decoded_size = decoded_size,
        .packed_size = packed_size,
        .max_block_decoded_size = max_block_decoded_size,
    };
}
