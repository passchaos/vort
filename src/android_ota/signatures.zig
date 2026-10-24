//! Android update-engine Signatures protobuf parsing and key selection.

const std = @import("std");
const format = @import("format.zig");
const protobuf = @import("protobuf.zig");
const crypto = @import("vail_archive_crypto").android_ota;

pub const Error = format.Error || protobuf.Error || crypto.Error;
pub const PublicKey = crypto.PublicKey;

pub const Limits = struct {
    max_blob_size: usize = 16 * 1024 * 1024,
    max_signatures: usize = 128,
    max_signature_size: usize = 16 * 1024,
    max_keys: usize = 128,
};

pub const Signature = struct {
    version: ?u32,
    data: []const u8,
    unpadded_size: usize,
};

pub const Set = struct {
    bytes: []const u8,
    count: usize,
    limits: Limits,

    pub fn iterator(self: Set) Iterator {
        return .{ .reader = protobuf.Reader.init(self.bytes), .limits = self.limits };
    }
};

pub const Match = struct {
    signature_index: usize,
    key_index: usize,
};

pub const Iterator = struct {
    reader: protobuf.Reader,
    limits: Limits,

    pub fn next(self: *Iterator) Error!?Signature {
        while (try self.reader.next()) |field| {
            if (field.number != 1) continue;
            return @as(
                ?Signature,
                try parseSignature(try protobuf.expectBytes(field), self.limits),
            );
        }
        return null;
    }
};

pub fn parse(bytes: []const u8, limits: Limits) Error!Set {
    if (bytes.len == 0) return error.AndroidOtaSignatureMissing;
    if (bytes.len > limits.max_blob_size) return error.OutputLimitExceeded;
    var count: usize = 0;
    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| {
        if (field.number != 1) continue;
        if (count >= limits.max_signatures) return error.OutputLimitExceeded;
        _ = try parseSignature(try protobuf.expectBytes(field), limits);
        count += 1;
    }
    if (count == 0) return error.AndroidOtaSignatureMissing;
    return .{ .bytes = bytes, .count = count, .limits = limits };
}

pub fn verifyAny(
    set: Set,
    keys: []const PublicKey,
    digest: *const [32]u8,
) Error!Match {
    if (keys.len == 0) return error.AndroidOtaSignatureMissing;
    if (keys.len > set.limits.max_keys) return error.OutputLimitExceeded;
    var iterator = set.iterator();
    var signature_index: usize = 0;
    while (try iterator.next()) |signature| : (signature_index += 1) {
        const encoded = signature.data[0..signature.unpadded_size];
        for (keys, 0..) |key, key_index| {
            key.verifySha256(digest, encoded) catch |err| switch (err) {
                error.InvalidSignature, error.SignatureMismatch => continue,
                else => return err,
            };
            return .{
                .signature_index = signature_index,
                .key_index = key_index,
            };
        }
    }
    return error.AndroidOtaSignatureMismatch;
}

fn parseSignature(bytes: []const u8, limits: Limits) Error!Signature {
    var version: ?u32 = null;
    var data: ?[]const u8 = null;
    var unpadded: ?u32 = null;
    var reader = protobuf.Reader.init(bytes);
    while (try reader.next()) |field| switch (field.number) {
        1 => {
            if (version != null) return error.InvalidAndroidOtaSignature;
            const raw = try protobuf.expectVarint(field);
            version = std.math.cast(u32, raw) orelse
                return error.InvalidAndroidOtaSignature;
        },
        2 => {
            if (data != null) return error.InvalidAndroidOtaSignature;
            const value = try protobuf.expectBytes(field);
            if (value.len == 0 or value.len > limits.max_signature_size)
                return error.InvalidAndroidOtaSignature;
            data = value;
        },
        3 => {
            if (unpadded != null or field.wire_type != .fixed32)
                return error.InvalidAndroidOtaSignature;
            unpadded = field.value.fixed32;
        },
        else => {},
    };
    const signature = data orelse return error.InvalidAndroidOtaSignature;
    const actual_size: usize = unpadded orelse @intCast(signature.len);
    if (actual_size == 0 or actual_size > signature.len)
        return error.InvalidAndroidOtaSignature;
    return .{
        .version = version,
        .data = signature,
        .unpadded_size = actual_size,
    };
}

test "Android OTA Signatures parses fixed32 padding and enforces limits" {
    const allocator = std.testing.allocator;
    var inner: std.ArrayList(u8) = .empty;
    defer inner.deinit(allocator);
    try protobuf.appendBytesField(allocator, &inner, 2, "signature-padding");
    try inner.append(allocator, 0x1d);
    var size: [4]u8 = undefined;
    std.mem.writeInt(u32, &size, 9, .little);
    try inner.appendSlice(allocator, &size);
    var outer: std.ArrayList(u8) = .empty;
    defer outer.deinit(allocator);
    try protobuf.appendMessageField(allocator, &outer, 1, inner.items);
    try protobuf.appendMessageField(allocator, &outer, 1, inner.items);
    const set = try parse(outer.items, .{});
    try std.testing.expectEqual(@as(usize, 2), set.count);
    var iterator = set.iterator();
    const signature = (try iterator.next()).?;
    try std.testing.expectEqual(@as(usize, 9), signature.unpadded_size);
    try std.testing.expect((try iterator.next()) != null);
    try std.testing.expect((try iterator.next()) == null);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parse(outer.items, .{ .max_signatures = 1 }),
    );
    inner.items[inner.items.len - 1] = 0xff;
    var invalid: std.ArrayList(u8) = .empty;
    defer invalid.deinit(allocator);
    try protobuf.appendMessageField(allocator, &invalid, 1, inner.items);
    try std.testing.expectError(error.InvalidAndroidOtaSignature, parse(invalid.items, .{}));
}
