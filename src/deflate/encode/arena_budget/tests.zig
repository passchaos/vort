const std = @import("std");
const arena_budget = @import("../arena_budget.zig");
const budget = @import("../total_budget.zig");
const allocator = std.testing.allocator;
const prefix = "caller-prefix:";
const payload = "message=42;state=nominal;arena=retained;\n" ** 192;

const Message = union(enum) {
    bytes: []const u8,
    chunks: []const []const u8,
};

// Observe only requests reaching the physical backing allocator. Two observers
// can share this meter without joining the output and arena ownership domains.
const Meter = struct {
    live: usize = 0,
    peak: usize = 0,
    allocations: usize = 0,
};

const Observer = struct {
    backing: std.mem.Allocator,
    meter: *Meter,
    live: usize = 0,
    peak: usize = 0,
    requests: usize = 0,
    rejected: usize = 0,
    successful_growths: usize = 0,
    remaining_allocations: ?usize = null,
    deny_growth: bool = false,

    fn get(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn change(self: *@This(), old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
        self.meter.live = self.meter.live - old + new;
        self.meter.peak = @max(self.meter.peak, self.meter.live);
    }

    const vtable: std.mem.Allocator.VTable = .{ .alloc = alloc, .resize = resize, .remap = remap, .free = free };

    fn alloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.requests += 1;
        if (self.remaining_allocations) |remaining| {
            if (remaining == 0) {
                self.rejected += 1;
                return null;
            }
            self.remaining_allocations = remaining - 1;
        }
        const result = self.backing.rawAlloc(len, alignment, ra) orelse return null;
        self.meter.allocations += 1;
        self.change(0, len);
        return result;
    }

    fn resize(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) bool {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.requests += 1;
        if (self.deny_growth and len > bytes.len) {
            self.rejected += 1;
            return false;
        }
        if (!self.backing.rawResize(bytes, alignment, len, ra)) return false;
        if (len > bytes.len) self.successful_growths += 1;
        self.change(bytes.len, len);
        return true;
    }

    fn remap(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ra: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.requests += 1;
        if (self.deny_growth and len > bytes.len) {
            self.rejected += 1;
            return null;
        }
        const result = self.backing.rawRemap(bytes, alignment, len, ra) orelse return null;
        if (len > bytes.len) self.successful_growths += 1;
        self.change(bytes.len, len);
        return result;
    }

    fn free(ctx: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.backing.rawFree(bytes, alignment, ra);
        self.change(bytes.len, 0);
    }
};

fn options(comptime C: type) C.CompressionOptions {
    return .{ .parser = .hash, .lz77_options = .{ .window_len = 8 * 1024, .max_chain = 4, .nice_len = 32 } };
}

fn append(comptime C: type, owner: *C.RawFixedSyncFlushEncoder, out: *std.ArrayList(u8), message: Message, config: C.CompressionOptions) !usize {
    return switch (message) {
        .bytes => |bytes| owner.encodeAppend(out, bytes, config),
        .chunks => |chunks| owner.encodeChunksAppend(out, chunks, config),
    };
}

fn oracle(comptime C: type, out: *std.ArrayList(u8), message: Message, config: C.CompressionOptions) !usize {
    var plain = config;
    plain.max_total_working_memory = null;
    plain.memory_profile = null;
    return switch (message) {
        .bytes => |bytes| C.encodeRawFixedSyncFlushAppend(allocator, out, bytes, plain),
        .chunks => |chunks| C.encodeRawFixedSyncFlushChunksAppend(allocator, out, chunks, plain),
    };
}

fn nodeCount(arena: std.heap.ArenaAllocator) usize {
    var result: usize = 0;
    for ([_]@TypeOf(arena.state.used_list){ arena.state.used_list, arena.state.free_list }) |first| {
        var it = first;
        while (it) |node| : (it = node.next) result += 1;
    }
    return result;
}

fn retained(owner: anytype, physical_bytes: usize) !void {
    // Node.size is deliberately not used as the expected-value oracle: the
    // observer saw the actual allocations, and queryCapacity excludes headers.
    const header = @sizeOf(@TypeOf(owner.arena.state.used_list.?.*));
    try std.testing.expectEqual(header, arena_budget.node_header_bytes);
    try std.testing.expectEqual(physical_bytes, try arena_budget.retainedBytes(owner.arena));
    try std.testing.expectEqual(physical_bytes, owner.arena.queryCapacity() + nodeCount(owner.arena) * header);
    if (nodeCount(owner.arena) != 0) try std.testing.expect(physical_bytes > owner.arena.queryCapacity());
}

