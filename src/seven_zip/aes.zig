const std = @import("std");
const core = @import("../core.zig");
const crypto = @import("vail_archive_crypto").seven_zip;

pub const Error = core.Error || error{
    Invalid7zAesProperties,
    Invalid7zEncryptionOptions,
    Invalid7zPassword,
    PasswordRequired,
};

pub const max_salt_len = crypto.max_salt_len;
pub const block_len = crypto.block_len;
pub const key_len = crypto.key_len;
pub const max_cycles_power = crypto.hard_max_cycles_power;
pub const direct_key_power = crypto.direct_key_power;

pub const Properties = struct {
    num_cycles_power: u6,
    salt: [max_salt_len]u8 = @splat(0),
    salt_len: u5 = 0,
    iv: [block_len]u8 = @splat(0),
    iv_len: u5 = 0,

    pub fn saltBytes(self: *const Properties) []const u8 {
        return self.salt[0..self.salt_len];
    }

    pub fn ivBytes(self: *const Properties) []const u8 {
        return self.iv[0..self.iv_len];
    }
};

/// Encryption inputs are explicit so callers can obtain IV material from their
/// own CSPRNG. Reusing the same base IV for two archives with the same password
/// is unsafe. A per-folder stream index is added to the low 64 bits of `iv`.
pub const Options = struct {
    password: []const u8,
    iv: [block_len]u8,
    salt: [max_salt_len]u8 = @splat(0),
    salt_len: u5 = 0,
    num_cycles_power: u6 = 19,
};

pub fn parseProperties(bytes: []const u8) Error!Properties {
    if (bytes.len == 0) return .{ .num_cycles_power = 0 };
    const first = bytes[0];
    const num_cycles_power: u6 = @truncate(first);
    if (num_cycles_power > max_cycles_power and num_cycles_power != direct_key_power)
        return error.Invalid7zAesProperties;
    if (first & 0xc0 == 0) {
        if (bytes.len != 1) return error.Invalid7zAesProperties;
        return .{ .num_cycles_power = num_cycles_power };
    }
    if (bytes.len < 2) return error.Invalid7zAesProperties;
    const second = bytes[1];
    const salt_len: usize = ((first >> 7) & 1) + (second >> 4);
    const iv_len: usize = ((first >> 6) & 1) + (second & 0x0f);
    if (salt_len > max_salt_len or iv_len > block_len or
        bytes.len != 2 + salt_len + iv_len)
        return error.Invalid7zAesProperties;
    var properties = Properties{
        .num_cycles_power = num_cycles_power,
        .salt_len = @intCast(salt_len),
        .iv_len = @intCast(iv_len),
    };
    @memcpy(properties.salt[0..salt_len], bytes[2..][0..salt_len]);
    @memcpy(properties.iv[0..iv_len], bytes[2 + salt_len ..]);
    return properties;
}

pub fn propertiesForStream(options: Options, stream_index: u64) Error!Properties {
    try validateOptions(options);
    var iv = options.iv;
    var carry = stream_index;
    for (iv[0..8]) |*byte| {
        const low: u8 = @truncate(carry);
        const sum = @as(u16, byte.*) + low;
        byte.* = @truncate(sum);
        carry = (carry >> 8) + (sum >> 8);
    }
    if (carry != 0) return error.Invalid7zEncryptionOptions;
    return .{
        .num_cycles_power = options.num_cycles_power,
        .salt = options.salt,
        .salt_len = options.salt_len,
        .iv = iv,
        .iv_len = block_len,
    };
}

pub fn appendProperties(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    properties: Properties,
) !void {
    const salt_len: usize = properties.salt_len;
    const iv_len: usize = properties.iv_len;
    if (salt_len > max_salt_len or iv_len > block_len)
        return error.Invalid7zAesProperties;
    var first: u8 = properties.num_cycles_power;
    if (salt_len != 0) first |= 0x80;
    if (iv_len != 0) first |= 0x40;
    try output.append(allocator, first);
    if (salt_len == 0 and iv_len == 0) return;
    const second: u8 = @intCast(
        ((if (salt_len == 0) 0 else salt_len - 1) << 4) |
            (if (iv_len == 0) 0 else iv_len - 1),
    );
    try output.append(allocator, second);
    try output.appendSlice(allocator, properties.salt[0..salt_len]);
    try output.appendSlice(allocator, properties.iv[0..iv_len]);
}

pub fn encryptAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: Options,
    stream_index: u64,
) !usize {
    const properties = try propertiesForStream(options, stream_index);
    const padded_len = std.mem.alignForward(usize, input.len, block_len);
    try output.ensureUnusedCapacity(allocator, padded_len);
    if (padded_len == 0) return 0;

    var key = try deriveKey(allocator, options.password, properties, max_cycles_power);
    defer std.crypto.secureZero(u8, &key);
    var context = crypto.Encryptor.init(key, properties.iv);
    defer context.deinit();
    var offset: usize = 0;
    while (offset < padded_len) : (offset += block_len) {
        var plain: [block_len]u8 = @splat(0);
        const available = @min(block_len, input.len -| offset);
        if (available != 0) @memcpy(plain[0..available], input[offset..][0..available]);
        var encrypted: [block_len]u8 = undefined;
        context.encryptBlocks(&plain, &encrypted) catch
            return error.Invalid7zEncryptionOptions;
        output.appendSliceAssumeCapacity(&encrypted);
        std.crypto.secureZero(u8, &plain);
    }
    return padded_len;
}

