//! Split-destination semantic sink for the PNG ring history.
//!
//! The sink owns the ring write cursor and releases complete rows behind the
//! immutable DEFLATE lookback. Matches split at the ring end instead of
//! rebasing retained bytes.
const std = @import("std");
const core = @import("../../core.zig");
const checksum = @import("../../checksum.zig");
const png = @import("../../png.zig");
const ring_history = @import("ring_history.zig");

pub const Error = core.Error;
pub const Ring = ring_history.Ring;
pub const ring_len = ring_history.ring_len;

pub const RingSemanticSink = struct {
    ring: Ring,
    row_len: usize,
    bytes_per_pixel: usize,
    stride: usize,
    height: usize,
    expected_virtual_len: usize,
    output: []u8,
    row_scratch: []u8,
    row_index: usize = 0,
    check_adler: bool,
    adler: checksum.Adler32 = .{},

    pub fn init(
        scratch: []u8,
        row_scratch: []u8,
        output: []u8,
        row_len: usize,
        height: usize,
        bytes_per_pixel: usize,
        expected_virtual_len: usize,
        check_adler: bool,
    ) Error!RingSemanticSink {
        const stride = std.math.add(usize, row_len, 1) catch
            return error.IntegerOverflow;
        const output_len = std.math.mul(usize, row_len, height) catch
            return error.IntegerOverflow;
        if (row_scratch.len < stride or output.len < output_len) {
            return error.OutputTooSmall;
        }
        return .{
            .ring = try Ring.init(scratch),
            .row_len = row_len,
            .bytes_per_pixel = bytes_per_pixel,
            .stride = stride,
            .height = height,
            .expected_virtual_len = expected_virtual_len,
            .output = output[0..output_len],
            .row_scratch = row_scratch[0..stride],
            .check_adler = check_adler,
        };
    }

    pub inline fn hasHeadroom(self: *const RingSemanticSink, count: usize) bool {
        const remaining = self.expected_virtual_len -| self.ring.total_written;
        // At the exact virtual end, allow the compact tail to read the EOB
        // token as long as the ring has room for a maximum match.
        const needed = if (remaining == 0)
            258
        else
            @min(@max(count, 258), remaining);
        const limit = self.ring.writeLimit();
        const space = if (self.ring.write_pos <= limit)
            limit - self.ring.write_pos
        else
            0;
        return space >= needed;
    }

    inline fn writeByte(self: *RingSemanticSink, byte: u8) Error!void {
        if (self.ring.total_written >= self.expected_virtual_len)
            return error.SizeMismatch;
        if (self.ring.write_pos >= self.ring.scratch.len) return error.OutputTooSmall;
        self.ring.scratch[self.ring.write_pos] = byte;
        try self.ring.advanceWrite(1);
    }

    pub inline fn emitSemanticLiteral(self: *RingSemanticSink, entry: u32) Error!void {
        const advance: usize = @intCast((entry >> 8) & 0xf);
        const first: u8 = @truncate(entry >> 16);
        const second: u8 = @truncate(entry >> 24);
        if (advance == 1) {
            try self.writeByte(first);
            // The second lane is harmless speculative output. It is written
            // only when the ring cursor has room, which hasHeadroom guarantees.
            if (self.ring.write_pos < self.ring.scratch.len)
                self.ring.scratch[self.ring.write_pos] = second;
            return;
        }
        try self.writeByte(first);
        try self.writeByte(second);
    }

    pub inline fn emitSemanticLiteralTriple(
        self: *RingSemanticSink,
        first: u32,
        second: u32,
        third: u32,
    ) Error!void {
        const first_advance: usize = @intCast((first >> 8) & 0xf);
        const second_advance: usize = @intCast((second >> 8) & 0xf);
        const third_advance: usize = @intCast((third >> 8) & 0xf);
        const second_offset = first_advance;
        const third_offset = first_advance + second_advance;
        const advance = third_offset + third_advance;
        const pos = self.ring.write_pos;
        self.ring.scratch[pos] = @truncate(first >> 16);
        self.ring.scratch[pos + 1] = @truncate(first >> 24);
        self.ring.scratch[pos + second_offset] = @truncate(second >> 16);
        self.ring.scratch[pos + second_offset + 1] = @truncate(second >> 24);
        self.ring.scratch[pos + third_offset] = @truncate(third >> 16);
        self.ring.scratch[pos + third_offset + 1] = @truncate(third >> 24);
        try self.ring.advanceWrite(advance);
    }

    pub inline fn emitByte(self: *RingSemanticSink, byte: u8) Error!void {
        try self.writeByte(byte);
    }

    pub fn copyMatch(self: *RingSemanticSink, length: usize, distance: usize) Error!void {
        try ringCopyMatch(&self.ring, length, distance);
    }

    pub fn drainRows(self: *RingSemanticSink, final: bool) Error!void {
        while (self.row_index < self.height and
            (final or self.ring.hasReleasableRow(self.stride)))
        {
            if (self.ring.total_consumed + self.stride > self.ring.total_written)
                break;
            const encoded_row = try self.ring.currentRow(
                self.stride,
                self.row_scratch,
            );
            const filter = encoded_row[0];
            if (filter > @intFromEnum(png.PngFilterMethod.paeth))
                return error.CorruptFrame;
            if (self.check_adler) self.adler.update(encoded_row);
            const output_offset = self.row_index * self.row_len;
            const row = self.output[output_offset..][0..self.row_len];
            const previous: ?[]const u8 = if (output_offset == 0)
                null
            else
                self.output[output_offset - self.row_len ..][0..self.row_len];
            _ = try png.reconstructPngScanline(
                filter,
                encoded_row[1..],
                previous,
                self.bytes_per_pixel,
                row,
            );
            try self.ring.releaseRow(self.stride);
            self.row_index += 1;
        }
    }

    pub fn finish(self: *const RingSemanticSink) Error!void {
        if (self.ring.total_written != self.expected_virtual_len or
            self.row_index != self.height)
        {
            return error.SizeMismatch;
        }
    }

    pub inline fn adlerDigest(self: *const RingSemanticSink) u32 {
        return self.adler.digest();
    }
};

