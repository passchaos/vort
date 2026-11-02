//! Serialized FSE headers from libzstd 1.6.0 Mozilla 1 MiB level 3.
const std = @import("std");
pub const Mapping = struct { bases: []const usize, bits: []const u8 };
const Fixture = struct { bytes: []const u8, values: []const u16, states: usize, max_log: u4 };
const fixtures = [_]Fixture{
    .{ .bytes = &.{ 0x61, 0x05, 0x84, 0x08, 0x33, 0x8e, 0x41, 0x26, 0x74, 0x1d }, .values = &.{ 22, 1, 2, 2, 1, 1, 1, 1, 3, 7, 6, 8, 6, 2, 4, 7, 5, 3 }, .states = 64, .max_log = 8 },
    .{ .bytes = &.{ 0x12, 0xa0, 0xc0, 0x30, 0x06, 0x82, 0x10, 0x02, 0x84, 0x42, 0x10, 0x02, 0x85, 0xe0, 0x04, 0x42, 0x10, 0x82, 0x11, 0x02, 0x05, 0xe2, 0x58, 0x26, 0x36, 0x04, 0x09, 0x7c }, .values = &.{ 1, 5, 12, 6, 3, 4, 4, 2, 1, 2, 5, 2, 2, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2, 4, 2, 2, 1, 1, 1, 1, 2, 1, 1, 1, 2, 4, 7, 11, 19, 12, 3, 2, 4, 1, 30 }, .states = 128, .max_log = 9 },
    .{ .bytes = &.{ 0x64, 0xa9, 0xb1, 0x0a, 0x52, 0xc1, 0x44, 0x46, 0x93, 0x0e, 0x31, 0x86, 0xa0, 0x08, 0x1a, 0x06, 0x00 }, .values = &.{ 150, 141, 85, 16, 21, 24, 17, 6, 13, 9, 7, 4, 6, 6, 4, 0, 5, 4, 0, 2, 3, 0, 3, 0, 0, 0 }, .states = 512, .max_log = 9 },
};

pub fn check(comptime Table: type, comptime parse_table: anytype, comptime Scalar: type, mappings: [3]Mapping, hits: *usize) !void {
    var expected_hits: usize = 0;
    for (fixtures, mappings) |fixture, mapping| {
        var table: Table = undefined;
        var offset: usize = 0;
        try parse_table(&table, fixture.bytes, &offset, mapping.bases, mapping.bits, mapping.bases.len, fixture.max_log);
        try std.testing.expectEqual(fixture.bytes.len, offset);
        try std.testing.expectEqual(fixture.states, table.len);
        var reference: [512]Scalar.Entry = undefined;
        try Scalar.build(fixture.values, reference[0..fixture.states]);
        for (reference[0..fixture.states], table.entries[0..fixture.states]) |entry, actual| {
            try std.testing.expectEqual(@as(u32, @intCast(mapping.bases[entry.symbol])), actual.base);
            try std.testing.expectEqual(mapping.bits[entry.symbol], actual.additional_bits);
            try std.testing.expectEqual(entry.baseline, actual.next_state);
            try std.testing.expectEqual(entry.bits, actual.state_bits);
        }
        if (fixture.states == 64 or fixture.states == 128) expected_hits += 1;
        try std.testing.expectEqual(expected_hits, hits.*);
        for (0..fixture.bytes.len) |prefix| {
            offset = 0;
            try std.testing.expectError(error.TruncatedFrame, parse_table(&table, fixture.bytes[0..prefix], &offset, mapping.bases, mapping.bits, mapping.bases.len, fixture.max_log));
        }
        try std.testing.expectEqual(expected_hits, hits.*);
    }
}
