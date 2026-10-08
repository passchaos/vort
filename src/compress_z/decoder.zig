const std = @import("std");
const core = @import("../core.zig");
const bit_stream = @import("bit_stream.zig");

pub const Error = core.Error || error{
    InvalidCompressHeader,
    InvalidCompressStream,
};

pub const Header = struct {
    max_code_bits: u5,
    block_mode: bool,
};

const initial_code_bits: u5 = 9;
const clear_code: u16 = 256;
const block_first_code: usize = 257;
const literal_count: usize = 256;

const Output = union(enum) {
    fixed: struct {
        bytes: []u8,
        written: usize = 0,
    },
    dynamic: struct {
        allocator: std.mem.Allocator,
        bytes: *std.ArrayList(u8),
        limit: usize,
    },
    count: struct {
        written: usize = 0,
        limit: usize,
    },

    fn len(self: Output) usize {
        return switch (self) {
            .fixed => |state| state.written,
            .dynamic => |state| state.bytes.items.len,
            .count => |state| state.written,
        };
    }

    fn appendReversed(self: *Output, reversed: []const u8) !void {
        switch (self.*) {
            .fixed => |*state| {
                const end = std.math.add(usize, state.written, reversed.len) catch
                    return error.OutputTooSmall;
                if (end > state.bytes.len) return error.OutputTooSmall;
                for (reversed, 0..) |_, index|
                    state.bytes[state.written + index] = reversed[reversed.len - 1 - index];
                state.written = end;
            },
            .dynamic => |*state| {
                const end = std.math.add(usize, state.bytes.items.len, reversed.len) catch
                    return error.OutputLimitExceeded;
                if (end > state.limit) return error.OutputLimitExceeded;
                try state.bytes.ensureUnusedCapacity(state.allocator, reversed.len);
                var index = reversed.len;
                while (index != 0) {
                    index -= 1;
                    state.bytes.appendAssumeCapacity(reversed[index]);
                }
            },
            .count => |*state| {
                const end = std.math.add(usize, state.written, reversed.len) catch
                    return error.OutputLimitExceeded;
                if (end > state.limit) return error.OutputLimitExceeded;
                state.written = end;
            },
        }
    }
};

pub fn parseHeader(input: []const u8) Error!Header {
    if (input.len < 3) return error.TruncatedFrame;
    if (input[0] != 0x1f or input[1] != 0x9d) return error.InvalidMagic;
    const flags = input[2];
    if (flags & 0x60 != 0) return error.InvalidCompressHeader;
    const max_code_bits: u5 = @intCast(flags & 0x1f);
    if (max_code_bits < initial_code_bits or max_code_bits > 16)
        return error.InvalidCompressHeader;
    return .{
        .max_code_bits = max_code_bits,
        .block_mode = flags & 0x80 != 0,
    };
}

pub fn decodeInto(allocator: std.mem.Allocator, input: []const u8, output: []u8) !usize {
    var sink = Output{ .fixed = .{ .bytes = output } };
    try decode(allocator, input, &sink);
    return sink.len();
}

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return decodeAllocLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodeAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    var sink = Output{ .dynamic = .{
        .allocator = allocator,
        .bytes = &bytes,
        .limit = max_output_len,
    } };
    try decode(allocator, input, &sink);
    return bytes.toOwnedSlice(allocator);
}

pub fn decodedSize(allocator: std.mem.Allocator, input: []const u8) !usize {
    return decodedSizeLimited(allocator, input, std.math.maxInt(usize));
}

pub fn decodedSizeLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) !usize {
    var sink = Output{ .count = .{ .limit = max_output_len } };
    try decode(allocator, input, &sink);
    return sink.len();
}

