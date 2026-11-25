const std = @import("std");
const h = @import("step_borrow_helpers.zig");

fn parallelOptions(comptime Z: type) Z.NativeIncrementalParallelFrameEncoder.Options {
    return .{ .frame = h.options(Z), .parallel = .{ .io = std.Io.failing, .worker_count = 2, .job_size = 128, .max_inflight_jobs = 2, .max_inflight_bytes = 256 } };
}

fn refused(encoder: anytype, payload: []const u8, expected: anyerror) !void {
    var regions: [12][]const u8 = @splat(&.{});
    regions[0] = std.mem.asBytes(encoder);
    regions[1] = payload;
    if (comptime @hasField(@TypeOf(encoder.*), "owner")) {
        const owner = encoder.owner;
        regions[2] = std.mem.asBytes(owner);
        regions[3] = std.mem.asBytes(owner.control);
        regions[4] = std.mem.asBytes(owner.queue);
        regions[5] = std.mem.sliceAsBytes(owner.queue.jobs);
        regions[6] = std.mem.sliceAsBytes(owner.queue.workers);
        if (owner.options.frame.memory_profile) |profile| regions[7] = std.mem.asBytes(profile);
        if (owner.options.frame.control_profile) |profile| regions[8] = std.mem.asBytes(profile);
        if (owner.options.parallel.profile) |profile| regions[9] = std.mem.asBytes(profile);
    } else {
        if (encoder.options.memory_profile) |profile| regions[7] = std.mem.asBytes(profile);
        if (encoder.options.control_profile) |profile| regions[8] = std.mem.asBytes(profile);
        if (encoder.allocation.lease) |lease| if (lease.state) |state| {
            regions[2] = std.mem.asBytes(state);
            if (state.profile) |profile| regions[9] = std.mem.asBytes(profile);
        };
    }
    var saved: [regions.len][]u8 = @splat(&.{});
    defer for (saved) |bytes| h.a.free(bytes);
    for (regions, &saved) |region, *bytes| bytes.* = try h.a.dupe(u8, region);
    try std.testing.expectError(expected, encoder.writeSkippable(3, payload));
    for (regions, saved) |region, bytes| try std.testing.expectEqualSlices(u8, bytes, region);
}

fn ownedList(encoder: anytype, list: anytype) !void {
    const bytes = std.mem.sliceAsBytes(list.allocatedSlice());
    try std.testing.expect(bytes.len > 0 and list.items.len < list.capacity);
    @memset(bytes, 0x83);
    try refused(encoder, bytes[bytes.len - 1 ..], error.InvalidBlockPlan);
}

fn drain(encoder: anytype, id: u4, payload: []const u8) !void {
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.a);
    var output: [17]u8 = undefined;
    for (0..(payload.len + 8) / output.len + 4) |_| {
        const step = try encoder.step("", &output);
        try wire.appendSlice(h.a, output[0..step.progress.output_written]);
        if (step.status == .done) break;
    } else return error.TestUnexpectedResult;
    try std.testing.expectEqual(payload.len + 8, wire.items.len);
    try std.testing.expectEqual(@as(u32, 0x184D2A50) + id, std.mem.readInt(u32, wire.items[0..4], .little));
    try std.testing.expectEqual(@as(u32, @intCast(payload.len)), std.mem.readInt(u32, wire.items[4..8], .little));
    try std.testing.expectEqualSlices(u8, payload, wire.items[8..]);
}

