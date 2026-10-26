//! Fixed mixed-search storage with explicit allocator ownership. Allocation
//! leaves the large arrays uninitialized; the planner initializes only the
//! required fields in place before use, without a returned aggregate temporary.
const std = @import("std");

pub fn Workspace(comptime Cache: type, comptime Prefix: type, comptime Histogram: type) type {
    return struct {
        cache: Cache = undefined,
        prefix: Prefix = undefined,
        histogram: Histogram = undefined,

        pub fn create(allocator: std.mem.Allocator) std.mem.Allocator.Error!*@This() {
            return allocator.create(@This());
        }

        pub fn destroy(self: *@This(), allocator: std.mem.Allocator) void {
            allocator.destroy(self);
        }
    };
}