fn sameAllocator(expected: std.mem.Allocator, actual: std.mem.Allocator) !void {
    try std.testing.expectEqual(expected.ptr, actual.ptr);
    try std.testing.expectEqual(expected.vtable, actual.vtable);
}

fn fresh(comptime C: type, message: Message) !void {
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try expected.appendSlice(allocator, prefix);
    const written = try oracle(C, &expected, message, options(C));
    var default_peak: usize = 0;
    var required: usize = 0;
    inline for (.{ false, true }) |tracked| {
        var meter: Meter = .{};
        var count: Observer = .{ .backing = allocator, .meter = &meter };
        {
            var owner = C.RawFixedSyncFlushEncoder.init(count.get());
            defer owner.deinit();
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(count.get());
            try out.appendSlice(count.get(), prefix);
            var profile: C.EncodeMemoryProfile = .{};
            var config = options(C);
            if (tracked) config.memory_profile = &profile;
            try std.testing.expectEqual(written, try append(C, &owner, &out, message, config));
            try std.testing.expectEqualSlices(u8, expected.items, out.items);
            try retained(&owner, count.live - out.capacity);
            try sameAllocator(count.get(), owner.allocator);
            try sameAllocator(count.get(), owner.arena.child_allocator);
            if (tracked) {
                try std.testing.expect(profile.available);
                try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
                try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
                required = meter.peak;
                try std.testing.expectEqual(default_peak + budget.control_bytes, required);
            } else {
                default_peak = meter.peak;
                try std.testing.expect(!profile.available);
            }
        }
        try std.testing.expectEqual(@as(usize, 0), count.live);
        try std.testing.expectEqual(@as(usize, 0), meter.live);
    }
    try std.testing.expect(required != 0);
    inline for (.{ false, true }) |deny| {
        var meter: Meter = .{};
        var count: Observer = .{ .backing = allocator, .meter = &meter };
        {
            var owner = C.RawFixedSyncFlushEncoder.init(count.get());
            defer owner.deinit();
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(count.get());
            try out.appendSlice(count.get(), prefix);
            var profile: C.EncodeMemoryProfile = .{};
            var config = options(C);
            config.max_total_working_memory = required - @intFromBool(deny);
            config.memory_profile = &profile;
            if (deny) {
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, append(C, &owner, &out, message, config));
                try std.testing.expectEqualSlices(u8, prefix, out.items);
                try std.testing.expect(profile.peak_requested_bytes <= config.max_total_working_memory.?);
            } else {
                const accepted = append(C, &owner, &out, message, config) catch |err| {
                    std.debug.print("arena exact fresh D={d}: {s}, physical peak={d}, live={d}, profile peak={d}, output capacity={d}\n", .{ required, @errorName(err), meter.peak, meter.live, profile.peak_requested_bytes, out.capacity });
                    return err;
                };
                try std.testing.expectEqual(written, accepted);
                try std.testing.expectEqualSlices(u8, expected.items, out.items);
                try std.testing.expectEqual(required, profile.peak_requested_bytes);
                try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
            }
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            try retained(&owner, count.live - out.capacity);
            try sameAllocator(count.get(), owner.allocator);
            try sameAllocator(count.get(), owner.arena.child_allocator);
        }
        try std.testing.expectEqual(@as(usize, 0), meter.live);
    }
}

