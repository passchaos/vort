const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{
    InvalidLzmaHeader,
    InvalidLzmaStream,
    UnsupportedLzmaFeature,
};

pub const Header = struct {
    lc: u4,
    lp: u3,
    pb: u3,
    dictionary_size: u32,
    uncompressed_size: ?u64,
};

pub const DecodeOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = std.math.maxInt(usize),
};

const alone_header_len: usize = 13;

pub fn parseHeader(input: []const u8) Error!Header {
    if (input.len < alone_header_len) return error.TruncatedFrame;
    const properties = try parseProperties(input[0]);
    const dictionary_size = @max(@as(u32, 4096), std.mem.readInt(u32, input[1..5], .little));
    const size = std.mem.readInt(u64, input[5..13], .little);
    return .{
        .lc = properties.lc,
        .lp = properties.lp,
        .pb = properties.pb,
        .dictionary_size = dictionary_size,
        .uncompressed_size = if (size == std.math.maxInt(u64)) null else size,
    };
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
    const header = try parseHeader(input);
    if (header.dictionary_size > options.max_dictionary_size) return error.OutputLimitExceeded;
    if (header.uncompressed_size) |size|
        if (size > options.max_output_len) return error.OutputLimitExceeded;
    return decodeRawAlloc(
        allocator,
        input[alone_header_len..],
        header,
        options.max_output_len,
        header.uncompressed_size == null,
    );
}

pub fn decodedSize(allocator: std.mem.Allocator, input: []const u8) !usize {
    return decodedSizeLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodedSizeLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) !usize {
    const decoded = try decodeAllocLimited(allocator, input, max_output_len);
    defer allocator.free(decoded);
    return decoded.len;
}

pub fn decodeZipPayloadInto(
    allocator: std.mem.Allocator,
    payload: []const u8,
    expected_size: usize,
    output: []u8,
    max_dictionary_size: usize,
    end_marker: bool,
) !usize {
    if (output.len < expected_size) return error.OutputTooSmall;
    const decoded = try decodeZipPayloadAllocLimited(
        allocator,
        payload,
        expected_size,
        max_dictionary_size,
        end_marker,
    );
    defer allocator.free(decoded);
    @memcpy(output[0..decoded.len], decoded);
    return decoded.len;
}

pub fn decodeZipPayloadAllocLimited(
    allocator: std.mem.Allocator,
    payload: []const u8,
    expected_size: usize,
    max_dictionary_size: usize,
    end_marker: bool,
) ![]u8 {
    if (payload.len < 9) return error.TruncatedFrame;
    const properties_size = std.mem.readInt(u16, payload[2..4], .little);
    if (properties_size != 5) return error.InvalidLzmaHeader;
    const properties = try parseProperties(payload[4]);
    const dictionary_size = @max(@as(u32, 4096), std.mem.readInt(u32, payload[5..9], .little));
    if (dictionary_size > max_dictionary_size) return error.OutputLimitExceeded;
    return decodeRawAlloc(
        allocator,
        payload[9..],
        .{
            .lc = properties.lc,
            .lp = properties.lp,
            .pb = properties.pb,
            .dictionary_size = dictionary_size,
            .uncompressed_size = if (end_marker) null else expected_size,
        },
        expected_size,
        end_marker,
    );
}

/// Decode the marker-terminated raw LZMA-302eos payload used by lzip members.
/// This integration helper is public within the source tree but is not
/// re-exported by the standalone LZMA facade.
pub fn decodeLzipPayloadAllocLimited(
    allocator: std.mem.Allocator,
    payload: []const u8,
    dictionary_size: u32,
    max_output_len: usize,
) ![]u8 {
    return decodeRawAlloc(
        allocator,
        payload,
        .{
            .lc = 3,
            .lp = 0,
            .pb = 2,
            .dictionary_size = dictionary_size,
            .uncompressed_size = null,
        },
        max_output_len,
        true,
    );
}

/// Decode a raw LZMA1 payload stored by a 7z coder. The five property bytes
/// contain the normal LZMA property byte followed by a little-endian
/// dictionary size; 7z supplies the exact unpacked size out of band.
pub fn decode7zPayloadAllocLimited(
    allocator: std.mem.Allocator,
    payload: []const u8,
    properties: []const u8,
    expected_size: usize,
    max_dictionary_size: usize,
) ![]u8 {
    if (properties.len != 5) return error.InvalidLzmaHeader;
    const parsed = try parseProperties(properties[0]);
    const dictionary_size = @max(@as(u32, 4096), std.mem.readInt(u32, properties[1..5], .little));
    if (dictionary_size > max_dictionary_size) return error.OutputLimitExceeded;
    return decodeRawAlloc(
        allocator,
        payload,
        .{
            .lc = parsed.lc,
            .lp = parsed.lp,
            .pb = parsed.pb,
            .dictionary_size = dictionary_size,
            .uncompressed_size = expected_size,
        },
        expected_size,
        false,
    );
}

const Properties = struct { lc: u4, lp: u3, pb: u3 };

