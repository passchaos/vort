const std = @import("std");

pub const marker = [4]u8{ 0x00, 0x00, 0xff, 0xff };

pub const Point = struct {
    marker_offset: usize,
    resume_offset: usize,
};

pub fn find(input: []const u8) ?Point {
    var scanner: Scanner = .{};
    return scanner.scan(input).point;
}

pub const ScanResult = struct {
    input_read: usize,
    point: ?Point = null,
};

/// Fragmentation-independent scanner matching zlib's inflateSync search for
/// the byte-aligned empty stored LEN/NLEN marker `00 00 ff ff`.
pub const Scanner = struct {
    matched: u3 = 0,
    total_input: usize = 0,
    done: bool = false,

    pub fn reset(self: *Scanner) void {
        self.* = .{};
    }

    pub fn scan(self: *Scanner, input: []const u8) ScanResult {
        if (self.done) return .{ .input_read = 0 };
        const prefix = [_]u3{ 0, 1, 0, 0 };
        for (input, 0..) |byte, index| {
            while (self.matched != 0 and byte != marker[self.matched])
                self.matched = prefix[self.matched - 1];
            if (byte == marker[self.matched]) self.matched += 1;
            self.total_input += 1;
            if (self.matched == marker.len) {
                self.done = true;
                return .{
                    .input_read = index + 1,
                    .point = .{
                        .marker_offset = self.total_input - marker.len,
                        .resume_offset = self.total_input,
                    },
                };
            }
        }
        return .{ .input_read = input.len };
    }
};

test "deflate sync scanner handles overlaps and fragmented markers" {
    const input = "noise\x00\x00\x00\xff\x00\x00\xff\xffsuffix";
    const expected = Point{ .marker_offset = 9, .resume_offset = 13 };
    try std.testing.expectEqualDeep(expected, find(input).?);

    var scanner: Scanner = .{};
    var found: ?Point = null;
    for (input) |byte| {
        const result = scanner.scan(&.{byte});
        try std.testing.expectEqual(@as(usize, 1), result.input_read);
        if (result.point) |point| {
            found = point;
            break;
        }
    }
    try std.testing.expectEqualDeep(expected, found.?);
}

test "deflate sync scanner rejects partial and can reset" {
    var scanner: Scanner = .{};
    try std.testing.expect(scanner.scan("\x00\x00\xff").point == null);
    try std.testing.expect(scanner.scan("x").point == null);
    scanner.reset();
    const found = scanner.scan("\x00\x00\xff\xff").point.?;
    try std.testing.expectEqual(@as(usize, 0), found.marker_offset);
    try std.testing.expectEqual(@as(usize, 4), found.resume_offset);
    try std.testing.expectEqual(@as(usize, 0), scanner.scan("ignored").input_read);
}
