const std = @import("std");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const block_header_size: usize = 0x400;
pub const block_data_size: usize = 0x7c00;
pub const blocks_per_group: usize = 64;
pub const group_data_size: usize = block_data_size * blocks_per_group;
pub const group_total_size: usize = format.wii_group_size;
pub const max_exceptions_per_list: usize = 52 * 64;

pub const ParsedExceptionLists = struct {
    allocator: std.mem.Allocator,
    entries: []format.HashException,
    list_starts: []usize,
    consumed: usize,

    pub fn deinit(self: *ParsedExceptionLists) void {
        self.allocator.free(self.list_starts);
        self.allocator.free(self.entries);
        self.* = undefined;
    }

    pub fn list(self: ParsedExceptionLists, index: usize) []const format.HashException {
        const start = self.list_starts[index];
        const end = self.list_starts[index + 1];
        return self.entries[start..end];
    }
};

pub const ExtractedGroup = struct {
    allocator: std.mem.Allocator,
    data: []u8,
    exceptions: []format.HashException,

    pub fn deinit(self: *ExtractedGroup) void {
        self.allocator.free(self.exceptions);
        self.allocator.free(self.data);
        self.* = undefined;
    }
};

pub fn parseExceptionListsAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    list_count: usize,
    align_after_last: bool,
    max_exceptions: usize,
) Error!ParsedExceptionLists {
    const starts = try allocator.alloc(usize, list_count + 1);
    errdefer allocator.free(starts);
    var entries: std.ArrayList(format.HashException) = .empty;
    errdefer entries.deinit(allocator);
    var offset: usize = 0;
    for (0..list_count) |list_index| {
        starts[list_index] = entries.items.len;
        if (input.len - offset < 2) return error.TruncatedFrame;
        const count: usize = std.mem.readInt(u16, input[offset..][0..2], .big);
        offset += 2;
        if (count > max_exceptions) return error.OutputLimitExceeded;
        const bytes = std.math.mul(usize, count, 22) catch
            return error.IntegerOverflow;
        if (bytes > input.len - offset) return error.TruncatedFrame;
        try entries.ensureUnusedCapacity(allocator, count);
        for (0..count) |_| {
            var hash: [20]u8 = undefined;
            @memcpy(&hash, input[offset + 2 ..][0..20]);
            entries.appendAssumeCapacity(.{
                .offset = std.mem.readInt(u16, input[offset..][0..2], .big),
                .hash = hash,
            });
            offset += 22;
        }
    }
    starts[list_count] = entries.items.len;
    if (align_after_last)
        offset = std.mem.alignForward(usize, offset, 4);
    if (offset > input.len) return error.TruncatedFrame;
    return .{
        .allocator = allocator,
        .entries = try entries.toOwnedSlice(allocator),
        .list_starts = starts,
        .consumed = offset,
    };
}

pub fn reconstructEncryptedGroupAlloc(
    allocator: std.mem.Allocator,
    decrypted: []const u8,
    key: *const [16]u8,
    exceptions: []const format.HashException,
) Error![]u8 {
    if (decrypted.len > group_data_size) return error.SizeMismatch;
    for (exceptions) |exception| {
        const block_index = exception.offset / block_header_size;
        const within_block = exception.offset % block_header_size;
        if (block_index >= blocks_per_group or
            within_block + exception.hash.len > block_header_size)
            return error.CorruptFrame;
    }
    const output = try allocator.alloc(u8, group_total_size);
    errdefer allocator.free(output);
    var data = try allocator.alloc(u8, group_data_size);
    defer allocator.free(data);
    @memset(data, 0);
    @memcpy(data[0..decrypted.len], decrypted);
    var headers: [blocks_per_group][block_header_size]u8 = @splat(@splat(0));
    buildHashHeaders(data, &headers);

    for (exceptions) |exception| {
        const block_index = exception.offset / block_header_size;
        const within_block = exception.offset % block_header_size;
        @memcpy(
            headers[block_index][within_block..][0..20],
            &exception.hash,
        );
    }

    var context = std.crypto.core.aes.Aes128.initEnc(key.*);
    defer std.crypto.secureZero(@TypeOf(context), (&context)[0..1]);
    for (0..blocks_per_group) |block_index| {
        const output_block = output[block_index * format.wii_block_size ..][0..format.wii_block_size];
        var zero_iv: [16]u8 = @splat(0);
        encryptCbc(
            &context,
            &zero_iv,
            &headers[block_index],
            output_block[0..block_header_size],
        );
        var data_iv: [16]u8 = output_block[0x3d0..0x3e0].*;
        encryptCbc(
            &context,
            &data_iv,
            data[block_index * block_data_size ..][0..block_data_size],
            output_block[block_header_size..],
        );
    }
    return output;
}

