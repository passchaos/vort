const std = @import("std");
const writer = @import("../writer.zig");
const raw = @import("../lzma2_writer.zig");
const chunk = @import("chunk.zig");
const container = @import("../container.zig");
const allocator = std.testing.allocator;

fn decodeRaw(payload: []const u8, plain: []const u8, dictionary_size: usize) !void {
    const decoded = try container.decode7zPayloadAllocLimited(allocator, payload, try raw.dictionaryProperty(dictionary_size), plain.len, dictionary_size);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);
}
fn options(size: usize) raw.EncodeOptions {
    return .{ .chunk_size = size, .dictionary_size = 128 * 1024, .parser = .fast, .match_options = .{ .finder = .hc4, .nice_len = 32, .depth = 8 } };
}

const Summary = struct { compressed: usize = 0, stored: usize = 0, largest_plain: usize = 0, largest_payload: usize = 0 };
fn summarize(payload: []const u8) !Summary {
    var result: Summary = .{};
    var position: usize = 0;
    while (payload[position] != 0) {
        const control = payload[position];
        const low_plain = @as(usize, std.mem.readInt(u16, payload[position + 1 ..][0..2], .big));
        if (control < 0x80) {
            const plain_len = low_plain + 1;
            try std.testing.expect(control == 1 or control == 2);
            try std.testing.expect(plain_len <= chunk.max_stored_chunk_len);
            result.stored += 1;
            position += 3 + plain_len;
        } else {
            const plain_len = (@as(usize, control & 0x1f) << 16) + low_plain + 1;
            const packed_len = @as(usize, std.mem.readInt(u16, payload[position + 3 ..][0..2], .big)) + 1;
            try std.testing.expect(packed_len <= chunk.max_compressed_payload_len);
            result.compressed += 1;
            result.largest_plain = @max(result.largest_plain, plain_len);
            result.largest_payload = @max(result.largest_payload, packed_len);
            position += 5 + @as(usize, @intFromBool(control >= 0xc0)) + packed_len;
        }
        try std.testing.expect(position < payload.len);
    }
    try std.testing.expectEqual(position + 1, payload.len);
    return result;
}

test "LZMA2 large chunks real two MiB compressed packet and exact tail clipping" {
    const size = chunk.max_compressed_plain_len;
    const input = try allocator.alloc(u8, size + 1);
    defer allocator.free(input);
    const phrase = "large LZMA2 packets preserve real models and dictionaries";
    for (input, 0..) |*byte, index| byte.* = phrase[index % phrase.len];
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    _ = try raw.appendCompressedPayloadWithAdvancedOptions(allocator, &encoded, input, options(size));
    try std.testing.expectEqual(@as(u8, 0xff), encoded.items[0]);
    try std.testing.expectEqual(@as(u16, 0xffff), std.mem.readInt(u16, encoded.items[1..3], .big));
    const summary = try summarize(encoded.items);
    try std.testing.expectEqual(@as(usize, 1), summary.compressed);
    try std.testing.expectEqual(size, summary.largest_plain);
    try std.testing.expectEqual(@as(usize, 1), summary.stored);
    try decodeRaw(encoded.items, input, options(size).dictionary_size);
    const xz = try writer.encodeAlloc(allocator, input, .{ .block_size = size + 1, .chunk_size = size, .dictionary_size = 128 * 1024, .parser = .fast, .match_options = options(size).match_options });
    defer allocator.free(xz);
    const decoded = try container.decodeAlloc(allocator, xz);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "LZMA2 large chunks bounded payload fallback is a complete stored group" {
    const size = chunk.max_compressed_plain_len;
    const input = try allocator.alloc(u8, size);
    defer allocator.free(input);
    var random: u32 = 0x724ec06b;
    for (input) |*byte| {
        random = random *% 1664525 +% 1013904223;
        byte.* = @truncate(random >> 24);
    }
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    _ = try raw.appendCompressedPayloadWithAdvancedOptions(allocator, &encoded, input, .{ .chunk_size = size, .parser = .literal_only });
    const summary = try summarize(encoded.items);
    try std.testing.expectEqual(@as(usize, 0), summary.compressed);
    try std.testing.expectEqual(@as(usize, 32), summary.stored);
    try std.testing.expectEqual(try raw.storedPayloadSize(size), encoded.items.len);
    try std.testing.expectEqual(@as(u8, 1), encoded.items[0]);
    for (1..32) |index| try std.testing.expectEqual(@as(u8, 2), encoded.items[index * (chunk.max_stored_chunk_len + 3)]);
    try decodeRaw(encoded.items, input, raw.dictionary_size);
}

test "LZMA2 large chunks one byte grouping and scalar boundaries precede allocation" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    _ = try raw.appendCompressedPayloadWithAdvancedOptions(allocator, &encoded, "abc", .{ .chunk_size = 1, .parser = .literal_only });
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 0, 'a', 2, 0, 0, 'b', 2, 0, 0, 'c', 0 }, encoded.items);
    var failed = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "prefix");
    for ([_]usize{ 0, chunk.max_compressed_plain_len + 1 }) |invalid| {
        try std.testing.expectError(error.InvalidBlockPlan, raw.appendCompressedPayloadWithAdvancedOptions(failed.allocator(), &output, "x", .{ .chunk_size = invalid }));
        try std.testing.expectEqualStrings("prefix", output.items);
        try std.testing.expectError(error.InvalidBlockPlan, writer.encodeAppend(failed.allocator(), &output, "x", .{ .chunk_size = invalid }));
        try std.testing.expectEqualStrings("prefix", output.items);
    }
    try std.testing.expectEqual(@as(usize, 0), failed.allocated_bytes);
    try std.testing.expectEqual(@as(u8, 37), try raw.dictionaryProperty(1610612736));
    try std.testing.expectError(error.InvalidBlockPlan, raw.dictionaryProperty(1610612737));
}

