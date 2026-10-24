//! Independent Zstd entropy arithmetic, path replay and requested-byte accounting.
const std = @import("std");

pub const plain = "HQ search abcdefghabcdefghXabcdefgh literal tail\n" ** 3;
pub const prefix = "HQ search abcdefghabcdefghXabcdefgh literal tail\n";

pub const ll_bases = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24, 28, 32, 40, 48, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536 };
pub const ll_bits = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
pub const ml_bases = [_]u32{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 37, 39, 41, 43, 47, 51, 59, 67, 83, 99, 131, 259, 515, 1027, 2051, 4099, 8195, 16387, 32771, 65539 };
pub const ml_bits = [_]u8{0} ** 32 ++ [_]u8{ 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };

fn symbol(length: usize, bases: []const u32, bits: []const u8) usize {
    for (bases, bits, 0..) |base, width, code|
        if (length >= base and length - base < (@as(usize, 1) << @intCast(width))) return code;
    unreachable;
}

pub fn sequencePrice(model: anytype, literal_len: usize, match_len: usize, offset_value: u32) u64 {
    const ll = symbol(literal_len, &ll_bases, &ll_bits);
    const ml = symbol(match_len, &ml_bases, &ml_bits);
    const of = std.math.log2_int(u32, offset_value);
    const extra = @as(u64, ll_bits[ll]) + ml_bits[ml] + of;
    return @as(u64, model.ll_prices[ll]) + model.ml_prices[ml] + model.of_prices[of] + extra * 256;
}

pub const RepeatChoice = struct { physical: usize, repeats: [3]usize };

pub fn repeat(literals: usize, value: u32, initial: [3]usize) ?RepeatChoice {
    if (value == 0) return null;
    if (value > 3) return .{ .physical = value - 3, .repeats = .{ value - 3, initial[0], initial[1] } };
    if (literals != 0) return switch (value) {
        1 => .{ .physical = initial[0], .repeats = initial },
        2 => .{ .physical = initial[1], .repeats = .{ initial[1], initial[0], initial[2] } },
        3 => .{ .physical = initial[2], .repeats = .{ initial[2], initial[0], initial[1] } },
        else => unreachable,
    };
    return switch (value) {
        1 => .{ .physical = initial[1], .repeats = .{ initial[1], initial[0], initial[2] } },
        2 => .{ .physical = initial[2], .repeats = .{ initial[2], initial[0], initial[1] } },
        3 => if (initial[0] > 1) .{ .physical = initial[0] - 1, .repeats = .{ initial[0] - 1, initial[0], initial[1] } } else null,
        else => unreachable,
    };
}

pub fn finiteCost(prefix_bytes: []const u8, input: []const u8, model: anytype, position: usize, pending: usize, repeated: [3]usize) u64 {
    if (position == input.len) return 0;
    var best = @as(u64, model.literal_prices[input[position]]) + finiteCost(prefix_bytes, input, model, position + 1, pending + 1, repeated);
    const absolute = prefix_bytes.len + position;
    for (1..absolute + 1) |physical| {
        var length: usize = 0;
        while (length < input.len - position) : (length += 1) {
            const candidate = absolute - physical + length;
            const byte = if (candidate < prefix_bytes.len) prefix_bytes[candidate] else input[candidate - prefix_bytes.len];
            if (byte != input[position + length]) break;
        }
        if (length < 3) continue;
        for (3..length + 1) |matched| {
            for ([_]u32{ 1, 2, 3, @intCast(physical + 3) }) |value| {
                const selected = repeat(pending, value, repeated) orelse continue;
                if (selected.physical != physical) continue;
                const cost = sequencePrice(model, pending, matched, value) + finiteCost(prefix_bytes, input, model, position + matched, 0, selected.repeats);
                best = @min(best, cost);
            }
        }
    }
    return best;
}

