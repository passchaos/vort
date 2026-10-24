const std = @import("std");
const checksum = @import("../checksum.zig");
const rar15 = @import("rar15.zig");
const rar20 = @import("rar20.zig");
const rar29 = @import("rar29.zig");
const rar4_encryption = @import("rar4_encryption.zig");

pub const Error = rar15.Error || rar20.Error || rar29.Error || rar4_encryption.Error ||
    std.mem.Allocator.Error || error{
    InvalidRarArchive,
    UnsupportedRarCompression,
    RarPasswordRequired,
    SizeMismatch,
    ChecksumMismatch,
    OutputLimitExceeded,
};

pub const Method = enum {
    stored,
    rar15,
    rar20,
    rar29,
    unsupported,
};

pub const Metadata = struct {
    method: Method,
    crc32: u32,
    packed_size: usize,
    unpacked_size: usize,
    encryption: ?rar4_encryption.Metadata,
    unicode: bool,
};

pub const DecodeOptions = struct {
    password: ?[]const u8 = null,
    max_output_len: usize,
    max_ppmd_memory: usize = rar29.default_max_ppmd_memory,
    max_vm_instructions: usize = rar29.default_max_vm_instructions,
};

pub const EncodedText = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    owned: ?[]u8,
    unicode: bool,

    pub fn deinit(self: *EncodedText) void {
        if (self.owned) |bytes| self.allocator.free(bytes);
        self.* = undefined;
    }
};

pub fn encodeTextAlloc(
    allocator: std.mem.Allocator,
    utf8: []const u8,
) (std.mem.Allocator.Error || error{InvalidUtf8})!EncodedText {
    const unicode = for (utf8) |byte| {
        if (byte >= 0x80) break true;
    } else false;
    if (!unicode) return .{
        .allocator = allocator,
        .bytes = utf8,
        .owned = null,
        .unicode = false,
    };
    const utf16 = try std.unicode.utf8ToUtf16LeAlloc(allocator, utf8);
    defer allocator.free(utf16);
    const bytes = try allocator.dupe(u8, std.mem.sliceAsBytes(utf16));
    return .{
        .allocator = allocator,
        .bytes = bytes,
        .owned = bytes,
        .unicode = true,
    };
}

pub fn storedBorrowed(
    wire_data: []const u8,
    metadata: Metadata,
) Error![]const u8 {
    if (metadata.encryption != null or metadata.unicode or
        metadata.method != .stored or
        metadata.packed_size != metadata.unpacked_size or
        wire_data.len != metadata.packed_size)
    {
        return error.InvalidRarArchive;
    }
    if (checksum.crc32(wire_data) != metadata.crc32) return error.ChecksumMismatch;
    return trimText(wire_data, false);
}

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    wire_data: []const u8,
    metadata: Metadata,
    options: DecodeOptions,
) Error![]u8 {
    if (metadata.unpacked_size > options.max_output_len)
        return error.OutputLimitExceeded;
    if (wire_data.len != metadata.packed_size) return error.InvalidRarArchive;
    var decrypted: ?rar4_encryption.Decrypted = if (metadata.encryption) |encryption| blk: {
        const password = options.password orelse return error.RarPasswordRequired;
        break :blk try rar4_encryption.decryptAlloc(
            allocator,
            wire_data,
            password,
            encryption,
        );
    } else null;
    defer if (decrypted) |*value| value.deinit();
    const data = if (decrypted) |*value| value.bytes else wire_data;
    var output = try allocator.alloc(u8, metadata.unpacked_size);
    errdefer allocator.free(output);
    switch (metadata.method) {
        .stored => {
            if (data.len < output.len or data.len - output.len >= rar4_encryption.block_len)
                return error.SizeMismatch;
            @memcpy(output, data[0..output.len]);
        },
        .rar15 => try rar15.decodeInto(data, output),
        .rar20 => try rar20.decodeInto(data, output),
        .rar29 => try rar29.decodeIntoWithOptions(allocator, data, output, .{
            .max_output_len = metadata.unpacked_size,
            .max_ppmd_memory = options.max_ppmd_memory,
            .max_vm_instructions = options.max_vm_instructions,
        }),
        .unsupported => return error.UnsupportedRarCompression,
    }
    if (checksum.crc32(output) != metadata.crc32) return error.ChecksumMismatch;
    if (metadata.unicode) {
        if (output.len % 2 != 0) return error.InvalidRarArchive;
        const utf16_len = try terminatedUtf16Len(output, metadata.encryption != null);
        const utf16 = try allocator.alloc(u16, utf16_len);
        defer allocator.free(utf16);
        @memcpy(std.mem.sliceAsBytes(utf16), output[0 .. utf16_len * 2]);
        const utf8 = std.unicode.utf16LeToUtf8Alloc(allocator, utf16) catch |err| switch (err) {
            error.OutOfMemory => return error.OutOfMemory,
            else => return error.InvalidRarArchive,
        };
        allocator.free(output);
        output = utf8;
        if (output.len > options.max_output_len) return error.OutputLimitExceeded;
    } else {
        const text = try trimText(output, metadata.encryption != null);
        if (text.len != output.len) output = try allocator.realloc(output, text.len);
    }
    return output;
}

fn terminatedUtf16Len(bytes: []const u8, allow_padding: bool) Error!usize {
    const total = bytes.len / 2;
    for (0..total) |index| {
        if (std.mem.readInt(u16, bytes[index * 2 ..][0..2], .little) != 0) continue;
        if (!allow_padding)
            for (bytes[index * 2 ..]) |byte|
                if (byte != 0) return error.InvalidRarArchive;
        return index;
    }
    return total;
}

fn trimText(bytes: []const u8, allow_padding: bool) Error![]const u8 {
    const text_end = std.mem.indexOfScalar(u8, bytes, 0) orelse return bytes;
    if (!allow_padding)
        for (bytes[text_end..]) |byte|
            if (byte != 0) return error.InvalidRarArchive;
    return bytes[0..text_end];
}

test "RAR4 comment text encoding keeps ASCII borrowed and writes Unicode LE" {
    const allocator = std.testing.allocator;
    var ascii = try encodeTextAlloc(allocator, "comment");
    defer ascii.deinit();
    try std.testing.expect(!ascii.unicode);
    try std.testing.expect(ascii.owned == null);
    try std.testing.expectEqualSlices(u8, "comment", ascii.bytes);

    var unicode = try encodeTextAlloc(allocator, "世界");
    defer unicode.deinit();
    try std.testing.expect(unicode.unicode);
    try std.testing.expectEqualSlices(u8, &.{ 0x16, 0x4e, 0x4c, 0x75 }, unicode.bytes);
}
