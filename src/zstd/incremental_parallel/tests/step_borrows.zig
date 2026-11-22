const std = @import("std");
const h = @import("../../incremental/encoder/step_borrow_helpers.zig");
const target_supports_parallel = @import("../../parallel/types.zig").target_supports_parallel;

fn options(comptime Z: type) Z.NativeIncrementalParallelFrameEncoder.Options {
    return .{
        .frame = h.options(Z),
        .parallel = .{ .io = std.Io.failing, .worker_count = 2, .job_size = 128, .max_inflight_jobs = 2, .max_inflight_bytes = 256 },
    };
}

pub fn contracts(comptime Z: type) !void {
    try freshAndPrefix(Z);
    try privateCapacity(Z);
    try dictionariesAndProfiles(Z);
    try workerMetadata(Z);
    try heldQueueMutex(Z);
}

fn heldQueueMutex(comptime Z: type) !void {
    if (comptime !target_supports_parallel) return;
    var configured = options(Z);
    configured.parallel.io = std.testing.io;
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.init(h.a, configured);
    defer encoder.deinit();
    const owner = encoder.owner;
    const queue = owner.queue;
    try std.testing.expect(queue.config.geometry.worker_count > 0);
    try std.testing.expect(!queue.started);
    try owner.state.front.ensureTotalCapacity(owner.control.allocator(), 32);
    @memset(owner.state.front.allocatedSlice(), 0x83);
    const regions = [_][]u8{
        std.mem.asBytes(&encoder)[0..1],
        std.mem.asBytes(owner)[0..1],
        std.mem.asBytes(owner.control)[0..1],
        std.mem.asBytes(queue)[0..1],
        std.mem.asBytes(&queue.mutex)[0..1],
        std.mem.sliceAsBytes(queue.jobs)[0..1],
        std.mem.sliceAsBytes(queue.workers)[0..1],
        owner.state.front.allocatedSlice()[owner.state.front.capacity - 1 ..],
        std.mem.asBytes(&owner.actual_state)[0..1],
    };
    {
        // No worker has started. Holding this mutex makes public refusal
        // observable: any attempt to acquire it before validating the offer
        // would wait on this same thread instead of returning InvalidBlockPlan.
        try queue.mutex.lock(configured.parallel.io);
        defer queue.mutex.unlock(configured.parallel.io);
        var output: [19]u8 = @splat(0xA5);
        for (regions) |region| {
            try h.rejected(&encoder, region, &output, false);
            try h.rejected(&encoder, region, &output, true);
            try h.rejected(&encoder, "input", region, false);
            try h.rejected(&encoder, "input", region, true);
        }
    }
    try h.roundTrip(Z, &encoder, "held mutex refusal retry", null);
}

fn workerMetadata(comptime Z: type) !void {
    var configured = options(Z);
    configured.parallel.io = std.testing.io;
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.init(h.a, configured);
    defer encoder.deinit();
    const workers = std.mem.sliceAsBytes(encoder.owner.queue.workers);
    if (workers.len != 0) {
        try h.rejected(&encoder, workers[workers.len - 1 ..], &.{}, false);
        try h.rejected(&encoder, "input", workers[workers.len - 1 ..], true);
    }
    try h.roundTrip(Z, &encoder, "worker metadata retry", null);
}

fn freshAndPrefix(comptime Z: type) !void {
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.init(h.a, options(Z));
    defer encoder.deinit();
    var storage: [64]u8 = undefined;
    for (&storage, 0..) |*byte, i| byte.* = @truncate(i * 19 + 5);
    try h.rejected(&encoder, storage[0..32], storage[0..32], false);
    try h.rejected(&encoder, storage[0..32], storage[1..33], true);
    try h.rejected(&encoder, storage[1..33], storage[0..32], false);
    try h.rejected(&encoder, std.mem.asBytes(&encoder)[0..1], &.{}, true);
    try h.rejected(&encoder, "", std.mem.asBytes(&encoder)[0..1], false);
    try h.roundTrip(Z, &encoder, storage[0..32], null);
    const before = encoder.snapshot();
    try std.testing.expectEqual(.done, (try encoder.step("", std.mem.asBytes(encoder.owner))).status);
    try std.testing.expectEqualDeep(before, encoder.snapshot());

    var prefix_bytes: [32]u8 = @splat(0x62);
    var prefixed = try Z.NativeIncrementalParallelFrameEncoder.initWithPrefix(h.a, options(Z), &prefix_bytes);
    defer prefixed.deinit();
    try h.rejected(&prefixed, "input", prefix_bytes[0..1], true);
    try std.testing.expectEqual(.pending, prefixed.prefixSnapshot().phase);
    var output: [32]u8 = undefined;
    _ = try prefixed.step("", &output);
    try std.testing.expectEqual(.active, prefixed.prefixSnapshot().phase);
    // Preserve a prior failedProgress record as well as active prefix state.
    prefixed.options.max_output_len = 0;
    try std.testing.expectError(error.OutputLimitExceeded, prefixed.stepWithDirective("abc", &output, .end));
    const failed = prefixed.failedProgress();
    try h.rejected(&prefixed, "", prefix_bytes[0..1], false);
    try std.testing.expectEqual(failed, prefixed.failedProgress());
    try std.testing.expectEqual(.active, prefixed.prefixSnapshot().phase);
    prefixed.options.max_output_len = std.math.maxInt(Z.NativeIncrementalParallelFrameEncoder.Count);
    for (0..128) |_| {
        if ((try prefixed.step("", &output)).status == .done) break;
    } else return error.TestUnexpectedResult;
}

