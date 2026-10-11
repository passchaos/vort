const std = @import("std");
const apple_adc = @import("../apple_adc.zig");
const bzip2 = @import("../bzip2.zig");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const lzfse = @import("../lzfse.zig");
const lzma = @import("../lzma.zig");
const xz = @import("../xz.zig");
const format = @import("format.zig");

pub const Error = core.Error || format.Error || apple_adc.Error || bzip2.Error ||
    deflate.Error || lzfse.Error || lzma.Error || xz.Error ||
    std.mem.Allocator.Error;

pub const Compression = enum {
    copy,
    adc,
    zlib,
    bzip2,
    lzfse,
    xz,
};

pub const EncodeOptions = struct {
    compression: Compression = .zlib,
    block_size: usize = 1024 * 1024,
    name: []const u8 = "Apple_HFS",
    copy_if_larger: bool = true,
};

const EncodedBlock = struct {
    kind: format.ChunkKind,
    decoded_offset: usize,
    decoded_size: usize,
    packed_offset: usize,
    packed_size: usize,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) Error!usize {
    const start = output.items.len;
    errdefer output.shrinkRetainingCapacity(start);
    if (input.len % format.sector_size != 0) return error.InvalidDmg;
    if (options.block_size == 0 or options.block_size % format.sector_size != 0)
        return error.InvalidDmg;

    var data_fork: std.ArrayList(u8) = .empty;
    defer data_fork.deinit(allocator);
    var blocks: std.ArrayList(EncodedBlock) = .empty;
    defer blocks.deinit(allocator);
    var position: usize = 0;
    while (position < input.len) {
        const length = @min(options.block_size, input.len - position);
        const block_input = input[position..][0..length];
        var encoded: ?[]u8 = null;
        defer if (encoded) |bytes| allocator.free(bytes);
        var kind: format.ChunkKind = undefined;
        const selected: []const u8 = if (allZero(block_input)) blk: {
            kind = .zero;
            break :blk "";
        } else if (options.compression == .copy) blk: {
            kind = .copy;
            break :blk block_input;
        } else blk: {
            encoded = try encodeBlock(allocator, options.compression, block_input);
            if ((options.copy_if_larger or options.compression == .lzfse) and
                encoded.?.len >= block_input.len)
            {
                kind = .copy;
                break :blk block_input;
            }
            kind = compressionKind(options.compression);
            break :blk encoded.?;
        };
        const packed_offset = data_fork.items.len;
        try data_fork.appendSlice(allocator, selected);
        try blocks.append(allocator, .{
            .kind = kind,
            .decoded_offset = position,
            .decoded_size = length,
            .packed_offset = packed_offset,
            .packed_size = selected.len,
        });
        position += length;
    }

    const mish = try buildMishAlloc(allocator, input, blocks.items, options);
    defer allocator.free(mish);
    const xml = try buildPlistAlloc(allocator, mish, options.name);
    defer allocator.free(xml);

    try output.appendSlice(allocator, data_fork.items);
    const xml_offset = output.items.len - start;
    try output.appendSlice(allocator, xml);
    const trailer = try buildTrailer(
        data_fork.items,
        xml_offset,
        xml.len,
        input,
    );
    try output.appendSlice(allocator, &trailer);
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
    output: []u8,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn encodeBlock(
    allocator: std.mem.Allocator,
    compression: Compression,
    input: []const u8,
) Error![]u8 {
    return switch (compression) {
        .copy => unreachable,
        .adc => apple_adc.encodeAlloc(allocator, input),
        .zlib => deflate.encodeZlibBestAlloc(allocator, input, .{}),
        .bzip2 => bzip2.encodeAlloc(allocator, input, .{}),
        .lzfse => lzfse.encodeAlloc(allocator, input, .{}),
        .xz => xz.encodeAlloc(allocator, input, .{}),
    };
}

fn compressionKind(compression: Compression) format.ChunkKind {
    return switch (compression) {
        .copy => .copy,
        .adc => .adc,
        .zlib => .zlib,
        .bzip2 => .bzip2,
        .lzfse => .lzfse,
        .xz => .xz,
    };
}

fn buildMishAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    blocks: []const EncodedBlock,
    options: EncodeOptions,
) Error![]u8 {
    const record_count = std.math.add(usize, blocks.len, 1) catch
        return error.IntegerOverflow;
    const records_size = std.math.mul(
        usize,
        record_count,
        format.block_record_size,
    ) catch return error.IntegerOverflow;
    const size = std.math.add(usize, format.mish_header_size, records_size) catch
        return error.IntegerOverflow;
    const output = try allocator.alloc(u8, size);
    @memset(output, 0);
    format.writeU32Be(output, 0, format.mish_magic);
    format.writeU32Be(output, 4, 1);
    format.writeU64Be(output, 8, 0);
    format.writeU64Be(output, 0x10, input.len / format.sector_size);
    format.writeU64Be(output, 0x18, 0);
    const requested_sectors = std.math.add(
        usize,
        options.block_size / format.sector_size,
        8,
    ) catch return error.IntegerOverflow;
    format.writeU32Be(
        output,
        0x20,
        std.math.cast(u32, requested_sectors) orelse return error.IntegerOverflow,
    );
    format.writeU32Be(output, 0x24, 0xffff_ffff);
    format.writeU32Be(output, 0x40, 2);
    format.writeU32Be(output, 0x44, 32);
    format.writeU32Be(output, 0x48, checksum.crc32Best(input));
    format.writeU32Be(
        output,
        0xc8,
        std.math.cast(u32, record_count) orelse return error.IntegerOverflow,
    );
    for (blocks, 0..) |block, index| {
        const offset = format.mish_header_size + index * format.block_record_size;
        format.writeU32Be(output, offset, @intFromEnum(block.kind));
        format.writeU64Be(output, offset + 8, block.decoded_offset / format.sector_size);
        format.writeU64Be(output, offset + 0x10, block.decoded_size / format.sector_size);
        format.writeU64Be(output, offset + 0x18, block.packed_offset);
        format.writeU64Be(output, offset + 0x20, block.packed_size);
    }
    const end_offset = format.mish_header_size + blocks.len * format.block_record_size;
    format.writeU32Be(output, end_offset, @intFromEnum(format.ChunkKind.end));
    format.writeU64Be(
        output,
        end_offset + 8,
        input.len / format.sector_size,
    );
    return output;
}

