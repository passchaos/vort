const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidVmdk,
    UnsupportedVmdkFeature,
    UnsupportedVmdkCompression,
    MissingVmdkBackingFile,
};

pub const magic: u32 = 0x564d_444b;
pub const sector_size: usize = 512;
pub const header_size: usize = sector_size;
pub const gd_at_end: u64 = std.math.maxInt(u64);

pub const flag_newline_detect: u32 = 1 << 0;
pub const flag_redundant_directory: u32 = 1 << 1;
pub const flag_zero_grain: u32 = 1 << 2;
pub const flag_compressed: u32 = 1 << 16;
pub const flag_embedded_lba: u32 = 1 << 17;
pub const known_incompatible_flags: u32 = flag_compressed | flag_embedded_lba;

pub const compression_none: u16 = 0;
pub const compression_deflate: u16 = 1;

pub const MarkerType = enum(u32) {
    end_of_stream = 0,
    grain_table = 1,
    grain_directory = 2,
    footer = 3,
};

pub const Marker = struct {
    sectors: u64,
    size: u32,
    kind: MarkerType,
};

pub const Descriptor = struct {
    bytes: []const u8 = "",
    create_type: []const u8 = "",
    parent_file_name_hint: []const u8 = "",
    cid: ?u32 = null,
    parent_cid: ?u32 = null,

    pub fn hasParent(self: Descriptor) bool {
        return self.parent_cid != null and
            self.parent_cid.? != std.math.maxInt(u32);
    }
};

pub const Header = struct {
    version: u32,
    flags: u32,
    capacity_sectors: u64,
    virtual_size: u64,
    grain_sectors: u64,
    grain_size: usize,
    descriptor_offset: u64,
    descriptor_sectors: u64,
    num_gtes_per_gt: usize,
    redundant_gd_offset: u64,
    gd_offset: u64,
    overhead_sectors: u64,
    unclean_shutdown: bool,
    compression_algorithm: u16,
    from_footer: bool = false,

    pub fn isCompressed(self: Header) bool {
        return self.flags & flag_compressed != 0;
    }

    pub fn hasMarkers(self: Header) bool {
        return self.flags & flag_embedded_lba != 0;
    }

    pub fn hasZeroGrain(self: Header) bool {
        return self.flags & flag_zero_grain != 0;
    }

    pub fn hasRedundantDirectory(self: Header) bool {
        return self.flags & flag_redundant_directory != 0;
    }
};

pub fn parseHeader(input: []const u8) Error!Header {
    if (input.len < header_size) return error.TruncatedFrame;
    if (readU32Le(input, 0) != magic) return error.InvalidMagic;
    const version = readU32Le(input, 4);
    if (version == 0 or version > 3) return error.UnsupportedVersion;
    const flags = readU32Le(input, 8);
    if (flags & 0xffff_0000 & ~known_incompatible_flags != 0)
        return error.UnsupportedVmdkFeature;
    const compressed = flags & flag_compressed != 0;
    const embedded_lba = flags & flag_embedded_lba != 0;
    if (embedded_lba and !compressed) return error.InvalidVmdk;
    const compression_algorithm = readU16Le(input, 77);
    if (compressed) {
        if (!embedded_lba) return error.InvalidVmdk;
        if (compression_algorithm != compression_deflate)
            return error.UnsupportedVmdkCompression;
    } else if (compression_algorithm != compression_none) {
        return error.InvalidVmdk;
    }
    if (flags & flag_newline_detect != 0 and
        !std.mem.eql(u8, input[73..77], "\n \r\n"))
        return error.InvalidVmdk;

    const capacity_sectors = readU64Le(input, 12);
    const virtual_size = std.math.mul(
        u64,
        capacity_sectors,
        sector_size,
    ) catch return error.IntegerOverflow;
    const grain_sectors = readU64Le(input, 20);
    if (!isPowerOfTwo(grain_sectors) or grain_sectors < 8)
        return error.InvalidVmdk;
    const grain_size_u64 = std.math.mul(
        u64,
        grain_sectors,
        sector_size,
    ) catch return error.IntegerOverflow;
    const grain_size = std.math.cast(usize, grain_size_u64) orelse
        return error.IntegerOverflow;
    const num_gtes_per_gt: usize = readU32Le(input, 44);
    if (!isPowerOfTwo(num_gtes_per_gt) or
        num_gtes_per_gt < sector_size / 4 or
        num_gtes_per_gt > sector_size)
        return error.InvalidVmdk;

    const descriptor_offset = readU64Le(input, 28);
    const descriptor_sectors = readU64Le(input, 36);
    if ((descriptor_offset == 0) != (descriptor_sectors == 0))
        return error.InvalidVmdk;
    return .{
        .version = version,
        .flags = flags,
        .capacity_sectors = capacity_sectors,
        .virtual_size = virtual_size,
        .grain_sectors = grain_sectors,
        .grain_size = grain_size,
        .descriptor_offset = descriptor_offset,
        .descriptor_sectors = descriptor_sectors,
        .num_gtes_per_gt = num_gtes_per_gt,
        .redundant_gd_offset = readU64Le(input, 48),
        .gd_offset = readU64Le(input, 56),
        .overhead_sectors = readU64Le(input, 64),
        .unclean_shutdown = input[72] != 0,
        .compression_algorithm = compression_algorithm,
    };
}

