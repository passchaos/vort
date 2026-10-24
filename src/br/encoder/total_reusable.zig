//! One retained lease follows a movable reusable encoder and all its buffers.
//! Public output allocations transfer only after the complete wire is ready.
const std = @import("std");
const total = @import("total_budget.zig");
const entry = @import("total_entry.zig");
const retained = @import("total_retained.zig");
const alias = @import("hq_codec/alias.zig");
pub const Error = @import("../../core.zig").Error || total.Error;

pub fn needed(self: anytype, options: anytype) bool {
    return self.total_operation_depth == 0 and (entry.enabled(options) or self.total_memory_lease != null);
}

fn Scope(comptime Pointer: type) type {
    return struct {
        encoder: Pointer,
        backing: std.mem.Allocator,
        lease: total.Lease,

        fn finish(self: @This()) void {
            self.encoder.allocator = self.backing;
            self.encoder.total_operation_depth -= 1;
            if (!self.encoder.total_memory_inherited) self.lease.setProfile(null) catch unreachable;
        }
        fn mapError(self: @This(), err: anyerror) Error {
            if (err == error.OutOfMemory) return self.lease.translateError(error.OutOfMemory);
            inline for (@typeInfo(Error).error_set.?) |known|
                if (err == @field(Error, known.name)) return @field(Error, known.name);
            return error.InvalidBlockPlan;
        }
    };
}

fn begin(self: anytype, options: anytype) Error!Scope(@TypeOf(self)) {
    const backing = self.allocator;
    if (self.total_memory_lease == null) {
        const inherited = total.isTracked(backing);
        const seed = if (inherited) 0 else try retained.reusable(self);
        self.total_memory_lease = try total.Lease.init(backing, options.max_total_working_memory, options.memory_profile, seed);
        self.total_memory_inherited = inherited;
    } else {
        const lease = self.total_memory_lease.?;
        try lease.releaseToCaller(backing, 0);
        if (self.total_memory_inherited) {
            if (entry.enabled(options)) {
                var checked = try total.Lease.init(lease.allocator(), options.max_total_working_memory, options.memory_profile, 0);
                checked.deinit();
            }
        } else {
            const old_limit = lease.snapshot().limit;
            try lease.setLimit(options.max_total_working_memory);
            lease.setProfile(options.memory_profile) catch |err| {
                lease.setLimit(old_limit) catch unreachable;
                return err;
            };
        }
    }
    const lease = self.total_memory_lease.?;
    lease.beginOperation();
    self.allocator = lease.allocator();
    self.compound_matcher.allocator = self.allocator;
    self.serialized_matcher.allocator = self.allocator;
    self.rebindTotalStateAllocator(self.allocator);
    self.total_operation_depth += 1;
    return .{ .encoder = self, .backing = backing, .lease = lease };
}

fn transfer(lease: total.Lease, wire: []u8, caller: std.mem.Allocator) Error![]u8 {
    lease.releaseToCaller(caller, wire.len) catch |err| {
        if (err != error.InvalidBlockPlan) return err;
        var reservation = try lease.tryReserveExternal(wire.len);
        defer reservation.deinit();
        const result = try caller.alloc(u8, wire.len);
        reservation.markAllocated();
        @memcpy(result, wire);
        lease.allocator().free(wire);
        reservation.handoff();
        return result;
    };
    return wire;
}

fn Protected(comptime Input: type, comptime Options: type) type {
    return struct {
        data: alias.Snapshot,
        metadata: alias.Snapshot,
        original_options: Options,
        fn deinit(self: *@This()) void {
            self.metadata.deinit();
            self.data.deinit();
        }
        fn input(self: *const @This()) Input {
            return if (Input == []const u8) self.data.getInput() else self.data.getChunks();
        }
        fn options(self: *const @This()) Options {
            var value = entry.withoutMemoryOptions(self.original_options);
            value.shared_dictionary = self.data.getDictionary();
            value.metadata = self.metadata.getInput();
            return value;
        }
        fn aliases(self: *const @This()) bool {
            return self.data.ownedBytes() != 0 or self.metadata.ownedBytes() != 0;
        }
    };
}

fn protect(self: anytype, allocator: std.mem.Allocator, input: anytype, options: anytype) Error!Protected(@TypeOf(input), @TypeOf(options)) {
    const allocation = self.output.items.ptr[0..self.output.capacity];
    const data = if (@TypeOf(input) == []const u8)
        alias.Snapshot.initInput(allocator, allocation, input, options.shared_dictionary)
    else
        alias.Snapshot.initChunks(allocator, allocation, input, options.shared_dictionary);
    var snapshot = data catch |err| return mapKnown(err);
    errdefer snapshot.deinit();
    const metadata = alias.Snapshot.initInput(allocator, allocation, options.metadata, .{}) catch |err| return mapKnown(err);
    return .{ .data = snapshot, .metadata = metadata, .original_options = options };
}

fn mapKnown(err: anyerror) Error {
    inline for (@typeInfo(Error).error_set.?) |known|
        if (err == @field(Error, known.name)) return @field(Error, known.name);
    return error.InvalidBlockPlan;
}

