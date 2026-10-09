const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const lzma_encoder = @import("../lzma/encoder.zig");
const dictionary = @import("dictionary.zig");

pub const Error = core.Error || lzma_encoder.Error || error{InvalidLzipOptions};
pub const Mode = lzma_encoder.Mode;

pub const EncodeOptions = struct {
    dictionary_size: u32 = 32 * 1024,
    mode: Mode = .greedy,
};

pub const EncodeMember = struct {
    data: []const u8,
    options: EncodeOptions = .{},
};

const trailer_size: usize = 20;

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

/// Append one complete lzip member without changing `out.items` on error.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    const written = try appendMember(allocator, &encoded, input, options);
    try out.ensureUnusedCapacity(allocator, written);
    out.appendSliceAssumeCapacity(encoded.items);
    return written;
}

pub fn encodeMembersAlloc(
    allocator: std.mem.Allocator,
    members: []const EncodeMember,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeMembersAppend(allocator, &output, members);
    return output.toOwnedSlice(allocator);
}

pub fn encodeMembersInto(
    allocator: std.mem.Allocator,
    members: []const EncodeMember,
    output: []u8,
) !usize {
    const encoded = try encodeMembersAlloc(allocator, members);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

/// Append one complete concatenated lzip file transactionally.
pub fn encodeMembersAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    members: []const EncodeMember,
) !usize {
    if (members.len == 0) return error.InvalidLzipOptions;
    if (members.len > 1) {
        for (members) |member|
            if (member.data.len == 0) return error.InvalidLzipOptions;
    }

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    for (members) |member|
        _ = try appendMember(allocator, &encoded, member.data, member.options);

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

fn appendMember(
    allocator: std.mem.Allocator,
    encoded: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    const dictionary_encoding = dictionary.encodeCeiling(options.dictionary_size) orelse
        return error.InvalidLzipOptions;
    const start = encoded.items.len;
    try encoded.appendSlice(allocator, "LZIP\x01");
    try encoded.append(allocator, dictionary_encoding.code);

    // The current shared token representation stores distances in u16. A
    // larger declared lzip dictionary remains wire-compatible because using a
    // smaller match-search window never produces an out-of-range reference.
    const match_window = @min(
        @as(usize, dictionary_encoding.size),
        std.math.maxInt(u16),
    );
    _ = try lzma_encoder.encodeChunkAppend(allocator, encoded, input, .{
        .dictionary_size = match_window,
        .mode = options.mode,
        .end_marker = true,
    });

    const size_without_trailer = encoded.items.len - start;
    const member_size = std.math.add(usize, size_without_trailer, trailer_size) catch
        return error.IntegerOverflow;
    try appendU32(allocator, encoded, checksum.crc32Best(input));
    try appendU64(
        allocator,
        encoded,
        std.math.cast(u64, input.len) orelse return error.IntegerOverflow,
    );
    try appendU64(
        allocator,
        encoded,
        std.math.cast(u64, member_size) orelse return error.IntegerOverflow,
    );
    return member_size;
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

test "lzip writer round trips empty and fractional dictionary members" {
    const container = @import("container.zig");
    const cases = [_]struct {
        data: []const u8,
        requested_dictionary_size: u32,
        encoded_dictionary_size: u32,
    }{
        .{ .data = "", .requested_dictionary_size = 4096, .encoded_dictionary_size = 4096 },
        .{
            .data = "Vort lzip writer round trip\n" ** 256,
            .requested_dictionary_size = 300 * 1024,
            .encoded_dictionary_size = 320 * 1024,
        },
    };
    for (cases) |case| {
        const encoded = try encodeAlloc(std.testing.allocator, case.data, .{
            .dictionary_size = case.requested_dictionary_size,
        });
        defer std.testing.allocator.free(encoded);
        const header = try container.parseHeader(encoded);
        try std.testing.expectEqual(case.encoded_dictionary_size, header.dictionary_size);
        try std.testing.expectEqual(checksum.crc32Best(case.data), std.mem.readInt(u32, encoded[encoded.len - 20 ..][0..4], .little));
        try std.testing.expectEqual(@as(u64, case.data.len), std.mem.readInt(u64, encoded[encoded.len - 16 ..][0..8], .little));
        try std.testing.expectEqual(@as(u64, encoded.len), std.mem.readInt(u64, encoded[encoded.len - 8 ..][0..8], .little));
        const decoded = try container.decodeAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case.data, decoded);
    }
}

test "lzip concatenated writer round trips and rejects empty members" {
    const container = @import("container.zig");
    const first = "first lzip member\n" ** 64;
    const second = "second lzip member\n" ** 96;
    const members = [_]EncodeMember{
        .{ .data = first, .options = .{ .dictionary_size = 4096 } },
        .{ .data = second, .options = .{ .dictionary_size = 64 * 1024 } },
    };
    const encoded = try encodeMembersAlloc(std.testing.allocator, &members);
    defer std.testing.allocator.free(encoded);
    const info = try container.inspect(std.testing.allocator, encoded);
    try std.testing.expectEqual(@as(usize, 2), info.member_count);
    try std.testing.expectEqual(@as(u32, 64 * 1024), info.max_dictionary_size);
    const decoded = try container.decodeAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);

    const caller_output = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(caller_output);
    try std.testing.expectEqual(
        encoded.len,
        try encodeMembersInto(std.testing.allocator, &members, caller_output),
    );
    try std.testing.expectEqualSlices(u8, encoded, caller_output);

    const invalid = [_]EncodeMember{ .{ .data = first }, .{ .data = "" } };
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    const before = try std.testing.allocator.dupe(u8, appended.items);
    defer std.testing.allocator.free(before);
    try std.testing.expectError(
        error.InvalidLzipOptions,
        encodeMembersAppend(std.testing.allocator, &appended, &invalid),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
    try std.testing.expectError(
        error.InvalidLzipOptions,
        encodeMembersAppend(std.testing.allocator, &appended, &.{}),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
}

test "lzip writer caller output and append errors are transactional" {
    const input = "caller-owned lzip output" ** 32;
    const encoded = try encodeAlloc(std.testing.allocator, input, .{});
    defer std.testing.allocator.free(encoded);
    const output = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(output);
    try std.testing.expectEqual(encoded.len, try encodeInto(std.testing.allocator, input, output, .{}));
    try std.testing.expectEqualSlices(u8, encoded, output);
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeInto(std.testing.allocator, input, output[0 .. output.len - 1], .{}),
    );

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    const before = try std.testing.allocator.dupe(u8, appended.items);
    defer std.testing.allocator.free(before);
    try std.testing.expectError(
        error.InvalidLzipOptions,
        encodeAppend(std.testing.allocator, &appended, input, .{ .dictionary_size = 1024 }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
}
