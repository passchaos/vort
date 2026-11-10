//! One whole-operation requested-heap ledger for Deflate encoding. Matcher,
//! tokens, every candidate and wire/output allocations share the same policy.
const std = @import("std");
const shared = @import("../../io/requested_heap_budget.zig");
pub const Lease = shared.Lease;
pub const EncodeMemoryProfile = shared.EncodeMemoryProfile;
pub const control_bytes = shared.control_bytes;
pub const isTracked = shared.isTracked;
pub const Error = @import("../../core.zig").Error || std.mem.Allocator.Error || error{WorkingMemoryLimitExceeded};

pub fn requested(options: anytype) bool {
    return options.max_total_working_memory != null or options.memory_profile != null;
}

/// Policy belongs to the outer operation. Inner calls share its allocator,
/// including fallback presets that do not carry the original option fields.
pub fn forward(options: anytype) @TypeOf(options) {
    var inner = options;
    inner.max_total_working_memory = null;
    inner.memory_profile = null;
    if (@hasField(@TypeOf(options), "compression")) inner.compression = forward(inner.compression);
    return inner;
}

pub fn mapError(lease: Lease, err: anyerror) Error {
    if (err == error.OutOfMemory and lease.snapshot().last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
    return @errorCast(err);
}

fn innerArgs(args: anytype) @TypeOf(args) {
    var inner = args;
    inline for (std.meta.fields(@TypeOf(args))) |field| {
        if (@typeInfo(field.type) == .@"struct") {
            if (@hasField(field.type, "max_total_working_memory")) @field(inner, field.name) = forward(@field(inner, field.name));
        }
    }
    return inner;
}

fn begin(caller: std.mem.Allocator, options: anytype, existing: usize) Error!Lease {
    return Lease.init(caller, options.max_total_working_memory, options.memory_profile, existing) catch |err| {
        // Admission still records previously retained capacity as observed peak.
        // This call's borrowed scope ends even when no control state was created.
        if (!isTracked(caller)) if (options.memory_profile) |profile| profile.record(0, options.max_total_working_memory);
        return @errorCast(err);
    };
}

pub fn alloc(caller: std.mem.Allocator, options: anytype, comptime function: anytype, args: anytype) Error![]u8 {
    var lease = try begin(caller, options, 0);
    defer lease.deinit();
    var inner = innerArgs(args);
    inner[0] = lease.allocator();
    const bytes = @call(.auto, function, inner) catch |err| return mapError(lease, err);
    errdefer lease.allocator().free(bytes);
    if (lease.snapshot().hit_limit) return error.WorkingMemoryLimitExceeded;
    try lease.releaseToCaller(caller, bytes.len);
    return bytes;
}

/// Existing caller list capacity participates in the operation but remains
/// owned by caller, including successful growth on an otherwise failed call.
/// The codec's append routines preserve the original logical prefix on failure.
pub fn append(caller: std.mem.Allocator, output: *std.ArrayList(u8), options: anytype, comptime function: anytype, args: anytype) Error!usize {
    var lease = try begin(caller, options, if (isTracked(caller)) 0 else output.capacity);
    defer lease.deinit();
    defer lease.releaseToCaller(caller, output.capacity) catch unreachable;
    const original_length = output.items.len;
    errdefer output.shrinkRetainingCapacity(original_length);
    var inner = innerArgs(args);
    inner[0] = lease.allocator();
    const result = @call(.auto, function, inner) catch |err| return mapError(lease, err);
    if (lease.snapshot().hit_limit) return error.WorkingMemoryLimitExceeded;
    return result;
}

/// Legacy reusable facades retain only a caller-owned ArrayList. Adopt exact
/// scratch capacity at entry, use the shared allocator for all growth/free,
/// then restore physical ownership before closing this operation's ledger.
/// A cap below warmed capacity is rejected before changing scratch bytes.
pub fn reusable(owner: anytype, options: anytype, comptime function: anytype, args: anytype, comptime kind: enum { alloc, append, scratch, into }) Error!switch (kind) {
    .alloc => []u8,
    .append, .into => usize,
    .scratch => []const u8,
} {
    const caller = owner.allocator;
    const output: ?*std.ArrayList(u8) = if (kind == .append) args[1] else null;
    const separate_output = if (output) |out| out != &owner.scratch else false;
    const existing = if (isTracked(caller)) 0 else std.math.add(usize, owner.scratch.capacity, if (separate_output) output.?.capacity else 0) catch return error.IntegerOverflow;
    var lease = try begin(caller, options, existing);
    defer lease.deinit();
    const original_options = if (@hasField(@TypeOf(owner.*), "options")) owner.options else {};
    if (@hasField(@TypeOf(owner.*), "options")) owner.options = forward(options);
    defer if (@hasField(@TypeOf(owner.*), "options")) {
        owner.options = original_options;
    };
    owner.allocator = lease.allocator();
    defer {
        lease.releaseToCaller(caller, owner.scratch.capacity) catch unreachable;
        if (separate_output) lease.releaseToCaller(caller, output.?.capacity) catch unreachable;
        owner.allocator = caller;
    }
    const result = @call(.auto, function, innerArgs(args)) catch |err| return mapError(lease, err);
    if (kind == .alloc) {
        errdefer lease.allocator().free(result);
        try lease.releaseToCaller(caller, result.len);
    }
    return result;
}

/// Reserve first so the prior borrowed scratch result survives a refused call.
pub fn retainScratch(owner: anytype, bytes: []const u8) std.mem.Allocator.Error![]const u8 {
    try owner.scratch.ensureTotalCapacity(owner.allocator, bytes.len);
    owner.scratch.clearRetainingCapacity();
    owner.scratch.appendSliceAssumeCapacity(bytes);
    return owner.scratch.items;
}

/// Direct stored emission requests no new heap or ledger control storage.
/// Warm scratch still participates as existing owner capacity; admission must
/// finish before caller bytes are published, including a lowered cap of zero.
pub fn direct(caller: std.mem.Allocator, options: anytype, existing: usize) Error!void {
    if (isTracked(caller)) {
        var inherited = try begin(caller, options, 0);
        inherited.deinit();
        return;
    }
    if (options.memory_profile) |profile| profile.record(existing, options.max_total_working_memory);
    defer if (options.memory_profile) |profile| profile.record(0, options.max_total_working_memory);
    if (existing > (options.max_total_working_memory orelse std.math.maxInt(usize))) return error.WorkingMemoryLimitExceeded;
}

pub fn value(caller: std.mem.Allocator, options: anytype, comptime function: anytype, args: anytype, comptime Result: type) Error!Result {
    var lease = try begin(caller, options, 0);
    defer lease.deinit();
    var inner = innerArgs(args);
    inner[0] = lease.allocator();
    const result = @call(.auto, function, inner) catch |err| return mapError(lease, err);
    if (lease.snapshot().hit_limit) return error.WorkingMemoryLimitExceeded;
    return result;
}
