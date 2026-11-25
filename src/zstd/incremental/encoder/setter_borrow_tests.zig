const std = @import("std");
const h = @import("step_borrow_helpers.zig");
const Mode = enum { prefix, prefix_dictionary, dictionary };
const modes = [_]Mode{ .prefix, .prefix_dictionary, .dictionary };

fn install(encoder: anytype, dictionary: anytype, mode: Mode) !void {
    return switch (mode) {
        .prefix => encoder.setPrefix(dictionary.content),
        .prefix_dictionary => encoder.setPrefixWithDictionary(dictionary),
        .dictionary => encoder.setDictionary(dictionary),
    };
}

fn rejected(encoder: anytype, dictionary: anytype, mode: Mode, expected: anyerror) !void {
    var regions: [15][]const u8 = @splat(&.{});
    regions[0] = std.mem.asBytes(encoder);
    regions[1] = dictionary.content;
    if (dictionary.standard_bytes) |bytes| regions[2] = bytes;
    if (dictionary.prepared) |prepared| regions[3] = std.mem.asBytes(prepared);
    if (comptime @hasField(@TypeOf(encoder.*), "owner")) {
        const owner = encoder.owner;
        regions[4] = std.mem.asBytes(owner);
        regions[5] = std.mem.asBytes(owner.control);
        regions[6] = std.mem.asBytes(owner.queue);
        regions[7] = std.mem.sliceAsBytes(owner.queue.jobs);
        regions[8] = std.mem.sliceAsBytes(owner.queue.workers);
        if (owner.options.frame.memory_profile) |profile| regions[9] = std.mem.asBytes(profile);
        if (owner.options.frame.control_profile) |profile| regions[10] = std.mem.asBytes(profile);
        if (owner.options.parallel.profile) |profile| regions[11] = std.mem.asBytes(profile);
    } else {
        if (encoder.options.memory_profile) |profile| regions[9] = std.mem.asBytes(profile);
        if (encoder.options.control_profile) |profile| regions[10] = std.mem.asBytes(profile);
        if (encoder.allocation.lease) |lease| if (lease.state) |state| {
            regions[4] = std.mem.asBytes(state);
            if (state.profile) |profile| regions[11] = std.mem.asBytes(profile);
        };
    }
    var saved: [regions.len][]u8 = @splat(&.{});
    defer for (saved) |bytes| h.a.free(bytes);
    for (regions, &saved) |region, *bytes| bytes.* = try h.a.dupe(u8, region);
    try std.testing.expectError(expected, install(encoder, dictionary, mode));
    for (regions, saved) |region, bytes| try std.testing.expectEqualSlices(u8, bytes, region);
}

fn rejectedBytes(comptime Z: type, encoder: anytype, bytes: []const u8, expected: anyerror) !void {
    for (modes) |mode| try rejected(encoder, Z.NativeDictionary.initRawContent(bytes), mode, expected);
}

fn ownedList(comptime Z: type, encoder: anytype, list: anytype) !void {
    const bytes = std.mem.sliceAsBytes(list.allocatedSlice());
    try std.testing.expect(bytes.len != 0 and list.items.len < list.capacity);
    @memset(bytes, 0x83);
    try rejectedBytes(Z, encoder, bytes[bytes.len - 1 ..], error.InvalidBlockPlan);
}

