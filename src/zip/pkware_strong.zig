//! ZIP wire composition for password-based PKWARE Strong Encryption.
//!
//! Cryptographic key derivation, AES-CBC, padding, and password validation are
//! provided by Vail. This module owns only APPNOTE decryption-header layout,
//! synthesized-IV policy, size accounting, and strict password-only AES
//! profile validation.

const std = @import("std");
const crypto = @import("vail_archive_crypto").pkware_strong;

pub const Strength = crypto.Strength;
pub const block_len = crypto.block_len;

pub const format: u16 = 3;
pub const password_flag: u16 = 0x0001;
pub const explicit_iv_len: usize = block_len;
pub const synthesized_iv_material_len: usize = @sizeOf(u32) + @sizeOf(u64);
pub const fixed_remaining_len: usize = 16;
pub const explicit_prefix_len: usize = @sizeOf(u16) + explicit_iv_len + @sizeOf(u32);
pub const max_remaining_len: usize = 1 << 18;

pub const Error = crypto.Error || error{
    InvalidStrongEncryptionHeader,
    UnsupportedStrongEncryptionFeature,
};

pub const Options = struct {
    password: []const u8,
    strength: Strength = .aes256,
    iv: [block_len]u8,
    random_data: []const u8,
    validation_data: []const u8,
};

pub fn algorithmId(strength: Strength) u16 {
    return switch (strength) {
        .aes128 => 0x660e,
        .aes192 => 0x660f,
        .aes256 => 0x6610,
    };
}

pub fn bitLength(strength: Strength) u16 {
    return @intCast(strength.keyLen() * 8);
}

pub fn strengthFromAlgorithm(algorithm_id: u16, bit_length: u16) Error!Strength {
    const strength: Strength = switch (algorithm_id) {
        0x660e => .aes128,
        0x660f => .aes192,
        0x6610 => .aes256,
        else => return error.UnsupportedStrongEncryptionFeature,
    };
    if (bit_length != bitLength(strength)) return error.InvalidStrongEncryptionHeader;
    return strength;
}

pub fn validateOptions(options: Options) Error!void {
    const encrypted_random_size = std.math.add(usize, options.random_data.len, block_len) catch
        return error.IntegerOverflow;
    if (options.random_data.len == 0 or options.random_data.len % block_len != 0 or
        encrypted_random_size > std.math.maxInt(u16))
        return error.InvalidRandomDataLength;
    const validation_size = std.math.add(usize, options.validation_data.len, @sizeOf(u32)) catch
        return error.IntegerOverflow;
    if (options.validation_data.len == 0 or validation_size % block_len != 0 or
        validation_size > std.math.maxInt(u16))
        return error.InvalidValidationDataLength;
}

/// Returns the complete decryption-header plus encrypted compressed payload.
pub fn encryptAlloc(
    allocator: std.mem.Allocator,
    compressed: []const u8,
    options: Options,
) Error![]u8 {
    try validateOptions(options);
    var encrypted = try crypto.encryptAlloc(allocator, compressed, .{
        .password = options.password,
        .strength = options.strength,
        .cbc_iv = options.iv,
        .iv_material = &options.iv,
        .random_data = options.random_data,
        .validation_data = options.validation_data,
    });
    defer encrypted.deinit(allocator);

    const remaining_len = try checkedAdd(
        fixed_remaining_len,
        try checkedAdd(encrypted.encrypted_random_data.len, encrypted.validation_size),
    );
    if (remaining_len > max_remaining_len or remaining_len > std.math.maxInt(u32))
        return error.InvalidStrongEncryptionHeader;
    const file_ciphertext_len = encrypted.encrypted_payload.len - encrypted.validation_size;
    const total_len = try checkedAdd(
        explicit_prefix_len,
        try checkedAdd(remaining_len, file_ciphertext_len),
    );
    const output = try allocator.alloc(u8, total_len);
    errdefer {
        std.crypto.secureZero(u8, output);
        allocator.free(output);
    }

    var cursor: usize = 0;
    writeU16(output, &cursor, @intCast(explicit_iv_len));
    writeBytes(output, &cursor, &options.iv);
    writeU32(output, &cursor, @intCast(remaining_len));
    writeU16(output, &cursor, format);
    writeU16(output, &cursor, algorithmId(options.strength));
    writeU16(output, &cursor, bitLength(options.strength));
    writeU16(output, &cursor, password_flag);
    writeU16(output, &cursor, @intCast(encrypted.encrypted_random_data.len));
    writeBytes(output, &cursor, encrypted.encrypted_random_data);
    writeU32(output, &cursor, 0);
    writeU16(output, &cursor, @intCast(encrypted.validation_size));
    writeBytes(output, &cursor, encrypted.encrypted_payload[0..encrypted.validation_size]);
    std.debug.assert(cursor == explicit_prefix_len + remaining_len);
    writeBytes(output, &cursor, encrypted.encrypted_payload[encrypted.validation_size..]);
    std.debug.assert(cursor == output.len);
    return output;
}

