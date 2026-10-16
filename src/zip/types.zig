const winzip_aes = @import("vail_archive_crypto").winzip_aes;
const pkware_strong = @import("vail_archive_crypto").pkware_strong;

pub const WinZipAesStrength = winzip_aes.Strength;

pub const WinZipAesVendorVersion = enum(u16) {
    ae1 = 1,
    ae2 = 2,
};

pub const WinZipAesInfo = struct {
    version: WinZipAesVendorVersion,
    strength: WinZipAesStrength,
};

pub const PkwareStrongEncryptionStrength = pkware_strong.Strength;

pub const PkwareStrongEncryptionInfo = struct {
    strength: PkwareStrongEncryptionStrength,
};

pub const TimestampError = error{InvalidZipTimestamp};

/// ZIP "version made by" host-system identifiers from APPNOTE.
pub const CreatorSystem = enum(u8) {
    fat = 0,
    amiga = 1,
    openvms = 2,
    unix = 3,
    vm_cms = 4,
    atari_st = 5,
    hpfs = 6,
    macintosh = 7,
    z_system = 8,
    cp_m = 9,
    ntfs = 10,
    mvs = 11,
    vse = 12,
    acorn_risc = 13,
    vfat = 14,
    alternate_mvs = 15,
    beos = 16,
    tandem = 17,
    os_400 = 18,
    os_x = 19,
    _,
};

/// Raw MS-DOS timestamp carried by ZIP local and central headers.
/// `fromComponents` rounds an odd second down to ZIP's two-second precision.
pub const DosTimestamp = struct {
    time: u16 = 0,
    date: u16 = 0x0021,

    pub const deterministic: DosTimestamp = .{};

    pub const Components = struct {
        year: u16,
        month: u8,
        day: u8,
        hour: u8,
        minute: u8,
        second: u8,
    };

    pub fn fromComponents(components_value: Components) TimestampError!DosTimestamp {
        const year = components_value.year;
        const month = components_value.month;
        const day = components_value.day;
        const hour = components_value.hour;
        const minute = components_value.minute;
        const second = components_value.second;
        if (year < 1980 or year > 2107 or month < 1 or month > 12 or
            day < 1 or day > daysInMonth(year, month) or hour > 23 or
            minute > 59 or second > 59)
        {
            return error.InvalidZipTimestamp;
        }
        return .{
            .time = (@as(u16, hour) << 11) |
                (@as(u16, minute) << 5) |
                @as(u16, second / 2),
            .date = ((year - 1980) << 9) |
                (@as(u16, month) << 5) |
                @as(u16, day),
        };
    }

    pub fn components(self: DosTimestamp) TimestampError!Components {
        const value: Components = .{
            .year = 1980 + (self.date >> 9),
            .month = @truncate((self.date >> 5) & 0x0f),
            .day = @truncate(self.date & 0x1f),
            .hour = @truncate((self.time >> 11) & 0x1f),
            .minute = @truncate((self.time >> 5) & 0x3f),
            .second = @as(u8, @truncate(self.time & 0x1f)) * 2,
        };
        _ = try fromComponents(value);
        return value;
    }

    pub fn isValid(self: DosTimestamp) bool {
        _ = self.components() catch return false;
        return true;
    }
};

fn daysInMonth(year: u16, month: u8) u8 {
    return switch (month) {
        1, 3, 5, 7, 8, 10, 12 => 31,
        4, 6, 9, 11 => 30,
        2 => if (year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)) 29 else 28,
        else => 0,
    };
}

/// Encodes the conventional Unix mode in the upper half of ZIP external
/// attributes and mirrors the DOS directory bit for directory modes.
pub fn unixExternalAttributes(mode: u16) u32 {
    const dos_directory: u32 = if (mode & 0o170000 == 0o040000) 0x10 else 0;
    return (@as(u32, mode) << 16) | dos_directory;
}

pub const CompressionMethod = enum(u16) {
    stored = 0,
    shrink = 1,
    reduce_1 = 2,
    reduce_2 = 3,
    reduce_3 = 4,
    reduce_4 = 5,
    implode = 6,
    deflate = 8,
    deflate64 = 9,
    dcl_implode = 10,
    bzip2 = 12,
    lzma = 14,
    /// Deprecated PKWARE assignment retained for archives created before
    /// APPNOTE 6.3.8 reassigned Zstandard from method 20 to method 93.
    zstandard_legacy = 20,
    zstandard = 93,
    xz = 95,
    ppmd = 98,
    aes = 99,
    _,
};

/// Canonical central-directory metadata for one ZIP member.
///
/// `name` and `comment` borrow the parsed archive bytes. The remaining fields
/// are copied values and can configure an incremental entry decoder or restore
/// filesystem metadata according to caller policy.
pub const Entry = struct {
    name: []const u8,
    comment: []const u8 = "",
    method: CompressionMethod,
    flags: u16,
    crc32: u32,
    compressed_size: usize,
    uncompressed_size: usize,
    local_header_offset: usize,
    central_header_offset: usize,
    zip64: bool,
    modified: DosTimestamp = .deterministic,
    version_made_by: u16 = 0,
    internal_attributes: u16 = 0,
    external_attributes: u32 = 0,
    winzip_aes: ?WinZipAesInfo = null,
    pkware_strong_encryption: ?PkwareStrongEncryptionInfo = null,

    pub fn isDirectory(self: Entry) bool {
        if (self.name.len != 0 and self.name[self.name.len - 1] == '/') return true;
        return if (self.unixMode()) |mode| mode & 0o170000 == 0o040000 else false;
    }

    pub fn creatorSystem(self: Entry) CreatorSystem {
        return @enumFromInt(@as(u8, @truncate(self.version_made_by >> 8)));
    }

    pub fn unixMode(self: Entry) ?u16 {
        if (self.creatorSystem() != .unix) return null;
        return @truncate(self.external_attributes >> 16);
    }

    pub fn isSymbolicLink(self: Entry) bool {
        return if (self.unixMode()) |mode| mode & 0o170000 == 0o120000 else false;
    }

    pub fn isEncrypted(self: Entry) bool {
        return self.flags & 1 != 0;
    }

    pub fn isWinZipAes(self: Entry) bool {
        return self.winzip_aes != null;
    }

    pub fn isPkwareStrongEncrypted(self: Entry) bool {
        return self.pkware_strong_encryption != null;
    }
};
