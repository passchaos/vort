const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidWof,
    UnsupportedWofProvider,
    UnsupportedWofCompression,
};

pub const reparse_tag: u32 = 0x8000_0017;
pub const current_version: u32 = 1;
pub const file_provider: u32 = 2;
pub const file_provider_version: u32 = 1;

pub const Algorithm = enum(u32) {
    xpress4k = 0,
    lzx = 1,
    xpress8k = 2,
    xpress16k = 3,

    pub fn chunkSize(self: Algorithm) usize {
        return switch (self) {
            .xpress4k => 4 * 1024,
            .xpress8k => 8 * 1024,
            .xpress16k => 16 * 1024,
            .lzx => 32 * 1024,
        };
    }
};

pub const ExternalInfo = struct {
    algorithm: Algorithm,
    flags: u32,
};

pub fn parseExternalInfo(bytes: []const u8) Error!ExternalInfo {
    if (bytes.len != 20) return error.InvalidWof;
    if (readU32(bytes, 0) != current_version or readU32(bytes, 4) != file_provider)
        return error.UnsupportedWofProvider;
    if (readU32(bytes, 8) != file_provider_version) return error.UnsupportedWofProvider;
    const algorithm = std.enums.fromInt(Algorithm, readU32(bytes, 12)) orelse
        return error.UnsupportedWofCompression;
    const flags = readU32(bytes, 16);
    if (flags != 0) return error.UnsupportedWofProvider;
    return .{ .algorithm = algorithm, .flags = flags };
}

pub fn parseReparsePoint(bytes: []const u8) Error!ExternalInfo {
    if (bytes.len < 24 or readU32(bytes, 0) != reparse_tag)
        return error.InvalidWof;
    const data_len: usize = readU16(bytes, 4);
    if (readU16(bytes, 6) != 0 or data_len + 8 != bytes.len or
        (data_len != 16 and data_len != 20))
        return error.InvalidWof;
    if (readU32(bytes, 8) != current_version or readU32(bytes, 12) != file_provider)
        return error.UnsupportedWofProvider;
    if (readU32(bytes, 16) != file_provider_version) return error.UnsupportedWofProvider;
    const algorithm = std.enums.fromInt(Algorithm, readU32(bytes, 20)) orelse
        return error.UnsupportedWofCompression;
    const flags = if (data_len == 20) readU32(bytes, 24) else 0;
    if (flags != 0) return error.UnsupportedWofProvider;
    return .{ .algorithm = algorithm, .flags = flags };
}

pub fn encodeExternalInfo(algorithm: Algorithm) [20]u8 {
    var bytes: [20]u8 = @splat(0);
    writeU32(&bytes, 0, current_version);
    writeU32(&bytes, 4, file_provider);
    writeU32(&bytes, 8, file_provider_version);
    writeU32(&bytes, 12, @intFromEnum(algorithm));
    return bytes;
}

pub fn encodeReparsePoint(algorithm: Algorithm) [28]u8 {
    var bytes: [28]u8 = @splat(0);
    writeU32(&bytes, 0, reparse_tag);
    writeU16(&bytes, 4, 20);
    writeU32(&bytes, 8, current_version);
    writeU32(&bytes, 12, file_provider);
    writeU32(&bytes, 16, file_provider_version);
    writeU32(&bytes, 20, @intFromEnum(algorithm));
    return bytes;
}

pub const Chunk = struct {
    index: usize,
    encoded: []const u8,
    decoded_size: usize,

    pub fn isStored(self: Chunk) bool {
        return self.encoded.len == self.decoded_size;
    }
};

