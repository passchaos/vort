//! Independent fixtures for public LZMA1/LZMA2 encode controls.
//! Legacy bytes were generated from the frozen pre-controls commit c3521442.
//! Never regenerate them from the production implementation under test.
const std = @import("std");

pub const PresetCase = struct {
    level: u32,
    extreme: bool,
    dictionary_size: u32,
    mode: []const u8,
    finder: []const u8,
    nice_len: u16,
    depth: u32,
};

/// Fixed from liblzma 5.8.4 lzma_encoder_presets.c and independently checked
/// against its ABI, header/runtime version 50080042. Extraction helper SHA256:
/// 8fce3a73c82d724a4968fe848c646e4e6c6ee0b9a7bb8ecb844ea71c06e2b918.
/// The test compares every row rather than recomputing the resolver switches.
pub const preset_cases = [_]PresetCase{
    .{ .level = 0, .extreme = false, .dictionary_size = 262144, .mode = "fast", .finder = "hc3", .nice_len = 128, .depth = 4 },
    .{ .level = 1, .extreme = false, .dictionary_size = 1048576, .mode = "fast", .finder = "hc4", .nice_len = 128, .depth = 8 },
    .{ .level = 2, .extreme = false, .dictionary_size = 2097152, .mode = "fast", .finder = "hc4", .nice_len = 273, .depth = 24 },
    .{ .level = 3, .extreme = false, .dictionary_size = 4194304, .mode = "fast", .finder = "hc4", .nice_len = 273, .depth = 48 },
    .{ .level = 4, .extreme = false, .dictionary_size = 4194304, .mode = "normal", .finder = "bt4", .nice_len = 16, .depth = 0 },
    .{ .level = 5, .extreme = false, .dictionary_size = 8388608, .mode = "normal", .finder = "bt4", .nice_len = 32, .depth = 0 },
    .{ .level = 6, .extreme = false, .dictionary_size = 8388608, .mode = "normal", .finder = "bt4", .nice_len = 64, .depth = 0 },
    .{ .level = 7, .extreme = false, .dictionary_size = 16777216, .mode = "normal", .finder = "bt4", .nice_len = 64, .depth = 0 },
    .{ .level = 8, .extreme = false, .dictionary_size = 33554432, .mode = "normal", .finder = "bt4", .nice_len = 64, .depth = 0 },
    .{ .level = 9, .extreme = false, .dictionary_size = 67108864, .mode = "normal", .finder = "bt4", .nice_len = 64, .depth = 0 },
    .{ .level = 0, .extreme = true, .dictionary_size = 262144, .mode = "normal", .finder = "bt4", .nice_len = 273, .depth = 512 },
    .{ .level = 1, .extreme = true, .dictionary_size = 1048576, .mode = "normal", .finder = "bt4", .nice_len = 273, .depth = 512 },
    .{ .level = 2, .extreme = true, .dictionary_size = 2097152, .mode = "normal", .finder = "bt4", .nice_len = 273, .depth = 512 },
    .{ .level = 3, .extreme = true, .dictionary_size = 4194304, .mode = "normal", .finder = "bt4", .nice_len = 192, .depth = 0 },
    .{ .level = 4, .extreme = true, .dictionary_size = 4194304, .mode = "normal", .finder = "bt4", .nice_len = 273, .depth = 512 },
    .{ .level = 5, .extreme = true, .dictionary_size = 8388608, .mode = "normal", .finder = "bt4", .nice_len = 192, .depth = 0 },
    .{ .level = 6, .extreme = true, .dictionary_size = 8388608, .mode = "normal", .finder = "bt4", .nice_len = 273, .depth = 512 },
    .{ .level = 7, .extreme = true, .dictionary_size = 16777216, .mode = "normal", .finder = "bt4", .nice_len = 273, .depth = 512 },
    .{ .level = 8, .extreme = true, .dictionary_size = 33554432, .mode = "normal", .finder = "bt4", .nice_len = 273, .depth = 512 },
    .{ .level = 9, .extreme = true, .dictionary_size = 67108864, .mode = "normal", .finder = "bt4", .nice_len = 273, .depth = 512 },
};

pub fn legacyPlain() [512]u8 {
    var input: [512]u8 = undefined;
    var state: u32 = 0x12345678;
    for (&input, 0..) |*byte, index| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @as(u8, @truncate(state >> 24)) % 7 + 'a';
        if (index >= 256) byte.* = input[(index - 256) % 173];
    }
    return input;
}

pub fn hexBytes(comptime hex: []const u8) [hex.len / 2]u8 {
    var bytes: [hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, hex) catch unreachable;
    return bytes;
}