fn replacementFlow(comptime Z: type, encoder: anytype) !void {
    var bytes: [64]u8 = @splat(0x71);
    const dictionary = Z.NativeDictionary.initRawContent(&bytes);
    for (modes) |mode| try install(encoder, dictionary, mode);
    try encoder.setPrefix(bytes[1..]); // Old and new reads may share storage.
    try encoder.setPrefixWithDictionary(Z.NativeDictionary.initRawContent(bytes[2..]));
    try encoder.clearDictionary();
    try encoder.setPrefix("");
    try std.testing.expectEqual(.none, encoder.prefixSnapshot().phase);
    try encoder.setDictionary(Z.NativeDictionary.initRawContent(""));
    try encoder.setPrefixWithDictionary(Z.NativeDictionary.initRawContent(""));
    try encoder.clearDictionary();
    try encoder.setDictionary(dictionary);
    try h.roundTrip(Z, encoder, bytes[0..32], dictionary); // Input is also a read.
    try rejectedBytes(Z, encoder, std.mem.asBytes(encoder)[0..1], error.InvalidBlockPlan);
    try encoder.setPrefix(&bytes); // Direct retry at done, without reset.
    try encoder.nextFrame(encoder.options);
    _ = try encoder.step("", &.{});
    try rejectedBytes(Z, encoder, std.mem.asBytes(encoder)[0..1], error.InvalidStreamState);
    try std.testing.expectError(error.InvalidStreamState, encoder.clearDictionary());
    try h.roundTrip(Z, encoder, bytes[0..32], dictionary);
    try encoder.clearDictionary();
    try encoder.setPrefix(&bytes);
    try encoder.clearDictionary();
}

fn fullDictionaryFlow(comptime Z: type, encoder: anytype) !void {
    const bytes = try @import("../../encode/hq_test_helpers.zig").fullDictionary(h.a);
    defer h.a.free(bytes);
    const dictionary = (try Z.NativeDictionary.initFromStandardDictionary(bytes)).dictionary;
    var prepared = try Z.PreparedDecodeDictionary.init(dictionary);
    try encoder.setPrefixWithDictionary(dictionary); // Content lies inside FULL bytes.
    try encoder.setDictionary(prepared.handle());
    var invalid = dictionary;
    invalid.id +%= 1;
    try rejected(encoder, invalid, .dictionary, error.InvalidDictionaryMetadata);
    try encoder.setPrefixWithDictionary(invalid); // Prefix metadata stays deferred.
    try encoder.setPrefixWithDictionary(prepared.handle()); // Replace before encoding.
    try encoder.clearDictionary();
    try encoder.setDictionary(prepared.handle());
    try encoder.clearDictionary();
}

fn parallelOptions(comptime Z: type) Z.NativeIncrementalParallelFrameEncoder.Options {
    return .{ .frame = h.options(Z), .parallel = .{ .io = std.Io.failing, .worker_count = 2, .job_size = 128, .max_inflight_jobs = 2, .max_inflight_bytes = 256 } };
}

pub fn serial(comptime Z: type) !void {
    var encoder = try Z.NativeIncrementalFrameEncoder.init(h.a, h.options(Z));
    defer encoder.deinit();
    const bytes = std.mem.asBytes(&encoder.prefix_state);
    const before = try h.a.dupe(u8, bytes);
    defer h.a.free(before);
    const result = encoder.setPrefix(bytes);
    try std.testing.expectError(error.InvalidBlockPlan, result);
    try std.testing.expectEqualSlices(u8, before, bytes);
    try rejectedBytes(Z, &encoder, bytes, error.InvalidBlockPlan);
    inline for (.{ "block", "pending" }) |field| {
        try @field(encoder, field).ensureTotalCapacity(h.a, 16);
        try ownedList(Z, &encoder, @field(encoder, field));
    }
    try encoder.history.bytes.ensureTotalCapacity(h.a, 16);
    try ownedList(Z, &encoder, encoder.history.bytes);
    inline for (.{ "recent_entries", "long_entries" }) |field| {
        try @field(encoder.history.index, field).ensureTotalCapacity(h.a, 4);
        try ownedList(Z, &encoder, @field(encoder.history.index, field));
    }
    try fullDictionaryFlow(Z, &encoder);
    try replacementFlow(Z, &encoder);
}

