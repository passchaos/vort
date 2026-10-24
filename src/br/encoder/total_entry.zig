//! One operation-wide total quota. Nested public APIs receive the same tracked
//! allocator with their configuration cleared, so no frame resets this limit.
const std = @import("std");
const total_budget = @import("total_budget.zig");
const hq = @import("hq_options.zig");
pub const Error = @import("../../core.zig").Error || total_budget.Error;

pub const Emission = struct {
    profile: ?*hq.HqProfile,
    before: hq.HqProfile.Emitted,
    pub fn rollback(self: Emission) void {
        if (self.profile) |profile| profile.restoreEmitted(self.before);
    }
};

pub fn emission(options: anytype) Emission {
    const profile = if (options.hq) |raw| raw.profile else null;
    return .{ .profile = profile, .before = if (profile) |p| p.emitted() else .{} };
}

pub fn enabled(options: anytype) bool {
    return options.max_total_working_memory != null or options.memory_profile != null;
}

pub fn withoutMemoryOptions(options: anytype) @TypeOf(options) {
    var nested = options;
    nested.max_total_working_memory = null;
    nested.memory_profile = null;
    return nested;
}

pub fn owned(backing: std.mem.Allocator, input: anytype, options: anytype, comptime encode: anytype) Error![]u8 {
    const emitted = emission(options);
    errdefer emitted.rollback();
    var lease = try total_budget.Lease.init(backing, options.max_total_working_memory, options.memory_profile, 0);
    defer lease.deinit();
    const allocator = lease.allocator();
    const wire = encode(allocator, input, withoutMemoryOptions(options)) catch |err| {
        if (err == error.OutOfMemory) return lease.translateError(error.OutOfMemory);
        return err;
    };
    errdefer allocator.free(wire);
    try lease.releaseToCaller(backing, wire.len);
    return wire;
}

pub fn into(backing: std.mem.Allocator, input: anytype, output: []u8, options: anytype, comptime encode: anytype) Error!usize {
    const emitted = emission(options);
    errdefer emitted.rollback();
    var lease = try total_budget.Lease.init(backing, options.max_total_working_memory, options.memory_profile, 0);
    defer lease.deinit();
    const allocator = lease.allocator();
    const wire = encode(allocator, input, withoutMemoryOptions(options)) catch |err| {
        if (err == error.OutOfMemory) return lease.translateError(error.OutOfMemory);
        return err;
    };
    defer allocator.free(wire);
    if (output.len < wire.len) return error.OutOfMemory;
    @memcpy(output[0..wire.len], wire);
    return wire.len;
}

pub fn append(backing: std.mem.Allocator, output: *std.ArrayList(u8), input: anytype, options: anytype, comptime encode: anytype) Error!void {
    const emitted = emission(options);
    errdefer emitted.rollback();
    var lease = try total_budget.Lease.init(backing, options.max_total_working_memory, options.memory_profile, 0);
    defer lease.deinit();
    const allocator = lease.allocator();
    const wire = encode(allocator, input, withoutMemoryOptions(options)) catch |err| {
        if (err == error.OutOfMemory) return lease.translateError(error.OutOfMemory);
        return err;
    };
    defer allocator.free(wire);
    if (wire.len <= output.capacity - output.items.len) {
        output.appendSliceAssumeCapacity(wire);
        return;
    }
    const size = std.math.add(usize, output.items.len, wire.len) catch return error.IntegerOverflow;
    const buffer = allocator.alloc(u8, size) catch |err| return lease.translateError(err);
    @memcpy(buffer[0..output.items.len], output.items);
    @memcpy(buffer[output.items.len..], wire);
    output.deinit(backing);
    output.* = .{ .items = buffer, .capacity = buffer.len };
    lease.releaseToCaller(backing, buffer.len) catch unreachable;
}

/// Bounded output exhaustion can reject a candidate; a total-allocation denial
/// cannot silently turn the same operation into a stored success.
pub fn propagateAllocatorLimit(allocator: std.mem.Allocator) total_budget.Error!void {
    var lease = (try total_budget.Lease.fromAllocator(allocator)) orelse return;
    defer lease.deinit();
    if (lease.snapshot().last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
}
