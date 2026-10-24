const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{InvalidWimEntry};

pub const NamedStream = struct {
    name: []const u8,
    data: []const u8 = &.{},
};

/// Reparse stream bytes exclude the common 8-byte REPARSE_DATA_BUFFER header.
/// The tag and reserved value are stored in the WIM dentry instead.
pub const ReparseData = struct {
    tag: u32,
    data: []const u8,
    reserved: u16 = 0,
    flags: u16 = 0,
};

pub const Stream = struct {
    name: ?[]const u8,
    data: []const u8,
};

pub const Set = struct {
    directory: bool,
    default_data: []const u8,
    named: []const NamedStream,
    reparse: ?ReparseData,
    encrypted_raw: ?[]const u8,

    pub fn validate(self: Set) Error!void {
        if (self.directory and self.default_data.len != 0)
            return error.InvalidWimEntry;
        if (self.encrypted_raw) |raw| {
            if (raw.len == 0 or self.default_data.len != 0 or
                self.named.len != 0 or self.reparse != null)
                return error.InvalidWimEntry;
            return;
        }
        if (self.reparse) |reparse| {
            if (reparse.tag == 0 or reparse.data.len == 0)
                return error.InvalidWimEntry;
        }
        for (self.named, 0..) |stream, index| {
            if (!validStreamName(stream.name)) return error.InvalidWimEntry;
            if (try utf16ByteLength(stream.name) > std.math.maxInt(u16))
                return error.InvalidWimEntry;
            for (self.named[0..index]) |prior|
                if (std.ascii.eqlIgnoreCase(prior.name, stream.name))
                    return error.InvalidWimEntry;
        }
        if (self.extraCount() > std.math.maxInt(u16))
            return error.InvalidWimEntry;
    }

    pub fn mainData(self: Set) ?[]const u8 {
        if (self.encrypted_raw) |raw| return raw;
        if (self.extraCount() != 0) return null;
        if (self.reparse) |reparse| return reparse.data;
        if (!self.directory) return self.default_data;
        return null;
    }

    pub fn extraCount(self: Set) usize {
        if (self.encrypted_raw != null) return 0;
        const unnamed_count = @as(usize, @intFromBool(self.reparse != null)) +
            @intFromBool(!self.directory);
        if (unnamed_count <= 1 and self.named.len == 0) return 0;
        return unnamed_count + self.named.len;
    }

    pub fn extraStreams(self: Set) ExtraIterator {
        return .{ .set = self };
    }

    pub fn totalBytes(self: Set) Error!u64 {
        if (self.encrypted_raw) |raw| return raw.len;
        var total: u64 = 0;
        if (self.reparse) |reparse|
            total = try checkedAdd(total, reparse.data.len);
        if (!self.directory)
            total = try checkedAdd(total, self.default_data.len);
        for (self.named) |stream|
            total = try checkedAdd(total, stream.data.len);
        return total;
    }
};

pub const ExtraIterator = struct {
    set: Set,
    phase: enum { reparse, default, named, done } = .reparse,
    named_index: usize = 0,

    pub fn next(self: *ExtraIterator) ?Stream {
        if (self.set.extraCount() == 0) return null;
        while (true) switch (self.phase) {
            .reparse => {
                self.phase = .default;
                if (self.set.reparse) |reparse|
                    return .{ .name = null, .data = reparse.data };
            },
            .default => {
                self.phase = .named;
                if (!self.set.directory)
                    return .{ .name = null, .data = self.set.default_data };
            },
            .named => {
                if (self.named_index == self.set.named.len) {
                    self.phase = .done;
                    continue;
                }
                const stream = self.set.named[self.named_index];
                self.named_index += 1;
                return .{ .name = stream.name, .data = stream.data };
            },
            .done => return null,
        };
    }
};

pub fn hash(data: []const u8) [std.crypto.hash.Sha1.digest_length]u8 {
    var digest: [std.crypto.hash.Sha1.digest_length]u8 = @splat(0);
    if (data.len != 0) std.crypto.hash.Sha1.hash(data, &digest, .{});
    return digest;
}

pub fn utf16ByteLength(text: []const u8) Error!usize {
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidWimEntry;
    var units: usize = 0;
    var view = std.unicode.Utf8View.initUnchecked(text);
    var iterator = view.iterator();
    while (iterator.nextCodepoint()) |codepoint| {
        units = std.math.add(
            usize,
            units,
            if (codepoint < 0x10000) 1 else 2,
        ) catch return error.IntegerOverflow;
    }
    return std.math.mul(usize, units, 2) catch error.IntegerOverflow;
}

pub fn writeUtf16Le(output: []u8, offset: usize, text: []const u8) Error!usize {
    const bytes = try utf16ByteLength(text);
    const end = std.math.add(usize, offset, bytes) catch
        return error.IntegerOverflow;
    if (end > output.len) return error.OutputTooSmall;
    var cursor = offset;
    var view = std.unicode.Utf8View.initUnchecked(text);
    var iterator = view.iterator();
    while (iterator.nextCodepoint()) |codepoint| {
        if (codepoint < 0x10000) {
            writeU16(output, cursor, @intCast(codepoint));
            cursor += 2;
        } else {
            const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xd800;
            const low = @as(u16, @intCast(codepoint & 0x3ff)) + 0xdc00;
            writeU16(output, cursor, high);
            writeU16(output, cursor + 2, low);
            cursor += 4;
        }
    }
    return cursor;
}

fn validStreamName(name: []const u8) bool {
    return name.len != 0 and std.unicode.utf8ValidateSlice(name) and
        std.mem.indexOfAny(u8, name, "/\\\x00") == null;
}

fn checkedAdd(left: u64, right: usize) Error!u64 {
    return std.math.add(u64, left, right) catch error.IntegerOverflow;
}

fn writeU16(output: []u8, offset: usize, value: u16) void {
    std.mem.writeInt(u16, output[offset..][0..2], value, .little);
}

test "WIM writer stream rules match DISM extra-stream ordering" {
    const named = [_]NamedStream{
        .{ .name = "Zone.Identifier", .data = "zone" },
        .{ .name = "空", .data = "" },
    };
    const set = Set{
        .directory = false,
        .default_data = "data",
        .named = &named,
        .reparse = .{ .tag = 1, .data = "reparse" },
        .encrypted_raw = null,
    };
    try set.validate();
    try std.testing.expectEqual(@as(usize, 4), set.extraCount());
    try std.testing.expect(set.mainData() == null);
    var iterator = set.extraStreams();
    try std.testing.expectEqualStrings("reparse", iterator.next().?.data);
    try std.testing.expectEqualStrings("data", iterator.next().?.data);
    try std.testing.expectEqualStrings("Zone.Identifier", iterator.next().?.name.?);
    try std.testing.expectEqualStrings("空", iterator.next().?.name.?);
    try std.testing.expect(iterator.next() == null);
}