pub fn parseFooter(input: []const u8, initial: Header) Error!Header {
    if (input.len < 3 * sector_size or input.len % sector_size != 0)
        return error.TruncatedFrame;
    const marker_offset = input.len - 3 * sector_size;
    const footer_offset = input.len - 2 * sector_size;
    const eos_offset = input.len - sector_size;
    const footer_marker = try parseMarker(input, marker_offset);
    if (footer_marker.kind != .footer or
        footer_marker.sectors != 1 or footer_marker.size != 0)
        return error.InvalidVmdk;
    const eos = try parseMarker(input, eos_offset);
    if (eos.kind != .end_of_stream or eos.sectors != 0 or eos.size != 0)
        return error.InvalidVmdk;
    var footer = try parseHeader(input[footer_offset..]);
    if (footer.version != initial.version or
        footer.flags != initial.flags or
        footer.capacity_sectors != initial.capacity_sectors or
        footer.grain_sectors != initial.grain_sectors or
        footer.num_gtes_per_gt != initial.num_gtes_per_gt or
        footer.compression_algorithm != initial.compression_algorithm or
        footer.gd_offset == gd_at_end)
        return error.InvalidVmdk;
    footer.from_footer = true;
    return footer;
}

pub fn parseMarker(input: []const u8, offset: usize) Error!Marker {
    const end = std.math.add(usize, offset, 16) catch
        return error.IntegerOverflow;
    if (end > input.len) return error.TruncatedFrame;
    return .{
        .sectors = readU64Le(input, offset),
        .size = readU32Le(input, offset + 8),
        .kind = std.enums.fromInt(MarkerType, readU32Le(input, offset + 12)) orelse
            return error.InvalidVmdk,
    };
}

pub fn parseDescriptor(bytes: []const u8) Error!Descriptor {
    var descriptor = Descriptor{ .bytes = bytes };
    var position: usize = 0;
    while (position < bytes.len and bytes[position] != 0) {
        const line_end = std.mem.indexOfScalarPos(u8, bytes, position, '\n') orelse
            bytes.len;
        const line = std.mem.trim(u8, bytes[position..line_end], " \t\r");
        if (std.mem.startsWith(u8, line, "CID=")) {
            descriptor.cid = std.fmt.parseInt(u32, line[4..], 16) catch
                return error.InvalidVmdk;
        } else if (std.mem.startsWith(u8, line, "parentCID=")) {
            descriptor.parent_cid = std.fmt.parseInt(u32, line[10..], 16) catch
                return error.InvalidVmdk;
        } else if (std.mem.startsWith(u8, line, "createType=")) {
            descriptor.create_type = try quotedValue(line[11..]);
        } else if (std.mem.startsWith(u8, line, "parentFileNameHint=")) {
            descriptor.parent_file_name_hint = try quotedValue(line[19..]);
        }
        if (line_end == bytes.len) break;
        position = line_end + 1;
    }
    return descriptor;
}

fn quotedValue(text: []const u8) Error![]const u8 {
    const trimmed = std.mem.trim(u8, text, " \t");
    if (trimmed.len < 2 or trimmed[0] != '"' or trimmed[trimmed.len - 1] != '"')
        return error.InvalidVmdk;
    return trimmed[1 .. trimmed.len - 1];
}

fn isPowerOfTwo(value: anytype) bool {
    return value != 0 and value & (value - 1) == 0;
}

pub fn readU16Le(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

pub fn readU32Le(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

pub fn readU64Le(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}

pub fn writeU16Le(bytes: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, bytes[offset..][0..2], value, .little);
}

pub fn writeU32Le(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .little);
}

pub fn writeU64Le(bytes: []u8, offset: usize, value: u64) void {
    std.mem.writeInt(u64, bytes[offset..][0..8], value, .little);
}