fn parseProperties(value: u8) Error!Properties {
    if (value >= 225) return error.InvalidLzmaHeader;
    const lc: u4 = @intCast(value % 9);
    const remainder = value / 9;
    const lp: u3 = @intCast(remainder % 5);
    const pb: u3 = @intCast(remainder / 5);
    if (lc + lp > 4) return error.InvalidLzmaHeader;
    return .{ .lc = lc, .lp = lp, .pb = pb };
}

fn decodeRawAlloc(
    allocator: std.mem.Allocator,
    payload: []const u8,
    header: Header,
    max_output_len: usize,
    require_end_marker: bool,
) ![]u8 {
    const declared_size: ?usize = if (header.uncompressed_size) |size|
        std.math.cast(usize, size) orelse return error.OutputLimitExceeded
    else
        null;
    if (declared_size) |size| if (size > max_output_len) return error.OutputLimitExceeded;

    const decode_limit = if (max_output_len == std.math.maxInt(usize)) max_output_len else max_output_len + 1;
    var input: std.Io.Reader = .fixed(payload);
    const params = std.compress.lzma.Decode.Params{
        .properties = .{ .lc = header.lc, .lp = header.lp, .pb = header.pb },
        .dict_size = header.dictionary_size,
        .unpacked_size = if (declared_size) |size| size else null,
    };
    var decompressor = std.compress.lzma.Decompress.initParams(
        &input,
        allocator,
        &.{},
        params,
        decode_limit,
    ) catch |err| return mapInitError(err);
    defer decompressor.deinit();

    const io_limit: std.Io.Limit = if (max_output_len == std.math.maxInt(usize))
        .unlimited
    else
        .limited(decode_limit);
    const decoded = decompressor.reader.allocRemaining(allocator, io_limit) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.StreamTooLong => return error.OutputLimitExceeded,
        error.ReadFailed => return mapDecodeError(decompressor.err),
    };
    errdefer allocator.free(decoded);
    if (decoded.len > max_output_len) return error.OutputLimitExceeded;
    if (declared_size) |size| if (decoded.len != size) return error.SizeMismatch;
    if (require_end_marker and input.seek != payload.len) return error.TrailingData;
    return decoded;
}

const DecodeError = Error || std.mem.Allocator.Error;

fn mapInitError(err: anyerror) DecodeError {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.EndOfStream => error.TruncatedFrame,
        error.Overflow => error.IntegerOverflow,
        else => error.InvalidLzmaStream,
    };
}

fn mapDecodeError(err: ?std.compress.lzma.Decompress.Error) DecodeError {
    return switch (err orelse return error.InvalidLzmaStream) {
        error.OutOfMemory => error.OutOfMemory,
        error.EndOfStream => error.TruncatedFrame,
        error.Overflow => error.IntegerOverflow,
        error.DecompressedSizeMismatch => error.SizeMismatch,
        else => error.InvalidLzmaStream,
    };
}

test "LZMA-Alone decoder handles unknown-size Python streams" {
    const encoded_hex = "5d00008000ffffffffffffffff00341949ee8de9148a6aa5d5e0718be227a7ffffdac50000";
    var encoded: [encoded_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&encoded, encoded_hex);
    const expected = "hello lzma\n" ** 16 ++ "hell";
    const header = try parseHeader(&encoded);
    try std.testing.expectEqual(@as(u32, 8 * 1024 * 1024), header.dictionary_size);
    try std.testing.expectEqual(@as(?u64, null), header.uncompressed_size);

    const decoded = try decodeAlloc(std.testing.allocator, &encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    try std.testing.expectEqual(expected.len, try decodedSize(std.testing.allocator, &encoded));
    var output: [expected.len]u8 = undefined;
    try std.testing.expectEqual(expected.len, try decodeInto(std.testing.allocator, &encoded, &output));
    try std.testing.expectEqualSlices(u8, expected, &output);
    try std.testing.expectError(error.OutputLimitExceeded, decodeAllocLimited(std.testing.allocator, &encoded, expected.len - 1));

    var known_size = encoded;
    std.mem.writeInt(u64, known_size[5..13], expected.len, .little);
    const decoded_known = try decodeAlloc(std.testing.allocator, &known_size);
    defer std.testing.allocator.free(decoded_known);
    try std.testing.expectEqualSlices(u8, expected, decoded_known);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeAllocWithOptions(std.testing.allocator, &encoded, .{ .max_dictionary_size = 1024 * 1024 }),
    );
    try std.testing.expectError(error.OutputTooSmall, decodeInto(std.testing.allocator, &encoded, output[0 .. output.len - 1]));
    try std.testing.expectError(error.TruncatedFrame, decodeAlloc(std.testing.allocator, encoded[0..12]));
}

test "ZIP method 14 LZMA payload decoder uses the caller-known size" {
    const payload_hex = "090405005d0000800000341949ee8de9148a6aa5d6b6b979e10e636f54e7fffff2898000";
    var payload: [payload_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&payload, payload_hex);
    const expected = "hello lzma zip" ** 20;
    var output: [expected.len]u8 = undefined;
    try std.testing.expectEqual(
        expected.len,
        try decodeZipPayloadInto(
            std.testing.allocator,
            &payload,
            expected.len,
            &output,
            16 * 1024 * 1024,
            true,
        ),
    );
    try std.testing.expectEqualSlices(u8, expected, &output);
}
