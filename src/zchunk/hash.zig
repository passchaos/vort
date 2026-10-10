const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || error{UnsupportedZchunkHash};

pub const Kind = enum(u8) {
    sha1 = 0,
    sha256 = 1,
    sha512 = 2,
    sha512_128 = 3,

    pub fn digestSize(self: Kind) usize {
        return switch (self) {
            .sha1 => std.crypto.hash.Sha1.digest_length,
            .sha256 => std.crypto.hash.sha2.Sha256.digest_length,
            .sha512 => std.crypto.hash.sha2.Sha512.digest_length,
            .sha512_128 => 16,
        };
    }
};

pub fn fromInt(value: usize) Error!Kind {
    return std.enums.fromInt(Kind, value) orelse error.UnsupportedZchunkHash;
}

pub fn digest(kind: Kind, bytes: []const u8, output: *[64]u8) []const u8 {
    return digestSlices(kind, &.{bytes}, output);
}

pub fn digestSlices(kind: Kind, slices: []const []const u8, output: *[64]u8) []const u8 {
    switch (kind) {
        .sha1 => {
            var state = std.crypto.hash.Sha1.init(.{});
            for (slices) |slice| state.update(slice);
            var result: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
            state.final(&result);
            @memcpy(output[0..result.len], &result);
        },
        .sha256 => {
            var state = std.crypto.hash.sha2.Sha256.init(.{});
            for (slices) |slice| state.update(slice);
            var result: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
            state.final(&result);
            @memcpy(output[0..result.len], &result);
        },
        .sha512, .sha512_128 => {
            var state = std.crypto.hash.sha2.Sha512.init(.{});
            for (slices) |slice| state.update(slice);
            var result: [std.crypto.hash.sha2.Sha512.digest_length]u8 = undefined;
            state.final(&result);
            const length: usize = if (kind == .sha512) result.len else 16;
            @memcpy(output[0..length], result[0..length]);
        },
    }
    return output[0..kind.digestSize()];
}

pub fn isZero(bytes: []const u8) bool {
    for (bytes) |byte| if (byte != 0) return false;
    return true;
}

test "zchunk SHA-512/128 is the first 128 SHA-512 bits" {
    var shortened: [64]u8 = undefined;
    var complete: [64]u8 = undefined;
    try std.testing.expectEqualSlices(
        u8,
        digest(.sha512, "zchunk", &complete)[0..16],
        digest(.sha512_128, "zchunk", &shortened),
    );
}
