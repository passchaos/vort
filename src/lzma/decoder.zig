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

pub const MicroDecodeOptions = struct {
    dictionary_size: u32 = 8 * 1024 * 1024,
    max_output_len: usize = std.math.maxInt(usize),
    /// Decode a prefix without requiring range-code EOF or complete matches.
    allow_partial: bool = false,
};

const alone_header_len: usize = 13;
const max_lzma_dictionary_size: u32 = (1 << 30) + (1 << 29);

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

pub fn decodeMicroInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    dictionary_size: u32,
) !void {
    const decoded = try decodeMicroAllocWithOptions(allocator, input, output.len, .{
        .dictionary_size = dictionary_size,
        .max_output_len = output.len,
    });
    defer allocator.free(decoded);
    @memcpy(output, decoded);
}

pub fn decodeMicroAllocExactSize(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
    dictionary_size: u32,
) ![]u8 {
    return decodeMicroAllocWithOptions(allocator, input, expected_size, .{
        .dictionary_size = dictionary_size,
        .max_output_len = expected_size,
    });
}

pub fn decodeMicroAllocLimited(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
    dictionary_size: u32,
    max_output_len: usize,
) ![]u8 {
    return decodeMicroAllocWithOptions(allocator, input, expected_size, .{
        .dictionary_size = dictionary_size,
        .max_output_len = max_output_len,
    });
}

pub fn decodeMicroAllocWithOptions(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
    options: MicroDecodeOptions,
) ![]u8 {
    if (expected_size > options.max_output_len) return error.OutputLimitExceeded;
    if (options.dictionary_size < 4096 or options.dictionary_size > max_lzma_dictionary_size)
        return error.OutputLimitExceeded;
    if (input.len < 5) return error.TruncatedFrame;
    const properties = try parseProperties(~input[0]);
    var input_reader: std.Io.Reader = .fixed(input[5..]);
    var range_decoder = std.compress.lzma.RangeDecoder{
        .range = std.math.maxInt(u32),
        .code = std.mem.readInt(u32, input[1..5], .big),
    };
    var decoder = std.compress.lzma.Decode.init(allocator, .{
        .lc = properties.lc,
        .lp = properties.lp,
        .pb = properties.pb,
    }) catch |err| return mapInitError(err);
    defer decoder.deinit(allocator);
    var dictionary = CircularBuffer.init(options.dictionary_size, expected_size);
    dictionary.allow_partial = options.allow_partial;
    defer dictionary.deinit(allocator);
    var output = std.Io.Writer.Allocating.init(allocator);
    defer output.deinit();

    while (dictionary.len < expected_size) {
        var bytes_read: u64 = 0;
        switch (decoder.process(
            &input_reader,
            &output,
            &dictionary,
            &range_decoder,
            &bytes_read,
        ) catch |err| switch (err) {
            error.OutputLimitExceeded => return error.SizeMismatch,
            else => |decode_error| return mapProcessError(decode_error),
        }) {
            .more => {},
            .finished => return error.InvalidLzmaStream,
        }
    }

    const decoded = try output.toOwnedSlice();
    errdefer allocator.free(decoded);
    if (decoded.len != expected_size) return error.SizeMismatch;
    if (!options.allow_partial) {
        if (!range_decoder.isFinished()) return error.InvalidLzmaStream;
        if (input_reader.seek != input.len - 5) return error.TrailingData;
    }
    return decoded;
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
        false,
    );
}

/// Decode a marker-terminated raw LZMA1 payload when the unpacked size is
/// carried inside a surrounding container only implicitly. The five 7z-style
/// property bytes still provide lc/lp/pb and dictionary size.
pub fn decode7zPayloadAllocUnknownSizeLimited(
    allocator: std.mem.Allocator,
    payload: []const u8,
    properties: []const u8,
    max_output_len: usize,
    max_dictionary_size: usize,
) ![]u8 {
    if (properties.len != 5) return error.InvalidLzmaHeader;
    const parsed = try parseProperties(properties[0]);
    const dictionary_size = @max(
        @as(u32, 4096),
        std.mem.readInt(u32, properties[1..5], .little),
    );
    if (dictionary_size > max_dictionary_size)
        return error.OutputLimitExceeded;
    return decodeRawAlloc(
        allocator,
        payload,
        .{
            .lc = parsed.lc,
            .lp = parsed.lp,
            .pb = parsed.pb,
            .dictionary_size = dictionary_size,
            .uncompressed_size = null,
        },
        max_output_len,
        true,
        true,
    );
}