pub fn expectSentinel(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

/// The caller reuses and poisons its staging buffer after every accepted step.
/// This checks ownership in addition to chunk and output accounting.
pub fn driveEncode(comptime Encoder: type, allocator: std.mem.Allocator, encoder: *Encoder, plain: []const u8, input_chunk: usize, output_chunk: usize) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var input_offset: usize = 0;
    var input_staging: [257]u8 = undefined;
    var output_staging: [31]u8 = undefined;
    var finished = false;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < (plain.len + 1) * 16 + 4096);
        if (input_offset == plain.len and !finished) {
            encoder.finish();
            finished = true;
        }
        const offered_len = @min(input_chunk, plain.len - input_offset);
        @memcpy(input_staging[0..offered_len], plain[input_offset..][0..offered_len]);
        @memset(&output_staging, 0xa5);
        const target_len = if (calls % 5 == 0) 0 else output_chunk;
        const before = if (@hasDecl(Encoder, "snapshot")) encoder.snapshot() else .{ .input_read = encoder.total_input, .output_written = encoder.total_output };
        const stepped = try encoder.step(input_staging[0..offered_len], output_staging[0..target_len]);
        const after = if (@hasDecl(Encoder, "snapshot")) encoder.snapshot() else .{ .input_read = encoder.total_input, .output_written = encoder.total_output };
        try std.testing.expect(stepped.progress.input_read <= offered_len);
        try std.testing.expect(stepped.progress.output_written <= target_len);
        try std.testing.expectEqual(stepped.progress.input_read, after.input_read - before.input_read);
        try std.testing.expectEqual(stepped.progress.output_written, after.output_written - before.output_written);
        try expectSentinel(output_staging[stepped.progress.output_written..]);
        input_offset += stepped.progress.input_read;
        try encoded.appendSlice(allocator, output_staging[0..stepped.progress.output_written]);
        @memset(&input_staging, 0x3c);
        if (stepped.status == .done) {
            try std.testing.expectEqual(plain.len, input_offset);
            try std.testing.expectEqual(plain.len, after.input_read);
            try std.testing.expectEqual(encoded.items.len, after.output_written);
            break;
        }
    }
    return encoded.toOwnedSlice(allocator);
}

pub fn planningPlain() [6144]u8 {
    const seed = legacyPlain();
    var result: [6144]u8 = undefined;
    for (&result, 0..) |*byte, index| byte.* = seed[index % seed.len];
    // Leave a partial final match and a literal tail after the stable prefix.
    @memcpy(result[result.len - 9 ..], "tail:done");
    return result;
}

