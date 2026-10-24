const std = @import("std");
const core = @import("../core.zig");
const lzma_encoder = @import("../lzma/encoder.zig");
const chunk_encoder = @import("encoder/chunk.zig");

pub const max_uncompressed_chunk: usize = 65_536;
pub const max_stored_chunk_len = chunk_encoder.max_stored_chunk_len;
pub const max_compressed_payload_len = chunk_encoder.max_compressed_payload_len;
pub const max_compressed_plain_len = chunk_encoder.max_compressed_plain_len;
pub const lzma_property: u8 = 0x5d;
pub const dictionary_property: u8 = 0;
pub const dictionary_size: usize = 4096;
pub const max_dictionary_size: usize = lzma_encoder.max_dictionary_size;
pub const Parser = chunk_encoder.Parser;
pub const Properties = chunk_encoder.Properties;
pub const MatchOptions = chunk_encoder.MatchOptions;
pub const EncodeOptions = chunk_encoder.Options;

/// Return the smallest LZMA2 dictionary property whose advertised size covers
/// `requested_size`. Requests above 65,535 bytes select the LZMA-specific wide
/// matcher rather than widening the repository's shared LZ77 token.
pub fn dictionaryProperty(requested_size: usize) core.Error!u8 {
    if (requested_size < dictionary_size or requested_size > max_dictionary_size)
        return error.InvalidBlockPlan;
    var property: u8 = 0;
    while (property <= 37) : (property += 1)
        if (requested_size <= try dictionarySizeChecked(property)) return property;
    unreachable;
}

fn dictionarySizeChecked(property: u8) core.Error!usize {
    if (property > 37) return error.InvalidBlockPlan;
    const shift: u6 = @intCast(property / 2 + 11);
    const size: u64 = @as(u64, 2 | (property & 1)) << shift;
    return std.math.cast(usize, size) orelse error.IntegerOverflow;
}
fn dictionarySize(property: u8) usize {
    return dictionarySizeChecked(property) catch unreachable;
}

pub fn storedPayloadSize(input_len: usize) core.Error!usize {
    const chunk_count = if (input_len == 0) 0 else 1 + (input_len - 1) / max_uncompressed_chunk;
    const header_size = std.math.mul(usize, chunk_count, 3) catch return error.IntegerOverflow;
    const with_headers = std.math.add(usize, input_len, header_size) catch return error.IntegerOverflow;
    return std.math.add(usize, with_headers, 1) catch return error.IntegerOverflow;
}

/// Append a raw LZMA2 payload made of uncompressed chunks. The output is
/// transactional: allocation failure leaves `out.items` unchanged.
pub fn appendStoredPayload(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
) !usize {
    const encoded_size = try storedPayloadSize(input.len);
    _ = std.math.add(usize, out.items.len, encoded_size) catch return error.IntegerOverflow;
    // Reserve can relocate the ArrayList allocation. Snapshot only the caller's
    // input span when it borrows that allocation, including initialized spare
    // capacity; never read unrelated capacity bytes.
    var owned_input: ?[]u8 = null;
    defer if (owned_input) |bytes| allocator.free(bytes);
    const source = if (try inputOverlapsOutputAllocation(input, out)) blk: {
        const bytes = try allocator.dupe(u8, input);
        owned_input = bytes;
        break :blk bytes;
    } else input;
    try out.ensureUnusedCapacity(allocator, encoded_size);

    const start = out.items.len;
    var offset: usize = 0;
    while (offset < source.len) {
        const chunk_len = @min(max_uncompressed_chunk, source.len - offset);
        out.appendAssumeCapacity(if (offset == 0) 1 else 2);
        var size_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &size_bytes, @intCast(chunk_len - 1), .big);
        out.appendSliceAssumeCapacity(&size_bytes);
        out.appendSliceAssumeCapacity(source[offset..][0..chunk_len]);
        offset += chunk_len;
    }
    out.appendAssumeCapacity(0);
    std.debug.assert(out.items.len - start == encoded_size);
    return encoded_size;
}

fn inputOverlapsOutputAllocation(input: []const u8, out: *const std.ArrayList(u8)) core.Error!bool {
    return chunk_encoder.inputOverlapsOutputAllocation(input, out);
}

/// Append a raw LZMA2 payload whose chunks retain the configured preceding
/// dictionary. Each compressed chunk resets its probability state and
/// properties, while stored fallback chunks preserve the same history.
/// Greedy range coding is used when it beats an uncompressed chunk; otherwise
/// the writer falls back to the stored representation.
pub fn appendCompressedPayload(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
) !usize {
    return appendCompressedPayloadWithDictionarySize(allocator, out, input, dictionary_size);
}