/// Decode the headerless LZMA1 stream stored in a CHD v5 hunk. CHD fixes the
/// properties to lc/lp/pb=3/0/2 and carries both dictionary and output sizes
/// out of band. Every encoded byte belongs to exactly one hunk, so trailing
/// bytes are rejected even though an LZMA end marker is optional.
pub fn decodeChdPayloadAllocExactSize(
    allocator: std.mem.Allocator,
    payload: []const u8,
    expected_size: usize,
    dictionary_size: u32,
) ![]u8 {
    if (dictionary_size < 4096 or dictionary_size > max_lzma_dictionary_size)
        return error.OutputLimitExceeded;
    return decodeRawAlloc(
        allocator,
        payload,
        .{
            .lc = 3,
            .lp = 0,
            .pb = 2,
            .dictionary_size = dictionary_size,
            .uncompressed_size = expected_size,
        },
        expected_size,
        false,
        true,
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
    require_full_input: bool,
) ![]u8 {
    const declared_size: ?usize = if (header.uncompressed_size) |size|
        std.math.cast(usize, size) orelse return error.OutputLimitExceeded
    else
        null;
    if (declared_size) |size| if (size > max_output_len) return error.OutputLimitExceeded;

    var input: std.Io.Reader = .fixed(payload);
    var range_decoder = std.compress.lzma.RangeDecoder.init(&input) catch |err|
        return mapInitError(err);
    var decoder = std.compress.lzma.Decode.init(allocator, .{
        .lc = header.lc,
        .lp = header.lp,
        .pb = header.pb,
    }) catch |err| return mapInitError(err);
    defer decoder.deinit(allocator);
    const decode_output_limit = declared_size orelse max_output_len;
    var dictionary = CircularBuffer.init(header.dictionary_size, decode_output_limit);
    defer dictionary.deinit(allocator);
    var output = std.Io.Writer.Allocating.init(allocator);
    defer output.deinit();

    var saw_end_marker = false;
    while (true) {
        if (declared_size) |size| {
            if (dictionary.len == size) break;
        }
        var bytes_read: u64 = 0;
        switch (decoder.process(
            &input,
            &output,
            &dictionary,
            &range_decoder,
            &bytes_read,
        ) catch |err| switch (err) {
            error.OutputLimitExceeded => if (declared_size != null)
                return error.SizeMismatch
            else
                return error.OutputLimitExceeded,
            else => |decode_error| return mapProcessError(decode_error),
        }) {
            .more => {},
            .finished => {
                saw_end_marker = true;
                break;
            },
        }
    }

    const decoded = try output.toOwnedSlice();
    errdefer allocator.free(decoded);
    if (decoded.len > max_output_len) return error.OutputLimitExceeded;
    if (declared_size) |size| if (decoded.len != size) return error.SizeMismatch;
    if (require_end_marker and !saw_end_marker) return error.InvalidLzmaStream;
    if (require_full_input and input.seek != payload.len) return error.TrailingData;
    return decoded;
}

pub const CircularBuffer = struct {
    bytes: std.ArrayList(u8) = .empty,
    dictionary_size: usize,
    output_limit: usize,
    cursor: usize = 0,
    len: usize = 0,
    allow_partial: bool = false,

    pub fn init(dictionary_size: usize, output_limit: usize) CircularBuffer {
        return .{
            .dictionary_size = dictionary_size,
            .output_limit = output_limit,
        };
    }

    pub fn deinit(self: *CircularBuffer, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
    }

    pub fn lastOr(self: CircularBuffer, default: u8) u8 {
        if (self.len == 0) return default;
        const index = (self.dictionary_size + self.cursor - 1) % self.dictionary_size;
        return self.bytes.items[index];
    }

    pub fn lastN(self: CircularBuffer, distance: usize) !u8 {
        if (distance == 0 or distance > self.dictionary_size or distance > self.len)
            return error.CorruptInput;
        const index = (self.dictionary_size + self.cursor - distance) % self.dictionary_size;
        return self.bytes.items[index];
    }

    pub fn appendLiteral(
        self: *CircularBuffer,
        allocator: std.mem.Allocator,
        byte: u8,
        writer: *std.Io.Writer,
    ) !void {
        if (self.len >= self.output_limit) return error.OutputLimitExceeded;
        if (self.cursor < self.bytes.items.len) {
            self.bytes.items[self.cursor] = byte;
        } else {
            try self.bytes.append(allocator, byte);
        }
        try writer.writeByte(byte);
        self.cursor += 1;
        if (self.cursor == self.dictionary_size) self.cursor = 0;
        self.len += 1;
    }

    pub fn appendLz(
        self: *CircularBuffer,
        allocator: std.mem.Allocator,
        length: usize,
        distance: usize,
        writer: *std.Io.Writer,
    ) !void {
        if (distance == 0 or distance > self.dictionary_size or distance > self.len)
            return error.CorruptInput;
        const remaining = self.output_limit -| self.len;
        if (!self.allow_partial and length > remaining) return error.OutputLimitExceeded;
        for (0..@min(length, remaining)) |_| {
            const byte = try self.lastN(distance);
            try self.appendLiteral(allocator, byte, writer);
        }
    }
};

const DecodeError = Error || std.mem.Allocator.Error;

fn mapInitError(err: anyerror) DecodeError {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.EndOfStream => error.TruncatedFrame,
        error.Overflow => error.IntegerOverflow,
        else => error.InvalidLzmaStream,
    };
}

