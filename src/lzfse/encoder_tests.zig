const std = @import("std");
const lzfse = @import("../lzfse.zig");
const format = @import("format.zig");
const fse = @import("fse.zig");
const working = @import("../io/working_allocator.zig");
const allocator = std.testing.allocator;

fn checkEncoded(input: []const u8, encoded: lzfse.Encoded) !void {
    const decoded = try lzfse.decodeAlloc(allocator, encoded.bytes);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expectEqualDeep(try wireSummary(encoded.bytes), encoded.summary);
    try std.testing.expect(encoded.peak_working_bytes >= encoded.bytes.len);
}

// Decode the serialized record streams independently of the encoder's Plan,
// so rejected FSE candidates cannot inflate the returned summary.
fn wireSummary(bytes: []const u8) !lzfse.Summary {
    var summary = lzfse.Summary{};
    const archive = try lzfse.parse(bytes);
    var iterator = archive.iterator();
    while (try iterator.next()) |block| {
        switch (block.kind) {
            .uncompressed => summary.stored_blocks += 1,
            .lzvn => summary.lzvn_blocks += 1,
            .compressed_v1, .compressed_v2 => {
                if (block.kind == .compressed_v1) summary.fse_v1_blocks += 1 else summary.fse_v2_blocks += 1;
                const header = try format.parseCompressedHeader(bytes[block.offset..]);
                summary.fse_records += header.match_count;
                summary.fse_literal_payload_bytes += header.literal_payload_size;
                summary.fse_lmd_payload_bytes += header.lmd_payload_size;
                var l_table: [64]fse.ValueDecoderEntry = undefined;
                var m_table: [64]fse.ValueDecoderEntry = undefined;
                var d_table: [256]fse.ValueDecoderEntry = undefined;
                try fse.initValueDecoderTable(64, &header.l_frequencies, &format.l_extra_bits, &format.l_base_value, &l_table);
                try fse.initValueDecoderTable(64, &header.m_frequencies, &format.m_extra_bits, &format.m_base_value, &m_table);
                try fse.initValueDecoderTable(256, &header.d_frequencies, &format.d_extra_bits, &format.d_base_value, &d_table);
                var states = [_]u16{ header.l_state, header.m_state, header.d_state };
                var reader = try fse.BitReader.init(bytes[block.payload_offset + header.literal_payload_size .. block.next_offset], header.lmd_bits);
                var distance: usize = 0;
                var literals: usize = 0;
                var matched: usize = 0;
                for (0..header.match_count) |_| {
                    const l: usize = @intCast(try fse.decodeValue(&states[0], &l_table, &reader));
                    const m: usize = @intCast(try fse.decodeValue(&states[1], &m_table, &reader));
                    const d: usize = @intCast(try fse.decodeValue(&states[2], &d_table, &reader));
                    if (d != 0) distance = d;
                    try std.testing.expect(distance != 0);
                    literals += l;
                    matched += m;
                    if (m != 0) summary.max_fse_distance = @max(summary.max_fse_distance, distance);
                    summary.max_fse_match_length = @max(summary.max_fse_match_length, m);
                }
                try std.testing.expectEqual(block.raw_size, literals + matched);
                try std.testing.expect(header.literal_count >= literals and header.literal_count - literals <= 3);
                summary.fse_literal_bytes += literals;
                summary.fse_matched_bytes += matched;
            },
        }
    }
    return summary;
}

fn legacyReference(input: []const u8, block_size: usize, use_lzvn: bool) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var position: usize = 0;
    while (position < input.len or (input.len == 0 and output.items.len == 0)) {
        const block = input[position..][0..@min(block_size, input.len - position)];
        const payload = if (use_lzvn and block.len != 0) try lzfse.encodeLzvnAlloc(allocator, block) else null;
        defer if (payload) |bytes| allocator.free(bytes);
        const compressed = if (payload) |bytes| bytes.len + 12 < block.len + 8 else false;
        var header: [12]u8 = @splat(0);
        std.mem.writeInt(u32, header[0..4], if (compressed) format.compressed_lzvn_magic else format.uncompressed_magic, .little);
        std.mem.writeInt(u32, header[4..8], @intCast(block.len), .little);
        if (compressed) {
            std.mem.writeInt(u32, header[8..12], @intCast(payload.?.len), .little);
            try output.appendSlice(allocator, &header);
            try output.appendSlice(allocator, payload.?);
        } else {
            try output.appendSlice(allocator, header[0..8]);
            try output.appendSlice(allocator, block);
        }
        position += block.len;
        if (input.len == 0) break;
    }
    try output.appendSlice(allocator, "bvx$");
    return output.toOwnedSlice(allocator);
}

