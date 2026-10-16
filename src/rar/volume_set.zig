const std = @import("std");
const archive_mod = @import("archive.zig");
const checksum = @import("../checksum.zig");
const rar50 = @import("rar50.zig");
const rar5_encryption = @import("rar5_encryption.zig");

pub const Error = archive_mod.Error || error{
    InvalidRarVolumeSet,
    RarVolumeEntryNotFound,
    RarVolumeSessionPoisoned,
};

const Fragment = struct {
    archive_index: usize,
    entry: archive_mod.Entry,
};

pub const Entry = struct {
    name: archive_mod.Name,
    method: archive_mod.Method,
    method_id: u8,
    compression_version: u8,
    dictionary_size: ?usize,
    crc32: ?u32,
    compressed_size: usize,
    uncompressed_size: usize,
    solid: bool,
    directory: bool,
    encrypted: bool,
    encryption: ?archive_mod.Encryption,
    redirection: bool,
    unknown_size: bool,
    safe_path: bool,
    fragment_index: usize,
    fragment_count: usize,

    pub fn isDirectory(self: Entry) bool {
        return self.directory;
    }
};

pub const VolumeSet = struct {
    allocator: std.mem.Allocator,
    archives: []archive_mod.OwnedHeaderArchive,
    entries: []Entry,
    fragments: []Fragment,

    pub fn parseAlloc(
        allocator: std.mem.Allocator,
        volume_bytes: []const []const u8,
    ) Error!VolumeSet {
        return parseAllocWithOptions(allocator, volume_bytes, .{});
    }

    pub fn parseAllocWithOptions(
        allocator: std.mem.Allocator,
        volume_bytes: []const []const u8,
        options: archive_mod.ParseOptions,
    ) Error!VolumeSet {
        if (volume_bytes.len == 0) return error.InvalidRarVolumeSet;
        const archives = try allocator.alloc(archive_mod.OwnedHeaderArchive, volume_bytes.len);
        var archive_count: usize = 0;
        errdefer {
            for (archives[0..archive_count]) |*archive| archive.deinit();
            allocator.free(archives);
        }
        for (volume_bytes, archives) |bytes, *parsed| {
            parsed.* = try archive_mod.parseOwnedHeadersAllocWithOptions(
                allocator,
                bytes,
                options,
            );
            archive_count += 1;
        }
        try validateVolumes(archives);

        var fragments: std.ArrayList(Fragment) = .empty;
        defer fragments.deinit(allocator);
        var entries: std.ArrayList(Entry) = .empty;
        defer entries.deinit(allocator);
        var pending_start: ?usize = null;
        var pending_size: usize = 0;

        for (archives, 0..) |owned_archive, archive_index| {
            const rar_archive = owned_archive.archive;
            var volume_iterator = rar_archive.iterator();
            while (try volume_iterator.next()) |fragment_entry| {
                if (fragment_entry.split_before) {
                    const start = pending_start orelse return error.InvalidRarVolumeSet;
                    const first = fragments.items[start].entry;
                    if (!compatibleFragments(first, fragment_entry))
                        return error.InvalidRarVolumeSet;
                } else {
                    if (pending_start != null) return error.InvalidRarVolumeSet;
                    if (fragment_entry.directory and fragment_entry.split_after)
                        return error.InvalidRarVolumeSet;
                    pending_start = fragments.items.len;
                    pending_size = 0;
                }

                pending_size = std.math.add(
                    usize,
                    pending_size,
                    fragment_entry.compressed_size,
                ) catch return error.IntegerOverflow;
                try fragments.append(allocator, .{
                    .archive_index = archive_index,
                    .entry = fragment_entry,
                });

                if (!fragment_entry.split_after) {
                    const start = pending_start orelse return error.InvalidRarVolumeSet;
                    const first = fragments.items[start].entry;
                    const count = fragments.items.len - start;
                    try entries.append(allocator, .{
                        .name = first.name,
                        .method = first.method,
                        .method_id = first.method_id,
                        .compression_version = first.compression_version,
                        .dictionary_size = first.dictionary_size,
                        .crc32 = fragment_entry.crc32,
                        .compressed_size = pending_size,
                        .uncompressed_size = fragment_entry.uncompressed_size,
                        .solid = first.solid,
                        .directory = first.directory,
                        .encrypted = first.encrypted,
                        .encryption = first.encryption,
                        .redirection = first.redirection,
                        .unknown_size = first.unknown_size,
                        .safe_path = first.safe_path,
                        .fragment_index = start,
                        .fragment_count = count,
                    });
                    pending_start = null;
                    pending_size = 0;
                }
            }
        }
        if (pending_start != null) return error.InvalidRarVolumeSet;

        const owned_fragments = try fragments.toOwnedSlice(allocator);
        errdefer allocator.free(owned_fragments);
        const owned_entries = try entries.toOwnedSlice(allocator);
        return .{
            .allocator = allocator,
            .archives = archives,
            .entries = owned_entries,
            .fragments = owned_fragments,
        };
    }

    pub fn deinit(self: *VolumeSet) void {
        for (self.archives) |*archive| archive.deinit();
        self.allocator.free(self.fragments);
        self.allocator.free(self.entries);
        self.allocator.free(self.archives);
        self.* = undefined;
    }

    pub fn iterator(self: *const VolumeSet) Iterator {
        return .{ .set = self };
    }

    pub fn find(self: *const VolumeSet, name: []const u8) ?Entry {
        for (self.entries) |entry|
            if (entry.name.eql(name)) return entry;
        return null;
    }

    pub fn extractSession(
        self: *const VolumeSet,
        allocator: std.mem.Allocator,
        options: archive_mod.DecodeOptions,
    ) ExtractSession {
        return ExtractSession.init(allocator, self, options);
    }

    pub fn extractByNameAllocWithOptions(
        self: *const VolumeSet,
        allocator: std.mem.Allocator,
        name: []const u8,
        options: archive_mod.DecodeOptions,
    ) Error![]u8 {
        const wanted = self.find(name) orelse return error.RarVolumeEntryNotFound;
        var session = self.extractSession(allocator, options);
        defer session.deinit();
        while (try session.nextAlloc()) |decoded| {
            if (sameEntry(decoded.entry, wanted)) return decoded.data;
            allocator.free(decoded.data);
        }
        return error.InvalidRarVolumeSet;
    }

    pub fn extractByNameAllocLimited(
        self: *const VolumeSet,
        allocator: std.mem.Allocator,
        name: []const u8,
        max_output_len: usize,
    ) Error![]u8 {
        return self.extractByNameAllocWithOptions(
            allocator,
            name,
            .{ .max_output_len = max_output_len },
        );
    }
};

