//! Root API and OpenZFS composition of one parallel-encoded Zstd frame.
const std = @import("std");
const a = std.testing.allocator;

pub fn contracts(comptime V: type) !void {
    try std.testing.expect(V.ZstdParallelOptions == V.zstd.ParallelOptions);
    try std.testing.expect(V.ZstdParallelProfile == V.zstd.ParallelProfile);
    try publicSurfaces(V);
    try dictionarySet(V);
    try zfsBody(V);
}

fn settings(comptime V: type, profile: *V.ZstdParallelProfile) V.ZstdParallelOptions {
    return .{
        .io = std.testing.io,
        .worker_count = 2,
        .job_size = 512,
        .max_inflight_jobs = 2,
        .max_inflight_bytes = 1024,
        .max_working_memory = 32 * 1024 * 1024,
        .profile = profile,
    };
}

fn native(comptime V: type) V.ZstdNativeFrameOptions {
    return .{
        .strategy = .fast,
        .block_size_max = 256,
        .window_log = 14,
        .max_match_history_len = 16 * 1024,
        .content_checksum = true,
    };
}

fn inputBytes() [4097]u8 {
    var result: [4097]u8 = undefined;
    var value: u32 = 0x2730_1026;
    for (result[0..512]) |*byte| {
        value = value *% 1664525 +% 1013904223;
        byte.* = @truncate(value >> 24);
    }
    for (1..8) |block| @memcpy(result[block * 512 ..][0..512], result[0..512]);
    result[4096] = 0x5a;
    return result;
}

fn publicSurfaces(comptime V: type) !void {
    const input = inputBytes();
    var profile: V.ZstdParallelProfile = .{};
    const parallel = settings(V, &profile);
    const options = native(V);
    const bound = try V.zstdEncodedNativeParallelFrameBound(input.len, options, parallel);
    const frame = try V.zstdEncodeNativeParallelFrameAlloc(a, &input, options, parallel);
    defer a.free(frame);
    try std.testing.expect(frame.len <= bound);
    try std.testing.expectEqual(@as(usize, 9), profile.published_jobs);
    try std.testing.expectEqual(@as(usize, 17), profile.published_blocks);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    const decoded = try V.zstdDecodeNativeFrameAllocExactSize(a, frame, input.len);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);

    const output = try a.alloc(u8, frame.len);
    defer a.free(output);
    const written = try V.zstdEncodeNativeParallelFrameIntoSlice(a, &input, options, output, parallel);
    try std.testing.expectEqualSlices(u8, frame, output[0..written]);
    @memset(output, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, V.zstdEncodeNativeParallelFrameIntoSlice(a, &input, options, output[0 .. frame.len - 1], parallel));
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(a);
    try appended.appendSlice(a, "root-prefix:");
    const added = try V.zstdEncodeNativeParallelFrameAppend(a, &appended, &input, options, parallel);
    try std.testing.expectEqual(frame.len, added);
    try std.testing.expectEqualSlices(u8, "root-prefix:", appended.items[0..12]);
    try std.testing.expectEqualSlices(u8, frame, appended.items[12..]);
}

fn dictionarySet(comptime V: type) !void {
    const input = inputBytes();
    const dictionaries = [_]V.ZstdNativeDictionary{V.ZstdNativeDictionary.init(77, input[0..512])};
    const set = V.ZstdNativeDictionarySet.init(&dictionaries);
    const options = native(V);
    var profile: V.ZstdParallelProfile = .{};
    const parallel = settings(V, &profile);
    const frame = try V.zstdEncodeNativeParallelFrameWithDictionaryAlloc(a, &input, options, dictionaries[0], parallel);
    defer a.free(frame);
    const selected = try V.zstdEncodeNativeParallelFrameWithDictionarySetAlloc(a, &input, options, set, 77, parallel);
    defer a.free(selected);
    try std.testing.expectEqualSlices(u8, frame, selected);
    const decoded = try V.zstdDecodeNativeFrameAllocWithDictionarySet(a, frame, set);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
    try std.testing.expectError(error.NeedDictionary, V.zstdEncodeNativeParallelFrameWithDictionarySetAlloc(a, &input, options, set, 78, parallel));
}

fn zfsBody(comptime V: type) !void {
    const input = inputBytes();
    var options = native(V);
    options.format = .magicless;
    options.include_content_size = false;
    options.content_checksum = false;
    var profile: V.ZstdParallelProfile = .{};
    const frame = try V.zstdEncodeNativeParallelFrameAlloc(a, &input, options, settings(V, &profile));
    defer a.free(frame);
    const wrapped = try a.alloc(u8, 8 + frame.len);
    defer a.free(wrapped);
    std.mem.writeInt(u32, wrapped[0..4], @intCast(frame.len), .big);
    // OpenZFS FAST level -1 metadata; the independently encoded body is Zstd.
    std.mem.writeInt(u32, wrapped[4..8], (@as(u32, 103) << 24) | 10507, .big);
    @memcpy(wrapped[8..], frame);
    const decoded = try V.zfs.decodeBlockAllocExactSize(a, .zstd, wrapped, input.len);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}