pub fn replay(a: std.mem.Allocator, prefix_bytes: []const u8, input: []const u8, initial: [3]usize, model: anytype, plan: anytype) !void {
    const output = try a.alloc(u8, prefix_bytes.len + input.len);
    defer a.free(output);
    @memcpy(output[0..prefix_bytes.len], prefix_bytes);
    var position: usize = 0;
    var repeated = initial;
    var cost: u64 = 0;
    for (plan.records, plan.offset_values) |record, value| {
        try std.testing.expect(record.literal_len <= input.len - position);
        @memcpy(output[prefix_bytes.len + position ..][0..record.literal_len], input[position..][0..record.literal_len]);
        for (input[position..][0..record.literal_len]) |byte| cost += model.literal_prices[byte];
        position += record.literal_len;
        const selected = repeat(record.literal_len, value, repeated) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(record.distance, selected.physical);
        try std.testing.expectEqual(@as(?usize, value), record.offset_value);
        try std.testing.expect(record.match_len >= 3 and record.match_len <= input.len - position and record.distance <= prefix_bytes.len + position);
        cost += sequencePrice(model, record.literal_len, record.match_len, value);
        for (0..record.match_len) |_| {
            output[prefix_bytes.len + position] = output[prefix_bytes.len + position - record.distance];
            position += 1;
        }
        try std.testing.expectEqual(position, record.match_end);
        repeated = selected.repeats;
    }
    @memcpy(output[prefix_bytes.len + position ..], input[position..]);
    for (input[position..]) |byte| cost += model.literal_prices[byte];
    try std.testing.expectEqual(cost, plan.estimated_cost);
    try std.testing.expectEqual(repeated, plan.final_repeated_offsets);
    try std.testing.expectEqualSlices(u8, input, output[prefix_bytes.len..]);
}

pub const Interior = struct {
    dictionary: [200]u8,
    input: []u8,
    target: usize,

    pub fn deinit(self: Interior, a: std.mem.Allocator) void {
        a.free(self.input);
    }
};

pub fn interior(a: std.mem.Allocator, target: usize) !Interior {
    var result: Interior = .{ .dictionary = undefined, .input = try a.alloc(u8, 50 + target + 1 + 100), .target = target };
    for (result.dictionary[0..100], 0..) |*byte, i| byte.* = @intCast(i);
    const shared = 100 - target - 1;
    @memcpy(result.dictionary[100..][0..shared], result.dictionary[target + 1 .. 100]);
    for (result.dictionary[100 + shared ..], 0..) |*byte, i| byte.* = @intCast(100 + i);
    for (result.input[0..50], 0..) |*byte, i| byte.* = @intCast(200 + i);
    @memcpy(result.input[50..150], result.dictionary[0..100]);
    @memcpy(result.input[150..], result.dictionary[100 + shared ..]);
    return result;
}

pub fn boundaryInput(a: std.mem.Allocator) ![]u8 {
    const bytes = try a.alloc(u8, 4098);
    var symbols: [3]u8 = @splat(0);
    var written: usize = 0;
    deBruijn(bytes[0..4094], &symbols, &written, 1, 1);
    @memcpy(bytes[0..4], "txyz");
    @memcpy(bytes[4094..], "txyz");
    return bytes;
}

fn deBruijn(bytes: []u8, symbols: *[3]u8, written: *usize, at: usize, period: usize) void {
    if (written.* == bytes.len) return;
    if (at > 2) {
        if (2 % period == 0) for (symbols[1..][0..period]) |byte| {
            if (written.* == bytes.len) return;
            bytes[written.*] = byte;
            written.* += 1;
        };
        return;
    }
    symbols[at] = symbols[at - period];
    deBruijn(bytes, symbols, written, at + 1, period);
    var next: usize = @as(usize, symbols[at - period]) + 1;
    while (next < 128 and written.* < bytes.len) : (next += 1) {
        symbols[at] = @intCast(next);
        deBruijn(bytes, symbols, written, at + 1, at);
    }
}

pub fn boundaryMinimum(input: []const u8, model: anytype) u64 {
    var best: u64 = input.len * 8 * 256;
    for (4094..input.len - 2) |position| {
        for (0..position) |candidate| {
            var length: usize = 0;
            while (length < input.len - position and input[position + length] == input[candidate + length]) : (length += 1) {}
            if (length < 3) continue;
            for (3..length + 1) |copy| {
                const cost = (input.len - copy) * 8 * 256 + sequencePrice(model, position, copy, @intCast(position - candidate + 3));
                best = @min(best, cost);
            }
        }
    }
    return best;
}

pub fn drive(collector: std.mem.Allocator, encoder: anytype, input: []const u8, input_quota: usize, output_quota: usize) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(collector);
    var offset = std.math.cast(usize, encoder.snapshot().frame_input) orelse return error.IntegerOverflow;
    var finishing = encoder.snapshot().finishing;
    var output: [257]u8 = undefined;
    for (0..input.len * 16 + 4096) |call| {
        if (offset == input.len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        @memset(&output, 0xa5);
        const end = @min(input.len, offset + input_quota);
        const before = encoder.snapshot();
        const result = try encoder.step(input[offset..end], output[0..if (call % 7 == 0) 0 else output_quota]);
        const after = encoder.snapshot();
        try std.testing.expectEqual(result.progress.input_read, after.frame_input - before.frame_input);
        try std.testing.expectEqual(result.progress.output_written, after.frame_output - before.frame_output);
        try untouched(output[result.progress.output_written..]);
        offset += result.progress.input_read;
        try bytes.appendSlice(collector, output[0..result.progress.output_written]);
        if (result.status == .done) {
            try std.testing.expectEqual(input.len, offset);
            return bytes.toOwnedSlice(collector);
        }
    }
    return error.TestUnexpectedResult;
}

