const std = @import("std");
const h = @import("step_borrow_helpers.zig");

pub fn contracts(comptime Z: type) !void {
    try freshAndPrefix(Z);
    try privateCapacity(Z);
    try dictionaries(Z);
    try profiles(Z);
    try @import("../../incremental_parallel/tests/step_borrows.zig").contracts(Z);
}

fn freshAndPrefix(comptime Z: type) !void {
    var encoder = try Z.NativeIncrementalFrameEncoder.init(h.a, h.options(Z));
    defer encoder.deinit();
    var storage: [64]u8 = undefined;
    for (&storage, 0..) |*byte, i| byte.* = @truncate(i * 17 + 3);
    try h.rejected(&encoder, storage[0..32], storage[0..32], false);
    try h.rejected(&encoder, storage[0..32], storage[1..33], true);
    try h.rejected(&encoder, storage[1..33], storage[0..32], false);
    try h.rejected(&encoder, std.mem.asBytes(&encoder)[0..1], &.{}, true);
    try h.rejected(&encoder, "", std.mem.asBytes(&encoder)[0..1], false);
    try h.roundTrip(Z, &encoder, storage[0..32], null);
    const done_before = encoder.snapshot();
    try std.testing.expectEqual(.done, (try encoder.step("", std.mem.asBytes(&encoder))).status);
    try std.testing.expectEqualDeep(done_before, encoder.snapshot());

    var prefix_bytes: [32]u8 = @splat(0x45);
    var prefixed = try Z.NativeIncrementalFrameEncoder.initWithPrefix(h.a, h.options(Z), &prefix_bytes);
    defer prefixed.deinit();
    try h.rejected(&prefixed, "input", prefix_bytes[0..1], true);
    try std.testing.expectEqual(.pending, prefixed.prefixSnapshot().phase);
    var output: [32]u8 = undefined;
    _ = try prefixed.step("", &output);
    try std.testing.expectEqual(.active, prefixed.prefixSnapshot().phase);
    try h.rejected(&prefixed, storage[0..32], storage[0..32], true);
    try std.testing.expectEqual(.active, prefixed.prefixSnapshot().phase);
    const final = try prefixed.stepWithDirective("input", &output, .end);
    try std.testing.expectEqual(.done, final.status);
}

fn privateCapacity(comptime Z: type) !void {
    var encoder = try Z.NativeIncrementalFrameEncoder.init(h.a, h.options(Z));
    defer encoder.deinit();
    inline for (.{ "block", "pending" }) |field| {
        try @field(encoder, field).ensureTotalCapacity(h.a, 32);
        try h.ownedList(&encoder, @field(encoder, field));
    }
    try encoder.history.bytes.ensureTotalCapacity(h.a, 32);
    try h.ownedList(&encoder, encoder.history.bytes);
    inline for (.{ "recent_entries", "long_entries" }) |field| {
        try @field(encoder.history.index, field).ensureTotalCapacity(h.a, 4);
        try h.ownedList(&encoder, @field(encoder.history.index, field));
    }
    encoder.reset();
    try h.ownedList(&encoder, encoder.block);
    try h.roundTrip(Z, &encoder, "capacity retry", null);
}

fn dictionaries(comptime Z: type) !void {
    var bytes: [64]u8 = @splat(0x53);
    const raw = Z.NativeDictionary.initRawContent(&bytes);
    var prepared = try Z.PreparedDecodeDictionary.init(raw);
    var encoder = try Z.NativeIncrementalFrameEncoder.initWithPresetDictionary(h.a, h.options(Z), prepared.handle());
    defer encoder.deinit();
    try h.rejected(&encoder, "input", bytes[0..1], false);
    try h.rejected(&encoder, "input", std.mem.asBytes(&prepared.state)[0..1], true);
    // Input and dictionary are both immutable reads and may share bytes.
    try h.roundTrip(Z, &encoder, bytes[0..32], raw);

    const standard = try @import("../../encode/hq_test_helpers.zig").fullDictionary(h.a);
    defer h.a.free(standard);
    const dictionary = (try Z.NativeDictionary.initFromStandardDictionary(standard)).dictionary;
    var options = h.options(Z);
    options.dictionary_id = dictionary.id;
    var full = try Z.NativeIncrementalFrameEncoder.initWithPresetDictionary(h.a, options, dictionary);
    defer full.deinit();
    try h.rejected(&full, "input", standard[0..1], true);
    try h.rejected(&full, "input", @constCast(dictionary.content[0..1]), false);
    try h.roundTrip(Z, &full, dictionary.content[0..32], dictionary);
}

fn profiles(comptime Z: type) !void {
    var memory: Z.EncodeMemoryProfile = .{};
    var control: Z.EncoderControlProfile = .{};
    var options = h.options(Z);
    options.memory_profile = &memory;
    options.control_profile = &control;
    var encoder = try Z.NativeIncrementalFrameEncoder.init(h.a, options);
    defer encoder.deinit();
    inline for (.{ "memory_profile", "control_profile" }) |field| {
        const bytes = std.mem.asBytes(@field(options, field).?);
        try h.rejected(&encoder, bytes[0..1], &.{}, false);
        try h.rejected(&encoder, "input", bytes[0..1], true);
    }
    var next_memory: Z.EncodeMemoryProfile = .{};
    encoder.options.memory_profile = &next_memory;
    try h.rejected(&encoder, std.mem.asBytes(&memory)[0..1], &.{}, true);
    try h.rejected(&encoder, "input", std.mem.asBytes(&next_memory)[0..1], false);
    try h.rejected(&encoder, "", std.mem.asBytes(encoder.allocation.lease.?.state.?)[0..1], false);
    var dictionary_bytes: [32]u8 = @splat(0x91);
    try std.testing.expectError(error.InvalidBlockPlan, encoder.setDictionary(Z.NativeDictionary.initRawContent(std.mem.asBytes(&control))));
    var output: [19]u8 = undefined;
    try encoder.setDictionary(Z.NativeDictionary.initRawContent(&dictionary_bytes));
    const saved_profile = encoder.options.control_profile;
    encoder.options.control_profile = @ptrCast(@alignCast(&encoder.codec_state));
    try h.rejected(&encoder, "input", &output, true);
    encoder.options.control_profile = saved_profile;
    try h.roundTrip(Z, &encoder, "profile retry", null);
}
