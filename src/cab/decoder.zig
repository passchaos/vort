const std = @import("std");
const archive_format = @import("archive.zig");
const deflate = @import("../deflate.zig");
const types = @import("types.zig");

pub const Error = archive_format.Error || deflate.Error;
pub const Archive = archive_format.Archive;
pub const Entry = types.Entry;

pub const ExtractOptions = struct {
    max_file_size: usize = std.math.maxInt(usize),
    max_folder_size: usize = std.math.maxInt(usize),
};

pub fn decodeFolderAllocLimited(
    allocator: std.mem.Allocator,
    archive: Archive,
    folder_index: usize,
    max_output_len: usize,
) ![]u8 {
    const folder = try archive.folderAt(folder_index);
    if (folder.decoded_size > max_output_len) return error.OutputLimitExceeded;
    switch (folder.compression) {
        .none, .mszip => {},
        else => return error.UnsupportedCabinetCompression,
    }
    if ((folder.compression == .none or folder.compression == .mszip) and folder.type_compress & 0xfff0 != 0)
        return error.UnsupportedCabinetFeature;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.ensureTotalCapacity(allocator, folder.decoded_size);
    var blocks = archive.dataBlockIterator(folder);
    while (try blocks.next()) |block| switch (folder.compression) {
        .none => output.appendSliceAssumeCapacity(block.compressed),
        .mszip => {
            if (block.compressed.len < 2 or !std.mem.eql(u8, block.compressed[0..2], "CK"))
                return error.InvalidCabinet;
            const history_start = output.items.len -| (32 * 1024);
            const decoded = try deflate.decodeRawAutoAllocWithDictionaryExactSize(
                allocator,
                block.compressed[2..],
                output.items[history_start..],
                block.uncompressed_size,
            );
            defer allocator.free(decoded);
            output.appendSliceAssumeCapacity(decoded);
        },
        else => unreachable,
    };
    if (output.items.len != folder.decoded_size) return error.SizeMismatch;
    return output.toOwnedSlice(allocator);
}

pub fn extractAllocWithOptions(
    allocator: std.mem.Allocator,
    archive: Archive,
    supplied_entry: Entry,
    options: ExtractOptions,
) ![]u8 {
    const entry = try archive.canonicalEntry(supplied_entry);
    if (entry.size > options.max_file_size) return error.OutputLimitExceeded;
    const folder = try decodeFolderAllocLimited(
        allocator,
        archive,
        entry.folder_index,
        options.max_folder_size,
    );
    defer allocator.free(folder);
    const end = std.math.add(usize, entry.folder_offset, entry.size) catch return error.IntegerOverflow;
    if (end > folder.len) return error.InvalidCabinet;
    return allocator.dupe(u8, folder[entry.folder_offset..end]);
}

pub fn extractAllocLimited(
    allocator: std.mem.Allocator,
    archive: Archive,
    entry: Entry,
    max_output_len: usize,
) ![]u8 {
    return extractAllocWithOptions(allocator, archive, entry, .{
        .max_file_size = max_output_len,
        .max_folder_size = max_output_len,
    });
}

pub fn extractAlloc(allocator: std.mem.Allocator, archive: Archive, entry: Entry) ![]u8 {
    return extractAllocWithOptions(allocator, archive, entry, .{});
}

pub fn extractInto(
    allocator: std.mem.Allocator,
    archive: Archive,
    entry: Entry,
    output: []u8,
    max_folder_size: usize,
) !usize {
    const canonical = try archive.canonicalEntry(entry);
    if (output.len < canonical.size) return error.OutputTooSmall;
    const decoded = try extractAllocWithOptions(allocator, archive, canonical, .{
        .max_file_size = output.len,
        .max_folder_size = max_folder_size,
    });
    defer allocator.free(decoded);
    @memcpy(output[0..decoded.len], decoded);
    return decoded.len;
}

pub fn extractByNameAllocLimited(
    allocator: std.mem.Allocator,
    archive: Archive,
    name: []const u8,
    max_output_len: usize,
) ![]u8 {
    const entry = (try archive.find(name)) orelse return error.CabinetEntryNotFound;
    return extractAllocLimited(allocator, archive, entry, max_output_len);
}

pub fn extractByNameAlloc(
    allocator: std.mem.Allocator,
    archive: Archive,
    name: []const u8,
) ![]u8 {
    const entry = (try archive.find(name)) orelse return error.CabinetEntryNotFound;
    return extractAlloc(allocator, archive, entry);
}