fn successFlow(comptime Z: type, encoder: anytype) !void {
    var payload: [64]u8 = @splat(0x72);
    const before = payload;
    try encoder.writeSkippable(15, &payload); // Direct retry after refusal.
    @memset(&payload, 0x44); // Payload is borrowed only until this call returns.
    try drain(encoder, 15, &before);
    try std.testing.expectEqual(.none, encoder.prefixSnapshot().phase);
    try std.testing.expectEqual(.skippable, encoder.prefixSnapshot().used_for);
    try encoder.writeSkippable(0, ""); // Drained boundary and exact empty header.
    try drain(encoder, 0, "");
    try encoder.setPrefix(&payload);
    try encoder.writeSkippable(3, &payload); // Immutable dictionary and payload share.
    try drain(encoder, 3, &payload);
    const invalid = Z.NativeDictionary{ .id = 7, .content = "history", .standard_bytes = "bad" };
    try encoder.setPrefixWithDictionary(invalid);
    try encoder.writeSkippable(4, "metadata is not read for skippable");
    try drain(encoder, 4, "metadata is not read for skippable");
    try encoder.nextFrame(encoder.options);
    try h.roundTrip(Z, encoder, "next ordinary data frame", null);
    try refused(encoder, std.mem.asBytes(encoder)[0..1], error.InvalidBlockPlan);
    try encoder.writeSkippable(2, "done boundary retry");
    try drain(encoder, 2, "done boundary retry");
}

pub fn serialReceiver(comptime Z: type) !void {
    var encoder = try Z.NativeIncrementalFrameEncoder.initWithPrefix(h.a, h.options(Z), "prefix");
    defer encoder.deinit();
    try refused(&encoder, std.mem.asBytes(&encoder.prefix_state), error.InvalidBlockPlan);
    try refused(&encoder, std.mem.asBytes(&encoder.options), error.InvalidBlockPlan);
    inline for (.{ "block", "pending" }) |field| {
        try @field(encoder, field).ensureTotalCapacity(h.a, 16);
        try ownedList(&encoder, @field(encoder, field));
    }
    try encoder.history.bytes.ensureTotalCapacity(h.a, 16);
    try ownedList(&encoder, encoder.history.bytes);
    inline for (.{ "recent_entries", "long_entries" }) |field| {
        try @field(encoder.history.index, field).ensureTotalCapacity(h.a, 4);
        try ownedList(&encoder, @field(encoder.history.index, field));
    }
    try successFlow(Z, &encoder);
    try stageAndSize(Z, false);
    try physicalOom(Z, false);
}

pub fn parallelReceiver(comptime Z: type) !void {
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.initWithPrefix(h.a, parallelOptions(Z), "prefix");
    defer encoder.deinit();
    try refused(&encoder, std.mem.asBytes(&encoder.owner.prefix_state), error.InvalidBlockPlan);
    try refused(&encoder, std.mem.asBytes(&encoder.options), error.InvalidBlockPlan);
    const owner = encoder.owner;
    const allocator = owner.control.allocator();
    try refused(&encoder, std.mem.asBytes(owner.control)[0..1], error.InvalidBlockPlan);
    try refused(&encoder, std.mem.asBytes(owner.queue)[0..1], error.InvalidBlockPlan);
    try refused(&encoder, std.mem.sliceAsBytes(owner.queue.jobs)[0..1], error.InvalidBlockPlan);
    try owner.state.front.ensureTotalCapacity(allocator, 16);
    try ownedList(&encoder, owner.state.front);
    try owner.queue.history.bytes.ensureTotalCapacity(allocator, 16);
    try ownedList(&encoder, owner.queue.history.bytes);
    for (owner.queue.jobs) |*job| {
        try job.bytes.ensureTotalCapacity(allocator, 16);
        try job.output.ensureTotalCapacity(allocator, 16);
        try ownedList(&encoder, job.bytes);
        try ownedList(&encoder, job.output);
    }
    inline for (.{ "values", "literals", "candidate" }) |field| {
        try @field(owner.actual_state, field).ensureTotalCapacity(allocator, 4);
        try ownedList(&encoder, @field(owner.actual_state, field));
    }
    inline for (std.meta.fields(@TypeOf(owner.actual_state.scratch))) |field| if (comptime field.type != bool) {
        try @field(owner.actual_state.scratch, field.name).ensureTotalCapacity(allocator, 4);
        try ownedList(&encoder, @field(owner.actual_state.scratch, field.name));
    };
    try successFlow(Z, &encoder);
    try heldMutex(Z);
    try stageAndSize(Z, true);
    try physicalOom(Z, true);
}