pub fn extractEncryptedGroupAlloc(
    allocator: std.mem.Allocator,
    encrypted: []const u8,
    key: *const [16]u8,
) Error!ExtractedGroup {
    if (encrypted.len == 0 or encrypted.len > group_total_size or
        encrypted.len % format.wii_block_size != 0)
        return error.SizeMismatch;
    const block_count = encrypted.len / format.wii_block_size;
    const data_len = std.math.mul(usize, block_count, block_data_size) catch
        return error.IntegerOverflow;
    const data = try allocator.alloc(u8, data_len);
    errdefer allocator.free(data);
    var original_headers = try allocator.alloc(
        [block_header_size]u8,
        block_count,
    );
    defer allocator.free(original_headers);

    var context = std.crypto.core.aes.Aes128.initDec(key.*);
    defer std.crypto.secureZero(@TypeOf(context), (&context)[0..1]);
    for (0..block_count) |block_index| {
        const encrypted_block = encrypted[block_index * format.wii_block_size ..][0..format.wii_block_size];
        var zero_iv: [16]u8 = @splat(0);
        decryptCbc(
            &context,
            &zero_iv,
            encrypted_block[0..block_header_size],
            &original_headers[block_index],
        );
        var data_iv: [16]u8 = encrypted_block[0x3d0..0x3e0].*;
        decryptCbc(
            &context,
            &data_iv,
            encrypted_block[block_header_size..],
            data[block_index * block_data_size ..][0..block_data_size],
        );
    }

    const padded = try allocator.alloc(u8, group_data_size);
    defer allocator.free(padded);
    @memset(padded, 0);
    @memcpy(padded[0..data.len], data);
    var expected_headers: [blocks_per_group][block_header_size]u8 = @splat(@splat(0));
    buildHashHeaders(padded, &expected_headers);

    var exceptions: std.ArrayList(format.HashException) = .empty;
    errdefer exceptions.deinit(allocator);
    for (0..block_count) |block_index|
        try appendHeaderExceptions(
            allocator,
            &exceptions,
            block_index,
            &original_headers[block_index],
            &expected_headers[block_index],
        );
    return .{
        .allocator = allocator,
        .data = data,
        .exceptions = try exceptions.toOwnedSlice(allocator),
    };
}

fn buildHashHeaders(
    data: []const u8,
    headers: *[blocks_per_group][block_header_size]u8,
) void {
    std.debug.assert(data.len == group_data_size);
    for (0..blocks_per_group) |block_index| {
        const block = data[block_index * block_data_size ..][0..block_data_size];
        for (0..31) |hash_index| {
            const source = block[hash_index * 0x400 ..][0..0x400];
            std.crypto.hash.Sha1.hash(
                source,
                headers[block_index][hash_index * 20 ..][0..20],
                .{},
            );
        }
    }
    for (0..8) |subgroup| {
        const base = subgroup * 8;
        for (0..8) |index|
            std.crypto.hash.Sha1.hash(
                headers[base + index][0..620],
                headers[base][640 + index * 20 ..][0..20],
                .{},
            );
        for (1..8) |index|
            @memcpy(headers[base + index][640..800], headers[base][640..800]);
        std.crypto.hash.Sha1.hash(
            headers[base][640..800],
            headers[0][832 + subgroup * 20 ..][0..20],
            .{},
        );
    }
    for (1..blocks_per_group) |index|
        @memcpy(headers[index][832..992], headers[0][832..992]);
}

