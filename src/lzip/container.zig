const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const lzma_decoder = @import("../lzma/decoder.zig");
const dictionary = @import("dictionary.zig");

pub const Error = core.Error || lzma_decoder.Error || error{
    InvalidLzipHeader,
    InvalidLzipStream,
};

pub const Header = struct {
    version: u8,
    coded_dictionary_size: u8,
    dictionary_size: u32,
};

pub const MemberInfo = struct {
    compressed_offset: usize,
    compressed_size: usize,
    uncompressed_size: u64,
    dictionary_size: u32,
    crc32: u32,
};

pub const FileInfo = struct {
    member_count: usize,
    compressed_size: usize,
    uncompressed_size: u64,
    max_dictionary_size: u32,
};

pub const DecodeOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = 512 * 1024 * 1024,
};

const header_size: usize = 6;
const trailer_size: usize = 20;
const min_member_size: usize = 36;

const Index = struct {
    members: []MemberInfo,
    info: FileInfo,

    fn deinit(self: Index, allocator: std.mem.Allocator) void {
        allocator.free(self.members);
    }
};

pub fn parseHeader(input: []const u8) Error!Header {
    if (input.len < header_size) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..4], "LZIP")) return error.InvalidMagic;
    if (input[4] != 1) return error.UnsupportedVersion;

    const coded = input[5];
    const dictionary_size = dictionary.decode(coded) orelse return error.InvalidLzipHeader;
    return .{
        .version = 1,
        .coded_dictionary_size = coded,
        .dictionary_size = dictionary_size,
    };
}

pub fn inspect(allocator: std.mem.Allocator, input: []const u8) !FileInfo {
    const index = try indexMembers(allocator, input);
    defer index.deinit(allocator);
    return index.info;
}

pub fn decodeInto(allocator: std.mem.Allocator, input: []const u8, output: []u8) !usize {
    const decoded = decodeAllocWithOptions(allocator, input, .{
        .max_output_len = output.len,
    }) catch |err| switch (err) {
        error.OutputLimitExceeded => return error.OutputTooSmall,
        else => |decode_error| return decode_error,
    };
    defer allocator.free(decoded);
    @memcpy(output[0..decoded.len], decoded);
    return decoded.len;
}

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeAllocWithOptions(allocator, input, .{});
}

pub fn decodeAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    return decodeAllocWithOptions(allocator, input, .{ .max_output_len = max_output_len });
}

pub fn decodeAllocWithOptions(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: DecodeOptions,
) ![]u8 {
    const index = try indexMembers(allocator, input);
    defer index.deinit(allocator);
    if (index.info.uncompressed_size > options.max_output_len)
        return error.OutputLimitExceeded;
    if (index.info.max_dictionary_size > options.max_dictionary_size)
        return error.OutputLimitExceeded;

    const declared_size = std.math.cast(usize, index.info.uncompressed_size) orelse
        return error.OutputLimitExceeded;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.ensureTotalCapacity(allocator, declared_size);

    for (index.members) |member| {
        const payload_start = member.compressed_offset + header_size;
        const payload_end = member.compressed_offset + member.compressed_size - trailer_size;
        const expected_size = std.math.cast(usize, member.uncompressed_size) orelse
            return error.OutputLimitExceeded;
        const decoded = lzma_decoder.decodeLzipPayloadAllocLimited(
            allocator,
            input[payload_start..payload_end],
            member.dictionary_size,
            expected_size,
        ) catch |err| switch (err) {
            error.OutputLimitExceeded => return error.SizeMismatch,
            else => |decode_error| return decode_error,
        };
        defer allocator.free(decoded);
        if (decoded.len != member.uncompressed_size) return error.SizeMismatch;
        if (checksum.crc32Best(decoded) != member.crc32) return error.ChecksumMismatch;
        try output.appendSlice(allocator, decoded);
    }
    if (output.items.len != declared_size) return error.SizeMismatch;
    return output.toOwnedSlice(allocator);
}

pub fn decodedSize(allocator: std.mem.Allocator, input: []const u8) !usize {
    return decodedSizeLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodedSizeLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) !usize {
    return decodedSizeWithOptions(allocator, input, .{ .max_output_len = max_output_len });
}

pub fn decodedSizeWithOptions(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: DecodeOptions,
) !usize {
    const decoded = try decodeAllocWithOptions(allocator, input, options);
    defer allocator.free(decoded);
    return decoded.len;
}

fn indexMembers(allocator: std.mem.Allocator, input: []const u8) !Index {
    if (input.len < min_member_size) return error.TruncatedFrame;

    var member_count: usize = 0;
    var end = input.len;
    var uncompressed_size: u64 = 0;
    var max_dictionary_size: u32 = 0;
    var contains_empty_member = false;
    while (end != 0) {
        const member = try memberEndingAt(input, end);
        member_count = std.math.add(usize, member_count, 1) catch return error.IntegerOverflow;
        uncompressed_size = std.math.add(u64, uncompressed_size, member.uncompressed_size) catch
            return error.IntegerOverflow;
        max_dictionary_size = @max(max_dictionary_size, member.dictionary_size);
        contains_empty_member = contains_empty_member or member.uncompressed_size == 0;
        end = member.compressed_offset;
    }
    if (member_count > 1 and contains_empty_member) return error.InvalidLzipStream;

    const members = try allocator.alloc(MemberInfo, member_count);
    errdefer allocator.free(members);
    end = input.len;
    var index = member_count;
    while (end != 0) {
        index -= 1;
        members[index] = try memberEndingAt(input, end);
        end = members[index].compressed_offset;
    }
    return .{
        .members = members,
        .info = .{
            .member_count = member_count,
            .compressed_size = input.len,
            .uncompressed_size = uncompressed_size,
            .max_dictionary_size = max_dictionary_size,
        },
    };
}