pub fn appendCompressedPayloadWithDictionarySize(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    requested_dictionary_size: usize,
) !usize {
    return appendCompressedPayloadWithOptions(
        allocator,
        out,
        input,
        requested_dictionary_size,
        .greedy,
    );
}

/// Compatibility entrypoint. Null matching controls retain the established
/// greedy/lazy wire; the advanced settings entrypoint accepts every core mode.
pub fn appendCompressedPayloadWithOptions(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    requested_dictionary_size: usize,
    parser: Parser,
) !usize {
    return appendCompressedPayloadWithAdvancedOptions(allocator, out, input, .{ .dictionary_size = requested_dictionary_size, .parser = parser });
}

pub fn appendCompressedPayloadWithAdvancedOptions(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    try options.validate();
    _ = try dictionaryProperty(options.dictionary_size);
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var candidate: std.ArrayList(u8) = .empty;
    defer candidate.deinit(allocator);
    var wide_planner: ?lzma_encoder.WideStreamPlanner = if (!options.advanced() and options.dictionary_size > std.math.maxInt(u16) and input.len != 0)
        try lzma_encoder.WideStreamPlanner.init(allocator, options.dictionary_size, input.len)
    else
        null;
    defer if (wide_planner) |*planner| planner.deinit();
    var state = try chunk_encoder.State.init(options);
    var offset: usize = 0;
    while (offset < input.len) {
        const chunk_len = @min(options.chunk_size, input.len - offset);
        const dictionary_start = offset - @min(offset, options.dictionary_size);
        const plan: ?lzma_encoder.WideStreamPlan = if (wide_planner) |*planner| switch (options.parser) {
            .greedy => try planner.planChunk(input, offset, offset + chunk_len),
            .lazy => try planner.planChunkLazy(input, offset, offset + chunk_len),
            else => unreachable,
        } else null;
        _ = try state.append(allocator, &encoded, &candidate, input[offset..][0..chunk_len], input[dictionary_start..offset], offset, options, plan);
        offset += chunk_len;
    }
    try encoded.append(allocator, 0);
    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

test "raw LZMA2 stored payload splits chunks and terminates" {
    const input = try std.testing.allocator.alloc(u8, max_uncompressed_chunk + 1);
    defer std.testing.allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    const written = try appendStoredPayload(std.testing.allocator, &encoded, input);

    try std.testing.expectEqual(try storedPayloadSize(input.len), written);
    try std.testing.expectEqual(@as(u8, 1), encoded.items[0]);
    try std.testing.expectEqualSlices(u8, &.{ 0xff, 0xff }, encoded.items[1..3]);
    const second = 3 + max_uncompressed_chunk;
    try std.testing.expectEqual(@as(u8, 2), encoded.items[second]);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, encoded.items[second + 1 ..][0..2]);
    try std.testing.expectEqual(@as(u8, 0), encoded.items[encoded.items.len - 1]);
}

test "raw LZMA2 empty stored payload is only an end marker" {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), try appendStoredPayload(std.testing.allocator, &encoded, ""));
    try std.testing.expectEqualSlices(u8, &.{0}, encoded.items);
}

test "LZMA2 dictionary properties round requested sizes upward" {
    const cases = [_]struct { requested: usize, property: u8, advertised: usize }{
        .{ .requested = 4096, .property = 0, .advertised = 4096 },
        .{ .requested = 4097, .property = 1, .advertised = 6144 },
        .{ .requested = 6144, .property = 1, .advertised = 6144 },
        .{ .requested = 6145, .property = 2, .advertised = 8192 },
        .{ .requested = 32 * 1024, .property = 6, .advertised = 32 * 1024 },
        .{ .requested = 48 * 1024, .property = 7, .advertised = 48 * 1024 },
        .{ .requested = 64 * 1024, .property = 8, .advertised = 64 * 1024 },
        .{ .requested = 128 * 1024, .property = 10, .advertised = 128 * 1024 },
        .{ .requested = 256 * 1024, .property = 12, .advertised = 256 * 1024 },
        .{ .requested = 1024 * 1024, .property = 16, .advertised = 1024 * 1024 },
        .{ .requested = 4 * 1024 * 1024, .property = 20, .advertised = 4 * 1024 * 1024 },
        .{ .requested = 8 * 1024 * 1024, .property = 22, .advertised = 8 * 1024 * 1024 },
        .{ .requested = 16 * 1024 * 1024, .property = 24, .advertised = 16 * 1024 * 1024 },
        .{ .requested = 32 * 1024 * 1024, .property = 26, .advertised = 32 * 1024 * 1024 },
        .{ .requested = 64 * 1024 * 1024, .property = 28, .advertised = 64 * 1024 * 1024 },
        .{ .requested = 1024 * 1024 * 1024, .property = 36, .advertised = 1024 * 1024 * 1024 },
        .{ .requested = max_dictionary_size, .property = 37, .advertised = max_dictionary_size },
    };
    for (cases) |case| {
        try std.testing.expectEqual(case.property, try dictionaryProperty(case.requested));
        try std.testing.expectEqual(case.advertised, dictionarySize(case.property));
    }
    try std.testing.expectError(error.InvalidBlockPlan, dictionaryProperty(dictionary_size - 1));
    try std.testing.expectError(error.InvalidBlockPlan, dictionaryProperty(max_dictionary_size + 1));
}

