//! Independent frozen XZ/LZMA2 fixtures from commit a549b7a2.
const std = @import("std");
pub const dictionary = @import("../lzma/large_dictionary_contract_helpers.zig");
pub const PresetWire = dictionary.PresetWire;
pub const max_chunk_size: usize = 2097152;
pub const max_stored_chunk_size: usize = 65536;
pub const max_compressed_payload_size: usize = 65536;

pub const Packet = struct {
    control: u8,
    plain_len: usize,
    compressed_len: ?usize,
    properties: ?u8,
    payload_offset: usize,
};

pub const Packets = struct {
    items: std.ArrayList(Packet) = .empty,
    plain_len: usize = 0,
    encoded_len: usize = 0,

    pub fn deinit(self: *Packets, allocator: std.mem.Allocator) void {
        self.items.deinit(allocator);
    }
};

/// Read packet envelopes independently from the production LZMA2 scanner.
/// Stop at the terminator so this works on a container's payload prefix too.
pub fn packets(allocator: std.mem.Allocator, encoded: []const u8) !Packets {
    var result: Packets = .{};
    errdefer result.deinit(allocator);
    var offset: usize = 0;
    while (offset < encoded.len) {
        const control = encoded[offset];
        offset += 1;
        if (control == 0) {
            result.encoded_len = offset;
            return result;
        }
        if (control == 1 or control == 2) {
            try std.testing.expect(encoded.len - offset >= 2);
            const length = (@as(usize, encoded[offset]) << 8 | encoded[offset + 1]) + 1;
            offset += 2;
            try std.testing.expect(length <= encoded.len - offset);
            try result.items.append(allocator, .{ .control = control, .plain_len = length, .compressed_len = null, .properties = null, .payload_offset = offset });
            result.plain_len += length;
            offset += length;
            continue;
        }
        try std.testing.expect(control >= 0x80);
        try std.testing.expect(encoded.len - offset >= 4);
        const plain_len = (@as(usize, control & 0x1f) << 16 | @as(usize, encoded[offset]) << 8 | encoded[offset + 1]) + 1;
        const compressed_len = (@as(usize, encoded[offset + 2]) << 8 | encoded[offset + 3]) + 1;
        offset += 4;
        var properties: ?u8 = null;
        if (control >= 0xc0) {
            try std.testing.expect(offset < encoded.len);
            properties = encoded[offset];
            offset += 1;
        }
        try std.testing.expect(compressed_len <= encoded.len - offset);
        try result.items.append(allocator, .{ .control = control, .plain_len = plain_len, .compressed_len = compressed_len, .properties = properties, .payload_offset = offset });
        result.plain_len += plain_len;
        offset += compressed_len;
    }
    return error.TestUnexpectedResult;
}

pub fn dictionarySize(property: u8) !u32 {
    try std.testing.expect(property <= 40);
    if (property == 40) return std.math.maxInt(u32);
    return @as(u32, 2 | (property & 1)) << @intCast(property / 2 + 11);
}

fn vli(bytes: []const u8, offset: *usize) !u64 {
    var value: u64 = 0;
    var shift: u6 = 0;
    while (true) {
        try std.testing.expect(offset.* < bytes.len and shift < 63);
        const byte = bytes[offset.*];
        offset.* += 1;
        value |= @as(u64, byte & 0x7f) << shift;
        if (byte & 0x80 == 0) return value;
        shift += 7;
    }
}

pub const FirstBlock = struct { dictionary_property: u8, advertised_dictionary_size: u32, payload_offset: usize };

/// Read the first Block Header's filter property. This allocates no dictionary.
pub fn firstBlock(encoded: []const u8) !FirstBlock {
    try std.testing.expect(encoded.len >= 16);
    try std.testing.expectEqualSlices(u8, &.{ 0xfd, '7', 'z', 'X', 'Z', 0 }, encoded[0..6]);
    const block_offset: usize = 12;
    const header_len = (@as(usize, encoded[block_offset]) + 1) * 4;
    try std.testing.expect(header_len >= 8 and header_len <= encoded.len - block_offset);
    const header = encoded[block_offset .. block_offset + header_len - 4];
    const flags = header[1];
    var offset: usize = 2;
    if (flags & 0x40 != 0) _ = try vli(header, &offset);
    if (flags & 0x80 != 0) _ = try vli(header, &offset);
    var property: ?u8 = null;
    for (0..@as(usize, (flags & 3) + 1)) |_| {
        const id = try vli(header, &offset);
        const property_len = try vli(header, &offset);
        try std.testing.expect(property_len <= header.len - offset);
        if (id == 0x21) {
            try std.testing.expectEqual(@as(u64, 1), property_len);
            property = header[offset];
        }
        offset += @intCast(property_len);
    }
    const result = property orelse return error.TestUnexpectedResult;
    return .{ .dictionary_property = result, .advertised_dictionary_size = try dictionarySize(result), .payload_offset = block_offset + header_len };
}