fn mapProcessError(err: anyerror) DecodeError {
    return switch (err) {
        error.OutOfMemory, error.WriteFailed => error.OutOfMemory,
        error.EndOfStream => error.TruncatedFrame,
        error.Overflow => error.IntegerOverflow,
        error.OutputLimitExceeded => error.OutputLimitExceeded,
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

test "MicroLZMA exact-size decoder handles pinned XZ Utils stream" {
    const allocator = std.testing.allocator;
    const encoded_text = @embedFile("testdata/microlzma-small.bin.b64");
    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const encoded = try allocator.alloc(
        u8,
        base64.calcSizeUpperBound(encoded_text.len),
    );
    defer allocator.free(encoded);
    const encoded_len = try base64.decode(encoded, encoded_text);
    const expected = @embedFile("../lzms/testdata/lzms-small.txt");
    try std.testing.expectEqual(@as(u8, ~@as(u8, 0x5d)), encoded[0]);
    const decoded = try decodeMicroAllocExactSize(
        allocator,
        encoded[0..encoded_len],
        expected.len,
        32 * 1024,
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(expected, decoded);
    @memset(decoded, 0);
    try decodeMicroInto(
        allocator,
        encoded[0..encoded_len],
        decoded,
        32 * 1024,
    );
    try std.testing.expectEqualStrings(expected, decoded);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeMicroAllocLimited(
            allocator,
            encoded[0..encoded_len],
            expected.len,
            32 * 1024,
            expected.len - 1,
        ),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        decodeMicroAllocExactSize(
            allocator,
            encoded[0..encoded_len],
            expected.len,
            1024,
        ),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        decodeMicroAllocExactSize(allocator, encoded[0..4], expected.len, 32 * 1024),
    );

    const bad_properties = try allocator.dupe(u8, encoded[0..encoded_len]);
    defer allocator.free(bad_properties);
    bad_properties[0] = ~@as(u8, 0x6f);
    try std.testing.expectError(
        error.InvalidLzmaHeader,
        decodeMicroAllocExactSize(allocator, bad_properties, expected.len, 32 * 1024),
    );
    const trailing = try allocator.alloc(u8, encoded_len + 1);
    defer allocator.free(trailing);
    @memcpy(trailing[0..encoded_len], encoded[0..encoded_len]);
    trailing[encoded_len] = 0;
    try std.testing.expectError(
        error.TrailingData,
        decodeMicroAllocExactSize(allocator, trailing, expected.len, 32 * 1024),
    );
}
