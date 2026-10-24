//! Search-controlled seekable calls stage every member before publication.
//! The old entry table remains initialized and unchanged until both wire and
//! replacement entry capacity are ready. All temporary bytes use the caller's
//! shared encoder allocator and therefore participate in its total heap quota.
const std = @import("std");

pub fn Staged(comptime Entry: type) type {
    return struct {
        wire: std.ArrayList(u8) = .empty,
        entries: std.ArrayList(Entry) = .empty,

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.wire.deinit(allocator);
            self.entries.deinit(allocator);
            self.* = .{};
        }

        pub fn reserveEntries(self: *const @This(), allocator: std.mem.Allocator, destination: *std.ArrayList(Entry)) std.mem.Allocator.Error!void {
            try destination.ensureTotalCapacity(allocator, self.entries.items.len);
        }

        pub fn commitEntries(self: *const @This(), destination: *std.ArrayList(Entry)) void {
            destination.clearRetainingCapacity();
            destination.appendSliceAssumeCapacity(self.entries.items);
        }
    };
}
