//! RAR 1.5 through 4.x file/header encryption composition.
//!
//! Vail owns the RAR15 byte cipher, RAR20/26 block cipher, and the RAR3/4
//! SHA-1 KDF with AES-128-CBC. This module owns archive policy: version
//! selection, optional RAR3/4 salts, AES zero padding, and allocator-backed
//! sensitive buffers.

const std = @import("std");
const crypto = @import("vail_archive_crypto").rar4;
const legacy = @import("vail_archive_crypto").rar_legacy;

pub const salt_len: usize = crypto.salt_len;
pub const block_len: usize = crypto.block_len;

pub const Error = crypto.Error || legacy.Error || error{
    InvalidRar4Ciphertext,
    InvalidRar4EncryptionMetadata,
};

pub const Method = enum {
    rar15,
    rar20,
    rar30,
};

pub const Metadata = struct {
    method: Method = .rar30,
    salt: ?[salt_len]u8,
};

pub const Options = struct {
    password: []const u8,
    salt: ?[salt_len]u8,
};

pub const Cipher = struct {
    keys: crypto.Keys,

    pub fn init(
        allocator: std.mem.Allocator,
        password: []const u8,
        metadata: Metadata,
    ) Error!Cipher {
        if (metadata.method != .rar30) return error.InvalidRar4EncryptionMetadata;
        return .{ .keys = try crypto.deriveKeys(allocator, password, metadata.salt) };
    }

    pub fn encryptAlloc(
        self: *const Cipher,
        allocator: std.mem.Allocator,
        plaintext: []const u8,
    ) Error![]u8 {
        const padding = (block_len - plaintext.len % block_len) % block_len;
        const padded_len = std.math.add(usize, plaintext.len, padding) catch
            return error.IntegerOverflow;
        const encrypted = try allocator.alloc(u8, padded_len);
        errdefer {
            std.crypto.secureZero(u8, encrypted);
            allocator.free(encrypted);
        }
        @memcpy(encrypted[0..plaintext.len], plaintext);
        @memset(encrypted[plaintext.len..], 0);
        var encryptor = crypto.Encryptor.init(self.keys.encryption, self.keys.iv);
        defer encryptor.deinit();
        encryptor.encryptBlocks(encrypted, encrypted) catch
            return error.InvalidRar4Ciphertext;
        return encrypted;
    }

    pub fn decryptAlloc(
        self: *const Cipher,
        allocator: std.mem.Allocator,
        ciphertext: []const u8,
    ) Error![]u8 {
        if (ciphertext.len == 0 or ciphertext.len % block_len != 0)
            return error.InvalidRar4Ciphertext;
        const plaintext = try allocator.alloc(u8, ciphertext.len);
        errdefer {
            std.crypto.secureZero(u8, plaintext);
            allocator.free(plaintext);
        }
        var decryptor = crypto.Decryptor.init(self.keys.encryption, self.keys.iv);
        defer decryptor.deinit();
        decryptor.decryptBlocks(ciphertext, plaintext) catch
            return error.InvalidRar4Ciphertext;
        return plaintext;
    }

    pub fn decryptBlocks(
        self: *const Cipher,
        ciphertext: []const u8,
        plaintext: []u8,
    ) Error!void {
        if (ciphertext.len == 0 or ciphertext.len != plaintext.len or
            ciphertext.len % block_len != 0)
            return error.InvalidRar4Ciphertext;
        var decryptor = crypto.Decryptor.init(self.keys.encryption, self.keys.iv);
        defer decryptor.deinit();
        decryptor.decryptBlocks(ciphertext, plaintext) catch
            return error.InvalidRar4Ciphertext;
    }

    pub fn deinit(self: *Cipher) void {
        self.keys.deinit();
        self.* = undefined;
    }
};