pub const Backing = struct {
    bytes: []const u8,
    algorithm: Algorithm,
    uncompressed_size: usize,
    chunk_size: usize,
    chunk_count: usize,
    entry_size: usize,
    table_size: usize,

    pub fn init(
        bytes: []const u8,
        algorithm: Algorithm,
        uncompressed_size_u64: u64,
    ) Error!Backing {
        const uncompressed_size = std.math.cast(usize, uncompressed_size_u64) orelse
            return error.IntegerOverflow;
        const chunk_size = algorithm.chunkSize();
        if (uncompressed_size == 0) {
            if (bytes.len != 0) return error.TrailingData;
            return .{
                .bytes = bytes,
                .algorithm = algorithm,
                .uncompressed_size = 0,
                .chunk_size = chunk_size,
                .chunk_count = 0,
                .entry_size = 4,
                .table_size = 0,
            };
        }
        const chunk_count = (std.math.add(
            usize,
            uncompressed_size,
            chunk_size - 1,
        ) catch return error.IntegerOverflow) / chunk_size;
        const entry_size: usize = if (uncompressed_size_u64 <= std.math.maxInt(u32)) 4 else 8;
        const table_size = std.math.mul(usize, chunk_count - 1, entry_size) catch
            return error.IntegerOverflow;
        if (table_size >= bytes.len) return error.InvalidWof;
        const data_len = bytes.len - table_size;
        var previous: usize = 0;
        for (0..chunk_count) |chunk_index| {
            const next = if (chunk_index + 1 == chunk_count)
                data_len
            else
                try readOffset(bytes, chunk_index * entry_size, entry_size);
            const decoded_size = @min(
                chunk_size,
                uncompressed_size - chunk_index * chunk_size,
            );
            if (next <= previous or next > data_len or next - previous > decoded_size)
                return error.InvalidWof;
            previous = next;
        }
        return .{
            .bytes = bytes,
            .algorithm = algorithm,
            .uncompressed_size = uncompressed_size,
            .chunk_size = chunk_size,
            .chunk_count = chunk_count,
            .entry_size = entry_size,
            .table_size = table_size,
        };
    }

    pub fn chunk(self: Backing, index: usize) Error!Chunk {
        if (index >= self.chunk_count) return error.RangeOutOfBounds;
        const start = if (index == 0)
            0
        else
            try readOffset(self.bytes, (index - 1) * self.entry_size, self.entry_size);
        const data_len = self.bytes.len - self.table_size;
        const end = if (index + 1 == self.chunk_count)
            data_len
        else
            try readOffset(self.bytes, index * self.entry_size, self.entry_size);
        const decoded_size = @min(
            self.chunk_size,
            self.uncompressed_size - index * self.chunk_size,
        );
        return .{
            .index = index,
            .encoded = self.bytes[self.table_size + start .. self.table_size + end],
            .decoded_size = decoded_size,
        };
    }
};

fn readOffset(bytes: []const u8, offset: usize, entry_size: usize) Error!usize {
    if (bytes.len -| offset < entry_size) return error.TruncatedFrame;
    const value = if (entry_size == 4)
        @as(u64, readU32(bytes, offset))
    else
        readU64(bytes, offset);
    return std.math.cast(usize, value) orelse error.IntegerOverflow;
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn readU64(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}

fn writeU16(bytes: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, bytes[offset..][0..2], value, .little);
}

fn writeU32(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .little);
}

test "WOF file provider metadata round trips" {
    inline for (std.enums.values(Algorithm)) |algorithm| {
        const external = encodeExternalInfo(algorithm);
        try std.testing.expectEqual(algorithm, (try parseExternalInfo(&external)).algorithm);
        const reparse = encodeReparsePoint(algorithm);
        try std.testing.expectEqual(algorithm, (try parseReparsePoint(&reparse)).algorithm);
    }

    var legacy: [24]u8 = @splat(0);
    writeU32(&legacy, 0, reparse_tag);
    writeU16(&legacy, 4, 16);
    writeU32(&legacy, 8, current_version);
    writeU32(&legacy, 12, file_provider);
    writeU32(&legacy, 16, file_provider_version);
    writeU32(&legacy, 20, @intFromEnum(Algorithm.xpress8k));
    try std.testing.expectEqual(
        Algorithm.xpress8k,
        (try parseReparsePoint(&legacy)).algorithm,
    );

    var bad_flags = encodeExternalInfo(.xpress4k);
    writeU32(&bad_flags, 16, 1);
    try std.testing.expectError(
        error.UnsupportedWofProvider,
        parseExternalInfo(&bad_flags),
    );
    var bad_algorithm = encodeExternalInfo(.xpress4k);
    writeU32(&bad_algorithm, 12, 4);
    try std.testing.expectError(
        error.UnsupportedWofCompression,
        parseExternalInfo(&bad_algorithm),
    );
}
