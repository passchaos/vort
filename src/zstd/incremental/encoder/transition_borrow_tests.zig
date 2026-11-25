const std = @import("std");
const h = @import("step_borrow_helpers.zig");

fn parallelOptions(comptime Z: type) Z.NativeIncrementalParallelFrameEncoder.Options {
    return .{ .frame = h.options(Z), .parallel = .{ .io = std.Io.failing, .worker_count = 2, .job_size = 128, .max_inflight_jobs = 2, .max_inflight_bytes = 256, .max_working_memory = 64 * 1024 * 1024 } };
}

fn rejectedTransition(encoder: anytype, options: anytype, dictionary: anytype, old_profile: anytype, exact: bool) !void {
    var regions: [11][]const u8 = @splat(&.{});
    regions[0] = std.mem.asBytes(encoder);
    regions[1] = std.mem.asBytes(old_profile);
    regions[2] = dictionary.content;
    if (dictionary.standard_bytes) |bytes| regions[3] = bytes;
    if (dictionary.prepared) |prepared| regions[4] = std.mem.asBytes(prepared);
    if (comptime @hasField(@TypeOf(options), "frame")) {
        if (options.frame.memory_profile) |profile| regions[5] = std.mem.asBytes(profile);
        regions[6] = std.mem.asBytes(encoder.owner);
        regions[7] = std.mem.asBytes(encoder.owner.control);
        regions[8] = std.mem.asBytes(encoder.owner.queue);
        regions[9] = std.mem.sliceAsBytes(encoder.owner.queue.jobs);
        regions[10] = std.mem.sliceAsBytes(encoder.owner.queue.workers);
    } else {
        if (options.memory_profile) |profile| regions[5] = std.mem.asBytes(profile);
        if (encoder.allocation.lease) |lease| if (lease.state) |state| {
            regions[6] = std.mem.asBytes(state);
        };
    }
    var saved: [regions.len][]u8 = @splat(&.{});
    defer for (saved) |bytes| h.a.free(bytes);
    for (regions, &saved) |region, *bytes| bytes.* = try h.a.dupe(u8, region);
    if (exact)
        try std.testing.expectError(error.InvalidBlockPlan, encoder.nextFrameExactSizeWithPresetDictionary(options, 0, dictionary))
    else
        try std.testing.expectError(error.InvalidBlockPlan, encoder.nextFrameWithPresetDictionary(options, dictionary));
    for (regions, saved) |region, bytes| try std.testing.expectEqualSlices(u8, bytes, region);
}

pub fn serial(comptime Z: type) !void {
    var encoder = try Z.NativeIncrementalFrameEncoder.init(h.a, h.options(Z));
    defer encoder.deinit();
    try h.roundTrip(Z, &encoder, "old frame", null);
    var profile: Z.EncodeMemoryProfile = .{ .limit = 17 };
    const before = try h.a.dupe(u8, std.mem.asBytes(&profile));
    defer h.a.free(before);
    const receiver = try h.a.dupe(u8, std.mem.asBytes(&encoder));
    defer h.a.free(receiver);
    var options = h.options(Z);
    options.dictionary_usage = .prefix;
    options.memory_profile = &profile;
    const result = encoder.nextFrameWithPresetDictionary(options, Z.NativeDictionary.initRawContent(std.mem.asBytes(&profile)));
    std.debug.print("serial transition profile changed={}\n", .{!std.mem.eql(u8, before, std.mem.asBytes(&profile))});
    try std.testing.expectError(error.InvalidBlockPlan, result);
    try std.testing.expectEqualSlices(u8, before, std.mem.asBytes(&profile));
    try std.testing.expectEqualSlices(u8, receiver, std.mem.asBytes(&encoder));
    var exact_options = options;
    exact_options.include_content_size = true;
    try rejectedTransition(&encoder, exact_options, Z.NativeDictionary.initRawContent(std.mem.asBytes(&profile)), &profile, true);
    try encoder.nextFrame(options);
    try h.roundTrip(Z, &encoder, "disjoint retry", null);

    // Once its old observer is detached, those bytes can become the next prefix.
    const released_profile = try h.a.dupe(u8, std.mem.asBytes(&profile));
    defer h.a.free(released_profile);
    var reused = options;
    reused.memory_profile = null;
    try encoder.nextFrameWithPresetDictionary(reused, Z.NativeDictionary.initRawContent(std.mem.asBytes(&profile)));
    try std.testing.expectEqualSlices(u8, released_profile, std.mem.asBytes(&profile));
    try h.roundTrip(Z, &encoder, "old observer as prefix", null);
    try std.testing.expectEqualSlices(u8, released_profile, std.mem.asBytes(&profile));
    // The ended prefix may in turn become a new observer; it is no longer read.
    try encoder.nextFrame(options);
    try h.roundTrip(Z, &encoder, "ended prefix as observer", null);
}

pub fn parallel(comptime Z: type) !void {
    var profile: Z.EncodeMemoryProfile = .{};
    var options = parallelOptions(Z);
    options.frame.memory_profile = &profile;
    var encoder = try Z.NativeIncrementalParallelFrameEncoder.init(h.a, options);
    defer encoder.deinit();
    try h.roundTrip(Z, &encoder, "old frame", null);
    const before = try h.a.dupe(u8, std.mem.asBytes(&profile));
    defer h.a.free(before);
    const bytes = std.mem.asBytes(&profile.limit);
    var next = options;
    next.frame.memory_profile = null;
    next.frame.dictionary_usage = .prefix;
    next.parallel.max_working_memory = 65 * 1024 * 1024;
    var collision: Z.EncodeMemoryProfile = .{ .limit = 23 };
    var rejected = next;
    rejected.frame.memory_profile = &collision;
    try rejectedTransition(&encoder, rejected, Z.NativeDictionary.initRawContent(std.mem.asBytes(&collision)), &profile, false);
    rejected.frame.include_content_size = true;
    try rejectedTransition(&encoder, rejected, Z.NativeDictionary.initRawContent(std.mem.asBytes(&collision)), &profile, true);
    try encoder.nextFrameWithPresetDictionary(next, Z.NativeDictionary.initRawContent(bytes));
    std.debug.print("parallel transition old profile changed={} limit={any}\n", .{ !std.mem.eql(u8, before, std.mem.asBytes(&profile)), profile.limit });
    try std.testing.expectEqualSlices(u8, before, std.mem.asBytes(&profile));
    try h.roundTrip(Z, &encoder, "new frame", null);
    try std.testing.expectEqualSlices(u8, before, std.mem.asBytes(&profile));
    // Completed prefix reads end before the new observer is attached.
    try encoder.nextFrame(options);
    try h.roundTrip(Z, &encoder, "ended prefix as observer", null);
}
