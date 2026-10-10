const std = @import("std");
const cpio = @import("../cpio.zig");
const header_mod = @import("header.zig");
const types = @import("types.zig");

pub const Error = cpio.Error || header_mod.Error || std.mem.Allocator.Error || error{
    InvalidRpmEncodeOptions,
    RpmHeaderOverflow,
};

pub const Options = struct {
    name: []const u8,
    version: []const u8,
    release: []const u8 = "1",
    architecture: []const u8 = "noarch",
    operating_system: []const u8 = "linux",
    license: []const u8 = "Unspecified",
    payload_compression: types.PayloadCompression = .xz,
    cpio_options: cpio.EncodeOptions = .{},
};

const HeaderEntry = struct {
    tag: u32,
    value_type: header_mod.ValueType,
    offset: u32,
    count: u32,
};

const HeaderBuilder = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayList(HeaderEntry) = .empty,
    store: std.ArrayList(u8) = .empty,

    fn deinit(self: *HeaderBuilder) void {
        self.entries.deinit(self.allocator);
        self.store.deinit(self.allocator);
        self.* = undefined;
    }

    fn addString(self: *HeaderBuilder, tag: u32, value: []const u8) Error!void {
        if (std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidRpmEncodeOptions;
        const offset = try self.currentOffset();
        try self.store.appendSlice(self.allocator, value);
        try self.store.append(self.allocator, 0);
        try self.entries.append(self.allocator, .{
            .tag = tag,
            .value_type = .string,
            .offset = offset,
            .count = 1,
        });
    }

    fn addInt32(self: *HeaderBuilder, tag: u32, value: u32) Error!void {
        try self.alignStore(4);
        const offset = try self.currentOffset();
        var bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &bytes, value, .big);
        try self.store.appendSlice(self.allocator, &bytes);
        try self.entries.append(self.allocator, .{
            .tag = tag,
            .value_type = .int32,
            .offset = offset,
            .count = 1,
        });
    }

    fn addBinary(self: *HeaderBuilder, tag: u32, value: []const u8) Error!void {
        const offset = try self.currentOffset();
        try self.store.appendSlice(self.allocator, value);
        try self.entries.append(self.allocator, .{
            .tag = tag,
            .value_type = .binary,
            .offset = offset,
            .count = std.math.cast(u32, value.len) orelse return error.RpmHeaderOverflow,
        });
    }

    fn finishAlloc(self: *HeaderBuilder, region_tag: u32) Error![]u8 {
        const index_count = std.math.add(usize, self.entries.items.len, 1) catch
            return error.IntegerOverflow;
        const index_bytes = std.math.mul(usize, index_count, 16) catch
            return error.IntegerOverflow;
        const region_offset = try self.currentOffset();
        var trailer: [16]u8 = undefined;
        writeIndex(&trailer, .{
            .tag = region_tag,
            .value_type = .binary,
            .offset = 0 -% (std.math.cast(u32, index_bytes) orelse return error.RpmHeaderOverflow),
            .count = 16,
        });
        try self.store.appendSlice(self.allocator, &trailer);

        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(self.allocator);
        try output.appendSlice(self.allocator, &.{ 0x8e, 0xad, 0xe8, 1, 0, 0, 0, 0 });
        try appendBe32(self.allocator, &output, @intCast(index_count));
        try appendBe32(
            self.allocator,
            &output,
            std.math.cast(u32, self.store.items.len) orelse return error.RpmHeaderOverflow,
        );
        var region: [16]u8 = undefined;
        writeIndex(&region, .{
            .tag = region_tag,
            .value_type = .binary,
            .offset = region_offset,
            .count = 16,
        });
        try output.appendSlice(self.allocator, &region);
        for (self.entries.items) |entry| {
            var bytes: [16]u8 = undefined;
            writeIndex(&bytes, entry);
            try output.appendSlice(self.allocator, &bytes);
        }
        try output.appendSlice(self.allocator, self.store.items);
        return output.toOwnedSlice(self.allocator);
    }

    fn currentOffset(self: *const HeaderBuilder) Error!u32 {
        return std.math.cast(u32, self.store.items.len) orelse error.RpmHeaderOverflow;
    }

    fn alignStore(self: *HeaderBuilder, alignment: usize) Error!void {
        const remainder = self.store.items.len % alignment;
        if (remainder != 0)
            try self.store.appendNTimes(self.allocator, 0, alignment - remainder);
    }
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const cpio.EncodeEntry,
    options: Options,
) Error![]u8 {
    try validateOptions(options);
    const raw_payload = try cpio.encodeAlloc(allocator, entries, options.cpio_options);
    defer allocator.free(raw_payload);
    const payload = try cpio.encodeCompressedAlloc(allocator, entries, .{
        .archive_options = options.cpio_options,
        .compression = cpioCompression(options.payload_compression),
    });
    defer allocator.free(payload);

    var main_builder = HeaderBuilder{ .allocator = allocator };
    defer main_builder.deinit();
    try main_builder.addString(1000, options.name);
    try main_builder.addString(1001, options.version);
    try main_builder.addString(1002, options.release);
    try main_builder.addInt32(1009, try installedSize(entries));
    try main_builder.addString(1014, options.license);
    try main_builder.addString(1021, options.operating_system);
    try main_builder.addString(1022, options.architecture);
    try main_builder.addString(1124, "cpio");
    try main_builder.addString(1125, compressorName(options.payload_compression));
    try main_builder.addString(1126, compressorFlags(options.payload_compression));
    const main_header = try main_builder.finishAlloc(63);
    defer allocator.free(main_header);

    var sha1: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    std.crypto.hash.Sha1.hash(main_header, &sha1, .{});
    var sha256: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(main_header, &sha256, .{});
    var md5_state = std.crypto.hash.Md5.init(.{});
    md5_state.update(main_header);
    md5_state.update(payload);
    var md5: [std.crypto.hash.Md5.digest_length]u8 = undefined;
    md5_state.final(&md5);
    const sha1_hex = lowerHex(&sha1);
    const sha256_hex = lowerHex(&sha256);

    var signature_builder = HeaderBuilder{ .allocator = allocator };
    defer signature_builder.deinit();
    try signature_builder.addString(269, &sha1_hex);
    try signature_builder.addString(273, &sha256_hex);
    const package_size = std.math.add(usize, main_header.len, payload.len) catch
        return error.IntegerOverflow;
    try signature_builder.addInt32(
        1000,
        std.math.cast(u32, package_size) orelse return error.RpmHeaderOverflow,
    );
    try signature_builder.addBinary(1004, &md5);
    try signature_builder.addInt32(
        1007,
        std.math.cast(u32, raw_payload.len) orelse return error.RpmHeaderOverflow,
    );
    const signature_header = try signature_builder.finishAlloc(62);
    defer allocator.free(signature_header);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try appendLead(allocator, &output, options);
    try output.appendSlice(allocator, signature_header);
    const signature_remainder = output.items.len % 8;
    if (signature_remainder != 0)
        try output.appendNTimes(allocator, 0, 8 - signature_remainder);
    try output.appendSlice(allocator, main_header);
    try output.appendSlice(allocator, payload);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const cpio.EncodeEntry,
    options: Options,
) Error!usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    const start = output.items.len;
    errdefer output.items.len = start;
    try output.appendSlice(allocator, encoded);
    return encoded.len;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    entries: []const cpio.EncodeEntry,
    options: Options,
    output: []u8,
) Error!usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn appendLead(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    options: Options,
) Error!void {
    var lead: [96]u8 = @splat(0);
    lead[0..6].* = .{ 0xed, 0xab, 0xee, 0xdb, 3, 0 };
    var name_buffer: [96]u8 = undefined;
    const lead_name = std.fmt.bufPrint(
        &name_buffer,
        "{s}-{s}-{s}",
        .{ options.name, options.version, options.release },
    ) catch return error.InvalidRpmEncodeOptions;
    if (lead_name.len > 65) return error.InvalidRpmEncodeOptions;
    @memcpy(lead[10..][0..lead_name.len], lead_name);
    std.mem.writeInt(u16, lead[78..80], 5, .big);
    try output.appendSlice(allocator, &lead);
}