pub fn serialProfile(comptime Z: type) !void {
    var profile: Z.EncodeMemoryProfile = .{};
    var control: Z.EncoderControlProfile = .{};
    var options = h.options(Z);
    options.memory_profile = &profile;
    options.control_profile = &control;
    var encoder = try Z.NativeIncrementalFrameEncoder.initWithPrefix(h.a, options, "prefix");
    defer encoder.deinit();
    try refused(&encoder, std.mem.asBytes(&profile), error.InvalidBlockPlan);
    try refused(&encoder, std.mem.asBytes(&control), error.InvalidBlockPlan);
    var next: Z.EncodeMemoryProfile = .{};
    encoder.options.memory_profile = &next;
    try refused(&encoder, std.mem.asBytes(&profile), error.InvalidBlockPlan);
    try refused(&encoder, std.mem.asBytes(&next), error.InvalidBlockPlan);
    try successFlow(Z, &encoder);
    try sharedObserver(Z);
}

pub fn parallelProfile(comptime Z: type) !void {
    var profile: Z.EncodeMemoryProfile = .{};
    var control: Z.EncoderControlProfile = .{};
    var parallel: Z.NativeIncrementalParallelFrameEncoder.ParallelProfile = .{};
    var options = parallelOptions(Z);
    options.frame.memory_profile = &profile;
    options.frame.control_profile = &control;
    options.parallel.profile = &parallel;
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.initWithPrefix(h.a, options, "prefix");
    defer encoder.deinit();
    try refused(&encoder, std.mem.asBytes(&profile), error.InvalidBlockPlan);
    try refused(&encoder, std.mem.asBytes(&control), error.InvalidBlockPlan);
    try refused(&encoder, std.mem.asBytes(&parallel), error.InvalidBlockPlan);
    try successFlow(Z, &encoder);
}

pub fn parallelPending(comptime Z: type) !void {
    var profile: Z.EncodeMemoryProfile = .{};
    var options = parallelOptions(Z);
    options.frame.memory_profile = &profile;
    options.max_pending_output_len = 8;
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.initWithPrefix(h.a, options, "prefix");
    defer encoder.deinit();
    try refused(&encoder, "payload", error.OutputLimitExceeded);
    try std.testing.expectEqual(.none, encoder.owner.state.unit);
    encoder.options.max_pending_output_len = 64;
    try encoder.writeSkippable(3, "payload");
    // Lowering a limit after successful acceptance still retains queued output.
    encoder.options.max_pending_output_len = 0;
    const retained = try h.a.dupe(u8, encoder.owner.state.front.items);
    defer h.a.free(retained);
    try std.testing.expectError(error.OutputLimitExceeded, encoder.step("", &.{}));
    try std.testing.expectEqual(.skippable, encoder.owner.state.unit);
    try std.testing.expectEqualSlices(u8, retained, encoder.owner.state.front.items);
    encoder.options.max_pending_output_len = 64;
    try drain(&encoder, 3, "payload");
}

fn sharedObserver(comptime Z: type) !void {
    const total = @import("../../encode/total_budget.zig");
    var profile: Z.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(h.a, null, &profile, 0);
    defer lease.deinit();
    var encoder = try Z.NativeIncrementalFrameEncoder.initWithPrefix(lease.allocator(), h.options(Z), "prefix");
    defer encoder.deinit();
    try refused(&encoder, std.mem.asBytes(&profile), error.InvalidBlockPlan);
    try successFlow(Z, &encoder);
}

fn heldMutex(comptime Z: type) !void {
    if (comptime !@import("../../parallel/types.zig").target_supports_parallel) return;
    var options = parallelOptions(Z);
    options.parallel.io = std.testing.io;
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.initWithPrefix(h.a, options, "prefix");
    defer encoder.deinit();
    const queue = encoder.owner.queue;
    try std.testing.expect(queue.config.geometry.worker_count > 0 and !queue.started);
    {
        try queue.mutex.lock(options.parallel.io);
        defer queue.mutex.unlock(options.parallel.io);
        try refused(&encoder, std.mem.asBytes(&queue.mutex)[0..1], error.InvalidBlockPlan);
        try refused(&encoder, std.mem.asBytes(&encoder)[0..1], error.InvalidBlockPlan);
        try refused(&encoder, std.mem.asBytes(encoder.owner)[0..1], error.InvalidBlockPlan);
        try refused(&encoder, std.mem.asBytes(encoder.owner.control)[0..1], error.InvalidBlockPlan);
        try refused(&encoder, std.mem.sliceAsBytes(queue.jobs)[0..1], error.InvalidBlockPlan);
        try refused(&encoder, std.mem.sliceAsBytes(queue.workers)[0..1], error.InvalidBlockPlan);
    }
    try successFlow(Z, &encoder);
}