pub fn widePlain(allocator: std.mem.Allocator) ![]u8 {
    const gap = 66000;
    const repeat_len = 4096;
    const result = try allocator.alloc(u8, gap + repeat_len);
    var state: u32 = 0x91e10da5;
    for (result[0..gap]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memcpy(result[gap..], result[0..repeat_len]);
    return result;
}

pub const len2_plain = "ab0ab1ab2ab3ab4ab5ab6ab7ab8ab9";
pub const short_rep_plain = "abababababXbYbZb";

pub fn mixedPlain(allocator: std.mem.Allocator) ![]u8 {
    const chunk_len = 65536;
    const repeat_len = 512;
    const result = try allocator.alloc(u8, chunk_len + repeat_len);
    var state: u32 = 0xe8b7c4d3;
    for (result[0..chunk_len]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memcpy(result[chunk_len..], result[0..repeat_len]);
    return result;
}

pub const Lzma2Chunks = struct {
    stored: usize = 0,
    compressed: usize = 0,
    uncompressed_size: usize = 0,
    property_count: usize = 0,
    property_byte: ?u8 = null,
    first_compressed_control: ?u8 = null,
};

/// Parse only the LZMA2 chunk envelopes using format byte rules, independently
/// from the production parser and its reset bookkeeping.
pub fn inspectLzma2Chunks(payload: []const u8) !Lzma2Chunks {
    var result: Lzma2Chunks = .{};
    var offset: usize = 0;
    while (offset < payload.len) {
        const control = payload[offset];
        offset += 1;
        if (control == 0) {
            try std.testing.expectEqual(payload.len, offset);
            return result;
        }
        if (control == 1 or control == 2) {
            try std.testing.expect(payload.len - offset >= 2);
            const length = (@as(usize, payload[offset]) << 8 | payload[offset + 1]) + 1;
            offset += 2;
            try std.testing.expect(length <= payload.len - offset);
            offset += length;
            result.stored += 1;
            result.uncompressed_size += length;
            continue;
        }
        try std.testing.expect(control >= 0x80);
        try std.testing.expect(payload.len - offset >= 4);
        const plain_len = (@as(usize, control & 0x1f) << 16 | @as(usize, payload[offset]) << 8 | payload[offset + 1]) + 1;
        const compressed_len = (@as(usize, payload[offset + 2]) << 8 | payload[offset + 3]) + 1;
        offset += 4;
        if (control >= 0xc0) {
            try std.testing.expect(offset < payload.len);
            result.property_count += 1;
            result.property_byte = payload[offset];
            offset += 1;
        }
        try std.testing.expect(compressed_len <= payload.len - offset);
        offset += compressed_len;
        result.compressed += 1;
        result.uncompressed_size += plain_len;
        if (result.first_compressed_control == null) result.first_compressed_control = control;
    }
    return error.TestUnexpectedResult;
}

pub const lzma_greedy_hex =
    "5d00800000ffffffffffffffff003318c896782a692c14846974654b3af042c8c7204dd7becd97efa96467bcca85fcd3" ++
    "70fc5a17977688f8afbb17f0b48ab73650685ecf5033b7414779407403ca9fcae8257e3822df91bae48df818524feef0" ++
    "c7a24679eaae07079504e71cffad774f75f38b5c1644ac66fc23310a1f0b8e0704be1ec2d113b07b3b56a81c47d2e720" ++
    "a68a22266f4f510d65a5d1174b97161d41b0d4d51d84a7d39ee9a71e8bfdb3739bd4856fd4e2f3fd99ca24";

pub const lzma_lazy_hex =
    "5d00800000ffffffffffffffff003318c896782a692c14846974654b3af042c8c7204dd7becd97efa96467bcca85fcd3" ++
    "70fc5a17977688f8afbb17f0b48ab73650685ecf5033b7414779407403ca9fcae8257e3822df91bae48df817de32e18f" ++
    "f1179d708fa48dd92b241a0c98b1a2d0123b860ad444f3b1a6939426a53ba77f3757385be58962bf04067b158c744cc5" ++
    "8c41862cf9480056c085e3dfe447d7bd01404014ded3caac63e78e9c10625616d4df8e60ae6d8bfcb4eba2";

pub const xz_greedy_hex =
    "fd377a585a000004e6d6b4460200210100000000372797d6e001ff00a85d003318c896782a692c14846974654b3af042" ++
    "c8c7204dd7becd97efa96467bcca85fcd370fc5a17977688f8afbb17f0b48ab73650685ecf5033b7414779407403ca9f" ++
    "cae8257e3822df91bae48df818524feef0c7a24679eaae07079504e71cffad774f75f38b5c1644ac66fc23310a1f0b8e" ++
    "0704be1ec2d113b07b3b56a81c47d2e720a68a22266f4f510d65a5d1174b97161d41b0d4d51d84a7d39ee9a71e8bfdb3" ++
    "739bd48335b4720040594ab9a479576d0001c4018004000028bf1c9eb1c467fb020000000004595a";

pub const xz_lazy_hex =
    "fd377a585a000004e6d6b4460200210100000000372797d6e001ff00a85d003318c896782a692c14846974654b3af042" ++
    "c8c7204dd7becd97efa96467bcca85fcd370fc5a17977688f8afbb17f0b48ab73650685ecf5033b7414779407403ca9f" ++
    "cae8257e3822df91bae48df817de32e18ff1179d708fa48dd92b241a0c98b1a2d0123b860ad444f3b1a6939426a53ba7" ++
    "7f3757385be58962bf04067b158c744cc58c41862cf9480056c085e3dfe447d7bd01404014ded3caac63e78e9c106256" ++
    "16d4df8b5205290040594ab9a479576d0001c4018004000028bf1c9eb1c467fb020000000004595a";
pub const lzma_greedy_5000_hex =
    "5d88130000ffffffffffffffff003318c896782a692c14846974654b3af042c8c7204dd7becd97efa96467bcca85fcd3" ++
    "70fc5a17977688f8afbb17f0b48ab73650685ecf5033b7414779407403ca9fcae8257e3822df91bae48df818524feef0" ++
    "c7a24679eaae07079504e71cffad774f75f38b5c1644ac66fc23310a1f0b8e0704be1ec2d113b07b3b56a81c47d2e720" ++
    "a68a22266f4f510d65a5d1174b97161d41b0d4d51d84a7d39ee9a71e8bfdb3739bd4856fd4e2f3fd99ca24";

pub const lzma_lazy_5000_hex =
    "5d88130000ffffffffffffffff003318c896782a692c14846974654b3af042c8c7204dd7becd97efa96467bcca85fcd3" ++
    "70fc5a17977688f8afbb17f0b48ab73650685ecf5033b7414779407403ca9fcae8257e3822df91bae48df817de32e18f" ++
    "f1179d708fa48dd92b241a0c98b1a2d0123b860ad444f3b1a6939426a53ba77f3757385be58962bf04067b158c744cc5" ++
    "8c41862cf9480056c085e3dfe447d7bd01404014ded3caac63e78e9c10625616d4df8e60ae6d8bfcb4eba2";
