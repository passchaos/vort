const std = @import("std");
const deflate = @import("../../../deflate.zig");
const png = @import("../../../png.zig");
const history = @import("../../../deflate/png/windowed_history.zig");

test "PNG general windowed helper matches full scratch across block types" {
    const width = 1024;
    const height = 128;
    const info = try png.pngImageInfo(width, height, 8, .grayscale);
    const stride = width + 1;
    const filtered = try std.testing.allocator.alloc(u8, stride * height);
    defer std.testing.allocator.free(filtered);
    const expected = try std.testing.allocator.alloc(u8, width * height);
    defer std.testing.allocator.free(expected);

    for (0..height) |row_index| {
        const row = expected[row_index * width ..][0..width];
        for (row, 0..) |*byte, column| {
            byte.* = @truncate(
                row_index * 29 +
                    column * 17 +
                    (column / 7) * 11,
            );
        }
        const filter: u8 = @intCast(row_index % 5);
        filterRow(
            filter,
            row,
            if (row_index == 0)
                null
            else
                expected[(row_index - 1) * width ..][0..width],
            info.bytes_per_pixel,
            filtered[row_index * stride + 1 ..][0..width],
        );
        filtered[row_index * stride] = filter;
    }

    const dynamic = try deflate.encodeZlibDynamicSplitAlloc(
        std.testing.allocator,
        filtered,
        12 * 1024,
        .{},
    );
    defer std.testing.allocator.free(dynamic);
    const fixed = try deflate.encodeZlibFixedSplitAlloc(
        std.testing.allocator,
        filtered,
        12 * 1024,
        .{},
    );
    defer std.testing.allocator.free(fixed);
    const stored = try deflate.encodeZlibStoredAlloc(
        std.testing.allocator,
        filtered,
    );
    defer std.testing.allocator.free(stored);

    for ([_][]const u8{ dynamic, fixed, stored }) |encoded| {
        var window: [history.general_scratch_len]u8 = undefined;
        const candidate = try std.testing.allocator.alloc(u8, expected.len);
        defer std.testing.allocator.free(candidate);
        const result = try deflate.decodePngWindowedZlibImageWithOptions(
            encoded,
            &window,
            info,
            .{},
            candidate,
        );
        try std.testing.expectEqual(height, result.rows);
        try std.testing.expectEqual(expected.len, result.output_written);
        try std.testing.expectEqual(encoded.len, result.zlib_input_read);
        try std.testing.expectEqualSlices(u8, expected, candidate);

        const zlib_scratch =
            try std.testing.allocator.alloc(u8, filtered.len);
        defer std.testing.allocator.free(zlib_scratch);
        const filtered_row = try std.testing.allocator.alloc(u8, width);
        defer std.testing.allocator.free(filtered_row);
        const previous_row = try std.testing.allocator.alloc(u8, width);
        defer std.testing.allocator.free(previous_row);
        const reference = try std.testing.allocator.alloc(u8, expected.len);
        defer std.testing.allocator.free(reference);
        _ = try deflate.decodePngZlibImageWithOptions(
            encoded,
            zlib_scratch,
            filtered_row,
            previous_row,
            info,
            .{},
            reference,
        );
        try std.testing.expectEqualSlices(u8, reference, candidate);
    }

    // The public minimum is two DEFLATE windows. Stored blocks can be 65,535
    // bytes, so this additionally proves that the helper transactionally
    // splits them instead of requiring the four-window performance scratch.
    var minimum_window: [history.minimum_scratch_len]u8 = undefined;
    const minimum_output =
        try std.testing.allocator.alloc(u8, expected.len);
    defer std.testing.allocator.free(minimum_output);
    _ = try deflate.decodePngWindowedZlibImageWithOptions(
        stored,
        &minimum_window,
        info,
        .{},
        minimum_output,
    );
    try std.testing.expectEqualSlices(u8, expected, minimum_output);
}