pub fn noise(allocator: std.mem.Allocator, length: usize) ![]u8 {
    const result = try allocator.alloc(u8, length);
    var state: u32 = 0x94d049bb;
    for (result) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    return result;
}

pub fn repetitive(allocator: std.mem.Allocator, length: usize) ![]u8 {
    const result = try allocator.alloc(u8, length);
    const pattern = "LZMA2 large independent payload!\n";
    for (result, 0..) |*byte, index| byte.* = pattern[index % pattern.len];
    return result;
}

pub const PayloadBoundary = struct { plain_len: usize, noise_prefix: usize, payload_len: usize, input_sha256: [32]u8, payload_sha256: [32]u8 };
/// Finished range payloads independently frozen from the a549b7a2 literal core.
pub const payload_boundaries = [_]PayloadBoundary{
    .{ .plain_len = 65537, .noise_prefix = 64614, .payload_len = 65536, .input_sha256 = dictionary.hexBytes("e3255406f3b28fd3bc39826d428612289c450607ec90f6c319808d80bdab7715"), .payload_sha256 = dictionary.hexBytes("8e391ed67c03de5d77805ca98df31f209c8759075f63ac0feea8b6b0b64037be") },
    .{ .plain_len = 65538, .noise_prefix = 64615, .payload_len = 65537, .input_sha256 = dictionary.hexBytes("4c212d743100edb42bf413c09cc9750a19f7b1931c3f603ff59817175acc3231"), .payload_sha256 = dictionary.hexBytes("736c4ae84c5ba10c89ee256717078c9027fbe5af7cfaf2a42a16e5c322214a21") },
};

pub fn payloadBoundaryPlain(allocator: std.mem.Allocator, boundary: PayloadBoundary) ![]u8 {
    const result = try allocator.alloc(u8, boundary.plain_len);
    errdefer allocator.free(result);
    var state: u32 = 0xe18a9463;
    for (result[0..boundary.noise_prefix]) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    @memset(result[boundary.noise_prefix..], 0);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(result, &digest, .{});
    try std.testing.expectEqualSlices(u8, &boundary.input_sha256, &digest);
    return result;
}

pub fn drive(comptime Codec: type, allocator: std.mem.Allocator, state: *Codec, input: []const u8, input_chunk: usize, output_chunk: usize) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    const initial = state.snapshot();
    var input_offset = initial.input_read;
    var finished = initial.finishing;
    var staging_input: [257]u8 = undefined;
    var staging_output: [31]u8 = undefined;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < (input.len + 1) * 16 + 4096);
        if (input_offset == input.len and !finished) {
            state.finish();
            finished = true;
        }
        const take = @min(input_chunk, input.len - input_offset);
        @memcpy(staging_input[0..take], input[input_offset..][0..take]);
        @memset(&staging_output, 0xa5);
        const output_len = if (calls % 5 == 0) 0 else output_chunk;
        const before = state.snapshot();
        const step = try state.step(staging_input[0..take], staging_output[0..output_len]);
        const after = state.snapshot();
        try std.testing.expect(step.progress.input_read <= take and step.progress.output_written <= output_len);
        try std.testing.expectEqual(step.progress.input_read, after.input_read - before.input_read);
        try std.testing.expectEqual(step.progress.output_written, after.output_written - before.output_written);
        for (staging_output[step.progress.output_written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        input_offset += step.progress.input_read;
        try result.appendSlice(allocator, staging_output[0..step.progress.output_written]);
        @memset(&staging_input, 0x3c);
        if (step.status == .done) {
            try std.testing.expectEqual(input.len, input_offset);
            try std.testing.expectEqual(result.items.len, after.output_written - initial.output_written);
            return result.toOwnedSlice(allocator);
        }
    }
}