fn privateCapacity(comptime Z: type) !void {
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.init(h.a, options(Z));
    defer encoder.deinit();
    const owner = encoder.owner;
    const allocator = owner.control.allocator();
    try h.rejected(&encoder, std.mem.asBytes(owner)[0..1], &.{}, false);
    try h.rejected(&encoder, "input", std.mem.asBytes(owner.control)[0..1], true);
    try h.rejected(&encoder, "input", std.mem.asBytes(owner.queue)[0..1], false);
    try h.rejected(&encoder, std.mem.sliceAsBytes(owner.queue.jobs)[0..1], &.{}, true);
    if (owner.queue.workers.len != 0) try h.rejected(&encoder, "input", std.mem.sliceAsBytes(owner.queue.workers)[0..1], false);
    try owner.state.front.ensureTotalCapacity(allocator, 32);
    try h.ownedList(&encoder, owner.state.front);
    try owner.queue.history.bytes.ensureTotalCapacity(allocator, 32);
    try h.ownedList(&encoder, owner.queue.history.bytes);
    for (owner.queue.jobs) |*job| {
        try job.bytes.ensureTotalCapacity(allocator, 32);
        try h.ownedList(&encoder, job.bytes);
        try job.output.ensureTotalCapacity(allocator, 32);
        try h.ownedList(&encoder, job.output);
    }
    inline for (.{ "values", "literals", "candidate" }) |field| {
        try @field(owner.actual_state, field).ensureTotalCapacity(allocator, 4);
        try h.ownedList(&encoder, @field(owner.actual_state, field));
    }
    inline for (std.meta.fields(@TypeOf(owner.actual_state.scratch))) |field| if (comptime field.type != bool) {
        try @field(owner.actual_state.scratch, field.name).ensureTotalCapacity(allocator, 4);
        try h.ownedList(&encoder, @field(owner.actual_state.scratch, field.name));
    };
    encoder.reset();
    try h.ownedList(&encoder, owner.queue.jobs[0].bytes);
    try h.roundTrip(Z, &encoder, "parallel capacity retry", null);
}

fn dictionariesAndProfiles(comptime Z: type) !void {
    var memory: Z.EncodeMemoryProfile = .{};
    var control: Z.EncoderControlProfile = .{};
    var parallel: Z.NativeIncrementalParallelFrameEncoder.ParallelProfile = .{};
    var configured = options(Z);
    configured.frame.memory_profile = &memory;
    configured.frame.control_profile = &control;
    configured.parallel.profile = &parallel;
    var bytes: [64]u8 = @splat(0x73);
    const raw = Z.NativeDictionary.initRawContent(&bytes);
    var prepared = try Z.PreparedDecodeDictionary.init(raw);
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.initWithPresetDictionary(h.a, configured, prepared.handle());
    defer encoder.deinit();
    try h.rejected(&encoder, "input", bytes[0..1], false);
    try h.rejected(&encoder, "input", std.mem.asBytes(&prepared.state)[0..1], true);
    inline for (.{ "memory_profile", "control_profile" }) |field| {
        const profile_bytes = std.mem.asBytes(@field(configured.frame, field).?);
        try h.rejected(&encoder, profile_bytes[0..1], &.{}, false);
        try h.rejected(&encoder, "input", profile_bytes[0..1], true);
    }
    try h.rejected(&encoder, std.mem.asBytes(&parallel)[0..1], &.{}, false);
    try h.rejected(&encoder, "input", std.mem.asBytes(&parallel)[0..1], true);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.setDictionary(Z.NativeDictionary.initRawContent(std.mem.asBytes(&control))));
    try encoder.setDictionary(prepared.handle());
    try h.roundTrip(Z, &encoder, bytes[0..32], raw);

    const standard = try @import("../../encode/hq_test_helpers.zig").fullDictionary(h.a);
    defer h.a.free(standard);
    const dictionary = (try Z.NativeDictionary.initFromStandardDictionary(standard)).dictionary;
    var full_options = options(Z);
    full_options.frame.dictionary_id = dictionary.id;
    var full = try Z.NativeIncrementalParallelFrameEncoder.initWithPresetDictionary(h.a, full_options, dictionary);
    defer full.deinit();
    try h.rejected(&full, "input", standard[0..1], false);
    try h.rejected(&full, "input", @constCast(dictionary.content[0..1]), true);
    try h.roundTrip(Z, &full, dictionary.content[0..32], dictionary);
}
