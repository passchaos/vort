const std = @import("std");
const Runtime = @import("libzstd_runtime.zig").Runtime;

const raw_dictionary = "service=vort region=west status=complete message=bounded reference dictionary round trip\n" ** 8;
pub const payload = "service=vort region=west status=complete message=bounded reference dictionary round trip\n" ** 16;

pub fn contracts(comptime Codec: type, allocator: std.mem.Allocator, runtime: Runtime) !usize {
    var samples: [64][]const u8 = undefined;
    var sample_count: usize = 0;
    defer for (samples[0..sample_count]) |sample| allocator.free(sample);
    for (&samples, 0..) |*sample, index| {
        sample.* = try std.fmt.allocPrint(allocator, "service=vort region={d} status=complete message=bounded reference dictionary round trip key={d}\n" ** 4, .{ index % 7, index, index % 7, index, index % 7, index, index % 7, index });
        sample_count += 1;
    }
    const full = try runtime.trainDictionaryAlloc(allocator, &samples, 1024);
    defer allocator.free(full);
    const parsed = try Codec.NativeDictionary.initFromStandardDictionary(full);
    try std.testing.expect(parsed.dictionary.id != 0);
    try std.testing.expectEqual(runtime.dictionaryId(full).?, parsed.dictionary.id);

    var checked: usize = 0;
    for ([_]bool{ false, true }) |standard| {
        const bytes = if (standard) full else raw_dictionary;
        const dictionary = if (standard) parsed.dictionary else Codec.NativeDictionary.init(0, raw_dictionary);
        for ([_]c_int{ 7, 9 }) |strategy| {
            for ([_]c_int{ 15, 17 }) |window| {
                const options: Runtime.AdvancedOptions = .{
                    .strategy = strategy,
                    .window_log = window,
                    .search_log = 6,
                    .target_length = 64,
                    .min_match = 3,
                    .workers = 0,
                    .checksum = true,
                };
                const requested = try runtime.inspectAdvancedWithDictParameters(options, bytes);
                try std.testing.expectEqual(strategy, requested.strategy);
                try std.testing.expectEqual(window, requested.window_log);
                try std.testing.expectEqual(@as(c_int, 6), requested.search_log);
                try std.testing.expectEqual(@as(c_int, 64), requested.target_length);
                try std.testing.expectEqual(@as(c_int, 3), requested.min_match);
                try std.testing.expectEqual(@as(c_int, 0), requested.workers);
                try std.testing.expectEqual(@as(c_int, 1), requested.checksum);
                try std.testing.expectEqual(@as(c_int, 1), requested.content_size);
                try std.testing.expectEqual(@as(c_int, 1), requested.dict_id);
                const frame = try runtime.encodeAdvancedWithDictAlloc(allocator, payload, options, bytes);
                defer allocator.free(frame);
                const header = try Codec.inspectNativeFrameHeader(frame);
                try std.testing.expectEqual(dictionary.id, header.dictionary_id);
                const decoded = try Codec.decodeFrameAllocWithDictionary(allocator, frame, dictionary);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, payload, decoded);
                const vort = try Codec.encodeNativeFrameWithDictionaryAlloc(allocator, payload, .{
                    .strategy = if (strategy == 7) .btopt else .btultra2,
                    .window_log = @intCast(window),
                    .content_checksum = true,
                    .hq = .{ .search_depth = 64, .nice_len = 64, .min_match = 3 },
                }, dictionary);
                defer allocator.free(vort.frame);
                const output = try allocator.alloc(u8, payload.len);
                defer allocator.free(output);
                try runtime.decodeUsingDict(vort.frame, output, bytes);
                try std.testing.expectEqualSlices(u8, payload, output);
                checked += 1;
            }
        }
    }
    return checked;
}
