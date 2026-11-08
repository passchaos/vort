const std = @import("std");
const byte_source = @import("../../../io/source.zig");

pub const source_frame = @import("../frame.zig");
pub const source_input = @import("../input.zig");
pub const FrameFormat = source_frame.FrameFormat;

/// Normalized result supplied by the established slice frame inspector.
pub const SliceHeaderResult = struct {
    /// Descriptor through the final optional field; excludes standard magic.
    encoded_len: usize,
    content_size: ?u64,
    has_checksum: bool,
    single_segment: bool,
    window_size: u64,
    block_size_max: usize,
    dictionary_id: u32,
    first_block_offset: usize,
};

pub const SliceBlockKind = enum {
    raw,
    rle,
    compressed,
};

/// Normalized result supplied by the established slice block inspector.
pub const SliceBlockResult = struct {
    last: bool,
    kind: SliceBlockKind,
    declared_len: usize,
    wire_len: usize,
    header_offset: usize,
    payload_offset: usize,
    next_header_offset: usize,
};

pub const SourceMode = enum { normal, zero, excessive, fail };

pub const Span = struct {
    offset: usize,
    len: usize,
};

pub const TrackingSource = struct {
    bytes: []const u8,
    base_offset: u64 = 0,
    logical_len: ?u64 = null,
    max_chunk: usize = std.math.maxInt(usize),
    mode: SourceMode = .normal,
    fault_call: ?usize = null,
    forbidden: []const Span = &.{},
    calls: usize = 0,
    bytes_returned: usize = 0,
    max_requested: usize = 0,
    forbidden_read: bool = false,
    min_observed_offset: ?u64 = null,
    max_observed_offset: u64 = 0,

    pub fn source(self: *TrackingSource, max_read_size: usize) byte_source.Source {
        const len = self.logical_len orelse @as(u64, @intCast(self.bytes.len));
        return .{
            .context = self,
            .len = self.base_offset + len,
            .read_at = readAt,
            .max_read_size = max_read_size,
        };
    }

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *TrackingSource = @ptrCast(@alignCast(raw));
        self.calls += 1;
        self.max_requested = @max(self.max_requested, output.len);
        self.min_observed_offset = if (self.min_observed_offset) |old|
            @min(old, offset)
        else
            offset;
        self.max_observed_offset = @max(self.max_observed_offset, offset);

        if (self.fault_call == null or self.fault_call.? == self.calls) {
            switch (self.mode) {
                .zero => return 0,
                .excessive => return output.len + 1,
                .fail => return error.SourceReadFailed,
                .normal => {},
            }
        }
        if (offset < self.base_offset) return error.SourceReadFailed;
        const relative = std.math.cast(usize, offset - self.base_offset) orelse
            return error.SourceReadFailed;
        const request_end = std.math.add(usize, relative, output.len) catch
            return error.SourceReadFailed;
        for (self.forbidden) |span| {
            const span_end = std.math.add(usize, span.offset, span.len) catch
                return error.SourceReadFailed;
            if (relative < span_end and span.offset < request_end) {
                self.forbidden_read = true;
                return error.SourceReadFailed;
            }
        }
        if (relative >= self.bytes.len) return 0;
        const amount = @min(self.max_chunk, @min(output.len, self.bytes.len - relative));
        @memcpy(output[0..amount], self.bytes[relative..][0..amount]);
        self.bytes_returned += amount;
        return amount;
    }
};

pub const Fixture = struct {
    storage: [512]u8 = @splat(0),
    len: usize = 0,

    pub fn bytes(self: *const Fixture) []const u8 {
        return self.storage[0..self.len];
    }

    pub fn appendByte(self: *Fixture, value: u8) void {
        self.storage[self.len] = value;
        self.len += 1;
    }

    pub fn appendRepeat(self: *Fixture, value: u8, len: usize) void {
        @memset(self.storage[self.len..][0..len], value);
        self.len += len;
    }

    pub fn appendLittle(self: *Fixture, value: u64, len: usize) void {
        for (0..len) |index|
            self.appendByte(@truncate(value >> @intCast(index * 8)));
    }
};

const data_magic: u32 = 0xfd2f_b528;

pub fn prefixLen(format: FrameFormat) usize {
    return if (format == .standard) 4 else 0;
}

pub fn dictionaryFieldLen(descriptor: u8) usize {
    return switch (descriptor & 0x03) {
        0 => 0,
        1 => 1,
        2 => 2,
        else => 4,
    };
}

pub fn contentSizeFieldLen(descriptor: u8) usize {
    const single_segment = (descriptor & 0x20) != 0;
    const flag = descriptor >> 6;
    return if (single_segment or flag != 0)
        @as(usize, 1) << @intCast(flag)
    else
        0;
}

pub fn expectedEncodedLen(descriptor: u8) usize {
    return @as(usize, 1) + @intFromBool((descriptor & 0x20) == 0) +
        dictionaryFieldLen(descriptor) + contentSizeFieldLen(descriptor);
}

pub fn encodedContentSize(field_len: usize) u64 {
    return switch (field_len) {
        1 => 0x7f,
        2 => 0x1234,
        4 => 0x1234_5678,
        8 => 0x0807_0605_0403_0201,
        else => 0,
    };
}

pub fn expectedDictionaryId(field_len: usize) u32 {
    return switch (field_len) {
        0 => 0,
        1 => 0x78,
        2 => 0x5678,
        4 => 0x1234_5678,
        else => unreachable,
    };
}

pub fn appendDataHeader(fixture: *Fixture, format: FrameFormat, descriptor: u8) usize {
    const start = fixture.len;
    if (format == .standard) fixture.appendLittle(data_magic, 4);
    fixture.appendByte(descriptor);
    if ((descriptor & 0x20) == 0) fixture.appendByte(0x0b);
    const dictionary_len = dictionaryFieldLen(descriptor);
    fixture.appendLittle(0x1234_5678, dictionary_len);
    const content_len = contentSizeFieldLen(descriptor);
    fixture.appendLittle(encodedContentSize(content_len), content_len);
    return fixture.len - start;
}

pub fn appendBlockHeader(
    fixture: *Fixture,
    declared_len: usize,
    kind_bits: u2,
    last: bool,
) void {
    const encoded = (@as(u64, declared_len) << 3) |
        (@as(u64, kind_bits) << 1) | @intFromBool(last);
    fixture.appendLittle(encoded, 3);
}

pub fn appendBlock(
    fixture: *Fixture,
    declared_len: usize,
    kind: SliceBlockKind,
    last: bool,
) void {
    const kind_bits: u2 = switch (kind) {
        .raw => 0,
        .rle => 1,
        .compressed => 2,
    };
    appendBlockHeader(fixture, declared_len, kind_bits, last);
    fixture.appendRepeat(0xa7, if (kind == .rle) 1 else declared_len);
}

pub fn expectRange(range: source_input.Range, offset: u64, len: u64) !void {
    try std.testing.expectEqual(offset, range.offset);
    try std.testing.expectEqual(len, range.len);
}
