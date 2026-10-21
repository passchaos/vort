//! Stable random-access source for large Android OTA payloads and old images.
//!
//! The callback and context remain borrowed. Callers keep their length and
//! bytes stable for the lifetime of an archive or decode operation.

const std = @import("std");

pub const Error = error{
    SourceReadFailed,
    TruncatedFrame,
    IntegerOverflow,
    OutputLimitExceeded,
    ChecksumMismatch,
};

pub const Source = struct {
    context: *anyopaque,
    len: u64,
    read_at: *const fn (
        context: *anyopaque,
        offset: u64,
        output: []u8,
    ) error{SourceReadFailed}!usize,

    pub fn readExact(self: Source, offset: u64, output: []u8) Error!void {
        const length = std.math.cast(u64, output.len) orelse
            return error.IntegerOverflow;
        const end = std.math.add(u64, offset, length) catch
            return error.IntegerOverflow;
        if (end > self.len) return error.TruncatedFrame;
        var written: usize = 0;
        while (written < output.len) {
            const absolute = std.math.add(
                u64,
                offset,
                std.math.cast(u64, written) orelse return error.IntegerOverflow,
            ) catch return error.IntegerOverflow;
            const amount = try self.read_at(self.context, absolute, output[written..]);
            if (amount == 0 or amount > output.len - written)
                return error.TruncatedFrame;
            written += amount;
        }
    }

    pub fn readAllocLimited(
        self: Source,
        allocator: std.mem.Allocator,
        offset: u64,
        length: u64,
        max_length: usize,
    ) (Error || std.mem.Allocator.Error)![]u8 {
        const size = std.math.cast(usize, length) orelse
            return error.OutputLimitExceeded;
        if (size > max_length) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, size);
        errdefer allocator.free(output);
        try self.readExact(offset, output);
        return output;
    }

    pub fn verifySha256(
        self: Source,
        offset: u64,
        length: u64,
        expected: []const u8,
    ) Error!void {
        if (expected.len != 32) return error.ChecksumMismatch;
        const end = std.math.add(u64, offset, length) catch
            return error.IntegerOverflow;
        if (end > self.len) return error.TruncatedFrame;
        var state = std.crypto.hash.sha2.Sha256.init(.{});
        try self.updateSha256(offset, length, &state);
        var actual: [32]u8 = undefined;
        state.final(&actual);
        if (!std.mem.eql(u8, &actual, expected)) return error.ChecksumMismatch;
    }

    pub fn updateSha256(
        self: Source,
        offset: u64,
        length: u64,
        state: *std.crypto.hash.sha2.Sha256,
    ) Error!void {
        const end = std.math.add(u64, offset, length) catch
            return error.IntegerOverflow;
        if (end > self.len) return error.TruncatedFrame;
        var scratch: [64 * 1024]u8 = undefined;
        var consumed: u64 = 0;
        while (consumed < length) {
            const remaining = length - consumed;
            const amount = @min(
                scratch.len,
                std.math.cast(usize, remaining) orelse scratch.len,
            );
            try self.readExact(
                std.math.add(u64, offset, consumed) catch
                    return error.IntegerOverflow,
                scratch[0..amount],
            );
            state.update(scratch[0..amount]);
            consumed += amount;
        }
    }
};

test "Android OTA source completes short reads and verifies ranges" {
    const Context = struct {
        bytes: []const u8,
        max_chunk: usize,

        fn readAt(
            raw_context: *anyopaque,
            offset: u64,
            output: []u8,
        ) error{SourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw_context));
            const start = std.math.cast(usize, offset) orelse
                return error.SourceReadFailed;
            if (start >= self.bytes.len) return 0;
            const amount = @min(output.len, @min(self.max_chunk, self.bytes.len - start));
            @memcpy(output[0..amount], self.bytes[start..][0..amount]);
            return amount;
        }
    };
    var context = Context{ .bytes = "source-backed Android OTA", .max_chunk = 3 };
    const source = Source{
        .context = &context,
        .len = context.bytes.len,
        .read_at = Context.readAt,
    };
    var output: [10]u8 = undefined;
    try source.readExact(7, &output);
    try std.testing.expectEqualSlices(u8, "backed And", &output);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(context.bytes[7..17], &digest, .{});
    try source.verifySha256(7, 10, &digest);
    try std.testing.expectError(
        error.TruncatedFrame,
        source.readExact(context.bytes.len - 2, &output),
    );
}