fn warm(comptime C: type, message: Message) !void {
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try expected.appendSlice(allocator, prefix);
    _ = try oracle(C, &expected, message, options(C));
    var meter: Meter = .{};
    var count: Observer = .{ .backing = allocator, .meter = &meter };
    {
        var owner = C.RawFixedSyncFlushEncoder.init(count.get());
        defer owner.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(count.get());
        try out.appendSlice(count.get(), prefix);
        // Arena retention may consolidate its nodes on early resets. Settle the
        // real implementation before observing a stable warmed operation.
        for (0..6) |_| {
            out.shrinkRetainingCapacity(prefix.len);
            _ = try append(C, &owner, &out, message, options(C));
        }
        out.shrinkRetainingCapacity(prefix.len);
        const allocations = meter.allocations;
        meter.peak = meter.live;
        _ = try append(C, &owner, &out, message, options(C));
        try std.testing.expectEqualSlices(u8, expected.items, out.items);
        try std.testing.expectEqual(allocations, meter.allocations);
        try std.testing.expectEqual(meter.live, meter.peak);
        out.shrinkRetainingCapacity(prefix.len);
        const occupied = meter.live;
        var profile: C.EncodeMemoryProfile = .{};
        var config = options(C);
        config.memory_profile = &profile;
        meter.peak = meter.live;
        _ = try append(C, &owner, &out, message, config);
        try std.testing.expectEqualSlices(u8, expected.items, out.items);
        try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(occupied + budget.control_bytes, meter.peak);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        const required = meter.peak;
        out.shrinkRetainingCapacity(prefix.len);
        profile.reset();
        meter.peak = meter.live;
        config.max_total_working_memory = required;
        _ = try append(C, &owner, &out, message, config);
        try std.testing.expectEqualSlices(u8, expected.items, out.items);
        try std.testing.expectEqual(required, profile.peak_requested_bytes);
        try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
        // Admission must precede reset. Keep the previous result and inspect
        // both list heads and their cursors, in addition to physical capacity.
        const used = owner.arena.state.used_list;
        const free_list = owner.arena.state.free_list;
        const used_end = if (used) |node| node.end_index else 0;
        const free_end = if (free_list) |node| node.end_index else 0;
        const requests = count.requests;
        inline for (.{ required - 1, occupied - 1 }) |limit| {
            inline for (.{ Message{ .bytes = "" }, Message{ .chunks = &.{} }, Message{ .bytes = "replacement message" } }) |refused| {
                profile.reset();
                config.max_total_working_memory = limit;
                try std.testing.expectError(error.WorkingMemoryLimitExceeded, append(C, &owner, &out, refused, config));
                try std.testing.expectEqualSlices(u8, expected.items, out.items);
                try std.testing.expectEqual(used, owner.arena.state.used_list);
                try std.testing.expectEqual(free_list, owner.arena.state.free_list);
                try std.testing.expectEqual(used_end, if (owner.arena.state.used_list) |node| node.end_index else 0);
                try std.testing.expectEqual(free_end, if (owner.arena.state.free_list) |node| node.end_index else 0);
                try std.testing.expectEqual(requests, count.requests);
                try std.testing.expectEqual(occupied, profile.peak_requested_bytes);
                try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
                try retained(&owner, count.live - out.capacity);
            }
        }
        profile.reset();
        config.max_total_working_memory = null;
        out.shrinkRetainingCapacity(prefix.len);
        meter.peak = meter.live;
        _ = try append(C, &owner, &out, message, config);
        try std.testing.expectEqualSlices(u8, expected.items, out.items);
        try std.testing.expectEqual(@as(?usize, null), profile.limit);
        try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        // A following default operation must also shed all prior policy and
        // allocate no ledger control storage on the settled arena.
        out.shrinkRetainingCapacity(prefix.len);
        meter.peak = meter.live;
        const before_default = meter.allocations;
        _ = try append(C, &owner, &out, message, options(C));
        try std.testing.expectEqualSlices(u8, expected.items, out.items);
        try std.testing.expectEqual(before_default, meter.allocations);
        try std.testing.expectEqual(meter.live, meter.peak);
        try sameAllocator(count.get(), owner.allocator);
        try sameAllocator(count.get(), owner.arena.child_allocator);
    }
    try std.testing.expectEqual(@as(usize, 0), meter.live);
}

