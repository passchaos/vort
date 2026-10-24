//! Stored writers know their exact wire bound. Caller-owned destination bytes
//! remain outside a new operation's heap, while outputs and aliases are tracked
//! by the one canonical requested-heap lease when actual allocation is needed.
const std = @import("std");
const total = @import("total_budget.zig");
const alias = @import("stored_alias.zig");
pub const Error = @import("../../core.zig").Error || total.Error;

pub fn withoutMemory(options: anytype) @TypeOf(options) {
    var inner = options;
    inner.max_total_working_memory = null;
    inner.memory_profile = null;
    return inner;
}

fn zeroHeap(options: anytype) void {
    if (options.memory_profile) |profile| profile.record(0, options.max_total_working_memory);
}

fn zeroHeapOrInherit(backing: std.mem.Allocator, options: anytype) Error!void {
    if (total.isTracked(backing)) {
        var child = try total.Lease.init(backing, options.max_total_working_memory, options.memory_profile, 0);
        child.deinit();
    } else zeroHeap(options);
}

pub fn owned(backing: std.mem.Allocator, input: anytype, options: anytype, comptime bound: anytype, comptime write: anytype) Error![]u8 {
    const needed = try bound(input, options);
    var lease = try total.Lease.init(backing, options.max_total_working_memory, options.memory_profile, 0);
    defer lease.deinit();
    lease.beginOperation();
    const a = lease.allocator();
    const output = a.alloc(u8, needed) catch |err| return lease.translateError(err);
    errdefer a.free(output);
    const written = try write(a, input, output, withoutMemory(options));
    if (written != needed) return error.SizeMismatch;
    try lease.releaseToCaller(backing, output.len);
    return output;
}

/// The caller has already validated options and destination size. Snapshots
/// finish before the bounded writer touches any caller byte.
pub fn into(backing: std.mem.Allocator, input: anytype, output: []u8, options: anytype, comptime bound: anytype, comptime write: anytype) Error!usize {
    const needed = try bound(input, options);
    if (output.len < needed) return error.OutOfMemory;
    const destination = output[0..needed];
    const required = try alias.required(destination, input, options.metadata);
    if (required == 0) {
        // Creating a control for an operation that cannot allocate would make
        // zero a false rejection. Existing outer policy remains untouched.
        try zeroHeapOrInherit(backing, options);
        return write(backing, input, destination, withoutMemory(options));
    }
    var lease = try total.Lease.init(backing, options.max_total_working_memory, options.memory_profile, 0);
    defer lease.deinit();
    lease.beginOperation();
    const a = lease.allocator();
    var protected = alias.protect(a, destination, input, options.metadata) catch |err| return map(lease, err);
    defer protected.deinit();
    var inner = withoutMemory(options);
    inner.metadata = protected.metadata();
    return write(a, protected.input(), destination, inner);
}

/// Growth uses an exact replacement instead of mutating the caller's buffer.
/// Borrows into its old allocation therefore stay valid until publication.
pub fn append(backing: std.mem.Allocator, output: *std.ArrayList(u8), input: anytype, options: anytype, comptime bound: anytype, comptime write: anytype) Error!void {
    const needed = try bound(input, options);
    const end = std.math.add(usize, output.items.len, needed) catch return error.IntegerOverflow;
    if (needed <= output.capacity - output.items.len) {
        const allocation = output.items.ptr[output.items.len..end];
        const required = try alias.required(allocation, input, options.metadata);
        if (required == 0) {
            try zeroHeapOrInherit(backing, options);
            _ = try write(backing, input, output.items.ptr[output.items.len..end], withoutMemory(options));
            output.items.len = end;
            return;
        }
        var lease = try total.Lease.init(backing, options.max_total_working_memory, options.memory_profile, 0);
        defer lease.deinit();
        lease.beginOperation();
        const a = lease.allocator();
        var protected = alias.protect(a, allocation, input, options.metadata) catch |err| return map(lease, err);
        defer protected.deinit();
        var inner = withoutMemory(options);
        inner.metadata = protected.metadata();
        _ = try write(a, protected.input(), output.items.ptr[output.items.len..end], inner);
        output.items.len = end;
        return;
    }
    var lease = try total.Lease.init(backing, options.max_total_working_memory, options.memory_profile, 0);
    defer lease.deinit();
    lease.beginOperation();
    const a = lease.allocator();
    const replacement = a.alloc(u8, end) catch |err| return lease.translateError(err);
    errdefer a.free(replacement);
    @memcpy(replacement[0..output.items.len], output.items);
    const written = try write(a, input, replacement[output.items.len..end], withoutMemory(options));
    if (written != needed) return error.SizeMismatch;
    // Validate ownership transfer before releasing the original caller buffer.
    try lease.releaseToCaller(backing, replacement.len);
    output.deinit(backing);
    output.* = .{ .items = replacement, .capacity = replacement.len };
}

/// Reusable operations have already adopted their own scratch. An independent
/// caller output still uses the original backing allocator for its old bytes.
pub fn appendScoped(backing: std.mem.Allocator, lease: total.Lease, owned_output: bool, output: *std.ArrayList(u8), input: anytype, options: anytype, comptime bound: anytype, comptime write: anytype) Error!void {
    const needed = try bound(input, options);
    const end = std.math.add(usize, output.items.len, needed) catch return error.IntegerOverflow;
    const a = lease.allocator();
    if (needed <= output.capacity - output.items.len) {
        var protected = alias.protect(a, output.items.ptr[output.items.len..end], input, options.metadata) catch |err| return map(lease, err);
        defer protected.deinit();
        var inner = withoutMemory(options);
        inner.metadata = protected.metadata();
        _ = try write(a, protected.input(), output.items.ptr[output.items.len..end], inner);
        output.items.len = end;
        return;
    }
    const replacement = a.alloc(u8, end) catch |err| return lease.translateError(err);
    errdefer a.free(replacement);
    @memcpy(replacement[0..output.items.len], output.items);
    const written = try write(a, input, replacement[output.items.len..end], withoutMemory(options));
    if (written != needed) return error.SizeMismatch;
    if (!owned_output) try lease.releaseToCaller(backing, replacement.len);
    output.deinit(if (owned_output) a else backing);
    output.* = .{ .items = replacement, .capacity = replacement.len };
}

pub fn map(lease: total.Lease, err: anyerror) Error {
    if (err == error.OutOfMemory) return lease.translateError(error.OutOfMemory);
    inline for (@typeInfo(Error).error_set.?) |known|
        if (err == @field(Error, known.name)) return @field(Error, known.name);
    return error.InvalidBlockPlan;
}
