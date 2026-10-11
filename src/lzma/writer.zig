const std = @import("std");
const core = @import("../core.zig");
const encoder = @import("encoder.zig");

pub const Error = core.Error || encoder.Error;
pub const Properties = encoder.Properties;
pub const Mode = encoder.Mode;

pub const SizeMode = enum {
    known,
    end_marker,
};

pub const EncodeOptions = struct {
    properties: Properties = .{},
    dictionary_size: u32 = 32 * 1024,
    mode: Mode = .greedy,
    size_mode: SizeMode = .end_marker,
};

pub const ZipEncodeOptions = struct {
    properties: Properties = .{},
    dictionary_size: u32 = 32 * 1024,
    mode: Mode = .greedy,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

/// Encode the headerless, fixed-property LZMA1 payload stored by a CHD v5
/// hunk. CHD derives its advertised dictionary from the hunk size instead of
/// storing LZMA properties. The current greedy match finder uses at most a
/// 65,535-byte window; using a smaller encoder window remains valid when the
/// independently derived decoder dictionary is larger.
pub fn encodeChdPayloadAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    dictionary_size: u32,
) ![]u8 {
    if (dictionary_size < 4096 or dictionary_size > (1 << 30) + (1 << 29))
        return error.InvalidLzmaOptions;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encoder.encodeChunkAppend(allocator, &output, input, .{
        .properties = .{ .lc = 3, .lp = 0, .pb = 2 },
        .dictionary_size = @min(dictionary_size, std.math.maxInt(u16)),
        .mode = .greedy,
        .end_marker = false,
    });
    return output.toOwnedSlice(allocator);
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

/// Append a deterministic LZMA-Alone stream without changing `out.items` on
/// error.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    try validateCoreOptions(options.properties, options.dictionary_size);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encoded.append(allocator, try encoder.propertyByte(options.properties));
    try appendU32(allocator, &encoded, options.dictionary_size);
    try appendU64(allocator, &encoded, switch (options.size_mode) {
        .known => std.math.cast(u64, input.len) orelse return error.IntegerOverflow,
        .end_marker => std.math.maxInt(u64),
    });
    _ = try encoder.encodeChunkAppend(allocator, &encoded, input, .{
        .properties = options.properties,
        .dictionary_size = options.dictionary_size,
        .mode = options.mode,
        .end_marker = options.size_mode == .end_marker,
    });

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

pub fn encodeZipPayloadAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: ZipEncodeOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeZipPayloadAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

/// Append a ZIP method-14 payload, including the ZIP LZMA properties prefix
/// and mandatory end marker, without changing `out.items` on error.
pub fn encodeZipPayloadAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: ZipEncodeOptions,
) !usize {
    try validateZipOptions(options);
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encoded.appendSlice(allocator, &.{ 9, 4 });
    try appendU16(allocator, &encoded, 5);
    try encoded.append(allocator, try encoder.propertyByte(options.properties));
    try appendU32(allocator, &encoded, options.dictionary_size);
    _ = try encoder.encodeChunkAppend(allocator, &encoded, input, .{
        .properties = options.properties,
        .dictionary_size = options.dictionary_size,
        .mode = options.mode,
        .end_marker = true,
    });

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

pub fn validateZipOptions(options: ZipEncodeOptions) Error!void {
    return validateCoreOptions(options.properties, options.dictionary_size);
}

fn validateCoreOptions(properties: Properties, dictionary_size: u32) Error!void {
    _ = try encoder.propertyByte(properties);
    if (dictionary_size < 4096 or dictionary_size > std.math.maxInt(u16))
        return error.InvalidLzmaOptions;
}

fn appendU16(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendU32(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendU64(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u64) !void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

test "LZMA-Alone writer round trips known-size and end-marker streams" {
    const decoder = @import("decoder.zig");
    const input = "LZMA-Alone greedy match writer\n" ** 256;
    inline for (.{ SizeMode.known, SizeMode.end_marker }) |size_mode| {
        const encoded = try encodeAlloc(std.testing.allocator, input, .{ .size_mode = size_mode });
        defer std.testing.allocator.free(encoded);
        try std.testing.expect(encoded.len < input.len);
        const header = try decoder.parseHeader(encoded);
        try std.testing.expectEqual(@as(u32, 32 * 1024), header.dictionary_size);
        try std.testing.expectEqual(
            if (size_mode == .known) @as(?u64, input.len) else null,
            header.uncompressed_size,
        );
        const decoded = try decoder.decodeAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "LZMA-Alone writer handles empty input and transactional output" {
    const decoder = @import("decoder.zig");
    inline for (.{ SizeMode.known, SizeMode.end_marker }) |size_mode| {
        const encoded = try encodeAlloc(std.testing.allocator, "", .{ .size_mode = size_mode });
        defer std.testing.allocator.free(encoded);
        const decoded = try decoder.decodeAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqual(@as(usize, 0), decoded.len);
    }

    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(std.testing.allocator);
    try output.appendSlice(std.testing.allocator, "prefix:");
    const before = try std.testing.allocator.dupe(u8, output.items);
    defer std.testing.allocator.free(before);
    try std.testing.expectError(
        error.InvalidLzmaOptions,
        encodeAppend(std.testing.allocator, &output, "payload", .{ .dictionary_size = 1024 }),
    );
    try std.testing.expectEqualSlices(u8, before, output.items);
}

test "ZIP method 14 payload writer round trips with an end marker" {
    const decoder = @import("decoder.zig");
    const input = "ZIP method 14 LZMA payload\n" ** 128;
    const encoded = try encodeZipPayloadAlloc(std.testing.allocator, input, .{});
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &.{ 9, 4, 5, 0 }, encoded[0..4]);
    const decoded = try decoder.decodeZipPayloadAllocLimited(
        std.testing.allocator,
        encoded,
        input.len,
        32 * 1024,
        true,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}
