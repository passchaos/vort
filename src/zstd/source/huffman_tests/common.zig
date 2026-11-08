const std = @import("std");
const byte_source = @import("../../../io/source.zig");
const header = @import("../../literals/header.zig");
pub const source_huffman = @import("../huffman.zig");
pub const source_input = @import("../input.zig");
pub const source_literals = @import("../literals.zig");

pub const direct_description = [_]u8{ 0x83, 0x11, 0x11 };
/// One explicit weight; the low nibble is padding and must be ignored.
pub const minimum_direct_description = [_]u8{ 0x80, 0x1f };
/// 128 explicit weight-4 symbols plus the implied final symbol.
pub const maximum_direct_description = [_]u8{0xff} ++ [_]u8{0x44} ** 64;
pub const fse_description = [_]u8{
    0x37, 0x10, 0x65, 0x7a, 0x2b, 0x5c, 0xbc, 0x99,
    0x16, 0x77, 0xa0, 0xb3, 0xd9, 0x56, 0xae, 0x1a,
    0xa7, 0x6a, 0xc1, 0x32, 0xb2, 0x9a, 0x16, 0x9a,
    0xb2, 0xab, 0xdc, 0xef, 0x38, 0xe4, 0x38, 0xa8,
    0xe6, 0x2e, 0x6e, 0x87, 0x51, 0x10, 0x8b, 0xab,
    0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa,
    0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0xaa, 0x6a, 0x82,
};

pub const Mode = enum { normal, zero, excessive, fail };

pub const Span = struct {
    offset: usize,
    len: usize,
};

pub const TrackingSource = struct {
    bytes: []const u8,
    base_offset: u64 = 0,
    max_chunk: usize = std.math.maxInt(usize),
    mode: Mode = .normal,
    fault_call: ?usize = null,
    forbidden: []const Span = &.{},
    calls: usize = 0,
    bytes_returned: usize = 0,
    forbidden_read: bool = false,
    min_observed_offset: ?u64 = null,
    max_observed_offset: u64 = 0,

    pub fn source(self: *TrackingSource, max_read_size: usize) byte_source.Source {
        return .{
            .context = self,
            .len = self.base_offset + @as(u64, @intCast(self.bytes.len)),
            .read_at = readAt,
            .max_read_size = max_read_size,
        };
    }

    pub fn resetAccounting(self: *TrackingSource) void {
        self.calls = 0;
        self.bytes_returned = 0;
        self.forbidden_read = false;
        self.min_observed_offset = null;
        self.max_observed_offset = 0;
    }

    fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *TrackingSource = @ptrCast(@alignCast(raw));
        self.calls += 1;
        self.min_observed_offset = if (self.min_observed_offset) |old| @min(old, offset) else offset;
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
            const span_end = span.offset + span.len;
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
    storage: [256]u8 = @splat(0),
    len: usize = 0,
    header_len: usize = 0,
    description_len: usize = 0,
    stream_len: usize = 0,

    pub fn bytes(self: *const Fixture) []const u8 {
        return self.storage[0..self.len];
    }

    fn appendByte(self: *Fixture, value: u8) void {
        self.storage[self.len] = value;
        self.len += 1;
    }

    fn appendSlice(self: *Fixture, input: []const u8) void {
        @memcpy(self.storage[self.len..][0..input.len], input);
        self.len += input.len;
    }

    fn appendLittle(self: *Fixture, value: u64, len: usize) void {
        for (0..len) |index| self.appendByte(@truncate(value >> @intCast(index * 8)));
    }
};

fn appendHeader(
    fixture: *Fixture,
    kind: header.Kind,
    size_format: u2,
    regenerated_size: usize,
    compressed_size: usize,
) void {
    const wire: u64 = switch (kind) {
        .raw, .rle => if (size_format == 0 or size_format == 2)
            (@as(u64, regenerated_size) << 3) | @intFromEnum(kind)
        else
            (@as(u64, regenerated_size) << 4) |
                (@as(u64, size_format) << 2) | @intFromEnum(kind),
        .compressed, .treeless => blk: {
            const size_bits: u6 = switch (size_format) {
                0, 1 => 10,
                2 => 14,
                3 => 18,
            };
            const values = @as(u64, regenerated_size) |
                (@as(u64, compressed_size) << size_bits);
            break :blk (values << 4) |
                (@as(u64, size_format) << 2) | @intFromEnum(kind);
        },
    };
    fixture.header_len = header.encodedLen(@truncate(wire));
    fixture.appendLittle(wire, fixture.header_len);
}

pub fn compressedFixture(
    description: []const u8,
    size_format: u2,
    valid_jump: bool,
    append_count: bool,
) Fixture {
    var fixture: Fixture = .{};
    fixture.description_len = description.len;
    fixture.stream_len = 10;
    appendHeader(
        &fixture,
        .compressed,
        size_format,
        5,
        fixture.description_len + fixture.stream_len,
    );
    fixture.appendSlice(description);
    if (size_format == 0) {
        fixture.appendSlice(&([_]u8{0xd3} ** 10));
    } else if (valid_jump) {
        fixture.appendSlice(&.{ 1, 0, 1, 0, 1, 0, 0xa1, 0xa2, 0xa3, 0xa4 });
    } else {
        fixture.appendSlice(&.{ 5, 0, 5, 0, 5, 0, 0xb1, 0xb2, 0xb3, 0xb4 });
    }
    if (append_count) fixture.appendByte(0);
    return fixture;
}

pub fn treelessFixture() Fixture {
    var fixture: Fixture = .{};
    fixture.stream_len = 10;
    appendHeader(&fixture, .treeless, 0, 5, fixture.stream_len);
    fixture.appendSlice(&([_]u8{0xc4} ** 10));
    fixture.appendByte(0);
    return fixture;
}

pub fn plainFixture(kind: header.Kind) Fixture {
    std.debug.assert(kind == .raw or kind == .rle);
    var fixture: Fixture = .{};
    appendHeader(&fixture, kind, 0, 2, 0);
    if (kind == .raw)
        fixture.appendSlice("xy")
    else
        fixture.appendByte('x');
    fixture.appendByte(0);
    return fixture;
}

pub fn prefixFor(
    fixture: *const Fixture,
    source: *TrackingSource,
    previous_tree_available: bool,
) !source_literals.PrefixLayout {
    const block = try source_input.Range.init(
        source.source(128),
        source.base_offset,
        fixture.len,
    );
    return source_literals.parsePrefix(block, previous_tree_available);
}

pub fn expectRange(range: source_input.Range, offset: u64, len: u64) !void {
    try std.testing.expectEqual(offset, range.offset);
    try std.testing.expectEqual(len, range.len);
}
