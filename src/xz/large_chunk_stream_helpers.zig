const std = @import("std");
const core = @import("../core.zig");
const raw = @import("lzma2_incremental_encoder.zig");
const stream = @import("incremental_encoder.zig");
const container = @import("container.zig");
const raw_writer = @import("lzma2_writer.zig");

pub const allocator = std.testing.allocator;
pub const large: usize = 2 * 1024 * 1024;

pub fn noise(bytes: []u8) void {
    var seed: u32 = 0x18a73bc5;
    for (bytes) |*byte| {
        seed ^= seed << 13;
        seed ^= seed >> 17;
        seed ^= seed << 5;
        byte.* = @truncate(seed);
    }
}

pub fn rawEncode(encoder: *raw.Encoder, input: []const u8, input_chunk: usize, output_chunk: usize) ![]u8 {
    return encode(raw.Encoder, encoder, input, input_chunk, output_chunk);
}

pub fn xzEncode(encoder: *stream.Encoder, input: []const u8, input_chunk: usize, output_chunk: usize) ![]u8 {
    return encode(stream.Encoder, encoder, input, input_chunk, output_chunk);
}

pub fn feedXz(encoder: *stream.Encoder, output: *std.ArrayList(u8), input: []const u8) !void {
    var scratch: [7]u8 = undefined;
    var position: usize = 0;
    while (position < input.len) {
        const stepped = try checkedStep(encoder, input[position..], &scratch);
        try output.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        position += stepped.progress.input_read;
    }
}

pub fn drainFlush(encoder: *stream.Encoder, output: *std.ArrayList(u8)) !void {
    var scratch: [7]u8 = undefined;
    while (true) {
        const stepped = try checkedStep(encoder, "", &scratch);
        try output.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .need_input) return;
    }
}

fn encode(comptime Encoder: type, encoder: *Encoder, input: []const u8, input_chunk: usize, output_chunk: usize) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var scratch: [8192]u8 = undefined;
    var offset: usize = 0;
    while (offset < input.len) {
        const end = offset + @min(input_chunk, input.len - offset);
        const stepped = try checkedStep(encoder, input[offset..end], scratch[0..output_chunk]);
        try output.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        offset += stepped.progress.input_read;
    }
    encoder.finish();
    while (true) {
        const stepped = try checkedStep(encoder, "", scratch[0..output_chunk]);
        try output.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
    }
    return output.toOwnedSlice(allocator);
}

pub fn checkedStep(encoder: anytype, input: []const u8, output: []u8) !core.StepResult {
    const before = encoder.snapshot();
    @memset(output, 0xa5);
    const result = try encoder.step(input, output);
    const after = encoder.snapshot();
    try std.testing.expect(result.progress.input_read <= input.len);
    try std.testing.expect(result.progress.output_written <= output.len);
    try std.testing.expectEqual(result.progress.input_read, after.input_read - before.input_read);
    try std.testing.expectEqual(result.progress.output_written, after.output_written - before.output_written);
    for (output[result.progress.output_written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    if (@TypeOf(encoder.*) == raw.Encoder) {
        try std.testing.expect(after.buffered_input <= encoder.options.inputGroupSize());
        try std.testing.expect(after.buffered_history <= encoder.options.dictionary_size);
    } else try std.testing.expect(after.buffered_input <= encoder.options.block_size);
    return result;
}

pub fn decodeRaw(bytes: []const u8, plain: []const u8, dictionary_size: usize) !void {
    const decoded = try container.decode7zPayloadAllocLimited(allocator, bytes, try raw_writer.dictionaryProperty(dictionary_size), plain.len, dictionary_size);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);
}

pub const Envelope = struct {
    compressed: usize = 0,
    stored: usize = 0,
    plain: usize = 0,
    largest_plain: usize = 0,
    largest_payload: usize = 0,
    first_control: u8 = 0,
    end: usize = 0,
};

/// Independent LZMA2 envelope reader, using only format byte/bit rules.
pub fn inspect(bytes: []const u8, start: usize, require_end: bool) !Envelope {
    var result: Envelope = .{};
    var position = start;
    var first = true;
    while (position < bytes.len) {
        const control = bytes[position];
        position += 1;
        if (control == 0) {
            result.end = position;
            if (require_end) try std.testing.expectEqual(bytes.len, position);
            return result;
        }
        if (first) result.first_control = control;
        first = false;
        try std.testing.expect(bytes.len - position >= 2);
        if (control == 1 or control == 2) {
            const len = @as(usize, std.mem.readInt(u16, bytes[position..][0..2], .big)) + 1;
            position += 2;
            try std.testing.expect(len <= 65536 and len <= bytes.len - position);
            result.stored += 1;
            result.plain += len;
            result.largest_plain = @max(result.largest_plain, len);
            position += len;
            continue;
        }
        try std.testing.expect(control >= 0x80 and bytes.len - position >= 4);
        const plain = (@as(usize, control & 31) << 16 | std.mem.readInt(u16, bytes[position..][0..2], .big)) + 1;
        const payload = @as(usize, std.mem.readInt(u16, bytes[position + 2 ..][0..2], .big)) + 1;
        position += 4;
        if (control >= 0xc0) {
            try std.testing.expect(position < bytes.len);
            position += 1;
        }
        try std.testing.expect(plain <= large and payload <= 65536 and payload <= bytes.len - position);
        result.compressed += 1;
        result.plain += plain;
        result.largest_plain = @max(result.largest_plain, plain);
        result.largest_payload = @max(result.largest_payload, payload);
        position += payload;
    }
    return error.TestUnexpectedResult;
}