pub fn decodeRaw(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, dictionary_property: u8) !void {
    const xz = @import("../xz.zig");
    var decoder = try xz.RawLzma2IncrementalDecoder.init(allocator, .{ .dictionary_property = dictionary_property, .max_output_len = expected.len });
    defer decoder.deinit();
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    var finished = false;
    var staging_input: [257]u8 = undefined;
    var staging_output: [31]u8 = undefined;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < (encoded.len + expected.len + 1) * 8 + 4096);
        if (input_offset == encoded.len and !finished) {
            decoder.finish();
            finished = true;
        }
        const take = @min(staging_input.len, encoded.len - input_offset);
        @memcpy(staging_input[0..take], encoded[input_offset..][0..take]);
        @memset(&staging_output, 0xa5);
        const output_len: usize = if (calls % 5 == 0) 0 else staging_output.len;
        const step = try decoder.step(staging_input[0..take], staging_output[0..output_len]);
        try std.testing.expect(step.progress.input_read <= take and step.progress.output_written <= output_len);
        try std.testing.expect(step.progress.output_written <= expected.len - output_offset);
        try std.testing.expectEqualSlices(u8, expected[output_offset..][0..step.progress.output_written], staging_output[0..step.progress.output_written]);
        for (staging_output[step.progress.output_written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
        @memset(&staging_input, 0x3c);
        if (step.status == .done) {
            try std.testing.expectEqual(encoded.len, input_offset);
            try std.testing.expectEqual(expected.len, output_offset);
            return;
        }
    }
}

pub const default_hex =
    "fd377a585a000004e6d6b4460200210100000000372797d6e001ff00a85d003318c896782a692c14846974654b3af042" ++
    "c8c7204dd7becd97efa96467bcca85fcd370fc5a17977688f8afbb17f0b48ab73650685ecf5033b7414779407403ca9f" ++
    "cae8257e3822df91bae48df818524feef0c7a24679eaae07079504e71cffad774f75f38b5c1644ac66fc23310a1f0b8e" ++
    "0704be1ec2d113b07b3b56a81c47d2e720a68a22266f4f510d65a5d1174b97161d41b0d4d51d84a7d39ee9a71e8bfdb3" ++
    "739bd48335b4720040594ab9a479576d0001c4018004000028bf1c9eb1c467fb020000000004595a";

pub const raw_default_hex =
    "e001ff00a85d003318c896782a692c14846974654b3af042c8c7204dd7becd97efa96467bcca85fcd370fc5a17977688" ++
    "f8afbb17f0b48ab73650685ecf5033b7414779407403ca9fcae8257e3822df91bae48df818524feef0c7a24679eaae07" ++
    "079504e71cffad774f75f38b5c1644ac66fc23310a1f0b8e0704be1ec2d113b07b3b56a81c47d2e720a68a22266f4f51" ++
    "0d65a5d1174b97161d41b0d4d51d84a7d39ee9a71e8bfdb3739bd48335b47200";

pub const preset_wires = [_]PresetWire{
    .{ .level = 0, .extreme = false, .hex = "fd377a585a000004e6d6b446020021010c0000008f98419c0100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 1, .extreme = false, .hex = "fd377a585a000004e6d6b4460200210110000000a8708e860100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 2, .extreme = false, .hex = "fd377a585a000004e6d6b446020021011200000023b8872c0100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 3, .extreme = false, .hex = "fd377a585a000004e6d6b4460200210114000000ffe7ec090100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 4, .extreme = false, .hex = "fd377a585a000004e6d6b4460200210114000000ffe7ec090100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 5, .extreme = false, .hex = "fd377a585a000004e6d6b4460200210116000000742fe5a30100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 6, .extreme = false, .hex = "fd377a585a000004e6d6b4460200210116000000742fe5a30100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 7, .extreme = false, .hex = "fd377a585a000004e6d6b446020021011800000047583a430100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 8, .extreme = false, .hex = "fd377a585a000004e6d6b446020021011a000000cc9033e90100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 9, .extreme = false, .hex = "fd377a585a000004e6d6b446020021011c00000010cf58cc0100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 0, .extreme = true, .hex = "fd377a585a000004e6d6b446020021010c0000008f98419c0100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 1, .extreme = true, .hex = "fd377a585a000004e6d6b4460200210110000000a8708e860100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 2, .extreme = true, .hex = "fd377a585a000004e6d6b446020021011200000023b8872c0100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 3, .extreme = true, .hex = "fd377a585a000004e6d6b4460200210114000000ffe7ec090100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 4, .extreme = true, .hex = "fd377a585a000004e6d6b4460200210114000000ffe7ec090100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 5, .extreme = true, .hex = "fd377a585a000004e6d6b4460200210116000000742fe5a30100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 6, .extreme = true, .hex = "fd377a585a000004e6d6b4460200210116000000742fe5a30100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 7, .extreme = true, .hex = "fd377a585a000004e6d6b446020021011800000047583a430100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 8, .extreme = true, .hex = "fd377a585a000004e6d6b446020021011a000000cc9033e90100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
    .{ .level = 9, .extreme = true, .hex = "fd377a585a000004e6d6b446020021011c00000010cf58cc0100246c617267652064696374696f6e617279207072657365743a206162306162316162326162330000000080b12368bac8a74300013d25d2296a011fb6f37d010000000004595a" },
};