fn appendHeaderExceptions(
    allocator: std.mem.Allocator,
    exceptions: *std.ArrayList(format.HashException),
    block_index: usize,
    actual: *const [block_header_size]u8,
    expected: *const [block_header_size]u8,
) Error!void {
    const regions = [_][2]usize{
        .{ 0, 620 },
        .{ 620, 20 },
        .{ 640, 160 },
        .{ 800, 32 },
        .{ 832, 160 },
        .{ 992, 32 },
    };
    for (regions) |region| {
        var position: usize = 0;
        while (position < region[1]) : (position += 20) {
            const within_block = region[0] + @min(position, region[1] - 20);
            if (std.mem.eql(
                u8,
                actual[within_block..][0..20],
                expected[within_block..][0..20],
            )) continue;
            try exceptions.append(allocator, .{
                .offset = @intCast(block_index * block_header_size + within_block),
                .hash = actual[within_block..][0..20].*,
            });
        }
    }
}

fn encryptCbc(
    context: anytype,
    iv: *[16]u8,
    input: []const u8,
    output: []u8,
) void {
    std.debug.assert(input.len == output.len and input.len % 16 == 0);
    var offset: usize = 0;
    while (offset < input.len) : (offset += 16) {
        var plain: [16]u8 = input[offset..][0..16].*;
        for (&plain, iv.*) |*byte, previous| byte.* ^= previous;
        const encrypted: *[16]u8 = output[offset..][0..16];
        context.encrypt(encrypted, &plain);
        iv.* = encrypted.*;
    }
}

fn decryptCbc(
    context: anytype,
    iv: *[16]u8,
    input: []const u8,
    output: []u8,
) void {
    std.debug.assert(input.len == output.len and input.len % 16 == 0);
    var offset: usize = 0;
    while (offset < input.len) : (offset += 16) {
        const encrypted: *const [16]u8 = input[offset..][0..16];
        var plain: [16]u8 = undefined;
        context.decrypt(&plain, encrypted);
        for (&plain, iv.*) |*byte, previous| byte.* ^= previous;
        @memcpy(output[offset..][0..16], &plain);
        iv.* = encrypted.*;
        std.crypto.secureZero(u8, &plain);
    }
}

test "Wii partition exception lists parse and align" {
    const bytes = [_]u8{
        0, 1, 0, 3,
    } ++ [_]u8{0xaa} ** 20 ++ [_]u8{ 0, 0, 0, 0 };
    var parsed = try parseExceptionListsAlloc(
        std.testing.allocator,
        &bytes,
        2,
        true,
        max_exceptions_per_list,
    );
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.entries.len);
    try std.testing.expectEqual(@as(u16, 3), parsed.entries[0].offset);
    try std.testing.expectEqual(@as(usize, 28), parsed.consumed);
}

test "Wii partition rejects malformed exceptions" {
    try std.testing.expectError(
        error.TruncatedFrame,
        parseExceptionListsAlloc(std.testing.allocator, &.{}, 1, false, 1),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        parseExceptionListsAlloc(
            std.testing.allocator,
            &.{ 0, 1, 0, 0 },
            1,
            false,
            1,
        ),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parseExceptionListsAlloc(
            std.testing.allocator,
            &.{ 0, 2 },
            1,
            false,
            1,
        ),
    );

    const bad_exception = format.HashException{
        .offset = block_header_size - 19,
        .hash = @splat(0xaa),
    };
    const key: [16]u8 = @splat(0);
    try std.testing.expectError(
        error.CorruptFrame,
        reconstructEncryptedGroupAlloc(
            std.testing.allocator,
            &.{},
            &key,
            &.{bad_exception},
        ),
    );
}