pub fn decryptAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_len: usize,
    password: ?[]const u8,
    properties: Properties,
    allowed_cycles_power: u6,
) ![]u8 {
    const password_bytes = password orelse return error.PasswordRequired;
    if (input.len & (block_len - 1) != 0 or expected_len > input.len or
        input.len - expected_len >= block_len)
        return error.Invalid7zAesProperties;
    const output = try allocator.alloc(u8, expected_len);
    errdefer allocator.free(output);
    if (input.len == 0) return output;

    var key = try deriveKey(
        allocator,
        password_bytes,
        properties,
        allowed_cycles_power,
    );
    defer std.crypto.secureZero(u8, &key);
    var context = crypto.Decryptor.init(key, properties.iv);
    defer context.deinit();
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < input.len) : (input_offset += block_len) {
        const encrypted: *const [block_len]u8 = input[input_offset..][0..block_len];
        var plain: [block_len]u8 = undefined;
        context.decryptBlocks(encrypted, &plain) catch
            return error.Invalid7zAesProperties;
        const count = @min(block_len, expected_len - output_offset);
        if (count != 0) {
            @memcpy(output[output_offset..][0..count], plain[0..count]);
            output_offset += count;
        }
        std.crypto.secureZero(u8, &plain);
    }
    return output;
}

pub fn deriveKey(
    allocator: std.mem.Allocator,
    password: []const u8,
    properties: Properties,
    allowed_cycles_power: u6,
) ![key_len]u8 {
    return crypto.deriveKey(
        allocator,
        password,
        properties.saltBytes(),
        properties.num_cycles_power,
        .{ .max_cycles_power = allowed_cycles_power },
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidPassword => return error.Invalid7zPassword,
        error.KdfWorkLimitExceeded => return error.OutputLimitExceeded,
        error.InvalidBlockLength, error.InvalidKdfCycles => return error.Invalid7zAesProperties,
    };
}

fn validateOptions(options: Options) Error!void {
    if (!std.unicode.utf8ValidateSlice(options.password) or
        options.salt_len > max_salt_len or
        (options.num_cycles_power > max_cycles_power and
            options.num_cycles_power != direct_key_power))
        return error.Invalid7zEncryptionOptions;
}

test "7z AES properties round trip salt IV and stream index" {
    const options = Options{
        .password = "secret",
        .iv = [_]u8{0x10} ** block_len,
        .salt = [_]u8{0x20} ** max_salt_len,
        .salt_len = 8,
        .num_cycles_power = 19,
    };
    const properties = try propertiesForStream(options, 7);
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try appendProperties(std.testing.allocator, &encoded, properties);
    const parsed = try parseProperties(encoded.items);
    try std.testing.expectEqual(properties.num_cycles_power, parsed.num_cycles_power);
    try std.testing.expectEqualSlices(u8, properties.saltBytes(), parsed.saltBytes());
    try std.testing.expectEqualSlices(u8, properties.ivBytes(), parsed.ivBytes());
}

test "7z AES direct KDF and CBC round trip partial block" {
    const options = Options{
        .password = "密码",
        .iv = [_]u8{0x42} ** block_len,
        .salt = [_]u8{0x24} ** max_salt_len,
        .salt_len = 4,
        .num_cycles_power = direct_key_power,
    };
    const properties = try propertiesForStream(options, 0);
    const key = try deriveKey(
        std.testing.allocator,
        options.password,
        properties,
        max_cycles_power,
    );
    try std.testing.expectEqualSlices(u8, &.{ 0x24, 0x24, 0x24, 0x24, 0xc6, 0x5b, 0x01, 0x78 }, key[0..8]);

    var encrypted: std.ArrayList(u8) = .empty;
    defer encrypted.deinit(std.testing.allocator);
    const input = "7z AES payload with a partial block";
    _ = try encryptAppend(std.testing.allocator, &encrypted, input, options, 0);
    const decoded = try decryptAlloc(
        std.testing.allocator,
        encrypted.items,
        input.len,
        options.password,
        properties,
        max_cycles_power,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expectError(
        error.PasswordRequired,
        decryptAlloc(
            std.testing.allocator,
            encrypted.items,
            input.len,
            null,
            properties,
            max_cycles_power,
        ),
    );
}

test "7z AES rejects malformed properties and bounded KDF work" {
    try std.testing.expectError(error.Invalid7zAesProperties, parseProperties(&.{0x40}));
    try std.testing.expectError(error.Invalid7zAesProperties, parseProperties(&.{25}));
    const properties = Properties{ .num_cycles_power = 19 };
    try std.testing.expectError(
        error.OutputLimitExceeded,
        deriveKey(std.testing.allocator, "secret", properties, 18),
    );
    const key = try deriveKey(std.testing.allocator, "secret", properties, max_cycles_power);
    var expected: [key_len]u8 = undefined;
    _ = try std.fmt.hexToBytes(
        &expected,
        "6511f1507a3c2a982ae6def4f65818ed6cf242651aca19d15cebc6a67ae2891d",
    );
    try std.testing.expectEqual(expected, key);
}