fn stageAndSize(comptime Z: type, comptime parallel: bool) !void {
    var profile: Z.EncodeMemoryProfile = .{};
    var options = if (parallel) parallelOptions(Z) else h.options(Z);
    if (parallel) options.frame.memory_profile = &profile else options.memory_profile = &profile;
    var encoder = if (parallel)
        try Z.NativeIncrementalParallelFrameEncoder.initWithPrefix(h.a, options, "prefix")
    else
        try Z.NativeIncrementalFrameEncoder.initWithPrefix(h.a, options, "prefix");
    defer encoder.deinit();
    const before = try h.a.dupe(u8, std.mem.asBytes(&profile));
    defer h.a.free(before);
    const receiver = try h.a.dupe(u8, std.mem.asBytes(&encoder));
    defer h.a.free(receiver);
    // The descriptor is never read: its wire length must be refused first.
    const huge = std.mem.asBytes(&profile).ptr[0..std.math.maxInt(usize)];
    try std.testing.expectError(error.IntegerOverflow, encoder.writeSkippable(0, huge));
    try std.testing.expectEqualSlices(u8, before, std.mem.asBytes(&profile));
    try std.testing.expectEqualSlices(u8, receiver, std.mem.asBytes(&encoder));
    _ = try encoder.step("", &.{});
    try refused(&encoder, "busy frame", error.InvalidBlockPlan);
    try h.roundTrip(Z, &encoder, "finish busy data", null);

    var magicless = if (parallel) parallelOptions(Z) else h.options(Z);
    if (parallel) magicless.frame.format = .magicless else magicless.format = .magicless;
    var other = if (parallel)
        try Z.NativeIncrementalParallelFrameEncoder.initWithPrefix(h.a, magicless, "prefix")
    else
        try Z.NativeIncrementalFrameEncoder.initWithPrefix(h.a, magicless, "prefix");
    defer other.deinit();
    try refused(&other, std.mem.asBytes(&other)[0..1], error.InvalidBlockPlan);
    try std.testing.expectError(error.InvalidBlockPlan, other.writeSkippable(0, huge));
}

fn physicalOom(comptime Z: type, comptime parallel: bool) !void {
    var backing = std.testing.FailingAllocator.init(h.a, .{});
    var options = if (parallel) parallelOptions(Z) else h.options(Z);
    if (parallel) options.frame.dictionary_usage = .prefix else options.dictionary_usage = .prefix;
    const dictionary = Z.NativeDictionary.init(7, "prefix");
    var encoder = if (parallel)
        try Z.NativeIncrementalParallelFrameEncoder.initWithPresetDictionary(backing.allocator(), options, dictionary)
    else
        try Z.NativeIncrementalFrameEncoder.initWithPresetDictionary(backing.allocator(), options, dictionary);
    defer encoder.deinit();
    backing.fail_index = backing.alloc_index;
    try std.testing.expectError(error.OutOfMemory, encoder.writeSkippable(0, "payload"));
    try std.testing.expectEqual(.none, encoder.prefixSnapshot().phase);
    if (parallel) {
        try std.testing.expectEqual(@as(?Z.NativeIncrementalParallelFrameEncoder.Error, error.OutOfMemory), encoder.owner.failure);
        try std.testing.expectEqual(@as(u32, 0), encoder.options.frame.dictionary_id);
        try refused(&encoder, std.mem.asBytes(&encoder.options), error.OutOfMemory);
    } else {
        // Serial allocation refusal keeps its existing direct retry behavior.
        backing.fail_index = std.math.maxInt(usize);
        try encoder.setPrefix("retry prefix");
        try encoder.writeSkippable(0, "retry payload");
        try drain(&encoder, 0, "retry payload");
    }
}
