//! Reusable stored operation transactions share the exact retained scratch
//! ledger. Caller input/metadata remain borrowed until publication succeeds.
const std = @import("std");
const owner = @import("stored_memory_owner.zig");
const memory = @import("stored_memory.zig");
const alias = @import("stored_alias.zig");
pub const Error = memory.Error;

pub fn owned(self: anytype, input: anytype, options: anytype, comptime bound: anytype, comptime write: anytype) Error![]u8 {
    _ = try bound(input, options);
    var scope = try owner.begin(&self.memory, self.allocator, options, self.scratch.capacity);
    defer scope.deinit();
    const a = scope.allocator();
    const wire = memory.owned(a, input, memory.withoutMemory(options), bound, write) catch |err| return scope.mapError(err);
    errdefer a.free(wire);
    try scope.lease.releaseToCaller(self.allocator, wire.len);
    scope.commit();
    return wire;
}

pub fn scratch(self: anytype, input: anytype, options: anytype, comptime bound: anytype, comptime write: anytype) Error![]const u8 {
    const needed = try bound(input, options);
    var scope = try owner.begin(&self.memory, self.allocator, options, self.scratch.capacity);
    defer scope.deinit();
    const a = scope.allocator();
    if (needed > self.scratch.capacity) {
        // Keep the old allocation and all borrows into it alive until complete
        // encoding into the detached exact replacement has succeeded.
        const replacement = a.alloc(u8, needed) catch |err| return scope.mapError(err);
        errdefer a.free(replacement);
        _ = try write(a, input, replacement, memory.withoutMemory(options));
        self.scratch.deinit(a);
        self.scratch = .{ .items = replacement, .capacity = replacement.len };
    } else {
        const destination = self.scratch.items.ptr[0..needed];
        var protected = alias.protect(a, destination, input, options.metadata) catch |err| return scope.mapError(err);
        defer protected.deinit();
        var inner = memory.withoutMemory(options);
        inner.metadata = protected.metadata();
        _ = try write(a, protected.input(), destination, inner);
        self.scratch.items.len = needed;
    }
    scope.commit();
    return self.scratch.items;
}

pub fn into(self: anytype, input: anytype, output: []u8, options: anytype, comptime bound: anytype, comptime write: anytype) Error!usize {
    const needed = try bound(input, options);
    if (output.len < needed) return error.OutOfMemory;
    if (self.memory.lease == null and self.scratch.capacity == 0 and
        try alias.required(output[0..needed], input, options.metadata) == 0)
    {
        // No retained allocation needs adoption, and this destination cannot
        // require a snapshot. Keep cap-zero calls free of control allocations.
        return memory.into(self.allocator, input, output, options, bound, write);
    }
    var scope = try owner.begin(&self.memory, self.allocator, options, self.scratch.capacity);
    defer scope.deinit();
    // A call-scoped snapshot is charged to the same parent lease. Memory flags
    // are already installed; nested helpers cannot reconfigure or detach them.
    const written = memory.into(scope.allocator(), input, output, memory.withoutMemory(options), bound, write) catch |err| return scope.mapError(err);
    scope.commit();
    return written;
}

pub fn append(self: anytype, output: *std.ArrayList(u8), input: anytype, options: anytype, comptime bound: anytype, comptime write: anytype) Error!void {
    const needed = try bound(input, options);
    const end = std.math.add(usize, output.items.len, needed) catch return error.IntegerOverflow;
    if (self.memory.lease == null and self.scratch.capacity == 0 and
        needed <= output.capacity - output.items.len and
        try alias.required(output.items.ptr[output.items.len..end], input, options.metadata) == 0)
    {
        return memory.append(self.allocator, output, input, options, bound, write);
    }
    var scope = try owner.begin(&self.memory, self.allocator, options, self.scratch.capacity);
    defer scope.deinit();
    try memory.appendScoped(self.allocator, scope.lease, output == &self.scratch, output, input, memory.withoutMemory(options), bound, write);
    scope.commit();
}

test {
    _ = @import("stored_memory_reuse_tests.zig");
}