test "LZFSE public encoder round trips empty tiny random and repetitive inputs in every mode" {
    var random_data: [8192]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0xc71b_32e9_48ad_2195);
    random.random().bytes(&random_data);
    const original = random_data;
    for ([_][]const u8{ "", "abc", &random_data, "LZFSE mode coverage 0123456789\n" ** 256 }) |input| {
        for ([_]lzfse.Strategy{ .auto, .lzvn, .fse, .stored }) |strategy| {
            for ([_]lzfse.FseVersion{ .v1, .v2 }) |version| {
                var encoded = try lzfse.encodeWithSummaryAlloc(allocator, input, .{ .strategy = strategy, .fse_version = version, .block_size = 4096, .hash_log = 8 });
                defer encoded.deinit(allocator);
                try checkEncoded(input, encoded);
            }
        }
    }
    try std.testing.expectEqualSlices(u8, &original, &random_data);
}

test "LZFSE public encoder preserves explicit LZVN bytes and legacy stored switch" {
    const input = "legacy literal and matching opcode parity\n" ** 300;
    for ([_][]const u8{ "", "abc", input }) |payload| {
        const expected_lzvn = try legacyReference(payload, 4096, true);
        defer allocator.free(expected_lzvn);
        const expected_stored = try legacyReference(payload, 4096, false);
        defer allocator.free(expected_stored);
        var lzvn = try lzfse.encodeWithSummaryAlloc(allocator, payload, .{ .strategy = .lzvn, .use_lzvn = false, .block_size = 4096 });
        defer lzvn.deinit(allocator);
        try std.testing.expectEqualSlices(u8, expected_lzvn, lzvn.bytes);
        var stored = try lzfse.encodeWithSummaryAlloc(allocator, payload, .{ .use_lzvn = false, .block_size = 4096 });
        defer stored.deinit(allocator);
        try std.testing.expectEqualSlices(u8, expected_stored, stored.bytes);
        var explicit = try lzfse.encodeWithSummaryAlloc(allocator, payload, .{ .strategy = .stored, .use_lzvn = true, .block_size = 4096 });
        defer explicit.deinit(allocator);
        try std.testing.expectEqualSlices(u8, expected_stored, explicit.bytes);
    }
    const repeat: [100000]u8 = @splat(0);
    var automatic = try lzfse.encodeWithSummaryAlloc(allocator, &repeat, .{});
    defer automatic.deinit(allocator);
    var explicit = try lzfse.encodeWithSummaryAlloc(allocator, &repeat, .{ .strategy = .auto, .use_lzvn = false });
    defer explicit.deinit(allocator);
    var legacy = try lzfse.encodeWithSummaryAlloc(allocator, &repeat, .{ .strategy = .lzvn });
    defer legacy.deinit(allocator);
    try std.testing.expectEqualSlices(u8, automatic.bytes, explicit.bytes);
    try std.testing.expect(automatic.summary.fse_v2_blocks > 0);
    try std.testing.expect(automatic.bytes.len < legacy.bytes.len);
    try std.testing.expectEqual(@as(usize, 2359), automatic.summary.max_fse_match_length);
    try checkEncoded(&repeat, automatic);
}

test "LZFSE public encoder count cuts profitable prefixes without imposing a 32 KiB raw cap" {
    const input = try allocator.alloc(u8, 150000);
    defer allocator.free(input);
    var random = std.Random.DefaultPrng.init(0x593d_13c1_e31b_27a9);
    for (input) |*byte| byte.* = 32 + random.random().uintLessThan(u8, 64);
    var encoded = try lzfse.encodeWithSummaryAlloc(allocator, input, .{ .strategy = .fse, .use_lzvn = false, .block_size = 120000 });
    defer encoded.deinit(allocator);
    try checkEncoded(input, encoded);
    var iterator = (try lzfse.parse(encoded.bytes)).iterator();
    const first = (try iterator.next()).?;
    try std.testing.expectEqual(lzfse.BlockKind.compressed_v2, first.kind);
    try std.testing.expect(first.raw_size > 32768 and first.raw_size < 120000);
    const header = try format.parseCompressedHeader(encoded.bytes[first.offset..]);
    try std.testing.expectEqual(@as(usize, 40000), header.literal_count);
    try std.testing.expect(encoded.summary.fse_v2_blocks > 1);

    const zeros: [160 * 1024]u8 = @splat(0);
    var large = try lzfse.encodeWithSummaryAlloc(allocator, &zeros, .{ .strategy = .fse, .block_size = 96 * 1024 });
    defer large.deinit(allocator);
    try checkEncoded(&zeros, large);
    iterator = (try lzfse.parse(large.bytes)).iterator();
    try std.testing.expectEqual(@as(usize, 96 * 1024), (try iterator.next()).?.raw_size);
    const second = (try iterator.next()).?;
    try std.testing.expectEqual(@as(usize, 0), (try format.parseCompressedHeader(large.bytes[second.offset..])).literal_count);
}

