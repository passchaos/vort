//! A Job owns its frozen accepted-history prefix and its new plaintext.
const std = @import("std");
const core = @import("../../core.zig");
const views = @import("../parallel/job_view.zig");

pub fn Job(comptime Codec: type) type {
    return struct {
        state: enum { free, filling, queued, active, complete, delivering } = .free,
        ordinal: core.StreamCount = 0,
        bytes: std.ArrayList(u8) = .empty,
        prefix_len: usize = 0,
        frame_offset: core.StreamCount = 0,
        final: bool = false,
        output: std.ArrayList(u8) = .empty,
        block_count: usize = 0,
        work: Codec.Profile = .{},
        first_error: ?Codec.Error = null,
        merged: bool = false,
        publication_size: usize = 0,
        published_block_count: usize = 0,
        output_offset: usize = 0,

        pub fn plain(self: *const @This()) []const u8 {
            return self.bytes.items[self.prefix_len..];
        }

        pub fn view(self: *const @This(), window: usize) views.View {
            return .{ .bytes = self.bytes.items, .prefix_len = self.prefix_len, .frame_offset = self.frame_offset, .final = self.final, .window_limit = window };
        }

        pub fn clear(self: *@This()) void {
            self.bytes.clearRetainingCapacity();
            self.output.clearRetainingCapacity();
            const bytes = self.bytes;
            const output = self.output;
            self.* = .{ .bytes = bytes, .output = output };
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.bytes.deinit(allocator);
            self.output.deinit(allocator);
            self.* = .{};
        }
    };
}