const AllocationCase = struct {
    pub fn run(a: std.mem.Allocator, input: []const u8) !void {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(a);
        try output.appendSlice(a, "prefix");
        _ = raw.appendCompressedPayloadWithAdvancedOptions(a, &output, input, .{ .chunk_size = chunk.max_compressed_plain_len, .parser = .literal_only }) catch |err| {
            try std.testing.expectEqualStrings("prefix", output.items);
            return err;
        };
    }
};
test "LZMA2 large chunks stored group output allocation failure preserves committed state and alias" {
    const size = chunk.max_stored_chunk_len + 17;
    const input = try allocator.alloc(u8, size);
    defer allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index *% 53 +% 7);
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.ensureTotalCapacityPrecise(allocator, size);
    output.appendSliceAssumeCapacity(input);
    const count = try chunk.appendStored(allocator, &output, output.items, true);
    try std.testing.expectEqual(try chunk.storedGroupSize(size), count);
    try std.testing.expectEqualSlices(u8, input, output.items[0..size]);
    try std.testing.expectEqualSlices(u8, input[0..chunk.max_stored_chunk_len], output.items[size + 3 ..][0..chunk.max_stored_chunk_len]);
    try std.testing.expectEqual(@as(u8, 2), output.items[size + 3 + chunk.max_stored_chunk_len]);
    const state_options = options(chunk.max_compressed_plain_len);
    var state = try chunk.State.init(state_options);
    const before = state;
    var failure = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var empty: std.ArrayList(u8) = .empty;
    defer empty.deinit(allocator);
    try std.testing.expectError(error.OutOfMemory, state.appendUncompressed(failure.allocator(), &empty, input, true));
    try std.testing.expectEqualDeep(before, state);
    try std.testing.expectEqual(@as(usize, 0), empty.items.len);
    try std.testing.checkAllAllocationFailures(allocator, AllocationCase.run, .{input[0..]});
}

test "LZMA2 large chunks working memory errors cannot turn into stored success" {
    const value: raw.EncodeOptions = .{ .chunk_size = chunk.max_compressed_plain_len, .parser = .fast, .match_options = .{ .finder = .bt4, .nice_len = 32, .max_working_memory = 0 } };
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "prefix");
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, raw.appendCompressedPayloadWithAdvancedOptions(allocator, &output, "bounded matcher remains an actual error" ** 8, value));
    try std.testing.expectEqualStrings("prefix", output.items);
    var state = try chunk.State.init(value);
    const before = state;
    var candidate: std.ArrayList(u8) = .empty;
    defer candidate.deinit(allocator);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, state.append(allocator, &output, &candidate, "bounded parser work" ** 8, &.{}, 0, value, null));
    try std.testing.expectEqualDeep(before, state);
    try std.testing.expectEqualStrings("prefix", output.items);
}
