const std = @import("std");
const deflate = @import("../../deflate.zig");
const png = @import("../../png.zig");
const windowed_history =
    @import("../../deflate/png/windowed_history.zig");

test "PNG windowed RLE258 helper rejects buffers and ordinary tables" {
    const info = try png.pngImageInfo(4, 3, 8, .truecolor_alpha);
    var filtered: [17 * 3]u8 = @splat(0);
    for (0..3) |row| {
        filtered[row * 17] = @intFromEnum(png.PngFilterMethod.none);
        for (0..16) |column| {
            filtered[row * 17 + 1 + column] =
                @truncate(row * 31 + column * 7);
        }
    }
    const encoded = try deflate.encodeZlibDynamicWithOptionsAlloc(
        std.testing.allocator,
        &filtered,
        .{},
    );
    defer std.testing.allocator.free(encoded);

    var window: [windowed_history.scratch_len]u8 = undefined;
    var output: [48]u8 = @splat(0xa5);
    try std.testing.expectError(
        error.OutputTooSmall,
        deflate.decodePngWindowedRle258ZlibImageWithOptions(
            encoded,
            &window,
            info,
            .{},
            output[0 .. output.len - 1],
        ),
    );
    try std.testing.expectError(
        error.OutputTooSmall,
        deflate.decodePngWindowedRle258ZlibImageWithOptions(
            encoded,
            window[0 .. window.len - 1],
            info,
            .{},
            &output,
        ),
    );
    try std.testing.expectError(
        error.UnsupportedDeflateFeature,
        deflate.decodePngWindowedRle258ZlibImageWithOptions(
            encoded,
            &window,
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

test "PNG windowed RLE258 helper rejects aliased storage before parsing" {
    const info = try png.pngImageInfo(4, 3, 8, .truecolor_alpha);
    var storage: [windowed_history.scratch_len + 48]u8 = @splat(0);
    var separate_output: [48]u8 = @splat(0xa5);
    var separate_window: [windowed_history.scratch_len]u8 = undefined;

    try std.testing.expectError(
        error.UnsupportedDeflateFeature,
        deflate.decodePngWindowedRle258ZlibImageWithOptions(
            storage[0..2],
            storage[0..windowed_history.scratch_len],
            info,
            .{},
            &separate_output,
        ),
    );
    try std.testing.expectError(
        error.UnsupportedDeflateFeature,
        deflate.decodePngWindowedRle258ZlibImageWithOptions(
            storage[windowed_history.scratch_len..][0..2],
            &separate_window,
            info,
            .{},
            storage[windowed_history.scratch_len..],
        ),
    );
    try std.testing.expectError(
        error.UnsupportedDeflateFeature,
        deflate.decodePngWindowedRle258ZlibImageWithOptions(
            storage[windowed_history.scratch_len..][0..2],
            storage[0..windowed_history.scratch_len],
            info,
            .{},
            storage[0..48],
        ),
    );
    try std.testing.expectEqualSlices(
        u8,
        &([_]u8{0xa5} ** separate_output.len),
        &separate_output,
    );
}

test "PNG windowed RLE258 helper rejects forged overflowing row metadata" {
    var info = try png.pngImageInfo(4, 3, 8, .truecolor_alpha);
    info.row_len = std.math.maxInt(usize);
    info.zlib_payload_len = std.math.maxInt(usize);
    var window: [windowed_history.scratch_len]u8 = undefined;
    var output: [48]u8 = @splat(0xa5);

    try std.testing.expectError(
        error.IntegerOverflow,
        deflate.decodePngWindowedRle258ZlibImageWithOptions(
            &.{},
            &window,
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
