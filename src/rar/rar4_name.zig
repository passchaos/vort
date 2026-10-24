//! RAR4 custom Unicode file-name codec.

const std = @import("std");

pub const Error = std.mem.Allocator.Error || error{
    InvalidRar4UnicodeName,
};

pub const Encoded = struct {
    allocator: std.mem.Allocator,
    field: []u8,

    pub fn deinit(self: *Encoded) void {
        self.allocator.free(self.field);
        self.* = undefined;
    }
};

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    fallback: []const u8,
    encoded: []const u8,
) Error![]u8 {
    if (encoded.len == 0) return error.InvalidRar4UnicodeName;
    const high_byte: u16 = @as(u16, encoded[0]) << 8;
    var position: usize = 1;
    var flags: u8 = 0;
    var flag_bits: u8 = 0;
    var decoded_position: usize = 0;
    var units: std.ArrayList(u16) = .empty;
    defer units.deinit(allocator);
    while (position < encoded.len) {
        if (flag_bits == 0) {
            flags = encoded[position];
            position += 1;
            flag_bits = 8;
        }
        const kind = flags >> 6;
        flags <<= 2;
        flag_bits -= 2;
        switch (kind) {
            0 => {
                if (position >= encoded.len) return error.InvalidRar4UnicodeName;
                try units.append(allocator, encoded[position]);
                position += 1;
                decoded_position += 1;
            },
            1 => {
                if (position >= encoded.len) return error.InvalidRar4UnicodeName;
                try units.append(allocator, high_byte | encoded[position]);
                position += 1;
                decoded_position += 1;
            },
            2 => {
                if (encoded.len - position < 2) return error.InvalidRar4UnicodeName;
                try units.append(
                    allocator,
                    std.mem.readInt(u16, encoded[position..][0..2], .little),
                );
                position += 2;
                decoded_position += 1;
            },
            3 => {
                if (position >= encoded.len) return error.InvalidRar4UnicodeName;
                const length_byte = encoded[position];
                position += 1;
                const corrected = length_byte & 0x80 != 0;
                const count: usize = @as(usize, length_byte & 0x7f) + 2;
                const correction: u8 = if (corrected) blk: {
                    if (position >= encoded.len) return error.InvalidRar4UnicodeName;
                    defer position += 1;
                    break :blk encoded[position];
                } else 0;
                if (count > fallback.len -| decoded_position)
                    return error.InvalidRar4UnicodeName;
                for (fallback[decoded_position..][0..count]) |byte| {
                    try units.append(
                        allocator,
                        if (corrected) high_byte | (byte +% correction) else byte,
                    );
                }
                decoded_position += count;
            },
            else => unreachable,
        }
    }
    if (units.items.len == 0) return error.InvalidRar4UnicodeName;
    return std.unicode.utf16LeToUtf8Alloc(allocator, units.items) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.DanglingSurrogateHalf,
        error.ExpectedSecondSurrogateHalf,
        error.UnexpectedSecondSurrogateHalf,
        => error.InvalidRar4UnicodeName,
    };
}

pub fn encodeAlloc(allocator: std.mem.Allocator, name: []const u8) Error!Encoded {
    if (!std.unicode.utf8ValidateSlice(name)) return error.InvalidRar4UnicodeName;
    const normalized = try allocator.dupe(u8, name);
    defer allocator.free(normalized);
    for (normalized) |*byte| {
        if (byte.* == '/') byte.* = '\\';
    }
    const utf16 = std.unicode.utf8ToUtf16LeAlloc(allocator, normalized) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidUtf8 => return error.InvalidRar4UnicodeName,
    };
    defer allocator.free(utf16);

    var fallback: std.ArrayList(u8) = .empty;
    defer fallback.deinit(allocator);
    var view = std.unicode.Utf8View.initUnchecked(normalized);
    var iterator = view.iterator();
    while (iterator.nextCodepoint()) |codepoint|
        try fallback.append(
            allocator,
            if (codepoint <= 0x7f) @intCast(codepoint) else '_',
        );
    if (fallback.items.len == 0 or std.mem.indexOfScalar(u8, fallback.items, 0) != null)
        return error.InvalidRar4UnicodeName;

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encoded.append(allocator, 0); // High byte is unused by code-2 units.
    var offset: usize = 0;
    while (offset < utf16.len) {
        const count = @min(@as(usize, 4), utf16.len - offset);
        var flags: u8 = 0;
        for (0..count) |index| flags |= @as(u8, 2) << @intCast(6 - index * 2);
        try encoded.append(allocator, flags);
        for (utf16[offset..][0..count]) |unit| {
            var bytes: [2]u8 = undefined;
            std.mem.writeInt(u16, &bytes, unit, .little);
            try encoded.appendSlice(allocator, &bytes);
        }
        offset += count;
    }
    const field_len = std.math.add(usize, fallback.items.len + 1, encoded.items.len) catch
        return error.InvalidRar4UnicodeName;
    const field = try allocator.alloc(u8, field_len);
    @memcpy(field[0..fallback.items.len], fallback.items);
    field[fallback.items.len] = 0;
    @memcpy(field[fallback.items.len + 1 ..], encoded.items);
    return .{ .allocator = allocator, .field = field };
}

test "RAR4 Unicode names round trip code-2 UTF-16 units" {
    const allocator = std.testing.allocator;
    const name = "目录/данные/😀.txt";
    var encoded = try encodeAlloc(allocator, name);
    defer encoded.deinit();
    const separator = std.mem.indexOfScalar(u8, encoded.field, 0).?;
    const decoded = try decodeAlloc(
        allocator,
        encoded.field[0..separator],
        encoded.field[separator + 1 ..],
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("目录\\данные\\😀.txt", decoded);
}

test "RAR4 Unicode decoder covers literal high-byte and correction runs" {
    const allocator = std.testing.allocator;
    const fallback = "abcd";
    // high=0x04; kinds 0,1,3-copy, then one unused; values 'A', 0x38,
    // and a two-byte fallback copy.
    const decoded = try decodeAlloc(
        allocator,
        fallback,
        &.{ 0x04, 0x1c, 'A', 0x38, 0x00 },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Aиcd", decoded);
    try std.testing.expectError(
        error.InvalidRar4UnicodeName,
        decodeAlloc(allocator, fallback, &.{ 0, 0x80 }),
    );
}