pub const Encrypted = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    metadata: Metadata,

    pub fn deinit(self: *Encrypted) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const Decrypted = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,

    pub fn deinit(self: *Decrypted) void {
        std.crypto.secureZero(u8, self.bytes);
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub fn encryptAlloc(
    allocator: std.mem.Allocator,
    payload: []const u8,
    options: Options,
) Error!Encrypted {
    var cipher = try Cipher.init(allocator, options.password, .{ .salt = options.salt });
    defer cipher.deinit();
    return .{
        .allocator = allocator,
        .bytes = try cipher.encryptAlloc(allocator, payload),
        .metadata = .{ .method = .rar30, .salt = options.salt },
    };
}

pub fn decryptAlloc(
    allocator: std.mem.Allocator,
    ciphertext: []const u8,
    password: []const u8,
    metadata: Metadata,
) Error!Decrypted {
    if (metadata.method != .rar30) {
        if (metadata.salt != null) return error.InvalidRar4EncryptionMetadata;
        const plaintext = try allocator.dupe(u8, ciphertext);
        errdefer {
            std.crypto.secureZero(u8, plaintext);
            allocator.free(plaintext);
        }
        switch (metadata.method) {
            .rar15 => {
                var cipher = legacy.Rar15.init(password);
                defer cipher.deinit();
                cipher.crypt(plaintext);
            },
            .rar20 => {
                var cipher = legacy.Rar20.init(password);
                defer cipher.deinit();
                cipher.decryptBlocks(plaintext) catch return error.InvalidRar4Ciphertext;
            },
            .rar30 => unreachable,
        }
        return .{ .allocator = allocator, .bytes = plaintext };
    }
    var cipher = try Cipher.init(allocator, password, metadata);
    defer cipher.deinit();
    return .{
        .allocator = allocator,
        .bytes = try cipher.decryptAlloc(allocator, ciphertext),
    };
}

test "RAR15 and RAR20 composition dispatches to Vail" {
    const allocator = std.testing.allocator;
    const rar15_bytes = [_]u8{ 0x43, 0xdd, 0x9d, 0xf3, 0x2a, 0x83, 0xdb, 0x8f };
    var rar15_plain = try decryptAlloc(
        allocator,
        &rar15_bytes,
        "password",
        .{ .method = .rar15, .salt = null },
    );
    defer rar15_plain.deinit();
    try std.testing.expectEqualSlices(u8, &.{ 0, 1, 2, 3, 4, 5, 6, 7 }, rar15_plain.bytes);
    try std.testing.expectError(
        error.InvalidRar4EncryptionMetadata,
        decryptAlloc(
            allocator,
            &rar15_bytes,
            "password",
            .{ .method = .rar15, .salt = [_]u8{0} ** salt_len },
        ),
    );

    const rar20_bytes = [_]u8{
        0x84, 0x0c, 0x88, 0x90, 0x05, 0x93, 0x3a, 0x4e,
        0x0d, 0xa7, 0xf0, 0x86, 0x87, 0x5a, 0xd8, 0x28,
    };
    var rar20_plain = try decryptAlloc(
        allocator,
        &rar20_bytes,
        "password",
        .{ .method = .rar20, .salt = null },
    );
    defer rar20_plain.deinit();
    try std.testing.expectEqualSlices(
        u8,
        &.{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
        rar20_plain.bytes,
    );

    var partial: [15]u8 = undefined;
    try std.testing.expectError(
        error.InvalidRar4Ciphertext,
        decryptAlloc(
            allocator,
            &partial,
            "password",
            .{ .method = .rar20, .salt = null },
        ),
    );
}

test "RAR4 encryption composition pads and decrypts" {
    const allocator = std.testing.allocator;
    const payload = "RAR4 encrypted payload";
    var encrypted = try encryptAlloc(allocator, payload, .{
        .password = "RAR4 password",
        .salt = [_]u8{0x42} ** salt_len,
    });
    defer encrypted.deinit();
    try std.testing.expectEqual(@as(usize, 0), encrypted.bytes.len % block_len);
    var decrypted = try decryptAlloc(
        allocator,
        encrypted.bytes,
        "RAR4 password",
        encrypted.metadata,
    );
    defer decrypted.deinit();
    try std.testing.expectEqualSlices(u8, payload, decrypted.bytes[0..payload.len]);
}