fn validateOptions(options: Options) Error!void {
    const values = [_][]const u8{
        options.name,
        options.version,
        options.release,
        options.architecture,
        options.operating_system,
        options.license,
    };
    for (values) |value|
        if (value.len == 0 or std.mem.indexOfScalar(u8, value, 0) != null)
            return error.InvalidRpmEncodeOptions;
}

fn installedSize(entries: []const cpio.EncodeEntry) Error!u32 {
    var total: usize = 0;
    for (entries) |entry| total = std.math.add(usize, total, entry.data.len) catch
        return error.IntegerOverflow;
    return std.math.cast(u32, total) orelse error.RpmHeaderOverflow;
}

fn cpioCompression(compression: types.PayloadCompression) cpio.Compression {
    return switch (compression) {
        .none => .none,
        .gzip => .gzip,
        .bzip2 => .bzip2,
        .lzma => .lzma,
        .xz => .xz,
        .zstandard => .zstandard,
    };
}

fn compressorName(compression: types.PayloadCompression) []const u8 {
    return switch (compression) {
        .none => "none",
        .gzip => "gzip",
        .bzip2 => "bzip2",
        .lzma => "lzma",
        .xz => "xz",
        .zstandard => "zstd",
    };
}

fn compressorFlags(compression: types.PayloadCompression) []const u8 {
    return switch (compression) {
        .none => "0",
        .gzip, .bzip2 => "9",
        .lzma, .xz => "6",
        .zstandard => "19",
    };
}

fn writeIndex(output: *[16]u8, entry: HeaderEntry) void {
    std.mem.writeInt(u32, output[0..4], entry.tag, .big);
    std.mem.writeInt(u32, output[4..8], @intFromEnum(entry.value_type), .big);
    std.mem.writeInt(u32, output[8..12], entry.offset, .big);
    std.mem.writeInt(u32, output[12..16], entry.count, .big);
}

fn appendBe32(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u32,
) Error!void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .big);
    try output.appendSlice(allocator, &bytes);
}

fn lowerHex(input: anytype) [input.len * 2]u8 {
    const alphabet = "0123456789abcdef";
    var output: [input.len * 2]u8 = undefined;
    for (input, 0..) |byte, index| {
        output[index * 2] = alphabet[byte >> 4];
        output[index * 2 + 1] = alphabet[byte & 0x0f];
    }
    return output;
}