fn buildPlistAlloc(
    allocator: std.mem.Allocator,
    mish: []const u8,
    name: []const u8,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(
        allocator,
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" ++
            "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" " ++
            "\"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" ++
            "<plist version=\"1.0\"><dict><key>resource-fork</key><dict>" ++
            "<key>blkx</key><array><dict><key>Data</key><data>\n",
    );
    const encoded_size = std.base64.standard.Encoder.calcSize(mish.len);
    const encoded = try output.addManyAsSlice(allocator, encoded_size);
    _ = std.base64.standard.Encoder.encode(encoded, mish);
    try output.appendSlice(allocator, "\n</data><key>Name</key><string>");
    try appendXmlEscaped(allocator, &output, name);
    try output.appendSlice(
        allocator,
        "</string></dict></array></dict></dict></plist>\n",
    );
    return output.toOwnedSlice(allocator);
}

fn buildTrailer(
    data_fork: []const u8,
    xml_offset: usize,
    xml_length: usize,
    input: []const u8,
) Error![format.trailer_size]u8 {
    var trailer: [format.trailer_size]u8 = @splat(0);
    format.writeU32Be(&trailer, 0, format.koly_magic);
    format.writeU32Be(&trailer, 4, 4);
    format.writeU32Be(&trailer, 8, format.trailer_size);
    format.writeU64Be(&trailer, 0x18, 0);
    format.writeU64Be(&trailer, 0x20, data_fork.len);
    format.writeU32Be(&trailer, 0x50, 2);
    format.writeU32Be(&trailer, 0x54, 32);
    format.writeU32Be(&trailer, 0x58, checksum.crc32Best(data_fork));
    format.writeU64Be(&trailer, 0xd8, xml_offset);
    format.writeU64Be(&trailer, 0xe0, xml_length);

    var partition_crc_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &partition_crc_bytes, checksum.crc32Best(input), .big);
    format.writeU32Be(&trailer, 0x160, 2);
    format.writeU32Be(&trailer, 0x164, 32);
    format.writeU32Be(
        &trailer,
        0x168,
        checksum.crc32Best(&partition_crc_bytes),
    );
    format.writeU32Be(&trailer, 0x1e8, 1);
    format.writeU64Be(&trailer, 0x1ec, input.len / format.sector_size);
    return trailer;
}

fn appendXmlEscaped(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!void {
    for (input) |byte| {
        const replacement: []const u8 = switch (byte) {
            '&' => "&amp;",
            '<' => "&lt;",
            '>' => "&gt;",
            '"' => "&quot;",
            '\'' => "&apos;",
            else => {
                if (byte < 0x20 and byte != '\t' and byte != '\n' and byte != '\r')
                    return error.InvalidDmg;
                try output.append(allocator, byte);
                continue;
            },
        };
        try output.appendSlice(allocator, replacement);
    }
}

fn allZero(input: []const u8) bool {
    for (input) |byte| if (byte != 0) return false;
    return true;
}