fn separateAllocators(comptime C: type, message: Message) !void {
    // Heap buffers avoid a large test stack on 32-bit WASI. These allocators
    // have different physical storage, so an allocator routing bug is visible
    // in actual pointer ownership rather than merely in aggregate counters.
    const output_buffer = try allocator.alloc(u8, 16 * 1024);
    defer allocator.free(output_buffer);
    const arena_buffer = try allocator.alloc(u8, 512 * 1024);
    defer allocator.free(arena_buffer);
    var output_fba = std.heap.FixedBufferAllocator.init(output_buffer);
    var arena_fba = std.heap.FixedBufferAllocator.init(arena_buffer);
    var meter: Meter = .{};
    var output_count: Observer = .{ .backing = output_fba.allocator(), .meter = &meter };
    var arena_count: Observer = .{ .backing = arena_fba.allocator(), .meter = &meter };
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try expected.appendSlice(allocator, prefix);
    _ = try oracle(C, &expected, message, options(C));
    {
        var owner = C.RawFixedSyncFlushEncoder.init(output_count.get());
        owner.arena.child_allocator = arena_count.get();
        defer owner.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(output_count.get());
        try out.appendSlice(output_count.get(), prefix);
        var profile: C.EncodeMemoryProfile = .{};
        var config = options(C);
        config.memory_profile = &profile;
        _ = try append(C, &owner, &out, message, config);
        try std.testing.expectEqualSlices(u8, expected.items, out.items);
        try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try std.testing.expectEqual(out.capacity, output_count.live);
        try std.testing.expect(output_fba.ownsSlice(out.allocatedSlice()));
        try std.testing.expect(!arena_fba.ownsPtr(out.items.ptr));
        try std.testing.expect(arena_count.live > 0);
        for ([_]@TypeOf(owner.arena.state.used_list){ owner.arena.state.used_list, owner.arena.state.free_list }) |first| {
            var it = first;
            while (it) |node| : (it = node.next) {
                const pointer: [*]u8 = @ptrCast(node);
                try std.testing.expect(arena_fba.ownsPtr(pointer));
                try std.testing.expect(!output_fba.ownsPtr(pointer));
            }
        }
        try retained(&owner, arena_count.live);
        try sameAllocator(output_count.get(), owner.allocator);
        try sameAllocator(arena_count.get(), owner.arena.child_allocator);
        // Include retained capacity from both physical bases during resets.
        for (0..6) |_| {
            profile.reset();
            meter.peak = meter.live;
            out.shrinkRetainingCapacity(prefix.len);
            _ = try append(C, &owner, &out, message, config);
            try std.testing.expectEqualSlices(u8, expected.items, out.items);
            try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
            try std.testing.expectEqual(out.capacity, output_count.live);
            try retained(&owner, arena_count.live);
            try sameAllocator(output_count.get(), owner.allocator);
            try sameAllocator(arena_count.get(), owner.arena.child_allocator);
        }
        const required = meter.peak;
        try std.testing.expectEqual(meter.live + budget.control_bytes, required);
        profile.reset();
        meter.peak = meter.live;
        out.shrinkRetainingCapacity(prefix.len);
        config.max_total_working_memory = required;
        _ = try append(C, &owner, &out, message, config);
        try std.testing.expectEqualSlices(u8, expected.items, out.items);
        try std.testing.expectEqual(required, profile.peak_requested_bytes);
        try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
        profile.reset();
        config.max_total_working_memory = required - 1;
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, append(C, &owner, &out, message, config));
        try std.testing.expectEqualSlices(u8, expected.items, out.items);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try sameAllocator(output_count.get(), owner.allocator);
        try sameAllocator(arena_count.get(), owner.arena.child_allocator);
    }
    try std.testing.expectEqual(@as(usize, 0), meter.live);
    try std.testing.expectEqual(@as(usize, 0), output_count.live);
    try std.testing.expectEqual(@as(usize, 0), arena_count.live);
}

fn realOom(comptime C: type, message: Message) !void {
    const FailurePoint = enum { control, arena, output };
    inline for (std.meta.tags(FailurePoint)) |point| {
        var meter: Meter = .{};
        var output_count: Observer = .{ .backing = allocator, .meter = &meter };
        var arena_count: Observer = .{ .backing = allocator, .meter = &meter };
        {
            var owner = C.RawFixedSyncFlushEncoder.init(output_count.get());
            owner.arena.child_allocator = arena_count.get();
            defer owner.deinit();
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(output_count.get());
            try out.ensureTotalCapacityPrecise(output_count.get(), prefix.len);
            try out.appendSlice(output_count.get(), prefix);
            switch (point) {
                .control => output_count.remaining_allocations = 0,
                .arena => arena_count.remaining_allocations = 0,
                .output => {
                    // Permit the ledger control allocation, then refuse all
                    // output growth routes, including remap/resize fallbacks.
                    output_count.remaining_allocations = 1;
                    output_count.deny_growth = true;
                },
            }
            var profile: C.EncodeMemoryProfile = .{};
            var config = options(C);
            config.memory_profile = &profile;
            const attempt = append(C, &owner, &out, message, config);
            if (attempt) |result| std.debug.print("arena OOM point={s}: unexpectedly returned {d}, output capacity={d}, output requests={d}/rejected={d}, arena requests={d}/rejected={d}\n", .{ @tagName(point), result, out.capacity, output_count.requests, output_count.rejected, arena_count.requests, arena_count.rejected }) else |_| {}
            try std.testing.expectError(error.OutOfMemory, attempt);
            try std.testing.expectEqualSlices(u8, prefix, out.items);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            try sameAllocator(output_count.get(), owner.allocator);
            try sameAllocator(arena_count.get(), owner.arena.child_allocator);
            try retained(&owner, arena_count.live);
            switch (point) {
                .control => {
                    try std.testing.expect(output_count.rejected != 0);
                    try std.testing.expectEqual(@as(usize, 0), arena_count.requests);
                },
                .arena => try std.testing.expect(arena_count.rejected != 0),
                .output => try std.testing.expect(output_count.rejected != 0),
            }
            // Restore the real backing allocation policy. No failed lease or
            // stale OOM classification may prevent reuse of this same owner.
            output_count.remaining_allocations = null;
            output_count.deny_growth = false;
            arena_count.remaining_allocations = null;
            profile.reset();
            meter.peak = meter.live;
            _ = try append(C, &owner, &out, message, config);
            try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            try retained(&owner, arena_count.live);
        }
        try std.testing.expectEqual(@as(usize, 0), meter.live);
    }
}

