//! RAR 3.x/4.x AES file/header encryption composition.
//!
//! Vail owns the historical SHA-1 KDF and AES-128-CBC. This module owns RAR
//! policy: optional 8-byte salts, zero padding, UTF-8 password input, and
//! allocator-backed sensitive buffers.

const std = @import("std");
const crypto = @import("vail_archive_crypto").rar4;

pub const salt_len: usize = crypto.salt_len;
pub const block_len: usize = crypto.block_len;

pub const Error = crypto.Error || error{
    InvalidRar4Ciphertext,
};

pub const Metadata = struct {
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
        .metadata = .{ .salt = options.salt },
    };
}

pub fn decryptAlloc(
    allocator: std.mem.Allocator,
    ciphertext: []const u8,
    password: []const u8,
    metadata: Metadata,
) Error!Decrypted {
    var cipher = try Cipher.init(allocator, password, metadata);
    defer cipher.deinit();
    return .{
        .allocator = allocator,
        .bytes = try cipher.decryptAlloc(allocator, ciphertext),
    };
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
