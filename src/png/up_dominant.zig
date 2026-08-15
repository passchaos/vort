const builtin = @import("builtin");
const std = @import("std");
const core = @import("../core.zig");
const png = @import("../png.zig");

pub const Error = core.Error;

pub const ImageDecodeResult = struct {
    rows: usize,
    output_written: usize,
};

/// Dedicated executable section for the narrow whole-image Up specialization.
///
/// Keeping it outside the shared text section prevents a fixture-specific
/// helper from reordering the generic PNG and DEFLATE hot paths.
const text_section = switch (builtin.object_format) {
    .elf => ".vort_png_up_dominant",
    .macho => "__TEXT,__vort_png_up",
    .coff => ".text$vort_png_up",
    else => ".text",
};

/// Bound the prefix probe to RGBA8 images large enough to amortize a separate
/// whole-image dispatch. Other color modes and small icons retain the original
/// drainer without even entering the specialized section.
pub inline fn isCandidate(info: png.PngImageInfo) bool {
    return info.bit_depth == 8 and
        info.color_type == .truecolor_alpha and
        info.row_len >= 1024 and
        info.height >= 128;
}

/// Return true only when an inexpensive prefix proves the image is Up-heavy.
///
/// The first row may use any valid filter because Up has no useful previous
/// row there. Requiring the next fifteen rows to be Up selects the real
/// transparency workload without scanning every filter byte twice; all other
/// images remain on the established generic drainer.
fn hasUpPrefix(
    decoded: []const u8,
    row_len: usize,
    row_count: usize,
) Error!bool {
    if (row_count < 16) return false;
    const stride = std.math.add(usize, row_len, 1) catch
        return error.IntegerOverflow;
    const expected_len = std.math.mul(usize, stride, row_count) catch
        return error.IntegerOverflow;
    if (decoded.len != expected_len) return error.SizeMismatch;
    const first_filter = decoded[0];
    if (first_filter > @intFromEnum(png.PngFilterMethod.paeth)) {
        return error.CorruptFrame;
    }
    for (1..16) |row_index| {
        if (decoded[row_index * stride] !=
            @intFromEnum(png.PngFilterMethod.up))
        {
            return false;
        }
    }
    return true;
}

/// Reconstruct a whole image whose prefix established an Up-dominant shape.
///
/// This loop still validates every later filter. Up rows bypass the generic
/// filter enum/shape dispatch and use the same 32-byte vector add as the public
/// scanline implementation. Non-Up rows retain the generic reference kernel.
pub noinline fn tryReconstruct(
    decoded: []const u8,
    info: png.PngImageInfo,
    output: []u8,
) linksection(text_section) Error!?ImageDecodeResult {
    const output_len = try png.pngImageOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    if (!try hasUpPrefix(decoded, info.row_len, info.height)) {
        return null;
    }

    const stride = info.row_len + 1;
    var output_offset: usize = 0;
    for (0..info.height) |row_index| {
        const decoded_offset = row_index * stride;
        const filter = decoded[decoded_offset];
        if (filter > @intFromEnum(png.PngFilterMethod.paeth)) {
            return error.CorruptFrame;
        }
        const filtered =
            decoded[decoded_offset + 1 ..][0..info.row_len];
        const row = output[output_offset..][0..info.row_len];
        const previous = if (row_index == 0)
            null
        else
            output[output_offset - info.row_len ..][0..info.row_len];

        if (filter == @intFromEnum(png.PngFilterMethod.up)) {
            if (previous) |prev|
                reconstructUp(filtered, prev, row)
            else
                copyPossiblyAliased(row, filtered);
        } else {
            _ = try png.reconstructPngScanline(
                filter,
                filtered,
                previous,
                info.bytes_per_pixel,
                row,
            );
        }
        output_offset += info.row_len;
    }
    return ImageDecodeResult{
        .rows = info.height,
        .output_written = output_len,
    };
}

fn reconstructUp(
    filtered: []const u8,
    previous: []const u8,
    output: []u8,
) void {
    std.debug.assert(filtered.len == previous.len);
    std.debug.assert(output.len >= filtered.len);
    const lanes = 32;
    var i: usize = 0;
    while (i + lanes <= filtered.len) : (i += lanes) {
        const filtered_vec: @Vector(lanes, u8) =
            filtered[i..][0..lanes].*;
        const previous_vec: @Vector(lanes, u8) =
            previous[i..][0..lanes].*;
        output[i..][0..lanes].* = filtered_vec +% previous_vec;
    }
    while (i < filtered.len) : (i += 1) {
        output[i] = filtered[i] +% previous[i];
    }
}

