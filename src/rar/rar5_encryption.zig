//! RAR5 file-data encryption composition.
//!
//! Vail owns PBKDF2-HMAC-SHA256, AES-256-CBC, password checks, and keyed
//! checksum transforms. This module adds RAR policy: explicit caller-supplied
//! salt/IV, zero padding to an AES block, KDF limits, and wire metadata.

const std = @import("std");
const crypto = @import("vail_archive_crypto").rar5;

pub const password_check_flag: u64 = 0x0001;
pub const tweaked_checksums_flag: u64 = 0x0002;
pub const known_flags: u64 = password_check_flag | tweaked_checksums_flag;
pub const salt_len: usize = crypto.salt_len;
pub const iv_len: usize = crypto.block_len;
pub const password_check_record_len: usize = crypto.password_check_record_len;
pub const hard_max_kdf_count: u8 = crypto.hard_max_kdf_count;

pub const Error = std.mem.Allocator.Error || error{
    CorruptRar5PasswordCheck,
    InvalidRar5Ciphertext,
    InvalidRar5Encryption,
    InvalidRarPassword,
    InvalidRarPasswordEncoding,
    IntegerOverflow,
    Rar5KdfLimitExceeded,
};

pub const Metadata = struct {
    version: u64 = 0,
    flags: u64,
    kdf_count: u8,
    salt: [salt_len]u8,
    iv: [iv_len]u8,
    password_check: ?[password_check_record_len]u8,

    pub fn usesTweakedChecksums(self: Metadata) bool {
        return self.flags & tweaked_checksums_flag != 0;
    }
};

/// Per-entry encryption inputs. Salt and IV generation remain explicit so the
/// archive layer never hides global randomness and deterministic fixtures are
/// possible. Applications must use unique unpredictable values per entry.
pub const Options = struct {
    password: []const u8,
    salt: [salt_len]u8,
    iv: [iv_len]u8,
    kdf_count: u8 = 15,
    include_password_check: bool = true,
    use_tweaked_checksums: bool = true,
};