pub const JointLedger = struct {
    live: usize = 0,
    peak: usize = 0,

    pub fn beginMeasurement(self: *JointLedger) void {
        self.peak = self.live;
    }
};

pub const TrackingAllocator = struct {
    backing: std.mem.Allocator,
    joint: ?*JointLedger = null,
    live: usize = 0,
    peak: usize = 0,
    allocated_bytes: usize = 0,
    freed_bytes: usize = 0,
    alloc_attempts: usize = 0,
    resize_attempts: usize = 0,
    remap_attempts: usize = 0,
    free_calls: usize = 0,
    successful_resizes: usize = 0,
    successful_remaps: usize = 0,
    fail_alloc_after: ?usize = null,
    fail_resize_after: ?usize = null,
    fail_remap_after: ?usize = null,
    forced_failures: usize = 0,
    force_moving_growth: bool = false,
    force_copy_reallocation: bool = false,
    poison_before_free: bool = false,
    peak_operation: Operation = .allocate,
    peak_before: usize = 0,
    peak_request: usize = 0,
    owned_peak: usize = 0,
    slots: [1024]Slot = @splat(.{}),

    pub const Operation = enum { allocate, resize, remap };
    const Slot = struct { pointer: ?[*]u8 = null, len: usize = 0, excluded_bytes: usize = 0 };

    pub fn init(backing: std.mem.Allocator) TrackingAllocator {
        return .{ .backing = backing };
    }

    pub fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = allocate, .resize = resize, .remap = remap, .free = free } };
    }

    pub fn clearFailures(self: *TrackingAllocator) void {
        self.fail_alloc_after = null;
        self.fail_resize_after = null;
        self.fail_remap_after = null;
    }

    pub fn beginMeasurement(self: *TrackingAllocator) void {
        self.peak = self.live;
        self.peak_before = self.live;
        self.peak_request = 0;
        self.owned_peak = self.ownedLive();
    }

    /// Exclude only this pre-existing caller allocation. A moving replacement
    /// is a new request and stays counted until the caller explicitly takes it.
    pub fn excludeInitialAllocation(self: *TrackingAllocator, memory: []u8) void {
        self.slot(memory).excluded_bytes = memory.len;
        self.owned_peak = self.ownedLive();
    }

    pub fn ownedLive(self: *const TrackingAllocator) usize {
        var borrowed: usize = 0;
        for (self.slots) |record| borrowed += record.excluded_bytes;
        return self.live - borrowed;
    }

    fn recordOwnedPeak(self: *TrackingAllocator) void {
        self.owned_peak = @max(self.owned_peak, self.ownedLive());
    }

    fn slot(self: *TrackingAllocator, memory: []u8) *Slot {
        for (&self.slots) |*record| if (record.pointer == memory.ptr) {
            std.debug.assert(record.len == memory.len);
            return record;
        };
        @panic("untracked allocator pointer");
    }

    fn increase(self: *TrackingAllocator, amount: usize, operation: Operation, requested: usize) void {
        const previous = self.live;
        self.live += amount;
        self.allocated_bytes += amount;
        if (self.joint) |joint| {
            joint.live += amount;
            joint.peak = @max(joint.peak, joint.live);
        }
        if (self.live > self.peak) {
            self.peak = self.live;
            self.peak_operation = operation;
            self.peak_before = previous;
            self.peak_request = requested;
        }
    }

    fn decrease(self: *TrackingAllocator, amount: usize) void {
        std.debug.assert(amount <= self.live);
        self.live -= amount;
        self.freed_bytes += amount;
        if (self.joint) |joint| joint.live -= amount;
    }

    fn failure(self: *TrackingAllocator, after: ?usize, index: usize) bool {
        if (after) |limit| if (index >= limit) {
            self.forced_failures += 1;
            return true;
        };
        return false;
    }

    fn allocate(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const call = self.alloc_attempts;
        self.alloc_attempts += 1;
        if (self.failure(self.fail_alloc_after, call)) return null;
        const memory = self.backing.rawAlloc(len, alignment, address) orelse return null;
        for (&self.slots) |*record| if (record.pointer == null) {
            record.* = .{ .pointer = memory, .len = len };
            self.increase(len, .allocate, len);
            self.recordOwnedPeak();
            return memory;
        };
        @panic("tracking allocation table exhausted");
    }

    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const call = self.resize_attempts;
        self.resize_attempts += 1;
        const record = self.slot(memory);
        if (self.failure(self.fail_resize_after, call) or
            (self.force_moving_growth and len > memory.len) or
            (self.force_copy_reallocation and len != memory.len)) return false;
        if (!self.backing.rawResize(memory, alignment, len, address)) return false;
        self.successful_resizes += 1;
        if (len > memory.len) self.increase(len - memory.len, .resize, len) else self.decrease(memory.len - len);
        record.len = len;
        record.excluded_bytes = @min(record.excluded_bytes, len);
        self.recordOwnedPeak();
        return true;
    }

    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const call = self.remap_attempts;
        self.remap_attempts += 1;
        const record = self.slot(memory);
        if (self.failure(self.fail_remap_after, call) or
            (self.force_moving_growth and len > memory.len) or
            (self.force_copy_reallocation and len != memory.len)) return null;
        const result = self.backing.rawRemap(memory, alignment, len, address) orelse return null;
        self.successful_remaps += 1;
        if (len > memory.len) self.increase(len - memory.len, .remap, len) else self.decrease(memory.len - len);
        record.* = .{ .pointer = result, .len = len, .excluded_bytes = @min(record.excluded_bytes, len) };
        self.recordOwnedPeak();
        return result;
    }

    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const record = self.slot(memory);
        if (self.poison_before_free) @memset(memory, 0xdd);
        self.backing.rawFree(memory, alignment, address);
        record.* = .{};
        self.free_calls += 1;
        self.decrease(memory.len);
        self.recordOwnedPeak();
    }
};