fn quotaRollback(comptime C: type) !void {
    const first = "first independently allocated run; " ** 16;
    const second = try allocator.dupe(u8, payload);
    defer allocator.free(second);
    const chunks = [_][]const u8{ first, "", second };
    var required: usize = 0;
    {
        var owner = C.RawFixedSyncFlushEncoder.init(allocator);
        defer owner.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(allocator);
        try out.ensureTotalCapacity(allocator, 16 * 1024);
        try out.appendSlice(allocator, prefix);
        var profile: C.EncodeMemoryProfile = .{};
        var config = options(C);
        config.memory_profile = &profile;
        _ = try owner.encodeChunksAppend(&out, &.{first}, config);
        required = profile.peak_requested_bytes;
    }
    var meter: Meter = .{};
    var count: Observer = .{ .backing = allocator, .meter = &meter };
    {
        var owner = C.RawFixedSyncFlushEncoder.init(count.get());
        defer owner.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(count.get());
        try out.ensureTotalCapacity(count.get(), 16 * 1024);
        @memset(out.allocatedSlice(), 0xa7);
        try out.appendSlice(count.get(), prefix);
        var profile: C.EncodeMemoryProfile = .{};
        var config = options(C);
        config.memory_profile = &profile;
        config.max_total_working_memory = required;
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, owner.encodeChunksAppend(&out, &chunks, config));
        try std.testing.expectEqualSlices(u8, prefix, out.items);
        // The fixed block header was published into reserved tail storage
        // before a later request was refused; logical rollback is observable.
        try std.testing.expect(!std.mem.allEqual(u8, out.allocatedSlice()[prefix.len .. prefix.len + 8], 0xa7));
        try std.testing.expect(profile.peak_requested_bytes <= required);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try retained(&owner, count.live - out.capacity);
    }
    try std.testing.expectEqual(@as(usize, 0), meter.live);
}

fn crossSliceHistory(comptime C: type) !void {
    const first_storage = try allocator.alloc(u8, 2049);
    defer allocator.free(first_storage);
    const second_storage = try allocator.alloc(u8, 2049);
    defer allocator.free(second_storage);
    const first = first_storage[0..2048];
    const second = second_storage[0..2048];
    // No useful repeated pattern within each slice; the second slice can only
    // compress well by finding matches in the first slice's rolling history.
    var random: u32 = 0x7b0e49ac;
    for (first) |*byte| {
        random ^= random << 13;
        random ^= random >> 17;
        random ^= random << 5;
        byte.* = @truncate(random);
    }
    @memcpy(second, first);
    try std.testing.expect(@intFromPtr(first.ptr) + first.len != @intFromPtr(second.ptr));
    const chunks = [_][]const u8{ first, "", second };
    var single: std.ArrayList(u8) = .empty;
    defer single.deinit(allocator);
    _ = try oracle(C, &single, .{ .bytes = first }, options(C));
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    _ = try oracle(C, &expected, .{ .chunks = &chunks }, options(C));
    try std.testing.expect(expected.items.len <= single.items.len + 64);
    var meter: Meter = .{};
    var count: Observer = .{ .backing = allocator, .meter = &meter };
    {
        var owner = C.RawFixedSyncFlushEncoder.init(count.get());
        defer owner.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(count.get());
        var profile: C.EncodeMemoryProfile = .{};
        var config = options(C);
        config.memory_profile = &profile;
        _ = try owner.encodeChunksAppend(&out, &chunks, config);
        try std.testing.expectEqualSlices(u8, expected.items, out.items);
        try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try retained(&owner, count.live - out.capacity);
    }
    try std.testing.expectEqual(@as(usize, 0), meter.live);
    try expected.appendSlice(allocator, "\x01\x00\x00\xff\xff");
    const decoded = try C.decodeRawAutoAlloc(allocator, expected.items);
    defer allocator.free(decoded);
    try std.testing.expectEqual(@as(usize, 4096), decoded.len);
    try std.testing.expectEqualSlices(u8, first, decoded[0..2048]);
    try std.testing.expectEqualSlices(u8, second, decoded[2048..]);
}