test "LZFSE public encoder random fallback preserves complete requested raw blocks and summary attribution" {
    const input = try allocator.alloc(u8, 128 * 1024 + 17);
    defer allocator.free(input);
    var random = std.Random.DefaultPrng.init(0x4517_8913_bedd_347a);
    random.random().bytes(input);
    var encoded = try lzfse.encodeWithSummaryAlloc(allocator, input, .{ .block_size = 65536 });
    defer encoded.deinit(allocator);
    try checkEncoded(input, encoded);
    var iterator = (try lzfse.parse(encoded.bytes)).iterator();
    for ([_]usize{ 65536, 65536, 17 }) |size| {
        const block = (try iterator.next()).?;
        try std.testing.expectEqual(lzfse.BlockKind.uncompressed, block.kind);
        try std.testing.expectEqual(size, block.raw_size);
    }
    try std.testing.expect(try iterator.next() == null);
    const zeros: [8192]u8 = @splat(0);
    var rejected = try lzfse.encodeWithSummaryAlloc(allocator, &zeros, .{ .strategy = .auto, .fse_version = .v1, .block_size = 1024 });
    defer rejected.deinit(allocator);
    try checkEncoded(&zeros, rejected);
    try std.testing.expect(rejected.summary.lzvn_blocks > 0);
    try std.testing.expectEqual(@as(usize, 0), rejected.summary.fse_matched_bytes);
    try std.testing.expectEqual(@as(usize, 0), rejected.summary.fse_records);
}

test "LZFSE public encoder borrows raw history across blocks and enforces maximum distance" {
    const distance = 262139;
    const input = try allocator.alloc(u8, distance + 2359);
    defer allocator.free(input);
    var random = std.Random.DefaultPrng.init(0xf1a9_b740_e53d_589a);
    random.random().bytes(input[0..distance]);
    @memcpy(input[distance..], input[0..2359]);
    var wide = try lzfse.encodeWithSummaryAlloc(allocator, input, .{ .strategy = .fse, .block_size = 65536 });
    defer wide.deinit(allocator);
    try checkEncoded(input, wide);
    try std.testing.expect(wide.summary.stored_blocks > 0 and wide.summary.fse_v2_blocks > 0);
    try std.testing.expectEqual(@as(usize, distance), wide.summary.max_fse_distance);
    var limited = try lzfse.encodeWithSummaryAlloc(allocator, input, .{ .strategy = .fse, .block_size = 65536, .max_match_distance = distance - 1 });
    defer limited.deinit(allocator);
    try checkEncoded(input, limited);
    try std.testing.expect(limited.summary.max_fse_distance < distance);
    try std.testing.expect(limited.summary.fse_matched_bytes < wide.summary.fse_matched_bytes);
}