pub fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

test "Zstd HQ search controls independent tracker observes in place growth shrink and overlapping live requests" {
    var storage: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var tracked = TrackingAllocator.init(fixed.allocator());
    const a = tracked.allocator();
    var bytes = try a.alloc(u8, 16);
    try std.testing.expect(a.resize(bytes, 64));
    bytes = bytes.ptr[0..64];
    bytes = a.remap(bytes, 8) orelse return error.TestUnexpectedResult;
    const other = try a.alloc(u8, 24);
    try std.testing.expectEqual(@as(usize, 32), tracked.live);
    try std.testing.expectEqual(@as(usize, 64), tracked.peak);
    a.free(other);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
}

test "Zstd HQ search controls independent tracker charges old and new buffers during moving fallback growth" {
    var tracked = TrackingAllocator.init(std.testing.allocator);
    tracked.force_moving_growth = true;
    const a = tracked.allocator();
    var bytes = try a.dupe(u8, "12345678");
    bytes = try a.realloc(bytes, 16);
    try std.testing.expectEqualSlices(u8, "12345678", bytes[0..8]);
    try std.testing.expectEqual(@as(usize, 24), tracked.peak);
    try std.testing.expectEqual(@as(usize, 8), tracked.peak_before);
    try std.testing.expectEqual(@as(usize, 16), tracked.peak_request);
    try std.testing.expectEqual(TrackingAllocator.Operation.allocate, tracked.peak_operation);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    tracked.force_copy_reallocation = true;
    bytes = try a.dupe(u8, "12345678");
    tracked.beginMeasurement();
    bytes = try a.realloc(bytes, 4);
    try std.testing.expectEqualSlices(u8, "1234", bytes);
    try std.testing.expectEqual(@as(usize, 12), tracked.peak);
    try std.testing.expectEqual(@as(usize, 4), tracked.live);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}

test "Zstd HQ search controls independent failed allocation resize and remap preserve live bytes and old content" {
    var storage: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var tracked = TrackingAllocator.init(fixed.allocator());
    const a = tracked.allocator();
    var bytes = try a.dupe(u8, "12345678");
    tracked.fail_resize_after = tracked.resize_attempts;
    try std.testing.expect(!a.resize(bytes, 16));
    tracked.fail_remap_after = tracked.remap_attempts;
    try std.testing.expect(a.remap(bytes, 16) == null);
    tracked.fail_alloc_after = tracked.alloc_attempts;
    try std.testing.expectError(error.OutOfMemory, a.realloc(bytes, 16));
    try std.testing.expectEqualSlices(u8, "12345678", bytes);
    try std.testing.expectEqual(@as(usize, 8), tracked.live);
    try std.testing.expectEqual(@as(usize, 8), tracked.peak);
    tracked.clearFailures();
    bytes = a.remap(bytes, 16) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 16), tracked.live);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expect(tracked.forced_failures >= 3);
}

