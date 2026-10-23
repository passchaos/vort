const std = @import("std");
const container = @import("../container.zig");
const writer = @import("../lzma2_writer.zig");

test "LZMA2 one shot public error boundary excludes internal raw decoder errors" {
    const Public = struct {
        fn known(gpa: std.mem.Allocator, input: []const u8) (container.Error || std.mem.Allocator.Error)![]u8 {
            return container.decode7zPayloadAllocLimited(gpa, input, 0, 1, 4096);
        }
        fn unknown(gpa: std.mem.Allocator, input: []const u8) (container.Error || std.mem.Allocator.Error)![]u8 {
            return container.decode7zPayloadAllocUnknownSizeLimited(gpa, input, 0, 1, 4096);
        }
    };
    const input = [_]u8{ 1, 0, 0, 'a', 0 };
    const known = try Public.known(std.testing.allocator, &input);
    defer std.testing.allocator.free(known);
    const unknown = try Public.unknown(std.testing.allocator, &input);
    defer std.testing.allocator.free(unknown);
    try std.testing.expectEqualStrings("a", known);
    try std.testing.expectEqualStrings("a", unknown);
}

fn encode(payload: []const u8, dictionary_size: usize) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(std.testing.allocator);
    _ = try writer.appendCompressedPayloadWithDictionarySize(std.testing.allocator, &encoded, payload, dictionary_size);
    return encoded.toOwnedSlice(std.testing.allocator);
}

fn decode(encoded: []const u8, property: u8, expected: []const u8) !void {
    const output = try container.decode7zPayloadAllocLimited(std.testing.allocator, encoded, property, expected.len, std.math.maxInt(usize));
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualSlices(u8, expected, output);
    const unknown = try container.decode7zPayloadAllocUnknownSizeLimited(std.testing.allocator, encoded, property, expected.len, std.math.maxInt(usize));
    defer std.testing.allocator.free(unknown);
    try std.testing.expectEqualSlices(u8, expected, unknown);
}

fn readFixture(comptime name: []const u8) ![]u8 {
    const hex = std.mem.trim(u8, @embedFile(name), " \r\n");
    const bytes = try std.testing.allocator.alloc(u8, hex.len / 2);
    errdefer std.testing.allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, hex);
    return bytes;
}

test "LZMA2 one shot enforces the declared dictionary window in raw and XZ block paths" {
    var payload: [16384]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x2586_bc71);
    random.random().bytes(payload[0..8192]);
    @memcpy(payload[8192..], payload[0..8192]);
    const encoded = try encode(&payload, 8192);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded[0] >= 0xe0);
    try decode(encoded, 2, &payload);
    try std.testing.expectError(error.InvalidXzStream, container.decode7zPayloadAllocLimited(std.testing.allocator, encoded, 0, payload.len, std.math.maxInt(usize)));
    try std.testing.expectError(error.InvalidXzStream, container.decode7zPayloadAllocUnknownSizeLimited(std.testing.allocator, encoded, 0, payload.len, std.math.maxInt(usize)));

    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(std.testing.allocator);
    try body.appendSlice(std.testing.allocator, encoded);
    while ((12 + body.items.len) % 4 != 0) try body.append(std.testing.allocator, 0);
    var header: container.BlockHeader = .{ .end_offset = 12, .header_size = 12, .packed_size = null, .unpacked_size = payload.len, .dictionary_size = 8192 };
    const block = try container.decodeIncrementalBlockAlloc(std.testing.allocator, header, body.items, .none, payload.len);
    defer block.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, &payload, block.decoded);
    header.dictionary_size = 4096;
    try std.testing.expectError(error.InvalidXzStream, container.decodeIncrementalBlockAlloc(std.testing.allocator, header, body.items, .none, payload.len));
}

test "LZMA2 one shot shares reset controls empty and independent liblzma fixtures" {
    const empty = [_]u8{0};
    try decode(&empty, 0, "");
    const payload = [_]u8{ 1, 2, 3, 4 } ** 64;
    const original = try encode(&payload, 4096);
    defer std.testing.allocator.free(original);
    const end = original.len - 1;
    for ([_]u8{ 0xa0, 0xc0, 0xe0 }) |control| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(std.testing.allocator);
        try encoded.appendSlice(std.testing.allocator, original[0..end]);
        try encoded.append(std.testing.allocator, control | (original[0] & 31));
        try encoded.appendSlice(std.testing.allocator, original[1..5]);
        if (control >= 0xc0) try encoded.append(std.testing.allocator, original[5]);
        try encoded.appendSlice(std.testing.allocator, original[6..]);
        try decode(encoded.items, 0, &(payload ++ payload));
    }
    const fixture_hex = std.mem.trim(u8, @embedFile("two_mib.hex"), " \r\n");
    const fixture = try std.testing.allocator.alloc(u8, fixture_hex.len / 2);
    defer std.testing.allocator.free(fixture);
    _ = try std.fmt.hexToBytes(fixture, fixture_hex);
    const output = try container.decode7zPayloadAllocLimited(std.testing.allocator, fixture, 0, 2 * 1024 * 1024, 4096);
    defer std.testing.allocator.free(output);
    const pattern = "LZMA2 progressive symbols and bounded dictionary\n";
    for (output, 0..) |byte, index| try std.testing.expectEqual(pattern[index % pattern.len], byte);
}

test "LZMA2 one shot validates range termination and exact packed boundaries" {
    const payload = "range termination invariants\n" ** 128;
    const encoded = try encode(payload, 4096);
    defer std.testing.allocator.free(encoded);
    const body_end = encoded.len - 1;
    var corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[body_end - 1] ^= 1;
    try std.testing.expectError(error.InvalidXzStream, container.decode7zPayloadAllocLimited(std.testing.allocator, corrupt, 0, payload.len, 4096));
    const packed_len = std.mem.readInt(u16, encoded[3..5], .big);
    @memcpy(corrupt, encoded);
    std.mem.writeInt(u16, corrupt[3..5], packed_len - 1, .big);
    try std.testing.expectError(error.SizeMismatch, container.decode7zPayloadAllocLimited(std.testing.allocator, corrupt, 0, payload.len, 4096));
    const shortened = try std.mem.concat(std.testing.allocator, u8, &.{ corrupt[0 .. body_end - 1], corrupt[body_end..] });
    defer std.testing.allocator.free(shortened);
    try std.testing.expectError(error.InvalidXzStream, container.decode7zPayloadAllocLimited(std.testing.allocator, shortened, 0, payload.len, 4096));
    try std.testing.expectError(error.TruncatedFrame, container.decode7zPayloadAllocLimited(std.testing.allocator, encoded[0..body_end], 0, payload.len, 4096));
}

test "LZMA2 one shot allocation failure matrix releases raw state and exact output" {
    // Independent liblzma chunks change probability contexts 0 -> 4 -> 4 -> 3,
    // including same-size property resets and replacement allocation failures.
    const payload = ("lc lp pb reset invariants\n" ** 8) ** 4;
    const encoded = try readFixture("reset_properties.hex");
    defer std.testing.allocator.free(encoded);
    const Check = struct {
        fn run(allocator: std.mem.Allocator, input: []const u8, expected: []const u8) !void {
            const output = try container.decode7zPayloadAllocLimited(allocator, input, 0, expected.len, 4096);
            defer allocator.free(output);
            try std.testing.expectEqualSlices(u8, expected, output);
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Check.run, .{ encoded, payload });
}
