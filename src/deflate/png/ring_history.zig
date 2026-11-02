//! Ring-buffer filtered-history window for the PNG inflater.
//!
//! The immutable DEFLATE lookback is 32 KiB. A ring removes the periodic
//! compaction copy: released rows are reconstructed behind the lookback, the
//! write wraps at the ring end, and the oldest bytes are overwritten only
//! after their rows have been released.
const std = @import("std");
const core = @import("../../core.zig");
const checksum = @import("../../checksum.zig");
const png = @import("../../png.zig");
const history = @import("windowed_history.zig");

pub const Error = core.Error;

/// Four DEFLATE windows leave a 96 KiB append region after the immutable
/// lookback and comfortably cover one maximum-size row plus speculative
/// headroom.
pub const ring_len: usize = 4 * history.lookback_len;

pub const Ring = struct {
    scratch: []u8,
    /// Ring position of the next filtered byte to write.
    write_pos: usize = 0,
    /// Ring position of the oldest unreleased filtered row.
    row_start: usize = 0,
    total_written: usize = 0,
    total_consumed: usize = 0,

    pub fn init(scratch: []u8) Error!Ring {
        if (scratch.len < 2 * history.lookback_len) return error.OutputTooSmall;
        return .{ .scratch = scratch };
    }

    pub fn output(self: *Ring) []u8 {
        return self.scratch;
    }

    /// The write may proceed up to the oldest unreleased row. When the write
    /// is already past that row in the current lap, the rest of the lap is
    /// free and the ring end is the limit.
    pub fn writeLimit(self: *const Ring) usize {
        if (self.write_pos <= self.row_start) {
            // At the very start there are no unreleased rows yet.
            if (self.row_start == 0 and self.write_pos == 0 and
                self.total_written == 0)
            {
                return self.scratch.len;
            }
            return self.row_start;
        }
        return self.scratch.len;
    }

    pub fn hasReleasableRow(self: *const Ring, stride: usize) bool {
        if (stride == 0 or stride > history.lookback_len) return false;
        if (self.total_consumed + stride > self.total_written) return false;
        return self.total_consumed + stride <=
            self.total_written -| history.lookback_len;
    }

    /// Returns a contiguous filtered row. A row crossing the ring end is
    /// copied into `row_scratch`; callers must keep it alive until release.
    pub fn currentRow(self: *const Ring, stride: usize, row_scratch: []u8) Error![]u8 {
        if (stride == 0 or self.total_consumed + stride > self.total_written) {
            return error.SizeMismatch;
        }
        const start = self.row_start;
        if (start + stride <= self.scratch.len) {
            return self.scratch[start..][0..stride];
        }
        if (row_scratch.len < stride) return error.OutputTooSmall;
        const first = self.scratch.len - start;
        @memcpy(row_scratch[0..first], self.scratch[start..]);
        @memcpy(row_scratch[first..stride], self.scratch[0 .. stride - first]);
        return row_scratch[0..stride];
    }

    pub fn releaseRow(self: *Ring, stride: usize) Error!void {
        if (self.total_consumed + stride > self.total_written) {
            return error.SizeMismatch;
        }
        self.total_consumed += stride;
        self.row_start = (self.row_start + stride) % self.scratch.len;
    }

    pub fn advanceWrite(self: *Ring, count: usize) Error!void {
        self.total_written = std.math.add(
            usize,
            self.total_written,
            count,
        ) catch return error.IntegerOverflow;
        self.write_pos = (self.write_pos + count) % self.scratch.len;
    }

    /// Start a new lap after the loop stopped at the ring end.
    pub fn wrap(self: *Ring) void {
        self.write_pos = 0;
    }
};

pub const ImageState = struct {
    ring: Ring,
    info: png.PngImageInfo,
    output: []u8,
    row_scratch: []u8,
    row_index: usize = 0,
    inflated_total: usize = 0,
    adler: checksum.Adler32 = .{},
    check_adler: bool,

    pub fn init(
        scratch: []u8,
        row_scratch: []u8,
        info: png.PngImageInfo,
        output: []u8,
        check_adler: bool,
    ) Error!ImageState {
        const output_len = try png.pngImageOutputLen(info);
        if (output.len < output_len) return error.OutputTooSmall;
        if (info.row_len >= history.lookback_len) {
            return error.UnsupportedDeflateFeature;
        }
        return .{
            .ring = try Ring.init(scratch),
            .info = info,
            .output = output[0..output_len],
            .row_scratch = row_scratch,
            .check_adler = check_adler,
        };
    }

    pub inline fn decodeOutput(self: *ImageState) []u8 {
        return self.ring.output();
    }

    pub inline fn writeLimit(self: *const ImageState) usize {
        return self.ring.writeLimit();
    }

    pub inline fn consumeStep(
        self: *ImageState,
        old_write_pos: usize,
        new_write_pos: usize,
        final: bool,
    ) Error!bool {
        if (new_write_pos < old_write_pos) return error.SizeMismatch;
        try self.ring.advanceWrite(new_write_pos - old_write_pos);
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

    pub fn finish(self: *ImageState) Error!void {
        if (self.inflated_total != self.info.zlib_payload_len or
            self.row_index != self.info.height)
        {
            return error.SizeMismatch;
        }
        if (self.ring.total_written != self.ring.scratch.len) {
            return error.SizeMismatch;
        }
    }

    pub inline fn adlerDigest(self: *const ImageState) u32 {
        return self.adler.digest();
    }

    inline fn drainRows(self: *ImageState, final: bool) Error!void {
        const stride = self.info.row_len + 1;
        while (self.row_index < self.info.height and
            (final or self.ring.hasReleasableRow(stride)))
        {
            if (self.ring.total_consumed + stride > self.ring.total_written) break;
            const encoded_row = try self.ring.currentRow(stride, self.row_scratch);
            const filter = encoded_row[0];
            if (filter > @intFromEnum(png.PngFilterMethod.paeth)) {
                return error.CorruptFrame;
            }
            if (self.check_adler) self.adler.update(encoded_row);
            const output_offset = self.row_index * self.info.row_len;
            const row = self.output[output_offset..][0..self.info.row_len];
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
            try self.ring.releaseRow(stride);
            self.row_index += 1;
        }
    }
};

test "ring history wraps rows and releases behind the lookback" {
    var scratch: [ring_len]u8 = undefined;
    for (&scratch, 0..) |*byte, index| byte.* = @truncate(index *% 37);
    var ring = try Ring.init(&scratch);
    const stride = 1201;
    try ring.advanceWrite(scratch.len + stride);
    ring.row_start = scratch.len - 100;
    ring.total_consumed = scratch.len - 100;
    var row_scratch: [stride]u8 = undefined;
    const row = try ring.currentRow(stride, &row_scratch);
    try std.testing.expectEqualSlices(
        u8,
        scratch[scratch.len - 100 ..],
        row[0..100],
    );
    try std.testing.expectEqualSlices(
        u8,
        scratch[0 .. stride - 100],
        row[100..],
    );
    try ring.releaseRow(stride);
    try std.testing.expectEqual(
        (scratch.len - 100 + stride) % scratch.len,
        ring.row_start,
    );
    try std.testing.expectEqual(scratch.len - 100 + stride, ring.total_consumed);
}
