const std = @import("std");
const container = @import("../container.zig");

pub fn size(check: container.Check) container.Error!usize {
    return switch (check) {
        .none => 0,
        .crc32 => 4,
        .crc64 => 8,
        .sha256 => 32,
        else => error.UnsupportedXzFeature,
    };
}

pub const State = struct {
    crc32: std.hash.Crc32 = std.hash.Crc32.init(),
    crc64: std.hash.crc.Crc64Xz = std.hash.crc.Crc64Xz.init(),
    sha256: std.crypto.hash.sha2.Sha256 = std.crypto.hash.sha2.Sha256.init(.{}),

    pub fn update(self: *State, kind: container.Check, bytes: []const u8) void {
        switch (kind) {
            .none => {},
            .crc32 => self.crc32.update(bytes),
            .crc64 => self.crc64.update(bytes),
            .sha256 => self.sha256.update(bytes),
            else => unreachable,
        }
    }

    pub fn verify(self: *State, kind: container.Check, stored: []const u8) container.Error!void {
        switch (kind) {
            .none => {},
            .crc32 => if (self.crc32.final() != std.mem.readInt(u32, stored[0..4], .little)) return error.ChecksumMismatch,
            .crc64 => if (self.crc64.final() != std.mem.readInt(u64, stored[0..8], .little)) return error.ChecksumMismatch,
            .sha256 => {
                var actual: [32]u8 = undefined;
                self.sha256.final(&actual);
                if (!std.mem.eql(u8, &actual, stored)) return error.ChecksumMismatch;
            },
            else => return error.UnsupportedXzFeature,
        }
    }
};