/// Copies a DEFLATE match into the ring, splitting destination and source spans
/// at the ring end. The caller guarantees the destination fits before
/// `writeLimit`; this helper only performs the copy and cursor advance.
pub fn ringCopyMatch(ring: *Ring, length: usize, distance: usize) Error!void {
    if (length == 0 or distance == 0 or distance > ring.total_written)
        return error.InvalidMatch;
    const ring_size = ring.scratch.len;
    if (length > ring_size) return error.OutputTooSmall;
    const dest_start = ring.write_pos;
    const source_virtual = ring.total_written - distance;
    if (distance == 1) {
        const byte = ring.scratch[source_virtual % ring_size];
        var copied: usize = 0;
        while (copied < length) {
            const destination = (dest_start + copied) % ring_size;
            const chunk = @min(length - copied, ring_size - destination);
            @memset(ring.scratch[destination..][0..chunk], byte);
            copied += chunk;
        }
    } else if (distance >= length) {
        var copied: usize = 0;
        while (copied < length) {
            const source = (source_virtual + copied) % ring_size;
            const destination = (dest_start + copied) % ring_size;
            const chunk = @min(
                length - copied,
                @min(ring_size - source, ring_size - destination),
            );
            @memcpy(
                ring.scratch[destination..][0..chunk],
                ring.scratch[source..][0..chunk],
            );
            copied += chunk;
        }
    } else {
        var copied: usize = 0;
        while (copied < length) : (copied += 1) {
            const source = (source_virtual + copied) % ring_size;
            const destination = (dest_start + copied) % ring_size;
            ring.scratch[destination] = ring.scratch[source];
        }
    }
    try ring.advanceWrite(length);
}

test "ring match splits at the ring end and preserves the source" {
    var scratch: [ring_history.ring_len]u8 = undefined;
    for (&scratch, 0..) |*byte, index| byte.* = @truncate(index *% 29);
    var ring = try Ring.init(&scratch);
    ring.total_written = ring.scratch.len - 5;
    ring.write_pos = ring.scratch.len - 5;
    const source = ring.total_written - 50;
    const expected = [_]u8{
        scratch[source],     scratch[source + 1], scratch[source + 2],
        scratch[source + 3], scratch[source + 4], scratch[source + 5],
        scratch[source + 6], scratch[source + 7], scratch[source + 8],
        scratch[source + 9],
    };
    try ringCopyMatch(&ring, 10, 50);
    for (expected, 0..) |byte, index| {
        const destination = (ring.scratch.len - 5 + index) % ring.scratch.len;
        try std.testing.expectEqual(byte, ring.scratch[destination]);
    }
    try std.testing.expectEqual(@as(usize, 5), ring.write_pos);
    try std.testing.expectEqual(ring.scratch.len + 5, ring.total_written);
}

test "ring RLE match fills across the ring end" {
    var scratch: [ring_history.ring_len]u8 = undefined;
    @memset(&scratch, 0);
    var ring = try Ring.init(&scratch);
    ring.total_written = ring.scratch.len - 5;
    ring.write_pos = ring.scratch.len - 5;
    ring.scratch[ring.scratch.len - 6] = 0xab;
    try ringCopyMatch(&ring, 10, 1);
    for (0..10) |index| {
        const destination = (ring.scratch.len - 5 + index) % ring.scratch.len;
        try std.testing.expectEqual(@as(u8, 0xab), ring.scratch[destination]);
    }
}

test "ring sink writes literals matches and reconstructs rows" {
    var scratch: [ring_history.ring_len]u8 = undefined;
    var row_scratch: [5]u8 = undefined;
    var output: [8]u8 = undefined;
    var sink = try RingSemanticSink.init(
        &scratch,
        &row_scratch,
        &output,
        4,
        2,
        1,
        10,
        false,
    );
    try sink.emitByte(0);
    try sink.emitByte(1);
    try sink.emitByte(2);
    try sink.emitByte(3);
    try sink.emitByte(4);
    try sink.emitByte(0);
    try sink.copyMatch(4, 5);
    try sink.drainRows(true);
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4, 1, 2, 3, 4 }, &output);
    try sink.finish();
}