test "PNG general windowed helper requires two-window minimum scratch" {
    const info = try png.pngImageInfo(4, 3, 8, .truecolor_alpha);
    var short: [history.minimum_scratch_len - 1]u8 = undefined;
    var output: [48]u8 = @splat(0xa5);
    try std.testing.expectError(
        error.OutputTooSmall,
        deflate.decodePngWindowedZlibImageWithOptions(
            &.{},
            &short,
            info,
            .{},
            &output,
        ),
    );
    try std.testing.expectEqualSlices(
        u8,
        &([_]u8{0xa5} ** output.len),
        &output,
    );
}

test "PNG general windowed helper validates wrapper and filter errors" {
    const info = try png.pngImageInfo(256, 256, 8, .grayscale);
    const stride = info.row_len + 1;
    const filtered = try std.testing.allocator.alloc(
        u8,
        stride * info.height,
    );
    defer std.testing.allocator.free(filtered);
    @memset(filtered, 0);
    const encoded = try deflate.encodeZlibDynamicSplitAlloc(
        std.testing.allocator,
        filtered,
        8 * 1024,
        .{},
    );
    defer std.testing.allocator.free(encoded);

    var window: [history.general_scratch_len]u8 = undefined;
    const output = try std.testing.allocator.alloc(
        u8,
        info.row_len * info.height,
    );
    defer std.testing.allocator.free(output);

    const bad_adler = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_adler);
    bad_adler[bad_adler.len - 1] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        deflate.decodePngWindowedZlibImageWithOptions(
            bad_adler,
            &window,
            info,
            .{},
            output,
        ),
    );
    _ = try deflate.decodePngWindowedZlibImageWithOptions(
        bad_adler,
        &window,
        info,
        .{ .ignore_adler = true },
        output,
    );

    const trailing = try std.testing.allocator.alloc(u8, encoded.len + 1);
    defer std.testing.allocator.free(trailing);
    @memcpy(trailing[0..encoded.len], encoded);
    trailing[encoded.len] = 0;
    try std.testing.expectError(
        error.TrailingData,
        deflate.decodePngWindowedZlibImageWithOptions(
            trailing,
            &window,
            info,
            .{},
            output,
        ),
    );
    try std.testing.expectError(
        error.TruncatedFrame,
        deflate.decodePngWindowedZlibImageWithOptions(
            encoded[0 .. encoded.len - 2],
            &window,
            info,
            .{},
            output,
        ),
    );

    filtered[0] = 5;
    const bad_filter = try deflate.encodeZlibDynamicSplitAlloc(
        std.testing.allocator,
        filtered,
        8 * 1024,
        .{},
    );
    defer std.testing.allocator.free(bad_filter);
    try std.testing.expectError(
        error.CorruptFrame,
        deflate.decodePngWindowedZlibImageWithOptions(
            bad_filter,
            &window,
            info,
            .{},
            output,
        ),
    );
}

fn filterRow(
    filter: u8,
    row: []const u8,
    previous: ?[]const u8,
    bytes_per_pixel: usize,
    filtered: []u8,
) void {
    std.debug.assert(filtered.len == row.len);
    for (row, 0..) |pixel, index| {
        const left: u8 = if (index >= bytes_per_pixel)
            row[index - bytes_per_pixel]
        else
            0;
        const up: u8 = if (previous) |prev| prev[index] else 0;
        const up_left: u8 = if (index >= bytes_per_pixel)
            if (previous) |prev| prev[index - bytes_per_pixel] else 0
        else
            0;
        const prediction: u8 = switch (filter) {
            0 => 0,
            1 => left,
            2 => up,
            3 => @intCast((@as(u16, left) + up) / 2),
            4 => paeth(left, up, up_left),
            else => unreachable,
        };
        filtered[index] = pixel -% prediction;
    }
}

fn paeth(left: u8, up: u8, up_left: u8) u8 {
    const p = @as(i16, left) + @as(i16, up) - @as(i16, up_left);
    const pa = @abs(p - @as(i16, left));
    const pb = @abs(p - @as(i16, up));
    const pc = @abs(p - @as(i16, up_left));
    return if (pa <= pb and pa <= pc)
        left
    else if (pb <= pc)
        up
    else
        up_left;
}