test "raw LZMA2 match compression round trips and falls back for noise" {
    const container = @import("container.zig");
    const repetitive = "literal LZMA2 compression\n" ** 4096;
    var compressed: std.ArrayList(u8) = .empty;
    defer compressed.deinit(std.testing.allocator);
    _ = try appendCompressedPayload(std.testing.allocator, &compressed, repetitive);
    try std.testing.expect(compressed.items[0] >= 0xe0);
    try std.testing.expect(compressed.items.len < repetitive.len);
    const decoded = try container.decode7zPayloadAllocLimited(
        std.testing.allocator,
        compressed.items,
        dictionary_property,
        repetitive.len,
        dictionary_size,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, repetitive, decoded);

    var noise: [4096]u8 = undefined;
    var state: u32 = 0x1234_5678;
    for (&noise) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    var stored: std.ArrayList(u8) = .empty;
    defer stored.deinit(std.testing.allocator);
    _ = try appendCompressedPayload(std.testing.allocator, &stored, &noise);
    try std.testing.expectEqual(@as(u8, 1), stored.items[0]);
    const decoded_noise = try container.decode7zPayloadAllocLimited(
        std.testing.allocator,
        stored.items,
        dictionary_property,
        noise.len,
        4096,
    );
    defer std.testing.allocator.free(decoded_noise);
    try std.testing.expectEqualSlices(u8, &noise, decoded_noise);
}