pub const Iterator = struct {
    set: *const VolumeSet,
    index: usize = 0,

    pub fn next(self: *Iterator) ?Entry {
        if (self.index == self.set.entries.len) return null;
        defer self.index += 1;
        return self.set.entries[self.index];
    }
};

pub const DecodedEntry = struct {
    entry: Entry,
    data: []u8,
};

pub const ExtractSession = struct {
    allocator: std.mem.Allocator,
    set: *const VolumeSet,
    options: archive_mod.DecodeOptions,
    index: usize = 0,
    rar50_decoder: rar50.Decoder,
    poisoned: bool = false,

    fn init(
        allocator: std.mem.Allocator,
        set: *const VolumeSet,
        options: archive_mod.DecodeOptions,
    ) ExtractSession {
        return .{
            .allocator = allocator,
            .set = set,
            .options = options,
            .rar50_decoder = rar50.Decoder.init(allocator),
        };
    }

    pub fn deinit(self: *ExtractSession) void {
        self.rar50_decoder.deinit();
        self.* = undefined;
    }

    pub fn nextAlloc(self: *ExtractSession) Error!?DecodedEntry {
        if (self.poisoned) return error.RarVolumeSessionPoisoned;
        if (self.index == self.set.entries.len) return null;
        const entry = self.set.entries[self.index];
        self.index += 1;
        if (entry.encrypted and entry.encryption == null)
            return self.fail(error.EncryptedRarEntry);
        if (entry.redirection or entry.unknown_size)
            return self.fail(error.UnsupportedRarFeature);
        if (entry.directory) {
            const data = self.allocator.alloc(u8, 0) catch |err| return self.fail(err);
            return .{ .entry = entry, .data = data };
        }
        if (entry.uncompressed_size > self.options.max_output_len)
            return self.fail(error.OutputLimitExceeded);
        if (entry.method == .rar50) {
            const dictionary_size = entry.dictionary_size orelse
                return self.fail(error.InvalidRarVolumeSet);
            if (dictionary_size > self.options.max_rar50_dictionary_size)
                return self.fail(error.Rar50DictionaryLimitExceeded);
        }

        var packed_data: std.ArrayList(u8) = .empty;
        defer packed_data.deinit(self.allocator);
        packed_data.ensureTotalCapacity(self.allocator, entry.compressed_size) catch |err|
            return self.fail(err);
        const fragment_end = entry.fragment_index + entry.fragment_count;
        for (self.set.fragments[entry.fragment_index..fragment_end]) |fragment| {
            const rar_archive = self.set.archives[fragment.archive_index].archive;
            const data_end = std.math.add(
                usize,
                fragment.entry.data_offset,
                fragment.entry.compressed_size,
            ) catch return self.fail(error.IntegerOverflow);
            if (data_end > rar_archive.bytes.len)
                return self.fail(error.TruncatedFrame);
            packed_data.appendSliceAssumeCapacity(
                rar_archive.bytes[fragment.entry.data_offset..data_end],
            );
        }
        if (packed_data.items.len != entry.compressed_size)
            return self.fail(error.InvalidRarVolumeSet);

        var decrypted: ?rar5_encryption.Decrypted = if (entry.encryption) |metadata| blk: {
            const password = self.options.password orelse
                return self.fail(error.RarPasswordRequired);
            break :blk rar5_encryption.decryptAlloc(
                self.allocator,
                packed_data.items,
                password,
                metadata,
                self.options.max_rar5_kdf_count,
            ) catch |err| return self.fail(err);
        } else null;
        defer if (decrypted) |*value| value.deinit();
        const packed_bytes = if (decrypted) |*value| value.bytes else packed_data.items;

        const output = self.allocator.alloc(u8, entry.uncompressed_size) catch |err|
            return self.fail(err);
        errdefer self.allocator.free(output);
        switch (entry.method) {
            .stored => {
                if (packed_bytes.len < output.len or packed_bytes.len - output.len >= 16)
                    return self.fail(error.SizeMismatch);
                @memcpy(output, packed_bytes[0..output.len]);
            },
            .rar50 => self.rar50_decoder.decodeMemberInto(
                packed_bytes,
                output,
                entry.compression_version,
                entry.dictionary_size orelse return self.fail(error.InvalidRarVolumeSet),
                entry.solid,
                .{ .max_dictionary_size = self.options.max_rar50_dictionary_size },
            ) catch |err| return self.fail(err),
            else => return self.fail(error.UnsupportedRarCompression),
        }
        if (entry.crc32) |expected| {
            const actual = checksum.crc32(output);
            const matches = if (decrypted) |*value|
                value.crcMatches(actual, expected)
            else
                actual == expected;
            if (!matches) return self.fail(error.ChecksumMismatch);
        }
        return .{ .entry = entry, .data = output };
    }

    fn fail(self: *ExtractSession, err: Error) Error {
        self.poisoned = true;
        return err;
    }
};