fn decode(allocator: std.mem.Allocator, input: []const u8, output: *Output) !void {
    const header = try parseHeader(input);
    const code_capacity = @as(usize, 1) << header.max_code_bits;
    const prefixes = try allocator.alloc(u16, code_capacity);
    defer allocator.free(prefixes);
    const suffixes = try allocator.alloc(u8, code_capacity);
    defer allocator.free(suffixes);
    const reversed = try allocator.alloc(u8, code_capacity);
    defer allocator.free(reversed);
    for (suffixes[0..literal_count], 0..) |*suffix, value| suffix.* = @intCast(value);

    var reader = bit_stream.Reader.init(input[3..]);
    var code_bits = initial_code_bits;
    var max_code = if (code_bits == header.max_code_bits)
        code_capacity
    else
        (@as(usize, 1) << code_bits) - 1;
    var next_code: usize = if (header.block_mode) block_first_code else literal_count;
    var previous_code: ?u16 = null;
    var first_byte: u8 = 0;

    while (reader.canRead(code_bits)) {
        if (code_bits < header.max_code_bits and next_code > max_code) {
            try reader.alignToCodeGroup(code_bits);
            code_bits += 1;
            max_code = if (code_bits == header.max_code_bits)
                code_capacity
            else
                (@as(usize, 1) << code_bits) - 1;
            if (!reader.canRead(code_bits)) return error.TruncatedFrame;
        }

        const encoded_code = try reader.readCode(code_bits);
        if (header.block_mode and encoded_code == clear_code) {
            if (previous_code == null) return error.InvalidCompressStream;
            try reader.alignToCodeGroup(code_bits);
            code_bits = initial_code_bits;
            max_code = if (code_bits == header.max_code_bits)
                code_capacity
            else
                (@as(usize, 1) << code_bits) - 1;
            next_code = block_first_code;
            previous_code = null;
            continue;
        }

        if (previous_code == null) {
            if (encoded_code >= literal_count) return error.InvalidCompressStream;
            first_byte = @intCast(encoded_code);
            reversed[0] = first_byte;
            try output.appendReversed(reversed[0..1]);
            previous_code = encoded_code;
            continue;
        }

        if (encoded_code > next_code or encoded_code >= code_capacity)
            return error.InvalidCompressStream;
        var code = encoded_code;
        var reversed_len: usize = 0;
        if (code == next_code) {
            if (next_code >= code_capacity) return error.InvalidCompressStream;
            reversed[reversed_len] = first_byte;
            reversed_len += 1;
            code = previous_code.?;
        }

        while (code >= literal_count) {
            if (code >= next_code or reversed_len >= reversed.len)
                return error.InvalidCompressStream;
            reversed[reversed_len] = suffixes[code];
            reversed_len += 1;
            code = prefixes[code];
        }
        if (reversed_len >= reversed.len) return error.InvalidCompressStream;
        first_byte = suffixes[code];
        reversed[reversed_len] = first_byte;
        reversed_len += 1;
        try output.appendReversed(reversed[0..reversed_len]);

        if (next_code < code_capacity) {
            prefixes[next_code] = previous_code.?;
            suffixes[next_code] = first_byte;
            next_code += 1;
        }
        previous_code = encoded_code;
    }

    if (reader.remainingBits() >= 8) return error.TruncatedFrame;
}

test "compress .Z header validation and empty stream" {
    const allocator = std.testing.allocator;
    const header = try parseHeader(&.{ 0x1f, 0x9d, 0x90 });
    try std.testing.expectEqual(@as(u5, 16), header.max_code_bits);
    try std.testing.expect(header.block_mode);
    const decoded = try decodeAlloc(allocator, &.{ 0x1f, 0x9d, 0x90 });
    defer allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 0), decoded.len);

    try std.testing.expectError(error.TruncatedFrame, parseHeader(&.{ 0x1f, 0x9d }));
    try std.testing.expectError(error.InvalidMagic, parseHeader(&.{ 0x1f, 0x8b, 0x90 }));
    try std.testing.expectError(error.InvalidCompressHeader, parseHeader(&.{ 0x1f, 0x9d, 0xb0 }));
    try std.testing.expectError(error.InvalidCompressHeader, parseHeader(&.{ 0x1f, 0x9d, 0x88 }));
}
