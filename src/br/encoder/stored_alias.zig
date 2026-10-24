//! Operation-scoped stored input and metadata snapshots. Stored encoders keep
//! only bytes, so these borrows cannot escape into a retained matcher cache.
const std = @import("std");
const alias = @import("hq_codec/alias.zig");
pub const Error = std.mem.Allocator.Error || error{ IntegerOverflow, InvalidBlockPlan };

pub fn Protected(comptime Input: type) type {
    return struct {
        data: alias.Snapshot,
        metadata_snapshot: alias.Snapshot,

        pub fn input(self: *const @This()) Input {
            return if (Input == []const u8) self.data.getInput() else self.data.getChunks();
        }

        pub fn metadata(self: *const @This()) []const u8 {
            return self.metadata_snapshot.getInput();
        }

        pub fn deinit(self: *@This()) void {
            self.metadata_snapshot.deinit();
            self.data.deinit();
        }
    };
}

pub fn protect(allocator: std.mem.Allocator, allocation: []const u8, input: anytype, metadata: []const u8) Error!Protected(@TypeOf(input)) {
    const snapshot = if (@TypeOf(input) == []const u8)
        alias.Snapshot.initInput(allocator, allocation, input, .{})
    else
        alias.Snapshot.initChunks(allocator, allocation, input, .{});
    var data = snapshot catch |err| return map(err);
    errdefer data.deinit();
    const metadata_snapshot = alias.Snapshot.initInput(allocator, allocation, metadata, .{}) catch |err| return map(err);
    return .{ .data = data, .metadata_snapshot = metadata_snapshot };
}

fn map(err: anyerror) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.IntegerOverflow => error.IntegerOverflow,
        else => error.InvalidBlockPlan,
    };
}