test "raw LZMA2 consecutive compressed chunks retain probability model" {
    const input = "persistent LZMA2 probability model and recent distances\n" ** 2400;
    try std.testing.expect(input.len > max_uncompressed_chunk);
    inline for (.{ dictionary_size, 128 * 1024 }) |configured_dictionary| {
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(std.testing.allocator);
        _ = try appendCompressedPayloadWithDictionarySize(
            std.testing.allocator,
            &encoded,
            input,
            configured_dictionary,
        );
        try std.testing.expectEqual(@as(u8, 0xe0), encoded.items[0]);
        const first_packed_size = @as(usize, std.mem.readInt(u16, encoded.items[3..5], .big)) + 1;
        const second_chunk = 6 + first_packed_size;
        try std.testing.expectEqual(@as(u8, 0x80), encoded.items[second_chunk]);

        const property = try dictionaryProperty(configured_dictionary);
        const decoded = try @import("container.zig").decode7zPayloadAllocLimited(
            std.testing.allocator,
            encoded.items,
            property,
            input.len,
            dictionarySize(property),
        );
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "raw LZMA2 payload switches safely from compressed to stored chunks" {
    const input = try std.testing.allocator.alloc(u8, max_uncompressed_chunk * 3);
    defer std.testing.allocator.free(input);
    @memset(input[0..max_uncompressed_chunk], 'A');
    var state: u32 = 0x9e37_79b9;
    for (input[max_uncompressed_chunk .. max_uncompressed_chunk * 2]) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    @memset(input[max_uncompressed_chunk * 2 ..], 'B');

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    _ = try appendCompressedPayload(std.testing.allocator, &encoded, input);
    try std.testing.expect(encoded.items[0] >= 0xe0);
    const first_packed_size = @as(usize, std.mem.readInt(u16, encoded.items[3..5], .big)) + 1;
    const second_chunk = 6 + first_packed_size;
    try std.testing.expectEqual(@as(u8, 2), encoded.items[second_chunk]);
    const third_chunk = second_chunk + 3 + max_uncompressed_chunk;
    try std.testing.expectEqual(@as(u8, 0xa0), encoded.items[third_chunk]);

    const decoded = try @import("container.zig").decode7zPayloadAllocLimited(
        std.testing.allocator,
        encoded.items,
        dictionary_property,
        input.len,
        4096,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "raw LZMA2 compressed payload reuses stored chunk dictionary" {
    const input = try std.testing.allocator.alloc(u8, max_uncompressed_chunk + dictionary_size);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x243f_6a88;
    for (input[0..max_uncompressed_chunk]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memcpy(
        input[max_uncompressed_chunk..],
        input[max_uncompressed_chunk - dictionary_size .. max_uncompressed_chunk],
    );

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    _ = try appendCompressedPayload(std.testing.allocator, &encoded, input);
    try std.testing.expectEqual(@as(u8, 1), encoded.items[0]);
    const second_chunk = 3 + max_uncompressed_chunk;
    try std.testing.expectEqual(@as(u8, 0xc0), encoded.items[second_chunk]);
    try std.testing.expect(encoded.items.len + 3000 < try storedPayloadSize(input.len));

    const decoded = try @import("container.zig").decode7zPayloadAllocLimited(
        std.testing.allocator,
        encoded.items,
        dictionary_property,
        input.len,
        dictionary_size,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "raw LZMA2 wide dictionary reaches beyond shared u16 history" {
    const requested_dictionary_size = 128 * 1024;
    const repeated_len = 8192;
    const input = try std.testing.allocator.alloc(u8, max_uncompressed_chunk * 2 + repeated_len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x1319_8a2e;
    for (input[0 .. max_uncompressed_chunk * 2]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memcpy(
        input[max_uncompressed_chunk * 2 ..],
        input[0..repeated_len],
    );

    var default_encoded: std.ArrayList(u8) = .empty;
    defer default_encoded.deinit(std.testing.allocator);
    _ = try appendCompressedPayload(std.testing.allocator, &default_encoded, input);
    var large_encoded: std.ArrayList(u8) = .empty;
    defer large_encoded.deinit(std.testing.allocator);
    _ = try appendCompressedPayloadWithDictionarySize(
        std.testing.allocator,
        &large_encoded,
        input,
        requested_dictionary_size,
    );
    const third_chunk = 2 * (3 + max_uncompressed_chunk);
    try std.testing.expectEqual(@as(u8, 2), default_encoded.items[third_chunk]);
    try std.testing.expectEqual(@as(u8, 0xc0), large_encoded.items[third_chunk]);
    try std.testing.expect(large_encoded.items.len + 7000 < default_encoded.items.len);

    const property = try dictionaryProperty(requested_dictionary_size);
    const decoded = try @import("container.zig").decode7zPayloadAllocLimited(
        std.testing.allocator,
        large_encoded.items,
        property,
        input.len,
        requested_dictionary_size,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "raw LZMA2 dictionary reaches beyond one MiB history" {
    const requested_dictionary_size = 2 * 1024 * 1024;
    const narrow_dictionary_size = 1024 * 1024;
    const repeated_len = 8192;
    const gap_len = 17 * max_uncompressed_chunk;
    const input = try std.testing.allocator.alloc(u8, gap_len + repeated_len);
    defer std.testing.allocator.free(input);
    var state: u32 = 0x243f_6a88;
    for (input[0..gap_len]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memcpy(input[gap_len..], input[0..repeated_len]);

    var narrow: std.ArrayList(u8) = .empty;
    defer narrow.deinit(std.testing.allocator);
    _ = try appendCompressedPayloadWithDictionarySize(
        std.testing.allocator,
        &narrow,
        input,
        narrow_dictionary_size,
    );
    var wide: std.ArrayList(u8) = .empty;
    defer wide.deinit(std.testing.allocator);
    _ = try appendCompressedPayloadWithDictionarySize(
        std.testing.allocator,
        &wide,
        input,
        requested_dictionary_size,
    );
    const final_chunk = 17 * (3 + max_uncompressed_chunk);
    try std.testing.expectEqual(@as(u8, 2), narrow.items[final_chunk]);
    try std.testing.expectEqual(@as(u8, 0xc0), wide.items[final_chunk]);
    try std.testing.expect(wide.items.len + 7000 < narrow.items.len);

    const property = try dictionaryProperty(requested_dictionary_size);
    try std.testing.expectEqual(@as(u8, 18), property);
    const decoded = try @import("container.zig").decode7zPayloadAllocLimited(
        std.testing.allocator,
        wide.items,
        property,
        input.len,
        requested_dictionary_size,
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}