fn AllocationFailures(comptime C: type) type {
    return struct {
        fn run(a: std.mem.Allocator) !void {
            var owner = C.RawFixedSyncFlushEncoder.init(a);
            defer owner.deinit();
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(a);
            try out.appendSlice(a, prefix);
            var profile: C.EncodeMemoryProfile = .{};
            var config = options(C);
            config.memory_profile = &profile;
            _ = owner.encodeChunksAppend(&out, &.{ "first run; ", "", payload }, config) catch |err| {
                try std.testing.expectEqualSlices(u8, prefix, out.items);
                try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
                return err;
            };
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
            const previous = try allocator.dupe(u8, out.items);
            defer allocator.free(previous);
            profile.reset();
            // The second operation also injects failures into retained-node
            // consolidation/reset and growth of an existing output allocation.
            _ = owner.encodeChunksAppend(&out, &.{ "first run; ", "", payload }, config) catch |err| {
                try std.testing.expectEqualSlices(u8, previous, out.items);
                try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
                return err;
            };
            try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        }
    };
}

fn sameInheritedLease(comptime C: type, message: Message) !void {
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try expected.appendSlice(allocator, prefix);
    _ = try oracle(C, &expected, message, options(C));
    var meter: Meter = .{};
    var count: Observer = .{ .backing = allocator, .meter = &meter };
    var profile: C.EncodeMemoryProfile = .{};
    const limit = 1024 * 1024;
    {
        var lease = try budget.Lease.init(count.get(), limit, &profile, 0);
        defer lease.deinit();
        const a = lease.allocator();
        {
            var owner = C.RawFixedSyncFlushEncoder.init(a);
            defer owner.deinit();
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(a);
            try out.appendSlice(a, prefix);
            // Null top-level options inherit the existing policy and profile.
            _ = try append(C, &owner, &out, message, options(C));
            try std.testing.expectEqualSlices(u8, expected.items, out.items);
            try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
            try std.testing.expectEqual(meter.live, profile.live_requested_bytes);
            try retained(&owner, count.live - out.capacity - budget.control_bytes);
            var config = options(C);
            config.max_total_working_memory = limit;
            config.memory_profile = &profile;
            out.shrinkRetainingCapacity(prefix.len);
            _ = try append(C, &owner, &out, message, config);
            try std.testing.expectEqualSlices(u8, expected.items, out.items);
            try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
            try std.testing.expectEqual(meter.live, profile.live_requested_bytes);
            config.max_total_working_memory = limit - 1;
            try std.testing.expectError(error.InvalidBlockPlan, append(C, &owner, &out, message, config));
            try std.testing.expectEqualSlices(u8, expected.items, out.items);
            var other_profile: C.EncodeMemoryProfile = .{};
            config.max_total_working_memory = limit;
            config.memory_profile = &other_profile;
            try std.testing.expectError(error.InvalidBlockPlan, append(C, &owner, &out, message, config));
            try std.testing.expectEqualSlices(u8, expected.items, out.items);
            try std.testing.expect(!other_profile.available);
            try sameAllocator(a, owner.allocator);
            try sameAllocator(a, owner.arena.child_allocator);
            out.shrinkRetainingCapacity(prefix.len);
            _ = try append(C, &owner, &out, message, options(C));
            try std.testing.expectEqualSlices(u8, expected.items, out.items);
            try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
            try std.testing.expectEqual(meter.live, profile.live_requested_bytes);
        }
        try std.testing.expectEqual(budget.control_bytes, meter.live);
        try std.testing.expectEqual(budget.control_bytes, profile.live_requested_bytes);
    }
    try std.testing.expectEqual(@as(usize, 0), meter.live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

fn distinctInheritedLeases(comptime C: type, message: Message) !void {
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try expected.appendSlice(allocator, prefix);
    _ = try oracle(C, &expected, message, options(C));
    var meter: Meter = .{};
    var output_count: Observer = .{ .backing = allocator, .meter = &meter };
    var arena_count: Observer = .{ .backing = allocator, .meter = &meter };
    var output_profile: C.EncodeMemoryProfile = .{};
    var arena_profile: C.EncodeMemoryProfile = .{};
    const primary_limit = 1024 * 1024;
    {
        var output_lease = try budget.Lease.init(output_count.get(), primary_limit, &output_profile, 0);
        defer output_lease.deinit();
        // State2 admits its control allocation but no arena node. The primary
        // has ample room, so refusal proves the original arena cap is respected.
        var arena_lease = try budget.Lease.init(arena_count.get(), budget.control_bytes, &arena_profile, 0);
        defer arena_lease.deinit();
        const out_a = output_lease.allocator();
        const arena_a = arena_lease.allocator();
        {
            var owner = C.RawFixedSyncFlushEncoder.init(out_a);
            owner.arena.child_allocator = arena_a;
            defer owner.deinit();
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(out_a);
            try out.appendSlice(out_a, prefix);
            try std.testing.expectError(error.WorkingMemoryLimitExceeded, append(C, &owner, &out, message, options(C)));
            try std.testing.expectEqualSlices(u8, prefix, out.items);
            try std.testing.expect(arena_lease.snapshot().hit_limit);
            try std.testing.expectEqual(budget.control_bytes, arena_count.live);
            try std.testing.expectEqual(budget.control_bytes, arena_profile.peak_requested_bytes);
            try std.testing.expectEqual(output_count.live, output_profile.live_requested_bytes);
            try sameAllocator(out_a, owner.allocator);
            try sameAllocator(arena_a, owner.arena.child_allocator);
            try arena_lease.setLimit(null);
            arena_lease.beginOperation();
            output_lease.beginOperation();
            output_profile.reset();
            arena_profile.reset();
            meter.peak = meter.live;
            _ = try append(C, &owner, &out, message, options(C));
            try std.testing.expectEqualSlices(u8, expected.items, out.items);
            // The secondary control stays in its own ledger. Its arena nodes
            // participate in the primary operation's borrowed scope exactly once.
            try std.testing.expectEqual(meter.peak - budget.control_bytes, output_profile.peak_requested_bytes);
            try std.testing.expectEqual(arena_count.peak, arena_profile.peak_requested_bytes);
            try std.testing.expectEqual(output_count.live, output_profile.live_requested_bytes);
            try std.testing.expectEqual(arena_count.live, arena_profile.live_requested_bytes);
            try std.testing.expectEqual(out.capacity + budget.control_bytes, output_count.live);
            try retained(&owner, arena_count.live - budget.control_bytes);
            var config = options(C);
            config.max_total_working_memory = primary_limit;
            config.memory_profile = &output_profile;
            out.shrinkRetainingCapacity(prefix.len);
            _ = try append(C, &owner, &out, message, config);
            try std.testing.expectEqualSlices(u8, expected.items, out.items);
            try std.testing.expectEqual(output_count.live, output_profile.live_requested_bytes);
            try std.testing.expectEqual(arena_count.live, arena_profile.live_requested_bytes);
            try sameAllocator(out_a, owner.allocator);
            try sameAllocator(arena_a, owner.arena.child_allocator);
        }
        try std.testing.expectEqual(2 * budget.control_bytes, meter.live);
    }
    try std.testing.expectEqual(@as(usize, 0), meter.live);
    try std.testing.expectEqual(@as(usize, 0), output_profile.live_requested_bytes);
    try std.testing.expectEqual(@as(usize, 0), arena_profile.live_requested_bytes);
}

const ResizeSample = struct {
    peak: usize,
    successful_growths: usize,
    rejected: usize,
};

fn resizeSample(comptime C: type, message: Message, expected: []const u8, deny_growth: bool, cap: ?usize) !ResizeSample {
    const output_buffer = try allocator.alloc(u8, 16 * 1024);
    defer allocator.free(output_buffer);
    // Give StdArena's speculative in-place growth enough physical room. A
    // small FBA can silently turn this into an unsupported-growth experiment.
    const arena_buffer = try allocator.alloc(u8, 2 * 1024 * 1024);
    defer allocator.free(arena_buffer);
    var output_fba = std.heap.FixedBufferAllocator.init(output_buffer);
    var arena_fba = std.heap.FixedBufferAllocator.init(arena_buffer);
    var meter: Meter = .{};
    var output_count: Observer = .{ .backing = output_fba.allocator(), .meter = &meter };
    var arena_count: Observer = .{ .backing = arena_fba.allocator(), .meter = &meter, .deny_growth = deny_growth };
    var sample: ResizeSample = undefined;
    {
        var owner = C.RawFixedSyncFlushEncoder.init(output_count.get());
        owner.arena.child_allocator = arena_count.get();
        defer owner.deinit();
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(output_count.get());
        try out.appendSlice(output_count.get(), prefix);
        var profile: C.EncodeMemoryProfile = .{};
        var config = options(C);
        config.memory_profile = &profile;
        config.max_total_working_memory = cap;
        _ = try append(C, &owner, &out, message, config);
        try std.testing.expectEqualSlices(u8, expected, out.items);
        try std.testing.expectEqual(meter.peak, profile.peak_requested_bytes);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        if (cap) |limit| try std.testing.expect(meter.peak <= limit);
        try std.testing.expectEqual(out.capacity, output_count.live);
        try std.testing.expect(output_fba.ownsSlice(out.allocatedSlice()));
        try std.testing.expect(!arena_fba.ownsPtr(out.items.ptr));
        for ([_]@TypeOf(owner.arena.state.used_list){ owner.arena.state.used_list, owner.arena.state.free_list }) |first| {
            var it = first;
            while (it) |node| : (it = node.next) {
                const pointer: [*]u8 = @ptrCast(node);
                try std.testing.expect(arena_fba.ownsPtr(pointer));
                try std.testing.expect(!output_fba.ownsPtr(pointer));
            }
        }
        try retained(&owner, arena_count.live);
        try sameAllocator(output_count.get(), owner.allocator);
        try sameAllocator(arena_count.get(), owner.arena.child_allocator);
        sample = .{ .peak = meter.peak, .successful_growths = arena_count.successful_growths, .rejected = arena_count.rejected };
    }
    try std.testing.expectEqual(@as(usize, 0), meter.live);
    try std.testing.expectEqual(@as(usize, 0), output_count.live);
    try std.testing.expectEqual(@as(usize, 0), arena_count.live);
    return sample;
}

fn supportingResizePolicy(comptime C: type, message: Message) !void {
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try expected.appendSlice(allocator, prefix);
    _ = try oracle(C, &expected, message, options(C));
    const fallback = try resizeSample(C, message, expected.items, true, null);
    try std.testing.expectEqual(@as(usize, 0), fallback.successful_growths);
    try std.testing.expect(fallback.rejected != 0);
    const supporting = try resizeSample(C, message, expected.items, false, null);
    try std.testing.expect(supporting.successful_growths != 0);
    // The cap can change optional probe behavior and select a smaller physical
    // fallback. An unlimited supporting peak is consequently not a minimum D.
    const capped = try resizeSample(C, message, expected.items, false, fallback.peak);
    try std.testing.expect(capped.peak <= fallback.peak);
    if (supporting.peak > fallback.peak) {
        try std.testing.expect(capped.peak < supporting.peak);
        std.debug.print("arena physical resize: unlimited supporting peak={d}, unsupported fallback D={d}, supporting cap=D peak={d}\n", .{ supporting.peak, fallback.peak, capped.peak });
    }
    // Settled warm occupied+control D/D-1 remains covered by warm() and
    // separateAllocators(); no unlimited supporting D-1 refusal is asserted.
}

pub fn contracts(comptime C: type) !void {
    const contiguous = [_][]const u8{ "", payload[0..137], "", payload[137..2048], payload[2048..], "" };
    // Each slice lives inside its own oversized allocation: the chunks cannot
    // accidentally become adjacent even if the allocator packs allocations.
    const first_storage = try allocator.alloc(u8, 2049);
    defer allocator.free(first_storage);
    const second_storage = try allocator.alloc(u8, payload.len - 2048 + 1);
    defer allocator.free(second_storage);
    @memcpy(first_storage[0..2048], payload[0..2048]);
    @memcpy(second_storage[0 .. payload.len - 2048], payload[2048..]);
    const separate = [_][]const u8{ "", first_storage[0..2048], "", second_storage[0 .. payload.len - 2048], "" };
    try std.testing.expect(@intFromPtr(separate[1].ptr) + separate[1].len != @intFromPtr(separate[3].ptr));
    try fresh(C, .{ .bytes = "" });
    try fresh(C, .{ .bytes = "x" });
    try fresh(C, .{ .bytes = payload });
    try fresh(C, .{ .chunks = &.{} });
    try fresh(C, .{ .chunks = &.{ "", "", "" } });
    try fresh(C, .{ .chunks = &contiguous });
    try warm(C, .{ .bytes = payload });
    try warm(C, .{ .chunks = &separate });
    try separateAllocators(C, .{ .bytes = payload });
    try separateAllocators(C, .{ .chunks = &separate });
    try realOom(C, .{ .bytes = payload });
    try realOom(C, .{ .chunks = &separate });
    try quotaRollback(C);
    try crossSliceHistory(C);
    try std.testing.checkAllAllocationFailures(allocator, AllocationFailures(C).run, .{});
    try fresh(C, .{ .chunks = &separate });
    try sameInheritedLease(C, .{ .bytes = payload });
    try sameInheritedLease(C, .{ .chunks = &separate });
    try distinctInheritedLeases(C, .{ .bytes = payload });
    try distinctInheritedLeases(C, .{ .chunks = &separate });
    try supportingResizePolicy(C, .{ .chunks = &separate });
}
