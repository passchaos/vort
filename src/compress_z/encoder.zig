const std = @import("std");
const core = @import("../core.zig");
const bit_stream = @import("bit_stream.zig");

pub const Error = core.Error || error{InvalidCompressHeader};

pub const EncodeOptions = struct {
    max_code_bits: u5 = 16,
    block_mode: bool = true,
};

const initial_code_bits: u5 = 9;
const clear_code: u16 = 256;
const block_first_code: usize = 257;
const literal_count: usize = 256;

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8, options: EncodeOptions) ![]u8 {
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

/// Append one complete Unix compress stream without changing `out.items` on error.
pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    if (options.max_code_bits < initial_code_bits or options.max_code_bits > 16)
        return error.InvalidCompressHeader;

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encoded.appendSlice(allocator, &.{
        0x1f,
        0x9d,
        @as(u8, options.max_code_bits) | @as(u8, if (options.block_mode) 0x80 else 0),
    });
    if (input.len != 0) try encodePayload(allocator, &encoded, input, options);

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

fn encodePayload(
    allocator: std.mem.Allocator,
    encoded: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !void {
    var writer = bit_stream.Writer.init(allocator, encoded);
    var dictionary = std.AutoHashMap(u32, u16).init(allocator);
    defer dictionary.deinit();

    const code_capacity = @as(usize, 1) << options.max_code_bits;
    const first_code = if (options.block_mode) block_first_code else literal_count;
    // gzip 1.10's unlzw path keeps the initial max-code threshold at 511 even
    // when maxbits is 9. Clear one slot early in that configuration so it
    // reads CLEAR at 9 bits instead of incorrectly attempting a 10-bit code.
    const insertion_limit = if (options.block_mode and options.max_code_bits == initial_code_bits)
        code_capacity - 1
    else
        code_capacity;
    try dictionary.ensureTotalCapacity(@intCast(@min(input.len, code_capacity - first_code)));

    var code_bits = initial_code_bits;
    var next_code = first_code;
    var current_code: u16 = input[0];
    for (input[1..]) |byte| {
        const key = pairKey(current_code, byte);
        if (dictionary.get(key)) |found| {
            current_code = found;
            continue;
        }

        try growCodeWidth(&writer, &code_bits, next_code, options.max_code_bits);
        try writer.writeCode(current_code, code_bits);

        if (next_code < insertion_limit) {
            try dictionary.put(key, @intCast(next_code));
            next_code += 1;
        } else if (options.block_mode) {
            try writer.writeCode(clear_code, code_bits);
            try writer.alignToCodeGroup(code_bits);
            dictionary.clearRetainingCapacity();
            code_bits = initial_code_bits;
            next_code = block_first_code;
        }
        current_code = byte;
    }

    try growCodeWidth(&writer, &code_bits, next_code, options.max_code_bits);
    try writer.writeCode(current_code, code_bits);
}

fn growCodeWidth(writer: *bit_stream.Writer, code_bits: *u5, next_code: usize, max_code_bits: u5) !void {
    if (code_bits.* >= max_code_bits) return;
    if (next_code <= (@as(usize, 1) << code_bits.*)) return;
    try writer.alignToCodeGroup(code_bits.*);
    code_bits.* += 1;
}

fn pairKey(prefix: u16, suffix: u8) u32 {
    return (@as(u32, prefix) << 8) | suffix;
}