pub fn decryptAlloc(
    allocator: std.mem.Allocator,
    encrypted: []const u8,
    password: []const u8,
    expected_strength: Strength,
    crc32: u32,
    uncompressed_size: u64,
) Error![]u8 {
    var cursor: usize = 0;
    const iv_size = try readU16(encrypted, &cursor);
    var cbc_iv: [block_len]u8 = @splat(0);
    const iv_material: []const u8 = switch (iv_size) {
        0 => synthesized: {
            std.mem.writeInt(u32, cbc_iv[0..4], crc32, .little);
            std.mem.writeInt(u64, cbc_iv[4..12], uncompressed_size, .little);
            break :synthesized cbc_iv[0..synthesized_iv_material_len];
        },
        explicit_iv_len => explicit: {
            const bytes = try readBytes(encrypted, &cursor, explicit_iv_len);
            cbc_iv = bytes[0..block_len].*;
            break :explicit &cbc_iv;
        },
        else => return error.UnsupportedStrongEncryptionFeature,
    };
    const remaining_len: usize = try readU32(encrypted, &cursor);
    if (remaining_len < fixed_remaining_len or remaining_len > max_remaining_len)
        return error.InvalidStrongEncryptionHeader;
    const remaining_start = cursor;
    const remaining_end = try checkedEnd(remaining_start, remaining_len, encrypted.len);
    if (try readU16(encrypted[0..remaining_end], &cursor) != format)
        return error.InvalidStrongEncryptionHeader;
    const algorithm_id = try readU16(encrypted[0..remaining_end], &cursor);
    const bit_length = try readU16(encrypted[0..remaining_end], &cursor);
    const actual_strength = try strengthFromAlgorithm(algorithm_id, bit_length);
    if (actual_strength != expected_strength) return error.InvalidStrongEncryptionHeader;
    const flags = try readU16(encrypted[0..remaining_end], &cursor);
    if (flags != password_flag) return error.UnsupportedStrongEncryptionFeature;
    const random_size: usize = try readU16(encrypted[0..remaining_end], &cursor);
    if (random_size < block_len or random_size % block_len != 0)
        return error.InvalidStrongEncryptionHeader;
    const encrypted_random_data = try readBytes(encrypted[0..remaining_end], &cursor, random_size);
    if (try readU32(encrypted[0..remaining_end], &cursor) != 0)
        return error.UnsupportedStrongEncryptionFeature;
    const validation_size: usize = try readU16(encrypted[0..remaining_end], &cursor);
    if (validation_size <= @sizeOf(u32) or validation_size % block_len != 0)
        return error.InvalidStrongEncryptionHeader;
    const validation_start = cursor;
    _ = try readBytes(encrypted[0..remaining_end], &cursor, validation_size);
    if (cursor != remaining_end) return error.InvalidStrongEncryptionHeader;

    return crypto.decryptAlloc(
        allocator,
        encrypted_random_data,
        encrypted[validation_start..],
        .{
            .password = password,
            .strength = actual_strength,
            .cbc_iv = cbc_iv,
            .iv_material = iv_material,
            .validation_size = validation_size,
        },
    );
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = try checkedAdd(start, len);
    if (end > limit) return error.InvalidStrongEncryptionHeader;
    return end;
}

fn readBytes(bytes: []const u8, cursor: *usize, len: usize) Error![]const u8 {
    const end = try checkedEnd(cursor.*, len, bytes.len);
    defer cursor.* = end;
    return bytes[cursor.*..end];
}

fn readU16(bytes: []const u8, cursor: *usize) Error!u16 {
    return std.mem.readInt(u16, (try readBytes(bytes, cursor, 2))[0..2], .little);
}

fn readU32(bytes: []const u8, cursor: *usize) Error!u32 {
    return std.mem.readInt(u32, (try readBytes(bytes, cursor, 4))[0..4], .little);
}

fn writeBytes(output: []u8, cursor: *usize, bytes: []const u8) void {
    @memcpy(output[cursor.*..][0..bytes.len], bytes);
    cursor.* += bytes.len;
}

fn writeU16(output: []u8, cursor: *usize, value: u16) void {
    std.mem.writeInt(u16, output[cursor.*..][0..2], value, .little);
    cursor.* += 2;
}

fn writeU32(output: []u8, cursor: *usize, value: u32) void {
    std.mem.writeInt(u32, output[cursor.*..][0..4], value, .little);
    cursor.* += 4;
}
