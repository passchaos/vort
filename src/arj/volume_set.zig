const std = @import("std");
const archive_mod = @import("archive.zig");

pub const Error = archive_mod.Error || std.mem.Allocator.Error || error{
    InvalidArjVolumeSet,
    ArjVolumeEntryNotFound,
};

const Fragment = struct {
    archive_index: usize,
    entry: archive_mod.Entry,
};

pub const Entry = struct {
    name: archive_mod.Name,
    method: archive_mod.Method,
    method_id: u8,
    file_type: u8,
    encryption: ?archive_mod.Encryption,
    compressed_size: usize,
    uncompressed_size: usize,
    fragment_index: usize,
    fragment_count: usize,

    pub fn isDirectory(self: Entry) bool {
        return self.file_type == 3;
    }

    pub fn isEncrypted(self: Entry) bool {
        return self.encryption != null;
    }
};

pub const VolumeSet = struct {
    allocator: std.mem.Allocator,
    archives: []archive_mod.Archive,
    entries: []Entry,
    fragments: []Fragment,

    pub fn parseAlloc(
        allocator: std.mem.Allocator,
        volume_bytes: []const []const u8,
    ) Error!VolumeSet {
        if (volume_bytes.len == 0) return error.InvalidArjVolumeSet;
        const archives = try allocator.alloc(archive_mod.Archive, volume_bytes.len);
        errdefer allocator.free(archives);
        for (volume_bytes, archives) |bytes, *parsed|
            parsed.* = try archive_mod.parse(bytes);

        const encryption_version = archives[0].encryption_version;
        var fragments: std.ArrayList(Fragment) = .empty;
        defer fragments.deinit(allocator);
        var entries: std.ArrayList(Entry) = .empty;
        defer entries.deinit(allocator);
        var pending_start: ?usize = null;
        var pending_compressed: usize = 0;
        var pending_uncompressed: usize = 0;
        var expected_total: ?usize = null;

        for (archives, 0..) |arj_archive, archive_index| {
            const has_next_volume = arj_archive.flags & 0x04 != 0;
            if (has_next_volume != (archive_index + 1 < archives.len) or
                arj_archive.encryption_version != encryption_version)
            {
                return error.InvalidArjVolumeSet;
            }
            var entry_iterator = arj_archive.iterator();
            while (try entry_iterator.next()) |fragment| {
                if (fragment.splitBefore()) {
                    const start = pending_start orelse
                        return error.InvalidArjVolumeSet;
                    const previous_archive = fragments.items[fragments.items.len - 1].archive_index;
                    if (previous_archive + 1 != archive_index)
                        return error.InvalidArjVolumeSet;
                    const first = fragments.items[start].entry;
                    if (!compatibleFragments(first, fragment) or
                        fragment.extended_file_position != pending_uncompressed)
                    {
                        return error.InvalidArjVolumeSet;
                    }
                } else {
                    if (pending_start != null or fragment.extended_file_position != 0)
                        return error.InvalidArjVolumeSet;
                    pending_start = fragments.items.len;
                    pending_compressed = 0;
                    pending_uncompressed = 0;
                    expected_total = null;
                }
                if (fragment.total_uncompressed_size) |total| {
                    if (expected_total) |expected| {
                        if (total != expected) return error.InvalidArjVolumeSet;
                    } else {
                        expected_total = total;
                    }
                }
                pending_compressed = std.math.add(
                    usize,
                    pending_compressed,
                    fragment.compressed_size,
                ) catch return error.IntegerOverflow;
                pending_uncompressed = std.math.add(
                    usize,
                    pending_uncompressed,
                    fragment.uncompressed_size,
                ) catch return error.IntegerOverflow;
                try fragments.append(allocator, .{
                    .archive_index = archive_index,
                    .entry = fragment,
                });

                if (!fragment.splitAfter()) {
                    const start = pending_start orelse
                        return error.InvalidArjVolumeSet;
                    if (expected_total) |total|
                        if (total != pending_uncompressed)
                            return error.InvalidArjVolumeSet;
                    const first = fragments.items[start].entry;
                    try entries.append(allocator, .{
                        .name = first.name,
                        .method = first.method,
                        .method_id = first.method_id,
                        .file_type = first.file_type,
                        .encryption = first.encryption,
                        .compressed_size = pending_compressed,
                        .uncompressed_size = pending_uncompressed,
                        .fragment_index = start,
                        .fragment_count = fragments.items.len - start,
                    });
                    pending_start = null;
                }
            }
            if (pending_start != null and !has_next_volume)
                return error.InvalidArjVolumeSet;
        }
        if (pending_start != null) return error.InvalidArjVolumeSet;

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

    pub fn extractAllocWithOptions(
        self: *const VolumeSet,
        allocator: std.mem.Allocator,
        entry: Entry,
        options: archive_mod.DecodeOptions,
    ) Error![]u8 {
        const canonical = self.canonicalEntry(entry) orelse
            return error.InvalidArjVolumeSet;
        if (canonical.uncompressed_size > options.max_output_len)
            return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, canonical.uncompressed_size);
        errdefer allocator.free(output);
        var written: usize = 0;
        const fragment_end = std.math.add(
            usize,
            canonical.fragment_index,
            canonical.fragment_count,
        ) catch return error.IntegerOverflow;
        if (fragment_end > self.fragments.len) return error.InvalidArjVolumeSet;
        for (self.fragments[canonical.fragment_index..fragment_end]) |fragment| {
            const end = std.math.add(
                usize,
                written,
                fragment.entry.uncompressed_size,
            ) catch return error.IntegerOverflow;
            if (end > output.len) return error.InvalidArjVolumeSet;
            const count = try self.archives[fragment.archive_index].extractFragmentIntoWithOptions(
                allocator,
                fragment.entry,
                output[written..end],
                options,
            );
            if (count != end - written) return error.SizeMismatch;
            written = end;
        }
        if (written != output.len) return error.SizeMismatch;
        return output;
    }

    fn canonicalEntry(self: *const VolumeSet, entry: Entry) ?Entry {
        for (self.entries) |candidate|
            if (sameEntry(candidate, entry)) return candidate;
        return null;
    }

    pub fn extractAllocLimited(
        self: *const VolumeSet,
        allocator: std.mem.Allocator,
        entry: Entry,
        max_output_len: usize,
    ) Error![]u8 {
        return self.extractAllocWithOptions(
            allocator,
            entry,
            .{ .max_output_len = max_output_len },
        );
    }

    pub fn extractByNameAllocWithOptions(
        self: *const VolumeSet,
        allocator: std.mem.Allocator,
        name: []const u8,
        options: archive_mod.DecodeOptions,
    ) Error![]u8 {
        const entry = self.find(name) orelse return error.ArjVolumeEntryNotFound;
        return self.extractAllocWithOptions(allocator, entry, options);
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

fn compatibleFragments(first: archive_mod.Entry, next: archive_mod.Entry) bool {
    return eqlNormalized(first.name.bytes, next.name.bytes) and
        first.method == next.method and first.method_id == next.method_id and
        first.file_type == next.file_type and first.encryption == next.encryption;
}

fn sameEntry(a: Entry, b: Entry) bool {
    return eqlNormalized(a.name.bytes, b.name.bytes) and
        a.method == b.method and a.method_id == b.method_id and
        a.file_type == b.file_type and a.encryption == b.encryption and
        a.compressed_size == b.compressed_size and
        a.uncompressed_size == b.uncompressed_size and
        a.fragment_index == b.fragment_index and
        a.fragment_count == b.fragment_count;
}

fn eqlNormalized(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |left, right|
        if ((if (left == '\\') '/' else left) !=
            (if (right == '\\') '/' else right)) return false;
    return true;
}