pub fn parallel(comptime Z: type) !void {
    var options = parallelOptions(Z);
    options.frame.dictionary_id = 7;
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.initWithDictionary(h.a, options, 7);
    defer encoder.deinit();
    const bytes = std.mem.asBytes(&encoder.options.frame.dictionary_id);
    const before = try h.a.dupe(u8, bytes);
    defer h.a.free(before);
    const result = encoder.setPrefix(bytes);
    try std.testing.expectError(error.InvalidBlockPlan, result);
    try std.testing.expectEqualSlices(u8, before, bytes);
    try rejectedBytes(Z, &encoder, bytes, error.InvalidBlockPlan);
    const owner = encoder.owner;
    const allocator = owner.control.allocator();
    try rejectedBytes(Z, &encoder, std.mem.asBytes(owner)[0..1], error.InvalidBlockPlan);
    try rejectedBytes(Z, &encoder, std.mem.asBytes(owner.control)[0..1], error.InvalidBlockPlan);
    try rejectedBytes(Z, &encoder, std.mem.asBytes(owner.queue)[0..1], error.InvalidBlockPlan);
    try rejectedBytes(Z, &encoder, std.mem.sliceAsBytes(owner.queue.jobs)[0..1], error.InvalidBlockPlan);
    try owner.state.front.ensureTotalCapacity(allocator, 16);
    try ownedList(Z, &encoder, owner.state.front);
    try owner.queue.history.bytes.ensureTotalCapacity(allocator, 16);
    try ownedList(Z, &encoder, owner.queue.history.bytes);
    for (owner.queue.jobs) |*job| {
        try job.bytes.ensureTotalCapacity(allocator, 16);
        try job.output.ensureTotalCapacity(allocator, 16);
        try ownedList(Z, &encoder, job.bytes);
        try ownedList(Z, &encoder, job.output);
    }
    inline for (.{ "values", "literals", "candidate" }) |field| {
        try @field(owner.actual_state, field).ensureTotalCapacity(allocator, 4);
        try ownedList(Z, &encoder, @field(owner.actual_state, field));
    }
    inline for (std.meta.fields(@TypeOf(owner.actual_state.scratch))) |field| if (comptime field.type != bool) {
        try @field(owner.actual_state.scratch, field.name).ensureTotalCapacity(allocator, 4);
        try ownedList(Z, &encoder, @field(owner.actual_state.scratch, field.name));
    };
    try fullDictionaryFlow(Z, &encoder);
    try replacementFlow(Z, &encoder);
    try heldMutex(Z);
}

pub fn serialProfile(comptime Z: type) !void {
    var profile: Z.EncodeMemoryProfile = .{};
    var control: Z.EncoderControlProfile = .{};
    var options = h.options(Z);
    options.memory_profile = &profile;
    options.control_profile = &control;
    var encoder = try Z.NativeIncrementalFrameEncoder.init(h.a, options);
    defer encoder.deinit();
    try rejectedBytes(Z, &encoder, std.mem.asBytes(&profile), error.InvalidBlockPlan);
    try rejectedBytes(Z, &encoder, std.mem.asBytes(&control), error.InvalidBlockPlan);
    try observerDictionarySpans(Z, &encoder, &profile);
    var next_profile: Z.EncodeMemoryProfile = .{};
    encoder.options.memory_profile = &next_profile;
    try rejectedBytes(Z, &encoder, std.mem.asBytes(&profile), error.InvalidBlockPlan);
    try rejectedBytes(Z, &encoder, std.mem.asBytes(&next_profile), error.InvalidBlockPlan);
    try replacementFlow(Z, &encoder);
    try sharedObserver(Z);
}

pub fn parallelProfile(comptime Z: type) !void {
    var profile: Z.EncodeMemoryProfile = .{};
    var control: Z.EncoderControlProfile = .{};
    var parallel_profile: Z.NativeIncrementalParallelFrameEncoder.ParallelProfile = .{};
    var options = parallelOptions(Z);
    options.frame.memory_profile = &profile;
    options.frame.control_profile = &control;
    options.parallel.profile = &parallel_profile;
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.init(h.a, options);
    defer encoder.deinit();
    try rejectedBytes(Z, &encoder, std.mem.asBytes(&profile), error.InvalidBlockPlan);
    try rejectedBytes(Z, &encoder, std.mem.asBytes(&control), error.InvalidBlockPlan);
    try rejectedBytes(Z, &encoder, std.mem.asBytes(&parallel_profile), error.InvalidBlockPlan);
    try observerDictionarySpans(Z, &encoder, &profile);
    try replacementFlow(Z, &encoder);
}