fn validateVolumes(archives: []const archive_mod.OwnedHeaderArchive) Error!void {
    const solid = archives[0].archive.solid;
    const header_encryption = archives[0].archive.header_encryption;
    for (archives, 0..) |owned_archive, index| {
        const rar_archive = owned_archive.archive;
        if (rar_archive.version != .rar5 or !rar_archive.multi_volume or
            rar_archive.solid != solid or
            !std.meta.eql(rar_archive.header_encryption, header_encryption))
            return error.InvalidRarVolumeSet;
        const expected_next = index + 1 < archives.len;
        if (rar_archive.has_next_volume != expected_next)
            return error.InvalidRarVolumeSet;
        if (rar_archive.volume_number) |number| {
            if (number != index) return error.InvalidRarVolumeSet;
        }
    }
}

fn compatibleFragments(first: archive_mod.Entry, next: archive_mod.Entry) bool {
    return std.mem.eql(u8, first.name.bytes, next.name.bytes) and
        first.method == next.method and first.method_id == next.method_id and
        first.compression_version == next.compression_version and
        first.dictionary_size == next.dictionary_size and
        first.uncompressed_size == next.uncompressed_size and
        first.solid == next.solid and first.directory == next.directory and
        first.encrypted == next.encrypted and first.redirection == next.redirection and
        std.meta.eql(first.encryption, next.encryption) and
        first.unknown_size == next.unknown_size;
}

fn sameEntry(a: Entry, b: Entry) bool {
    return a.fragment_index == b.fragment_index and a.fragment_count == b.fragment_count and
        a.compressed_size == b.compressed_size and a.uncompressed_size == b.uncompressed_size and
        a.method == b.method and std.mem.eql(u8, a.name.bytes, b.name.bytes);
}

test "RAR volume set rejects empty input" {
    try std.testing.expectError(
        error.InvalidRarVolumeSet,
        VolumeSet.parseAlloc(std.testing.allocator, &.{}),
    );
}