test "Zstd HQ search controls independent tracker excludes one borrowed identity but counts its moving replacement" {
    var tracked = TrackingAllocator.init(std.testing.allocator);
    tracked.force_moving_growth = true;
    const a = tracked.allocator();
    var bytes = try a.dupe(u8, "12345678");
    tracked.excludeInitialAllocation(bytes);
    tracked.beginMeasurement();
    try std.testing.expectEqual(@as(usize, 0), tracked.ownedLive());
    bytes = try a.realloc(bytes, 16);
    try std.testing.expectEqual(@as(usize, 24), tracked.peak);
    try std.testing.expectEqual(@as(usize, 16), tracked.owned_peak);
    try std.testing.expectEqual(@as(usize, 16), tracked.ownedLive());
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    var storage: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var shrinking = TrackingAllocator.init(fixed.allocator());
    const shrink_a = shrinking.allocator();
    var borrowed = try shrink_a.alloc(u8, 16);
    shrinking.excludeInitialAllocation(borrowed);
    try std.testing.expect(shrink_a.resize(borrowed, 8));
    borrowed = borrowed.ptr[0..8];
    try std.testing.expectEqual(@as(usize, 0), shrinking.ownedLive());
    try std.testing.expectEqual(@as(usize, 0), shrinking.owned_peak);
    shrink_a.free(borrowed);
    try std.testing.expectEqual(@as(usize, 0), shrinking.live);
}

// Independently captured from archived97c4ad99, before HQ search controls.
pub const Api = enum { native_default, level18, level21, level22, btopt, btultra, btultra2, dictionary, reusable, incremental, seekable };
pub const FrozenWire = struct { name: Api, hex: []const u8 };
pub const frozen_wires = [_]FrozenWire{
    .{ .name = .native_default, .hex = "28b52ffd24936d0100140248512073656172636820616263646566676858206c69746572616c207461696c0a03004fd55416728d2861906c34eb" },
    .{ .name = .level18, .hex = "28b52ffd20936d0100140248512073656172636820616263646566676858206c69746572616c207461696c0a03004fd55416728d2861" },
    .{ .name = .level21, .hex = "28b52ffd20936d0100140248512073656172636820616263646566676858206c69746572616c207461696c0a03004fd55416728d2861" },
    .{ .name = .level22, .hex = "28b52ffd20936d0100140248512073656172636820616263646566676858206c69746572616c207461696c0a03004fd55416728d2861" },
    .{ .name = .btopt, .hex = "28b52ffd24936d0100140248512073656172636820616263646566676858206c69746572616c207461696c0a03004fd5541672256e18906c34eb" },
    .{ .name = .btultra, .hex = "28b52ffd24936d0100140248512073656172636820616263646566676858206c69746572616c207461696c0a03004fd5541672256e18906c34eb" },
    .{ .name = .btultra2, .hex = "28b52ffd24936d0100140248512073656172636820616263646566676858206c69746572616c207461696c0a03004fd5541672256e18906c34eb" },
    .{ .name = .dictionary, .hex = "28b52ffd252a933d000000014000104aa9906c34eb" },
    .{ .name = .reusable, .hex = "28b52ffd24936d0100140248512073656172636820616263646566676858206c69746572616c207461696c0a03004fd5541672256e18906c34eb" },
    .{ .name = .incremental, .hex = "28b52ffd24936d0100140248512073656172636820616263646566676858206c69746572616c207461696c0a03004fd5541672256e18906c34eb" },
    .{ .name = .seekable, .hex = "28b52ffd24406d0100140248512073656172636820616263646566676858206c69746572616c207461696c0a03005475652157e28601e39e1a2928b52ffd24407d01001402666768616263646558206c69746572616c207461696c0a485120736561726368200400543560a836585e11b85cdd1f307828b52ffd24139900006465666768206c69746572616c207461696c0a328b30985e2a4d182d0000003a00000040000000e39e1a293c00000040000000dd1f30782000000013000000328b30980300000080b1ea928f" },
};

pub fn frozenAlloc(a: std.mem.Allocator, sample: FrozenWire) ![]u8 {
    const bytes = try a.alloc(u8, sample.hex.len / 2);
    errdefer a.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, sample.hex);
    return bytes;
}