fn detached(self: anytype, allocator: std.mem.Allocator, input: anytype, options: anytype, comptime encode: anytype) Error![]u8 {
    const Encoder = @typeInfo(@TypeOf(self)).pointer.child;
    var temporary = Encoder.init(allocator);
    defer temporary.deinit();
    return encode(&temporary, allocator, input, options) catch |err| return mapKnown(err);
}

/// A temporary codec may borrow a snapshot only until this operation ends.
/// Retained matchers in the original encoder must never cache those views.
fn detachedScratch(self: anytype, allocator: std.mem.Allocator, protected: anytype, comptime encode: anytype) Error![]const u8 {
    const Encoder = @typeInfo(@TypeOf(self)).pointer.child;
    var temporary = Encoder.init(allocator);
    defer temporary.deinit();
    const wire = encode(&temporary, protected.input(), protected.options()) catch |err| return mapKnown(err);
    try self.output.ensureTotalCapacity(allocator, wire.len);
    self.output.clearRetainingCapacity();
    self.output.appendSliceAssumeCapacity(wire);
    return self.output.items;
}

/// Protect the untracked reusable path with exactly the same snapshots as a
/// total lease. Null means every borrow is independent of retained output.
pub fn aliasScratch(self: anytype, input: anytype, options: anytype, comptime encode: anytype) Error!?[]const u8 {
    var protected = try protect(self, self.allocator, input, options);
    defer protected.deinit();
    if (!protected.aliases()) return null;
    return try detachedScratch(self, self.allocator, &protected, encode);
}

pub fn owned(self: anytype, caller: std.mem.Allocator, input: anytype, options: anytype, comptime encode: anytype) Error![]u8 {
    const emitted = entry.emission(options);
    errdefer emitted.rollback();
    const scope = try begin(self, options);
    defer scope.finish();
    var protected = protect(self, scope.lease.allocator(), input, options) catch |err| return scope.mapError(err);
    defer protected.deinit();
    const wire = (if (options.hq == null and protected.aliases())
        detached(self, scope.lease.allocator(), protected.input(), protected.options(), encode)
    else
        encode(self, scope.lease.allocator(), protected.input(), protected.options())) catch |err| return @errorCast(scope.mapError(err));
    errdefer scope.lease.allocator().free(wire);
    return transfer(scope.lease, wire, caller);
}

pub fn scratch(self: anytype, input: anytype, options: anytype, comptime encode: anytype) Error![]const u8 {
    const emitted = entry.emission(options);
    errdefer emitted.rollback();
    const scope = try begin(self, options);
    defer scope.finish();
    var protected = protect(self, scope.lease.allocator(), input, options) catch |err| return scope.mapError(err);
    defer protected.deinit();
    if (options.hq == null and protected.aliases())
        return detachedScratch(self, scope.lease.allocator(), &protected, encode) catch |err| return scope.mapError(err);
    return encode(self, protected.input(), protected.options()) catch |err| return @errorCast(scope.mapError(err));
}

pub fn into(self: anytype, input: anytype, output: []u8, options: anytype, comptime encode: anytype) Error!usize {
    const emitted = entry.emission(options);
    errdefer emitted.rollback();
    const scope = try begin(self, options);
    defer scope.finish();
    const allocator = scope.lease.allocator();
    var protected = protect(self, allocator, input, options) catch |err| return scope.mapError(err);
    defer protected.deinit();
    const wire = (if (self.isTotalOwnedRange(output) or (options.hq == null and protected.aliases()))
        detached(self, allocator, protected.input(), protected.options(), encode)
    else
        encode(self, allocator, protected.input(), protected.options())) catch |err| return scope.mapError(err);
    defer allocator.free(wire);
    if (output.len < wire.len) return error.OutOfMemory;
    @memcpy(output[0..wire.len], wire);
    return wire.len;
}

pub fn append(self: anytype, output: *std.ArrayList(u8), input: anytype, options: anytype, comptime encode: anytype) Error!void {
    const emitted = entry.emission(options);
    errdefer emitted.rollback();
    const scope = try begin(self, options);
    defer scope.finish();
    const allocator = scope.lease.allocator();
    var protected = protect(self, allocator, input, options) catch |err| return scope.mapError(err);
    defer protected.deinit();
    const owned_output = self.isTotalOwnedOutput(output);
    const wire = (if (owned_output or (options.hq == null and protected.aliases()))
        detached(self, allocator, protected.input(), protected.options(), encode)
    else
        encode(self, allocator, protected.input(), protected.options())) catch |err| return scope.mapError(err);
    defer allocator.free(wire);
    const prefix = output.items;
    if (wire.len <= output.capacity - prefix.len) {
        output.appendSliceAssumeCapacity(wire);
        return;
    }
    const size = std.math.add(usize, prefix.len, wire.len) catch return error.IntegerOverflow;
    const buffer = allocator.alloc(u8, size) catch |err| return @errorCast(scope.mapError(err));
    if (!owned_output) scope.lease.releaseToCaller(scope.backing, 0) catch unreachable;
    @memcpy(buffer[0..prefix.len], prefix);
    @memcpy(buffer[prefix.len..], wire);
    output.deinit(if (owned_output) allocator else scope.backing);
    output.* = .{ .items = buffer, .capacity = buffer.len };
    if (!owned_output) scope.lease.releaseToCaller(scope.backing, buffer.len) catch unreachable;
}