test "LZFSE public encoder output limits caller guards and append rollback are exact" {
    const input = "output ownership and limits 0123456789\n" ** 200;
    var encoded = try lzfse.encodeWithSummaryAlloc(allocator, input, .{ .strategy = .fse, .block_size = 2048 });
    defer encoded.deinit(allocator);
    const exact = lzfse.Options{ .strategy = .fse, .block_size = 2048, .max_output_len = encoded.bytes.len };
    const repeated = try lzfse.encodeAlloc(allocator, input, exact);
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, encoded.bytes, repeated);
    var small = exact;
    small.max_output_len -= 1;
    try std.testing.expectError(error.OutputLimitExceeded, lzfse.encodeAlloc(allocator, input, small));
    const guarded = try allocator.alloc(u8, encoded.bytes.len + 2);
    defer allocator.free(guarded);
    @memset(guarded, 0xcc);
    try std.testing.expectError(error.OutputLimitExceeded, lzfse.encodeInto(allocator, input, small, guarded[1 .. guarded.len - 1]));
    var no_memory = exact;
    no_memory.max_working_memory = 0;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, lzfse.encodeInto(allocator, input, no_memory, guarded[1 .. guarded.len - 1]));
    try std.testing.expectError(error.OutputTooSmall, lzfse.encodeInto(allocator, input, exact, guarded[1..encoded.bytes.len]));
    for (guarded) |byte| try std.testing.expectEqual(@as(u8, 0xcc), byte);
    try std.testing.expectEqual(encoded.bytes.len, try lzfse.encodeInto(allocator, input, exact, guarded[1 .. guarded.len - 1]));
    try std.testing.expectEqualSlices(u8, encoded.bytes, guarded[1 .. guarded.len - 1]);
    try std.testing.expectEqual(@as(u8, 0xcc), guarded[0]);
    try std.testing.expectEqual(@as(u8, 0xcc), guarded[guarded.len - 1]);
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "prefix");
    try std.testing.expectError(error.OutputLimitExceeded, lzfse.encodeAppend(allocator, &output, input, small));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, lzfse.encodeAppend(allocator, &output, input, no_memory));
    try std.testing.expectEqualStrings("prefix", output.items);
    try std.testing.expectEqual(encoded.bytes.len, try lzfse.encodeAppend(allocator, &output, input, exact));
    try std.testing.expectEqualSlices(u8, encoded.bytes, output.items[6..]);
}

test "LZFSE public encoder working budget covers returned candidates and plan storage but excludes caller input" {
    const input: [65536]u8 = @splat(0);
    var observer = working.WorkingAllocator.init(allocator, std.math.maxInt(usize));
    const observed_allocator = observer.allocator();
    var result = try lzfse.encodeWithSummaryAlloc(observed_allocator, &input, .{ .strategy = .fse, .hash_log = 8 });
    try std.testing.expectEqual(result.bytes.len, observer.live);
    try std.testing.expectEqual(observer.peak, result.peak_working_bytes);
    try std.testing.expect(result.peak_working_bytes > result.bytes.len);
    try std.testing.expect(result.peak_working_bytes < input.len);
    const peak = result.peak_working_bytes;
    result.deinit(observed_allocator);
    try std.testing.expectEqual(@as(usize, 0), observer.live);
    var exact = try lzfse.encodeWithSummaryAlloc(allocator, &input, .{ .strategy = .fse, .hash_log = 8, .max_working_memory = peak });
    defer exact.deinit(allocator);
    try std.testing.expect(exact.peak_working_bytes <= peak);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, lzfse.encodeAlloc(allocator, &input, .{ .strategy = .fse, .hash_log = 8, .max_working_memory = peak - 1 }));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, lzfse.encodeAlloc(allocator, &input, .{ .strategy = .stored, .max_working_memory = input.len - 1 }));
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, lzfse.encodeAlloc(failing.allocator(), &input, .{ .strategy = .fse }));
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, lzfse.encodeAlloc(allocator, "", .{ .max_working_memory = 0 }));
}

fn streamAllocationFailure(test_allocator: std.mem.Allocator, strategy: lzfse.Strategy, version: lzfse.FseVersion) !void {
    var input: [3089]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0xae6f_7b10_5cf2_2d4a);
    random.random().bytes(input[0..1024]);
    for (input[1024..], 1024..) |*byte, index| byte.* = "abcdefgh"[index % 8];
    var encoded = try lzfse.encodeWithSummaryAlloc(test_allocator, &input, .{ .strategy = strategy, .fse_version = version, .block_size = 1024, .hash_log = 8 });
    defer encoded.deinit(test_allocator);
    try checkEncoded(&input, encoded);
}

fn appendAllocationFailure(test_allocator: std.mem.Allocator) !void {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(test_allocator);
    try output.appendSlice(test_allocator, "prefix");
    _ = lzfse.encodeAppend(test_allocator, &output, "multi-block append\n" ** 200, .{ .strategy = .fse, .block_size = 1024, .hash_log = 8 }) catch |err| {
        try std.testing.expectEqualStrings("prefix", output.items);
        return err;
    };
}

test "LZFSE public encoder multi-block streams and append clean up every allocation failure" {
    for ([_]lzfse.Strategy{ .auto, .lzvn, .fse, .stored }) |strategy| {
        for ([_]lzfse.FseVersion{ .v1, .v2 }) |version|
            try std.testing.checkAllAllocationFailures(allocator, streamAllocationFailure, .{ strategy, version });
    }
    try std.testing.checkAllAllocationFailures(allocator, appendAllocationFailure, .{});
}