fn observerDictionarySpans(comptime Z: type, encoder: anytype, profile: *Z.EncodeMemoryProfile) !void {
    // Advanced prefix handles defer FULL metadata validation. Reject a live
    // observer's bytes before such a handle could publish them as a read borrow.
    var dictionary = Z.NativeDictionary.initRawContent("independent dictionary content");
    dictionary.standard_bytes = std.mem.asBytes(profile);
    try rejected(encoder, dictionary, .prefix_dictionary, error.InvalidBlockPlan);
    try rejected(encoder, dictionary, .dictionary, error.InvalidBlockPlan);

    // Use a real caller-owned prepared object as a profile backing allocation.
    // No handle is published until initialization finishes writing observations.
    const raw = Z.NativeDictionary.initRawContent("prepared observer backing");
    var prepared = try Z.PreparedDecodeDictionary.init(raw);
    const prepared_profile: *Z.EncodeMemoryProfile = @ptrCast(@alignCast(&prepared.state));
    prepared_profile.* = .{};
    if (comptime @hasField(@TypeOf(encoder.*), "owner")) {
        var options = parallelOptions(Z);
        options.frame.memory_profile = prepared_profile;
        var prepared_encoder = try Z.NativeIncrementalParallelFrameEncoder.init(h.a, options);
        defer prepared_encoder.deinit();
        try rejected(&prepared_encoder, prepared.handle(), .prefix_dictionary, error.InvalidBlockPlan);
        try rejected(&prepared_encoder, prepared.handle(), .dictionary, error.InvalidBlockPlan);
    } else {
        var options = h.options(Z);
        options.memory_profile = prepared_profile;
        var prepared_encoder = try Z.NativeIncrementalFrameEncoder.init(h.a, options);
        defer prepared_encoder.deinit();
        try rejected(&prepared_encoder, prepared.handle(), .prefix_dictionary, error.InvalidBlockPlan);
        try rejected(&prepared_encoder, prepared.handle(), .dictionary, error.InvalidBlockPlan);
    }
}

fn heldMutex(comptime Z: type) !void {
    if (comptime !@import("../../parallel/types.zig").target_supports_parallel) return;
    var options = parallelOptions(Z);
    options.parallel.io = std.testing.io;
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.init(h.a, options);
    defer encoder.deinit();
    const queue = encoder.owner.queue;
    try std.testing.expect(queue.config.geometry.worker_count > 0 and !queue.started);
    {
        try queue.mutex.lock(options.parallel.io);
        defer queue.mutex.unlock(options.parallel.io);
        try rejectedBytes(Z, &encoder, std.mem.asBytes(&queue.mutex)[0..1], error.InvalidBlockPlan);
        try rejectedBytes(Z, &encoder, std.mem.asBytes(&encoder)[0..1], error.InvalidBlockPlan);
        try rejectedBytes(Z, &encoder, std.mem.asBytes(encoder.owner)[0..1], error.InvalidBlockPlan);
        try rejectedBytes(Z, &encoder, std.mem.asBytes(encoder.owner.control)[0..1], error.InvalidBlockPlan);
        try rejectedBytes(Z, &encoder, std.mem.sliceAsBytes(queue.jobs)[0..1], error.InvalidBlockPlan);
        try rejectedBytes(Z, &encoder, std.mem.sliceAsBytes(queue.workers)[0..1], error.InvalidBlockPlan);
    }
    try replacementFlow(Z, &encoder);
}

fn sharedObserver(comptime Z: type) !void {
    const total = @import("../../encode/total_budget.zig");
    var profile: Z.EncodeMemoryProfile = .{};
    var lease = try total.Lease.init(h.a, null, &profile, 0);
    defer lease.deinit();
    var encoder = try Z.NativeIncrementalFrameEncoder.init(lease.allocator(), h.options(Z));
    defer encoder.deinit();
    try rejectedBytes(Z, &encoder, std.mem.asBytes(&profile), error.InvalidBlockPlan);
    try replacementFlow(Z, &encoder);
}