pub const Encrypted = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    metadata: Metadata,
    wire_crc32: u32,

    pub fn deinit(self: *Encrypted) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const Decrypted = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    keys: crypto.Keys,
    tweaked_checksums: bool,

    pub fn crcMatches(self: *const Decrypted, actual: u32, expected: u32) bool {
        return if (self.tweaked_checksums)
            self.keys.tweakCrc32(actual) == expected
        else
            actual == expected;
    }

    pub fn deinit(self: *Decrypted) void {
        self.keys.deinit();
        std.crypto.secureZero(u8, self.bytes);
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub fn validateMetadata(metadata: Metadata, max_kdf_count: u8) Error!void {
    try validateMetadataStructure(metadata);
    if (metadata.kdf_count > max_kdf_count or metadata.kdf_count > hard_max_kdf_count)
        return error.Rar5KdfLimitExceeded;
}

pub fn validateMetadataStructure(metadata: Metadata) Error!void {
    if (metadata.version != 0 or metadata.flags & ~known_flags != 0)
        return error.InvalidRar5Encryption;
    if ((metadata.flags & password_check_flag != 0) != (metadata.password_check != null))
        return error.InvalidRar5Encryption;
    if (metadata.password_check) |record|
        if (!crypto.passwordCheckRecordValid(record))
            return error.CorruptRar5PasswordCheck;
}

pub fn validateOptions(options: Options) Error!void {
    if (!std.unicode.utf8ValidateSlice(options.password))
        return error.InvalidRarPasswordEncoding;
    if (options.kdf_count > hard_max_kdf_count)
        return error.Rar5KdfLimitExceeded;
}

pub fn encryptAlloc(
    allocator: std.mem.Allocator,
    payload: []const u8,
    crc32: u32,
    options: Options,
) Error!Encrypted {
    try validateOptions(options);
    var keys = derive(options.password, options.salt, options.kdf_count, options.kdf_count) catch |err|
        return err;
    defer keys.deinit();
    const padding = (crypto.block_len - payload.len % crypto.block_len) % crypto.block_len;
    const padded_len = std.math.add(usize, payload.len, padding) catch
        return error.IntegerOverflow;
    const encrypted = try allocator.alloc(u8, padded_len);
    errdefer {
        std.crypto.secureZero(u8, encrypted);
        allocator.free(encrypted);
    }
    @memcpy(encrypted[0..payload.len], payload);
    @memset(encrypted[payload.len..], 0);
    var encryptor = crypto.Encryptor.init(keys.encryption, options.iv);
    defer encryptor.deinit();
    encryptor.encryptBlocks(encrypted, encrypted) catch
        return error.InvalidRar5Ciphertext;
    const flags = @as(u64, @intFromBool(options.include_password_check)) * password_check_flag |
        @as(u64, @intFromBool(options.use_tweaked_checksums)) * tweaked_checksums_flag;
    return .{
        .allocator = allocator,
        .bytes = encrypted,
        .metadata = .{
            .flags = flags,
            .kdf_count = options.kdf_count,
            .salt = options.salt,
            .iv = options.iv,
            .password_check = if (options.include_password_check)
                keys.passwordCheckRecord()
            else
                null,
        },
        .wire_crc32 = if (options.use_tweaked_checksums)
            keys.tweakCrc32(crc32)
        else
            crc32,
    };
}

pub fn decryptAlloc(
    allocator: std.mem.Allocator,
    ciphertext: []const u8,
    password: []const u8,
    metadata: Metadata,
    max_kdf_count: u8,
) Error!Decrypted {
    try validateMetadata(metadata, max_kdf_count);
    if (!std.unicode.utf8ValidateSlice(password))
        return error.InvalidRarPasswordEncoding;
    if (ciphertext.len % crypto.block_len != 0)
        return error.InvalidRar5Ciphertext;
    var keys = try derive(password, metadata.salt, metadata.kdf_count, max_kdf_count);
    errdefer keys.deinit();
    if (metadata.password_check) |record|
        if (!keys.verifyPasswordCheck(record[0..crypto.password_check_len].*))
            return error.InvalidRarPassword;
    const plaintext = try allocator.alloc(u8, ciphertext.len);
    errdefer {
        std.crypto.secureZero(u8, plaintext);
        allocator.free(plaintext);
    }
    var decryptor = crypto.Decryptor.init(keys.encryption, metadata.iv);
    defer decryptor.deinit();
    decryptor.decryptBlocks(ciphertext, plaintext) catch
        return error.InvalidRar5Ciphertext;
    return .{
        .allocator = allocator,
        .bytes = plaintext,
        .keys = keys,
        .tweaked_checksums = metadata.usesTweakedChecksums(),
    };
}

fn derive(
    password: []const u8,
    salt: [salt_len]u8,
    kdf_count: u8,
    max_kdf_count: u8,
) Error!crypto.Keys {
    return crypto.deriveKeys(password, salt, kdf_count, .{
        .max_kdf_count = max_kdf_count,
    }) catch |err| switch (err) {
        error.InvalidKdfCount => error.Rar5KdfLimitExceeded,
        error.InvalidBlockLength => unreachable,
    };
}

test "RAR5 encryption composition pads, decrypts, and checks keyed CRC" {
    const allocator = std.testing.allocator;
    const options = Options{
        .password = "RAR5 test 密码",
        .salt = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
        .iv = .{ 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 },
        .kdf_count = 3,
    };
    const payload = "RAR5 encrypted compressed payload";
    const crc32: u32 = 0x1234_5678;
    var encrypted = try encryptAlloc(allocator, payload, crc32, options);
    defer encrypted.deinit();
    try std.testing.expectEqual(@as(usize, 0), encrypted.bytes.len % crypto.block_len);
    try std.testing.expect(encrypted.wire_crc32 != crc32);
    var decrypted = try decryptAlloc(
        allocator,
        encrypted.bytes,
        options.password,
        encrypted.metadata,
        3,
    );
    defer decrypted.deinit();
    try std.testing.expectEqualSlices(u8, payload, decrypted.bytes[0..payload.len]);
    try std.testing.expect(decrypted.crcMatches(crc32, encrypted.wire_crc32));
    try std.testing.expectError(
        error.InvalidRarPassword,
        decryptAlloc(allocator, encrypted.bytes, "wrong", encrypted.metadata, 3),
    );
}

test "RAR5 encryption validates password-check integrity and KDF limits" {
    const allocator = std.testing.allocator;
    const options = Options{
        .password = "password",
        .salt = [_]u8{0x11} ** crypto.salt_len,
        .iv = [_]u8{0x22} ** crypto.block_len,
        .kdf_count = 2,
    };
    var encrypted = try encryptAlloc(allocator, "payload", 0, options);
    defer encrypted.deinit();
    var corrupt = encrypted.metadata;
    corrupt.password_check.?[11] ^= 1;
    try std.testing.expectError(
        error.CorruptRar5PasswordCheck,
        decryptAlloc(allocator, encrypted.bytes, options.password, corrupt, 2),
    );
    try std.testing.expectError(
        error.Rar5KdfLimitExceeded,
        decryptAlloc(allocator, encrypted.bytes, options.password, encrypted.metadata, 1),
    );
}