fn memberEndingAt(input: []const u8, end: usize) Error!MemberInfo {
    if (end < min_member_size) return error.InvalidLzipStream;
    const trailer = input[end - trailer_size .. end];
    const member_size_u64 = std.mem.readInt(u64, trailer[12..20], .little);
    const member_size = std.math.cast(usize, member_size_u64) orelse
        return error.InvalidLzipStream;
    if (member_size < min_member_size or member_size > end)
        return error.InvalidLzipStream;
    const start = end - member_size;
    const header = try parseHeader(input[start..][0..header_size]);
    const crc32 = std.mem.readInt(u32, trailer[0..4], .little);
    const uncompressed_size = std.mem.readInt(u64, trailer[4..12], .little);
    try validateTrailerConsistency(crc32, uncompressed_size, member_size_u64);
    return .{
        .compressed_offset = start,
        .compressed_size = member_size,
        .uncompressed_size = uncompressed_size,
        .dictionary_size = header.dictionary_size,
        .crc32 = crc32,
    };
}

fn validateTrailerConsistency(crc32: u32, data_size: u64, member_size: u64) Error!void {
    if ((crc32 == 0) != (data_size == 0)) return error.InvalidLzipStream;
    const maximum_member_size = (@as(u128, 9) * data_size + 7) / 8 + min_member_size;
    if (maximum_member_size > data_size and member_size > maximum_member_size)
        return error.InvalidLzipStream;
    const maximum_data_size = @as(u128, 7090) * (member_size - 26) - 1;
    if (maximum_data_size > member_size and data_size > maximum_data_size)
        return error.InvalidLzipStream;
}

test "lzip header decodes canonical and fractional dictionary sizes" {
    const smallest = try parseHeader("LZIP\x01\x0c");
    try std.testing.expectEqual(@as(u32, 4096), smallest.dictionary_size);
    const fractional = try parseHeader("LZIP\x01\xd3");
    try std.testing.expectEqual(@as(u32, 320 * 1024), fractional.dictionary_size);

    try std.testing.expectError(error.TruncatedFrame, parseHeader("LZIP\x01"));
    try std.testing.expectError(error.InvalidMagic, parseHeader("LZMA\x01\x0c"));
    try std.testing.expectError(error.UnsupportedVersion, parseHeader("LZIP\x02\x0c"));
    try std.testing.expectError(error.InvalidLzipHeader, parseHeader("LZIP\x01\x0b"));
    try std.testing.expectError(error.InvalidLzipHeader, parseHeader("LZIP\x01\x1e"));
}

test {
    _ = dictionary;
}

test "lzip decoder validates reference members and concatenation" {
    const first_hex = "4c5a4950010c00341949ee8de9148a6a3e85eb7b90eba1fffffbfde0003a319d3216000000000000003100000000000000";
    const second_hex = "4c5a4950010c0039994891b1699607da1f9626254cb362ec39fab33c54ffff69500000ba2ac21512000000000000003700000000000000";
    var first: [first_hex.len / 2]u8 = undefined;
    var second: [second_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&first, first_hex);
    _ = try std.fmt.hexToBytes(&second, second_hex);

    const first_decoded = try decodeAlloc(std.testing.allocator, &first);
    defer std.testing.allocator.free(first_decoded);
    try std.testing.expectEqualSlices(u8, "hello lzip\nhello lzip\n", first_decoded);

    var concatenated: std.ArrayList(u8) = .empty;
    defer concatenated.deinit(std.testing.allocator);
    try concatenated.appendSlice(std.testing.allocator, &first);
    try concatenated.appendSlice(std.testing.allocator, &second);
    const info = try inspect(std.testing.allocator, concatenated.items);
    try std.testing.expectEqual(@as(usize, 2), info.member_count);
    try std.testing.expectEqual(@as(u64, 40), info.uncompressed_size);
    try std.testing.expectEqual(@as(u32, 4096), info.max_dictionary_size);

    const decoded = try decodeAlloc(std.testing.allocator, concatenated.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello lzip\nhello lzip\nsecond member data", decoded);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocLimited(std.testing.allocator, concatenated.items, decoded.len - 1),
    );

    var corrupt = first;
    corrupt[corrupt.len - trailer_size] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeAlloc(std.testing.allocator, &corrupt));
}

test "lzip rejects empty members inside multimember files" {
    const empty_hex = "4c5a4950010c0083fffbffffc00000000000000000000000000000002400000000000000";
    const data_hex = "4c5a4950010c0039994891b1699607da1f9626254cb362ec39fab33c54ffff69500000ba2ac21512000000000000003700000000000000";
    var empty: [empty_hex.len / 2]u8 = undefined;
    var data: [data_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&empty, empty_hex);
    _ = try std.fmt.hexToBytes(&data, data_hex);
    const decoded = try decodeAlloc(std.testing.allocator, &empty);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);

    var invalid: std.ArrayList(u8) = .empty;
    defer invalid.deinit(std.testing.allocator);
    try invalid.appendSlice(std.testing.allocator, &empty);
    try invalid.appendSlice(std.testing.allocator, &data);
    try std.testing.expectError(error.InvalidLzipStream, inspect(std.testing.allocator, invalid.items));
}