fn copyPossiblyAliased(output: []u8, input: []const u8) void {
    if (output.ptr == input.ptr) return;
    std.mem.copyForwards(u8, output, input);
}

test "Up prefix policy selects only the intended shape" {
    const row_len = 7;
    const row_count = 16;
    try std.testing.expect(isCandidate(try png.pngImageInfo(
        256,
        128,
        8,
        .truecolor_alpha,
    )));
    try std.testing.expect(!isCandidate(try png.pngImageInfo(
        255,
        128,
        8,
        .truecolor_alpha,
    )));
    try std.testing.expect(!isCandidate(try png.pngImageInfo(
        256,
        128,
        8,
        .truecolor,
    )));
    var decoded: [(row_len + 1) * row_count]u8 = @splat(0);
    for (1..row_count) |row_index| {
        decoded[row_index * (row_len + 1)] =
            @intFromEnum(png.PngFilterMethod.up);
    }
    try std.testing.expect(try hasUpPrefix(
        &decoded,
        row_len,
        row_count,
    ));
    decoded[8 * (row_len + 1)] =
        @intFromEnum(png.PngFilterMethod.sub);
    try std.testing.expect(!try hasUpPrefix(
        &decoded,
        row_len,
        row_count,
    ));
    decoded[0] = 5;
    try std.testing.expectError(
        error.CorruptFrame,
        hasUpPrefix(&decoded, row_len, row_count),
    );
}

test "Up-dominant reconstruction matches scalar mixed rows and tails" {
    const row_len = 257;
    const row_count = 19;
    const info = try png.pngImageInfo(
        row_len,
        row_count,
        8,
        .grayscale,
    );
    var expected: [row_len * row_count]u8 = undefined;
    var decoded: [(row_len + 1) * row_count]u8 = undefined;

    for (0..row_count) |row_index| {
        const expected_row =
            expected[row_index * row_len ..][0..row_len];
        const previous: ?[]const u8 = if (row_index == 0)
            null
        else
            expected[(row_index - 1) * row_len ..][0..row_len];
        const filter: u8 = if (row_index == 0)
            @intFromEnum(png.PngFilterMethod.sub)
        else if (row_index == 17)
            @intFromEnum(png.PngFilterMethod.paeth)
        else
            @intFromEnum(png.PngFilterMethod.up);
        const decoded_offset = row_index * (row_len + 1);
        decoded[decoded_offset] = filter;
        const filtered = decoded[decoded_offset + 1 ..][0..row_len];
        for (expected_row, 0..) |*pixel, column| {
            pixel.* = @truncate(
                row_index *% 53 +%
                    column *% 79 +%
                    (column / 17) *% 11,
            );
        }
        filterRowForTest(
            filter,
            expected_row,
            previous,
            info.bytes_per_pixel,
            filtered,
        );
    }

    var actual: [expected.len]u8 = undefined;
    const result = (try tryReconstruct(&decoded, info, &actual)).?;
    try std.testing.expectEqual(row_count, result.rows);
    try std.testing.expectEqual(expected.len, result.output_written);
    try std.testing.expectEqualSlices(u8, &expected, &actual);

    decoded[18 * (row_len + 1)] = 5;
    try std.testing.expectError(
        error.CorruptFrame,
        tryReconstruct(&decoded, info, &actual),
    );
}

fn filterRowForTest(
    filter: u8,
    row: []const u8,
    previous: ?[]const u8,
    bytes_per_pixel: usize,
    filtered: []u8,
) void {
    for (row, 0..) |pixel, i| {
        const left: u8 =
            if (i >= bytes_per_pixel) row[i - bytes_per_pixel] else 0;
        const up: u8 = if (previous) |prev| prev[i] else 0;
        const up_left: u8 = if (i >= bytes_per_pixel)
            if (previous) |prev| prev[i - bytes_per_pixel] else 0
        else
            0;
        const prediction: u8 = switch (filter) {
            0 => 0,
            1 => left,
            2 => up,
            3 => @intCast(
                (@as(u16, left) + @as(u16, up)) / 2,
            ),
            4 => paethReference(left, up, up_left),
            else => unreachable,
        };
        filtered[i] = pixel -% prediction;
    }
}

fn paethReference(left: u8, up: u8, up_left: u8) u8 {
    const a: i32 = left;
    const b: i32 = up;
    const c: i32 = up_left;
    const p = a + b - c;
    const pa = @abs(p - a);
    const pb = @abs(p - b);
    const pc = @abs(p - c);
    if (pa <= pb and pa <= pc) return left;
    if (pb <= pc) return up;
    return up_left;
}
