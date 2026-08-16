const std = @import("std");
const core = @import("../../core.zig");
const checksum = @import("../../checksum.zig");
const png = @import("../../png.zig");

pub const Error = core.Error;

/// DEFLATE can reference at most 32 KiB of prior output. A second 32 KiB half
/// gives the inflater a contiguous append region while the first half retains
/// the immutable lookback, matching image-png's logical buffer model without
/// copying every emitted byte into a separate ring.
pub const lookback_len: usize = 32 * 1024;
pub const scratch_len: usize = 2 * lookback_len;

pub const Window = struct {
    scratch: []u8,
    write_pos: usize = 0,
    row_start: usize = 0,

    pub fn init(scratch: []u8) Error!Window {
        if (scratch.len < scratch_len) return error.OutputTooSmall;
        return .{ .scratch = scratch[0..scratch_len] };
    }

    pub fn output(self: *Window) []u8 {
        return self.scratch;
    }

    /// Return whether the oldest complete row has left the immutable DEFLATE
    /// lookback. The filter byte and all row bytes must be mutable together;
    /// releasing only a prefix of one row would make later PNG reconstruction
    /// impossible even though DEFLATE no longer needs that prefix.
    pub fn hasReleasableRow(
        self: *const Window,
        stride: usize,
    ) bool {
        if (stride == 0 or stride > lookback_len) return false;
        const mutable_end = self.write_pos -|
            @min(self.write_pos, lookback_len);
        return self.row_start <= mutable_end and
            stride <= mutable_end - self.row_start;
    }

    pub fn currentRow(
        self: *Window,
        stride: usize,
    ) Error![]u8 {
        if (stride == 0 or
            self.row_start > self.write_pos or
            stride > self.write_pos - self.row_start)
        {
            return error.SizeMismatch;
        }
        return self.scratch[self.row_start..][0..stride];
    }

    pub fn releaseRow(self: *Window, stride: usize) Error!void {
        _ = try self.currentRow(stride);
        self.row_start += stride;
    }

    /// Discard only rows already reconstructed by the caller. Every retained
    /// byte keeps the same relative order, so direct DEFLATE distances remain
    /// valid after rebasing the linear output cursor.
    pub fn compactReleased(self: *Window) Error!void {
        if (self.row_start == 0) return;
        if (self.row_start > self.write_pos) return error.SizeMismatch;
        const retained = self.write_pos - self.row_start;
        std.mem.copyForwards(
            u8,
            self.scratch[0..retained],
            self.scratch[self.row_start..self.write_pos],
        );
        self.write_pos = retained;
        self.row_start = 0;
    }
};

/// PNG row lifecycle layered over the contiguous DEFLATE history window.
///
/// Keeping row release, reconstruction, Adler accounting, and checked progress
/// here leaves `deflate.zig` responsible only for parsing and driving the hot
/// resumable semantic loop.
pub const ImageState = struct {
    window: Window,
    info: png.PngImageInfo,
    output: []u8,
    row_index: usize = 0,
    inflated_total: usize = 0,
    adler: checksum.Adler32 = .{},
    check_adler: bool,

    pub fn init(
        scratch: []u8,
        info: png.PngImageInfo,
        output: []u8,
        check_adler: bool,
    ) Error!ImageState {
        const output_len = try png.pngImageOutputLen(info);
        if (output.len < output_len) return error.OutputTooSmall;
        // `row_len + 1 > lookback_len` is the logical condition, but spelling
        // it without the addition also rejects forged maximum-size metadata
        // before the later row-stride calculation can overflow.
        if (info.row_len >= lookback_len) {
            return error.UnsupportedDeflateFeature;
        }
        return .{
            .window = try Window.init(scratch),
            .info = info,
            .output = output[0..output_len],
            .check_adler = check_adler,
        };
    }

    pub inline fn decodeOutput(self: *ImageState) []u8 {
        return self.window.output();
    }

    /// Commit one resumable semantic-loop step and release every complete row
    /// which is no longer inside DEFLATE's immutable 32 KiB lookback.
    pub inline fn consumeStep(
        self: *ImageState,
        old_write_pos: usize,
        new_write_pos: usize,
        final: bool,
    ) Error!bool {
        if (new_write_pos < old_write_pos) return error.SizeMismatch;
        self.window.write_pos = new_write_pos;
        self.inflated_total = std.math.add(
            usize,
            self.inflated_total,
            new_write_pos - old_write_pos,
        ) catch return error.IntegerOverflow;
        if (self.inflated_total > self.info.zlib_payload_len) {
            return error.SizeMismatch;
        }

        const rows_before = self.row_index;
        try self.drainRows(final);
        return self.row_index != rows_before;
    }

    pub inline fn compactReleased(self: *ImageState) Error!void {
        try self.window.compactReleased();
    }

    pub fn finish(self: *ImageState) Error!void {
        if (self.inflated_total != self.info.zlib_payload_len or
            self.row_index != self.info.height)
        {
            return error.SizeMismatch;
        }
        try self.window.compactReleased();
        if (self.window.write_pos != 0) return error.SizeMismatch;
    }

    pub inline fn adlerDigest(self: *const ImageState) u32 {
        return self.adler.digest();
    }

    inline fn drainRows(self: *ImageState, final: bool) Error!void {
        const stride = self.info.row_len + 1;
        while (self.row_index < self.info.height and
            (final or self.window.hasReleasableRow(stride)))
        {
            if (stride >
                self.window.write_pos - self.window.row_start) break;
            const encoded_row = try self.window.currentRow(stride);
            const filter = encoded_row[0];
            if (filter > @intFromEnum(png.PngFilterMethod.paeth)) {
                return error.CorruptFrame;
            }
            if (self.check_adler) self.adler.update(encoded_row);

            const output_offset = self.row_index * self.info.row_len;
            const row =
                self.output[output_offset..][0..self.info.row_len];
            const previous: ?[]const u8 = if (output_offset == 0)
                null
            else
                self.output[output_offset - self.info.row_len ..][0..self.info.row_len];
            _ = try png.reconstructPngScanline(
                filter,
                encoded_row[1..],
                previous,
                self.info.bytes_per_pixel,
                row,
            );
            try self.window.releaseRow(stride);
            self.row_index += 1;
        }
    }
};

test "windowed history releases and compacts complete rows only" {
    var scratch: [scratch_len]u8 = undefined;
    for (&scratch, 0..) |*byte, index| byte.* = @truncate(index);
    var window = try Window.init(&scratch);
    const stride = 1201;
    window.write_pos = scratch.len - 17;

    var released: usize = 0;
    while (window.hasReleasableRow(stride)) {
        const row = try window.currentRow(stride);
        try std.testing.expectEqual(
            @as(u8, @truncate(released * stride)),
            row[0],
        );
        try window.releaseRow(stride);
        released += 1;
    }
    try std.testing.expect(released != 0);
    const old_write_pos = window.write_pos;
    const discarded = window.row_start;
    var expected: [scratch_len]u8 = undefined;
    const retained = old_write_pos - discarded;
    @memcpy(
        expected[0..retained],
        scratch[discarded..old_write_pos],
    );

    try window.compactReleased();
    try std.testing.expectEqual(retained, window.write_pos);
    try std.testing.expectEqual(@as(usize, 0), window.row_start);
    try std.testing.expect(window.write_pos >= lookback_len);
    try std.testing.expect(window.write_pos < lookback_len + stride);
    try std.testing.expectEqualSlices(
        u8,
        expected[0..retained],
        scratch[0..retained],
    );
}
