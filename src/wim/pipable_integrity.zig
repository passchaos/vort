const std = @import("std");
const format = @import("format.zig");

pub const chunk_size: usize = 10 * 1024 * 1024;

pub const Verifier = struct {
    allocator: std.mem.Allocator,
    enabled: bool,
    max_chunks: usize,
    hashing: bool = false,
    hasher: std.crypto.hash.Sha1 = std.crypto.hash.Sha1.init(.{}),
    chunk_received: usize = 0,
    digests: std.ArrayList([20]u8) = .empty,
    table_digest: [20]u8 = undefined,
    table_digest_received: usize = 0,
    table_digest_index: usize = 0,
    table_digest_count: usize = 0,
    table_len: ?usize = null,
    table_offset: ?u64 = null,

    pub fn init(
        allocator: std.mem.Allocator,
        enabled: bool,
        max_chunks: usize,
    ) Verifier {
        return .{
            .allocator = allocator,
            .enabled = enabled,
            .max_chunks = max_chunks,
        };
    }

    pub fn deinit(self: *Verifier) void {
        self.digests.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn begin(self: *Verifier) !void {
        self.digests.clearRetainingCapacity();
        self.hasher = std.crypto.hash.Sha1.init(.{});
        self.chunk_received = 0;
        self.hashing = self.enabled;
        self.table_digest_received = 0;
        self.table_digest_index = 0;
        self.table_digest_count = 0;
        self.table_len = null;
        self.table_offset = null;
        if (self.enabled and self.max_chunks == 0) return error.OutputLimitExceeded;
    }

    pub fn update(self: *Verifier, bytes: []const u8) !void {
        if (!self.hashing or bytes.len == 0) return;
        var offset: usize = 0;
        while (offset < bytes.len) {
            const take = @min(
                chunk_size - self.chunk_received,
                bytes.len - offset,
            );
            self.hasher.update(bytes[offset..][0..take]);
            self.chunk_received += take;
            offset += take;
            if (self.chunk_received == chunk_size) try self.appendDigest();
        }
    }

    pub fn finishCoverage(self: *Verifier) !void {
        if (!self.hashing) return;
        if (self.chunk_received != 0) try self.appendDigest();
        self.hashing = false;
    }

    pub fn startTable(self: *Verifier, prefix: *const [12]u8, offset: u64) !void {
        const table_len: usize = format.readU32(prefix, 0);
        const count: usize = format.readU32(prefix, 4);
        const declared_chunk_size: usize = format.readU32(prefix, 8);
        if (count > self.max_chunks) return error.OutputLimitExceeded;
        const expected_len = std.math.add(
            usize,
            12,
            std.math.mul(usize, count, 20) catch return error.IntegerOverflow,
        ) catch return error.IntegerOverflow;
        if (table_len != expected_len or declared_chunk_size == 0)
            return error.InvalidWim;
        if (self.enabled) {
            if (declared_chunk_size != chunk_size) return error.UnsupportedWimFeature;
            if (count != self.digests.items.len) return error.InvalidWim;
        }
        self.table_len = table_len;
        self.table_offset = offset;
        self.table_digest_count = count;
        self.table_digest_index = 0;
        self.table_digest_received = 0;
    }

    pub fn consumeTable(self: *Verifier, input: []const u8) !usize {
        var consumed: usize = 0;
        while (self.table_digest_index < self.table_digest_count and consumed < input.len) {
            const take = @min(
                self.table_digest.len - self.table_digest_received,
                input.len - consumed,
            );
            @memcpy(
                self.table_digest[self.table_digest_received..][0..take],
                input[consumed..][0..take],
            );
            self.table_digest_received += take;
            consumed += take;
            if (self.table_digest_received != self.table_digest.len) break;
            if (self.enabled and !std.mem.eql(
                u8,
                &self.table_digest,
                &self.digests.items[self.table_digest_index],
            )) return error.ChecksumMismatch;
            self.table_digest_received = 0;
            self.table_digest_index += 1;
        }
        return consumed;
    }

    pub fn tableComplete(self: *const Verifier) bool {
        return self.table_digest_index == self.table_digest_count;
    }

    pub fn validateDeclaration(
        self: *const Verifier,
        resource: format.ResourceHeader,
    ) !void {
        if (self.table_len) |table_len| {
            if (resource.isZero() or resource.flags != 0 or
                resource.offset_in_wim != self.table_offset.? or
                resource.size_in_wim != table_len or
                resource.uncompressed_size != table_len)
            {
                return error.InvalidWim;
            }
        } else if (!resource.isZero()) {
            return error.InvalidWim;
        }
    }

    fn appendDigest(self: *Verifier) !void {
        if (self.digests.items.len >= self.max_chunks)
            return error.OutputLimitExceeded;
        var digest: [20]u8 = undefined;
        self.hasher.final(&digest);
        try self.digests.append(self.allocator, digest);
        self.hasher = std.crypto.hash.Sha1.init(.{});
        self.chunk_received = 0;
    }
};

test "pipable integrity verifier crosses the standard chunk boundary" {
    var verifier = Verifier.init(std.testing.allocator, true, 2);
    defer verifier.deinit();
    try verifier.begin();
    var block: [4096]u8 = undefined;
    for (&block, 0..) |*byte, index| byte.* = @truncate(index *% 29 +% 7);
    for (0..chunk_size / block.len) |_| try verifier.update(&block);
    try verifier.update(block[0..17]);
    try verifier.finishCoverage();
    try std.testing.expectEqual(@as(usize, 2), verifier.digests.items.len);

    var prefix: [12]u8 = undefined;
    std.mem.writeInt(u32, prefix[0..4], 52, .little);
    std.mem.writeInt(u32, prefix[4..8], 2, .little);
    std.mem.writeInt(u32, prefix[8..12], chunk_size, .little);
    try verifier.startTable(&prefix, 1234);
    for (verifier.digests.items) |digest| {
        var offset: usize = 0;
        while (offset < digest.len) {
            const consumed = try verifier.consumeTable(digest[offset..][0..1]);
            try std.testing.expectEqual(@as(usize, 1), consumed);
            offset += consumed;
        }
    }
    try std.testing.expect(verifier.tableComplete());
    try verifier.validateDeclaration(.{
        .size_in_wim = 52,
        .flags = 0,
        .offset_in_wim = 1234,
        .uncompressed_size = 52,
    });
}
