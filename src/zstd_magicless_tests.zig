//! Explicit standard/magicless public wire contracts; no codec-root import.
const std = @import("std");
const h = @import("tests/zstd_magicless_helpers.zig");
const a = std.testing.allocator;

pub fn contracts(comptime Z: type) !void {
    const Cases = Suite(Z);
    try Cases.headers();
    try Cases.encoders();
    try Cases.malformedAndLimits();
    try @import("tests/zstd_magicless_streams.zig").contracts(Z);
    try @import("tests/zstd_magicless_dictionaries.zig").contracts(Z);
    try @import("tests/zstd_magicless_memory.zig").contracts(Z);
}
fn Suite(comptime Z: type) type {
    return struct {
        fn headers() !void {
            const values = [_]struct { bytes: []const u8, size: ?u64, width: usize }{
                .{ .bytes = &.{ 0, 0 }, .size = null, .width = 0 },
                .{ .bytes = &.{ 0x20, 0 }, .size = 0, .width = 1 },
                .{ .bytes = &.{ 0x60, 0, 0 }, .size = 256, .width = 2 },
                .{ .bytes = &.{ 0xa0, 1, 0, 0, 0 }, .size = 1, .width = 4 },
                .{ .bytes = &.{ 0xe0, 1, 0, 0, 0, 1, 0, 0, 0 }, .size = (@as(u64, 1) << 32) + 1, .width = 8 },
            };
            for (values) |value| {
                const independent = try h.header(value.bytes, true);
                try std.testing.expectEqual(value.size, independent.content_size);
                try std.testing.expectEqual(value.width, independent.content_width);
                const parsed = try Z.inspectNativeFrameHeaderWithFormat(value.bytes, .magicless);
                try std.testing.expectEqual(value.size, parsed.content_size);
                try std.testing.expectEqual(value.bytes.len, parsed.payload_offset);
                try std.testing.expectEqual(independent.window, parsed.window_size);
                const standard = try h.standardAlloc(a, value.bytes);
                defer a.free(standard);
                const normal = try Z.inspectNativeFrameHeader(standard);
                try std.testing.expectEqual(value.size, normal.content_size);
                try std.testing.expectEqual(parsed.payload_offset + 4, normal.payload_offset);
                for (0..value.bytes.len) |cut|
                    try std.testing.expectError(error.TruncatedFrame, Z.inspectNativeFrameHeaderWithFormat(value.bytes[0..cut], .magicless));
            }
            try std.testing.expectError(error.CorruptFrame, Z.inspectNativeFrameHeaderWithFormat(&.{0x08}, .magicless));
            const empty = try h.rawAlloc(a, "", false);
            defer a.free(empty);
            try std.testing.expectEqual(@as(usize, 5), empty.len);
            try h.check(Z, a, empty, "", .{ .format = .magicless, .expected_output_len = 0 });
        }

        fn pair(payload: []const u8, options: Z.NativeFrameOptions) !void {
            var normal_options = options;
            normal_options.format = .standard;
            const normal = try Z.encodeNativeFrameWithOptionsAlloc(a, payload, normal_options);
            defer a.free(normal.frame);
            var magicless_options = options;
            magicless_options.format = .magicless;
            const magicless = try Z.encodeNativeFrameWithOptionsAlloc(a, payload, magicless_options);
            defer a.free(magicless.frame);
            try std.testing.expectEqual(normal.frame.len - 4, magicless.frame.len);
            try std.testing.expectEqualSlices(u8, normal.frame[4..], magicless.frame);
            const scan = try h.scan(magicless.frame, true);
            try std.testing.expectEqual(magicless.frame.len, scan.end);
            const header = try Z.inspectNativeFrameHeaderWithFormat(magicless.frame, .magicless);
            try std.testing.expectEqual(scan.header.payload_offset, header.payload_offset);
            try std.testing.expectEqual(scan.header.content_size, header.content_size);
            const first = try Z.inspectNativeFrameFirstBlockWithFormat(magicless.frame, .magicless);
            const first_at = try Z.inspectNativeFrameBlockAtWithFormat(magicless.frame, header.payload_offset, .magicless);
            try std.testing.expectEqual(first, first_at);
            try h.check(Z, a, magicless.frame, payload, .{ .format = .magicless, .expected_output_len = payload.len });
            try h.check(Z, a, normal.frame, payload, .{ .expected_output_len = payload.len });
            try std.testing.expectError(error.CorruptFrame, Z.decodedFrameSizeWithOptions(normal.frame, .{ .format = .magicless }));
        }

        fn encoders() !void {
            for ([_][]const u8{ "", "x", h.plain, "R" ** 512 }) |payload| {
                for ([_]Z.NativeFrameSelection{ .raw_or_rle, .literal_only, .fast_compressed }) |selection|
                    try pair(payload, .{ .selection = selection, .block_size_max = 128, .content_checksum = true });
            }
            for ([_]Z.Strategy{ .fast, .lazy2, .btopt, .btultra2 }) |strategy|
                try pair(h.plain ** 4, .{ .strategy = strategy, .window_log = 10, .hq = if (strategy == .btopt or strategy == .btultra2) .{ .search_depth = 8, .nice_len = 64 } else null });
            try pair(h.plain, .{ .selection = .raw_or_rle, .include_content_size = false, .content_checksum = false });
            for ([_]c_int{ 0, -1, -131072, 1, 3, 19, 22 }) |level| {
                const normal = try Z.encodeFrameWithLevelAndOptionsAlloc(a, h.plain ** 3, level, .{ .include_content_size = true, .content_checksum = true, .window_log = 10 });
                defer a.free(normal);
                const magicless = try Z.encodeFrameWithLevelAndOptionsAlloc(a, h.plain ** 3, level, .{ .format = .magicless, .include_content_size = true, .content_checksum = true, .window_log = 10 });
                defer a.free(magicless);
                try std.testing.expectEqualSlices(u8, normal[4..], magicless);
                try h.check(Z, a, magicless, h.plain ** 3, .{ .format = .magicless, .expected_output_len = (h.plain ** 3).len });
            }
            const large = try a.alloc(u8, 128 * 1024 + 3);
            defer a.free(large);
            var random: u32 = 0x5c98e213;
            for (large) |*byte| {
                random = random *% 1664525 +% 1013904223;
                byte.* = @truncate(random >> 24);
            }
            const wire = try h.rawAlloc(a, large, true);
            defer a.free(wire);
            // Independent exact bytes for this two-block RFC raw fixture,
            // checked before either the QA scanner or production decoder.
            try std.testing.expectEqual(@as(usize, 131090), wire.len);
            try std.testing.expectEqualSlices(u8, &.{ 0xa4, 3, 0, 2, 0, 0, 0, 0x10 }, wire[0..8]);
            const next_header: usize = 8 + 128 * 1024;
            try std.testing.expectEqualSlices(u8, large[0 .. 128 * 1024], wire[8..next_header]);
            try std.testing.expectEqualSlices(u8, &.{ 0x19, 0, 0 }, wire[next_header..][0..3]);
            try std.testing.expectEqualSlices(u8, large[128 * 1024 ..], wire[next_header + 3 ..][0..3]);
            const independent_header = try h.header(wire, true);
            try std.testing.expectEqual(@as(usize, 5), independent_header.payload_offset);
            try std.testing.expectEqual(@as(?u64, 131075), independent_header.content_size);
            try std.testing.expectEqual(@as(usize, 2), (try h.scan(wire, true)).blocks);
            try h.check(Z, a, wire, large, .{ .format = .magicless, .expected_output_len = large.len });
        }

        fn malformedAndLimits() !void {
            const payload = h.plain;
            const wire = try h.rawAlloc(a, payload, true);
            defer a.free(wire);
            const scan = try h.scan(wire, true);
            for ([_]usize{ 1, scan.header.payload_offset, scan.header.payload_offset + 2, wire.len - 5, wire.len - 1 }) |cut|
                try std.testing.expectError(error.TruncatedFrame, Z.decodeFrameAllocWithOptions(a, wire[0..cut], .{ .format = .magicless }));
            var corrupt = try a.dupe(u8, wire);
            defer a.free(corrupt);
            corrupt[corrupt.len - 1] ^= 1;
            try std.testing.expectError(error.ChecksumMismatch, Z.decodeFrameAllocWithOptions(a, corrupt, .{ .format = .magicless }));
            @memcpy(corrupt, wire);
            corrupt[scan.header.payload_offset] |= 6; // Reserved block type.
            try std.testing.expectError(error.CorruptFrame, Z.decodedFrameSizeWithOptions(corrupt, .{ .format = .magicless }));
            @memcpy(corrupt, wire);
            corrupt[1] += 1;
            try std.testing.expectError(error.SizeMismatch, Z.decodeFrameAllocWithOptions(a, corrupt, .{ .format = .magicless }));
            try std.testing.expectError(error.OutputLimitExceeded, Z.decodeFrameAllocWithOptions(a, wire, .{ .format = .magicless, .max_output_len = payload.len - 1 }));
            try std.testing.expectError(error.SizeMismatch, Z.decodeFrameAllocWithOptions(a, wire, .{ .format = .magicless, .expected_output_len = payload.len + 1 }));
            var output: [h.plain.len + 17]u8 = @splat(0xa5);
            try std.testing.expectError(error.OutputLimitExceeded, Z.decodeFrameIntoWithOptions(a, wire, &output, .{ .format = .magicless, .max_output_len = payload.len - 1 }));
            try h.untouched(&output);
            try std.testing.expectError(error.OutputTooSmall, Z.decodeFrameIntoWithOptions(a, wire, output[0 .. payload.len - 1], .{ .format = .magicless }));
            try h.untouched(&output);
            const skip = try Z.encodeSkippableFrameAlloc(a, 8, "metadata");
            defer a.free(skip);
            try std.testing.expectEqual(@as(usize, 0), try Z.decodedFrameSize(skip));
            try std.testing.expectError(error.CorruptFrame, Z.decodedFrameSizeWithOptions(skip, .{ .format = .magicless }));
        }
    };
}
