const std = @import("std");
const br = @import("../../../br.zig");
const allocator = std.testing.allocator;

fn reject(encoder: anytype, input: []const u8, output: []u8) !void {
    const before = try allocator.dupe(u8, std.mem.asBytes(encoder));
    defer allocator.free(before);
    const source = try allocator.dupe(u8, input);
    defer allocator.free(source);
    const destination = try allocator.dupe(u8, output);
    defer allocator.free(destination);
    const memory = encoder.memorySnapshot();
    try std.testing.expectError(error.InvalidBlockPlan, encoder.step(input, output));
    try std.testing.expectEqualSlices(u8, before, std.mem.asBytes(encoder));
    try std.testing.expectEqualSlices(u8, source, input);
    try std.testing.expectEqualSlices(u8, destination, output);
    try std.testing.expectEqualDeep(memory, encoder.memorySnapshot());
}

fn wire(encoder: anytype, input: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    var output: [17]u8 = undefined;
    var offset: usize = 0;
    while (offset < input.len) {
        const step = try encoder.step(input[offset..], &output);
        offset += step.progress.input_read;
        try result.appendSlice(allocator, output[0..step.progress.output_written]);
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try encoder.finish();
    while (!encoder.done) {
        const step = try encoder.step("", &output);
        try result.appendSlice(allocator, output[0..step.progress.output_written]);
        try std.testing.expect(step.status == .done or step.progress.output_written != 0);
    }
    return result.toOwnedSlice(allocator);
}

fn retryFresh(encoder: anytype, input: []const u8) !void {
    var control = @TypeOf(encoder.*).initWithOptions(allocator, encoder.options);
    defer control.deinit();
    const expected = try wire(&control, input);
    defer allocator.free(expected);
    const actual = try wire(encoder, input);
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

fn freshOverlap(comptime Encoder: type) !void {
    inline for (.{ false, true }) |large_window| {
        var encoder = Encoder.initWithOptions(std.testing.allocator, .{
            .stream = .{ .metadata = if (large_window) "" else "M", .large_window = large_window },
        });
        defer encoder.deinit();
        var bytes = [_]u8{ 's', 'o', 'u', 'r', 'c', 'e', 0, 0 };
        const before = bytes;
        const state = encoder.snapshot();
        try std.testing.expectError(error.InvalidBlockPlan, encoder.step(bytes[0..6], &bytes));
        try std.testing.expectEqualSlices(u8, &before, &bytes);
        try std.testing.expectEqualDeep(state, encoder.snapshot());
        try std.testing.expect(!encoder.prefix_written);
        try std.testing.expectEqual(@as(usize, 0), encoder.retainedCapacity());
        try retryFresh(&encoder, before[0..6]);
    }
}

test "Brotli encoder step borrows stored rejects fresh prefix overlap" {
    try freshOverlap(br.IncrementalStoredStreamEncoder);
}

test "Brotli encoder step borrows planned rejects fresh prefix overlap" {
    try freshOverlap(br.IncrementalPlannedStreamEncoder);
}

test "Brotli encoder step borrows static dictionary rejects fresh prefix overlap" {
    try freshOverlap(br.IncrementalStaticDictionaryStreamEncoder);
}

fn basicOwned(comptime Encoder: type) !void {
    var encoder = Encoder.initWithOptions(allocator, .{ .stream = .{ .metadata = "M" }, .block_len = 8 });
    defer encoder.deinit();
    try encoder.plain.ensureTotalCapacity(allocator, 128);
    try encoder.pending.ensureTotalCapacity(allocator, 128);
    @memset(encoder.plain.allocatedSlice(), 0x51);
    @memset(encoder.pending.allocatedSlice(), 0x52);
    var output: [32]u8 = @splat(0xcc);
    var io: [16]u8 = @splat('x');
    try reject(&encoder, io[0..8], io[7..8]);
    try reject(&encoder, io[0..1], &io);
    try reject(&encoder, std.mem.asBytes(&encoder)[0..1], &output);
    try reject(&encoder, "", std.mem.asBytes(&encoder)[0..1]);
    // Both lists are empty. The collision lies entirely in retained spare.
    try reject(&encoder, encoder.plain.allocatedSlice()[100..101], &output);
    try reject(&encoder, "input", encoder.plain.allocatedSlice()[100..101]);
    try reject(&encoder, encoder.pending.allocatedSlice()[100..101], &output);
    try reject(&encoder, "", encoder.pending.allocatedSlice()[100..101]);
    try retryFresh(&encoder, "ABCDEF");
    // The completed call does not write output or advance state.
    const done = try encoder.step("", std.mem.asBytes(&encoder));
    try std.testing.expect(done.status == .done);
}

fn reuseOwned(comptime Encoder: type) !void {
    var encoder = Encoder.initWithOptions(allocator, .{ .stream = .{ .metadata = "M" }, .block_len = 8 });
    defer encoder.deinit();
    const first = try wire(&encoder, "ABCDEF");
    defer allocator.free(first);
    try encoder.nextStream(encoder.options);
    var output: [32]u8 = @splat(0x77);
    try reject(&encoder, encoder.plain.allocatedSlice()[encoder.plain.capacity - 1 ..], &output);
    try reject(&encoder, "", encoder.pending.allocatedSlice()[encoder.pending.capacity - 1 ..]);
    try retryFresh(&encoder, "ABCDEF");
    encoder.reset();
    try reject(&encoder, "", encoder.plain.allocatedSlice()[encoder.plain.capacity - 1 ..]);
    try retryFresh(&encoder, "ABCDEF");
    const empty = std.mem.asBytes(&encoder)[0..0];
    const done = try encoder.step(empty, std.mem.asBytes(&encoder));
    try std.testing.expect(done.status == .done);
    try std.testing.expectEqual(@as(usize, 0), done.progress.output_written);
    try std.testing.expectError(error.TrailingData, encoder.step("x", &output));
}

test "Brotli encoder step borrows all facades protect receiver and full owned capacities" {
    inline for (.{ br.IncrementalStoredStreamEncoder, br.IncrementalPlannedStreamEncoder, br.IncrementalStaticDictionaryStreamEncoder }) |Encoder| {
        try basicOwned(Encoder);
        try reuseOwned(Encoder);
    }
}

fn pendingDrain(comptime Encoder: type) !void {
    var encoder = Encoder.initWithOptions(allocator, .{ .stream = .{ .metadata = "M" }, .block_len = 8 });
    defer encoder.deinit();
    const primed = try encoder.step("", &.{});
    try std.testing.expect(primed.status == .need_output);
    var output: [32]u8 = @splat(0x63);
    try reject(&encoder, encoder.pending.items[0..1], &output);
    try reject(&encoder, "ABCDEF", encoder.pending.allocatedSlice()[0..1]);
    var overlapping: [16]u8 = @splat('a');
    try reject(&encoder, overlapping[0..8], overlapping[7..8]);
    try retryFresh(&encoder, "ABCDEF");
}

test "Brotli encoder step borrows pending drain rejects before progress and retries" {
    inline for (.{ br.IncrementalStoredStreamEncoder, br.IncrementalPlannedStreamEncoder, br.IncrementalStaticDictionaryStreamEncoder }) |Encoder|
        try pendingDrain(Encoder);
}

fn metadata(comptime Encoder: type) !void {
    var bytes: [16]u8 = @splat('m');
    var encoder = Encoder.initWithOptions(allocator, .{ .stream = .{ .metadata = bytes[0..8] }, .block_len = 8 });
    defer encoder.deinit();
    try reject(&encoder, "", bytes[7..8]);
    // Two immutable readers are allowed to share the same bytes.
    try retryFresh(&encoder, bytes[0..8]);
    encoder.reset();
    encoder.options.stream.metadata = "M";
    try encoder.writeMetadata(bytes[0..8]);
    try reject(&encoder, "", bytes[0..1]);
    var output: [128]u8 = undefined;
    while (encoder.metadata_requested or encoder.flush_requested) _ = try encoder.step("", &output);
    // writeMetadata's borrowed slice expires when metadata is acknowledged.
    _ = try encoder.step("", bytes[0..1]);
    encoder.reset();
    try encoder.plain.ensureTotalCapacity(allocator, 64);
    encoder.options.stream.metadata = encoder.plain.allocatedSlice()[32..40];
    try reject(&encoder, "", &.{});
    encoder.options.stream.metadata = std.mem.asBytes(&encoder)[0..1];
    try reject(&encoder, "", &output);
    encoder.options.stream.metadata = "M";
    try std.testing.expectError(error.InvalidBlockPlan, encoder.writeMetadata(encoder.plain.allocatedSlice()[32..40]));
    encoder.reset();
    try retryFresh(&encoder, "ABCDEF");
}

test "Brotli encoder step borrows metadata readers remain disjoint from every writer" {
    inline for (.{ br.IncrementalStoredStreamEncoder, br.IncrementalPlannedStreamEncoder, br.IncrementalStaticDictionaryStreamEncoder }) |Encoder|
        try metadata(Encoder);
}

test "Brotli encoder step borrows accept adjacent ranges and empty borrowed slices" {
    inline for (.{ br.IncrementalStoredStreamEncoder, br.IncrementalPlannedStreamEncoder, br.IncrementalStaticDictionaryStreamEncoder }) |Encoder| {
        var bytes: [256]u8 = @splat('a');
        var encoder = Encoder.initWithOptions(allocator, .{ .stream = .{ .metadata = "M" }, .block_len = 8 });
        defer encoder.deinit();
        const step = try encoder.step(bytes[0..8], bytes[8..]);
        try std.testing.expectEqual(@as(usize, 8), step.progress.input_read);
        encoder.reset();
        encoder.options.stream.metadata = std.mem.asBytes(&encoder)[0..0];
        _ = try encoder.step(std.mem.asBytes(&encoder)[0..0], std.mem.asBytes(&encoder)[0..0]);
        encoder.reset();
        encoder.options.stream.metadata = "M";
        try retryFresh(&encoder, "ABCDEF");
    }
}

fn retainedList(encoder: anytype, list: anytype) !void {
    try list.ensureTotalCapacity(allocator, 16);
    const bytes = std.mem.sliceAsBytes(list.allocatedSlice());
    @memset(bytes, 0x55);
    var output: [32]u8 = @splat(0xaa);
    try reject(encoder, bytes[bytes.len - 1 ..], &output);
    try reject(encoder, "", bytes[bytes.len - 1 ..]);
    encoder.options.stream.metadata = bytes[bytes.len - 1 ..];
    try reject(encoder, "", &.{});
    encoder.options.stream.metadata = "M";
}

test "Brotli encoder step borrows protect planned and static retained scratch after reset" {
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .stream = .{ .metadata = "M", .quality = 0 }, .block_len = 8 });
    defer encoder.deinit();
    inline for (.{ "tokens", "commands", "history", "candidate_wire", "best_wire", "adaptive_single_wire", "adaptive_split_wire", "adaptive_grid_wire", "adaptive_grid_candidate_wire", "history_snapshot", "adaptive_split_history", "adaptive_grid_history" }) |field|
        try retainedList(&encoder, &@field(encoder.codec_state, field));
    try retainedList(&encoder, &encoder.codec_state.greedy_scratch.prev);
    try retainedList(&encoder, &encoder.codec_state.dictionary_greedy_scratch.head);
    try retainedList(&encoder, &encoder.codec_state.dictionary_greedy_scratch.prev);
    try retainedList(&encoder, &encoder.codec_state.fragment_scratch.table);
    encoder.reset();
    var output: [32]u8 = undefined;
    try reject(&encoder, "", std.mem.sliceAsBytes(encoder.codec_state.tokens.allocatedSlice())[0..1]);
    try retryFresh(&encoder, "ABCDEF");
    var static_encoder = br.IncrementalStaticDictionaryStreamEncoder.initWithOptions(allocator, .{ .stream = .{ .metadata = "M" }, .block_len = 8 });
    defer static_encoder.deinit();
    try retainedList(&static_encoder, &static_encoder.codec_state.commands);
    static_encoder.reset();
    try reject(&static_encoder, std.mem.sliceAsBytes(static_encoder.codec_state.commands.allocatedSlice())[0..1], &output);
    try retryFresh(&static_encoder, "ABCDEF");
}

test "Brotli encoder step borrows protect raw dictionary descriptors and cached bytes" {
    var dictionary: [32]u8 = @splat('d');
    var prefixes = [_][]const u8{dictionary[0..16]};
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .stream = .{ .metadata = "M", .quality = 0, .shared_dictionary = .{ .raw_prefixes = &prefixes } }, .block_len = 8 });
    defer encoder.deinit();
    try reject(&encoder, "", dictionary[15..16]);
    try reject(&encoder, "", std.mem.sliceAsBytes(&prefixes)[0..1]);
    try encoder.plain.ensureTotalCapacity(allocator, 128);
    prefixes[0] = encoder.plain.allocatedSlice()[100..108];
    try reject(&encoder, "", &.{});
    prefixes[0] = dictionary[0..16];
    // Input and dictionary may share immutable bytes.
    var output: [128]u8 = undefined;
    _ = try encoder.step(dictionary[0..8], &output);
    encoder.options.stream.shared_dictionary = .{};
    try reject(&encoder, "", dictionary[0..1]);
    // State and the compound matcher's copied descriptors retain the borrow.
    encoder.codec_state.shared_dictionary = .{};
    try reject(&encoder, "", dictionary[0..1]);
    encoder.reset();
    _ = try encoder.step("ABCDEF", dictionary[0..1]);
}

fn rejectDictionaryCount(encoder: anytype, ledger: anytype, profile: anytype) !void {
    const allocator_before = try allocator.dupe(u8, std.mem.asBytes(ledger));
    defer allocator.free(allocator_before);
    const profile_before = profile.*;
    var output: [32]u8 = @splat(0x88);
    try reject(encoder, "", &output);
    try std.testing.expectEqualSlices(u8, allocator_before, std.mem.asBytes(ledger));
    try std.testing.expectEqualDeep(profile_before, profile.*);
}

test "Brotli encoder step borrows bound RAW descriptor counts before visiting storage" {
    const tracking = @import("../../../tests/br_total_memory_helpers.zig");
    const shared = @import("../../shared_dictionary.zig");
    const serialized = @import("../../serialized_dictionary.zig");
    const prefixes: [shared.max_raw_prefixes + 1][]const u8 = @splat("");
    const sentinel: [*]const []const u8 = @ptrFromInt(@alignOf([]const u8));
    const huge_count = std.math.maxInt(usize) / @sizeOf([]const u8) + 1;
    const encoded = [_]u8{ 0x91, 0, 3, 'r', 'a', 'w', 0, 0 };
    const view = try serialized.parse(&encoded);
    const invalid = [_]br.SharedDictionary{
        .{ .raw_prefixes = &prefixes },
        .{ .raw_prefixes = sentinel[0..huge_count] },
        .{ .raw_prefixes = prefixes[0..shared.max_raw_prefixes], .serialized = &view },
    };
    var ledger = tracking.TrackingAllocator.init(allocator);
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(ledger.allocator(), .{
        .stream = .{ .metadata = "M", .quality = 0, .memory_profile = &profile, .max_total_working_memory = 64 * 1024 * 1024 },
        .block_len = 8,
    });
    defer encoder.deinit();
    // Configured dictionaries retain the existing public InvalidBlockPlan
    // mapping. Neither the oversized outer table nor its storage is visited.
    for (invalid) |dictionary| {
        encoder.options.stream.shared_dictionary = dictionary;
        try rejectDictionaryCount(&encoder, &ledger, &profile);
    }
    encoder.options.stream.shared_dictionary = .{};
    var output: [32]u8 = undefined;
    _ = try encoder.step("", &output);
    try std.testing.expect(encoder.prefix_written);
    const active = encoder.codec_state.shared_dictionary;
    // Active retained dictionaries do not go through options validation. The
    // admission boundary must impose the same count bound before any walk.
    for (invalid) |dictionary| {
        encoder.codec_state.shared_dictionary = dictionary;
        try rejectDictionaryCount(&encoder, &ledger, &profile);
    }
    encoder.codec_state.shared_dictionary = active;
    encoder.reset();
    encoder.options.stream.shared_dictionary = .{ .raw_prefixes = prefixes[0..shared.max_raw_prefixes] };
    try retryFresh(&encoder, "ABCDEF");
    encoder.reset();
    // An explicit empty prefix still consumes a slot; serialized RAW uses the
    // final slot, so fourteen explicit prefixes plus serialized RAW are valid.
    encoder.options.stream.shared_dictionary = .{ .raw_prefixes = prefixes[0 .. shared.max_raw_prefixes - 1], .serialized = &view };
    try retryFresh(&encoder, "rawraw");
}

test "Brotli encoder step borrows protect memory profiles before activation and retained lease control" {
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(allocator, .{ .stream = .{ .metadata = "M", .memory_profile = &profile, .max_total_working_memory = 4096 }, .block_len = 8 });
    defer encoder.deinit();
    const before = profile;
    try reject(&encoder, "", std.mem.asBytes(&profile)[0..1]);
    try std.testing.expectEqualDeep(before, profile);
    var output: [32]u8 = @splat(0x77);
    try reject(&encoder, std.mem.asBytes(&profile)[0..1], &output);
    encoder.options.stream.metadata = std.mem.asBytes(&profile)[0..1];
    try reject(&encoder, "", &output);
    try std.testing.expectEqualDeep(before, profile);
    encoder.options.stream.metadata = "M";
    _ = try encoder.step("", &.{});
    const lease = encoder.memory_binding.lease.?.state.?;
    const active = profile;
    try reject(&encoder, std.mem.asBytes(lease)[0..1], &output);
    try reject(&encoder, "", std.mem.asBytes(lease)[0..1]);
    try std.testing.expectEqualDeep(active, profile);
    encoder.options.stream.memory_profile = null;
    try reject(&encoder, "", std.mem.asBytes(&profile)[0..1]);
    encoder.reset();
    try retryFresh(&encoder, "ABCDEF");
}

test "Brotli encoder step borrows protect serialized dictionary view and backing" {
    const serialized = @import("../../serialized_dictionary.zig");
    var encoded = [_]u8{ 0x91, 0, 3, 'r', 'a', 'w', 0, 0 };
    var view = try serialized.parse(&encoded);
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .stream = .{ .metadata = "M", .quality = 0, .shared_dictionary = .{ .serialized = &view } }, .block_len = 8 });
    defer encoder.deinit();
    try reject(&encoder, "", encoded[0..1]);
    try reject(&encoder, "", std.mem.asBytes(&view)[0..1]);
    try encoder.plain.ensureTotalCapacity(allocator, 128);
    @memcpy(encoder.plain.allocatedSlice()[100..108], &encoded);
    view = try serialized.parse(encoder.plain.allocatedSlice()[100..108]);
    try reject(&encoder, "", &.{});
    view = try serialized.parse(&encoded);
    try retryFresh(&encoder, "rawrawraw");
}

fn retainedSlice(encoder: anytype, slice: anytype) !void {
    const bytes = std.mem.sliceAsBytes(slice);
    @memset(bytes, 0x66);
    var output: [16]u8 = @splat(0xcc);
    try reject(encoder, bytes[bytes.len - 1 ..], &output);
    try reject(encoder, "", bytes[bytes.len - 1 ..]);
    encoder.options.stream.metadata = bytes[bytes.len - 1 ..];
    try reject(encoder, "", &.{});
    encoder.options.stream.metadata = "M";
}

test "Brotli encoder step borrows protect nested matcher and HQ allocations" {
    const compound = @import("../../encoder/compound_dictionary_matcher.zig");
    const serialized = @import("../../encoder/serialized_dictionary_matcher.zig");
    const hq = @import("../../encoder/hq_codec.zig");
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .stream = .{ .metadata = "M", .quality = 0 }, .block_len = 8 });
    defer encoder.deinit();
    encoder.codec_state.compound_matcher = compound.Matcher.init(allocator);
    encoder.codec_state.serialized_matcher = serialized.Matcher.init(allocator);
    const cm = &encoder.codec_state.compound_matcher.?;
    cm.buckets = try allocator.alloc(@typeInfo(@TypeOf(cm.buckets)).pointer.child, 4);
    try retainedSlice(&encoder, cm.buckets);
    const sm = &encoder.codec_state.serialized_matcher.?;
    sm.heads = try allocator.alloc(u32, 4);
    sm.entries = try allocator.alloc(@typeInfo(@TypeOf(sm.entries)).pointer.child, 4);
    try retainedSlice(&encoder, sm.heads);
    try retainedSlice(&encoder, sm.entries);
    try encoder.codec_state.hq_state.ensureBudget(allocator, 64 * 1024 * 1024);
    const resources = &encoder.codec_state.hq_state;
    const a = resources.budget.?.allocator();
    var output: [16]u8 = @splat(0xcc);
    try reject(&encoder, std.mem.asBytes(resources.budget.?)[0..1], &output);
    try reject(&encoder, "", std.mem.asBytes(resources.budget.?)[0..1]);
    resources.model = try a.create(hq.Model);
    @memset(std.mem.asBytes(resources.model.?), 0);
    try retainedSlice(&encoder, std.mem.asBytes(resources.model.?));
    resources.matcher = .{};
    const matcher = &resources.matcher.?;
    inline for (.{ "heads2", "heads3", "heads4", "nodes", "candidates" }) |field| {
        const Item = @typeInfo(@TypeOf(@field(matcher.*, field))).pointer.child;
        @field(matcher.*, field) = try a.alloc(Item, 4);
        try retainedSlice(&encoder, @field(matcher.*, field));
    }
    resources.provider = .{
        .budget = resources.budget.?,
        .dictionary = .{},
        .profile = null,
        .compound = compound.Matcher.init(a),
        .serialized = serialized.Matcher.init(a),
    };
    const provider = &resources.provider.?;
    provider.builtin = .{ .allocator = a, .heads = try a.alloc(u32, 4), .words = try a.alloc(u32, 4) };
    try retainedSlice(&encoder, provider.builtin.?.heads);
    try retainedSlice(&encoder, provider.builtin.?.words);
    provider.compound.buckets = try a.alloc(@typeInfo(@TypeOf(provider.compound.buckets)).pointer.child, 4);
    try retainedSlice(&encoder, provider.compound.buckets);
    provider.serialized.heads = try a.alloc(u32, 4);
    provider.serialized.entries = try a.alloc(@typeInfo(@TypeOf(provider.serialized.entries)).pointer.child, 4);
    try retainedSlice(&encoder, provider.serialized.heads);
    try retainedSlice(&encoder, provider.serialized.entries);
    // Release the deliberately uninitialized test indices before valid retry.
    resources.deinit();
    encoder.reset();
    try retryFresh(&encoder, "ABCDEF");
}

test "Brotli encoder step borrows protect HQ profile and owned alias snapshots" {
    const hq = @import("../../encoder/hq_codec.zig");
    var profile: br.HqProfile = .{};
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .stream = .{ .metadata = "M", .quality = 10, .hq = .{ .profile = &profile, .block_len = 32 } } });
    defer encoder.deinit();
    const before = profile;
    try reject(&encoder, "", std.mem.asBytes(&profile)[0..1]);
    var output: [128]u8 = @splat(0xaa);
    try reject(&encoder, std.mem.asBytes(&profile)[0..1], &output);
    try std.testing.expectEqualDeep(before, profile);
    _ = try encoder.step("", &output);
    try encoder.codec_state.hq_state.ensureBudget(allocator, 64 * 1024 * 1024);
    const a = encoder.codec_state.hq_state.budget.?.allocator();
    var target: [64]u8 = @splat('x');
    const raw = [_][]const u8{target[0..8]};
    const chunks = [_][]const u8{target[8..16]};
    encoder.codec_state.hq_state.alias_snapshot = try hq.alias.Snapshot.initChunks(a, &target, &chunks, .{ .raw_prefixes = &raw });
    const snapshot = &encoder.codec_state.hq_state.alias_snapshot.?;
    try reject(&encoder, "", std.mem.sliceAsBytes(snapshot.chunk_storage.descriptors.?)[0..1]);
    try reject(&encoder, "", snapshot.chunk_storage.data.?[0..1]);
    try reject(&encoder, "", std.mem.sliceAsBytes(snapshot.raw_storage.descriptors.?)[0..1]);
    try reject(&encoder, "", snapshot.raw_storage.data.?[0..1]);
    // A copied dictionary is an internal immutable reader of snapshot storage.
    encoder.codec_state.shared_dictionary = snapshot.getDictionary();
    _ = try encoder.step("", &output);
    encoder.codec_state.shared_dictionary = .{};
    encoder.codec_state.hq_state.deinit();
    encoder.reset();
    try retryFresh(&encoder, "ABCDEF");
}

fn appendInput(encoder: anytype, input: []const u8, encoded: *std.ArrayList(u8)) !void {
    var output: [19]u8 = undefined;
    var offset: usize = 0;
    while (offset < input.len) {
        const end = @min(input.len, offset + 13);
        const step = try encoder.step(input[offset..end], &output);
        offset += step.progress.input_read;
        try encoded.appendSlice(allocator, output[0..step.progress.output_written]);
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
}

test "Brotli encoder step borrows preserve multiblock quality dictionary metadata continuation" {
    const first = "quality dictionary metadata first part\n" ** 4;
    const second = "quality dictionary metadata continued\n" ** 4;
    const prefixes = [_][]const u8{"quality dictionary metadata "};
    const serialized = @import("../../serialized_dictionary.zig");
    const raw_encoded = [_]u8{ 0x91, 0, 3, 'r', 'a', 'w', 0, 0 };
    const view = try serialized.parse(&raw_encoded);
    inline for (.{ false, true }) |use_hq| {
        for ([_]u4{ 0, 10, 11 }) |quality| {
            if (use_hq and quality == 0) continue;
            var profile: br.HqProfile = .{};
            var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{
                .stream = .{
                    .quality = quality,
                    .metadata = "prefix",
                    .shared_dictionary = .{ .raw_prefixes = &prefixes, .serialized = &view },
                    .hq = if (use_hq) .{ .profile = &profile, .block_len = 64 } else null,
                },
                .block_len = 64,
            });
            defer encoder.deinit();
            var encoded: std.ArrayList(u8) = .empty;
            defer encoded.deinit(allocator);
            try appendInput(&encoder, first, &encoded);
            try encoder.writeMetadata("between");
            var output: [19]u8 = undefined;
            while (encoder.flush_requested) {
                const step = try encoder.step("", &output);
                try encoded.appendSlice(allocator, output[0..step.progress.output_written]);
            }
            try appendInput(&encoder, second, &encoded);
            const tail = try wire(&encoder, "");
            defer allocator.free(tail);
            try encoded.appendSlice(allocator, tail);
            const decoded = try br.decodeStreamAllocWithOptions(allocator, encoded.items, .{
                .shared_dictionary = .{ .raw_prefixes = &prefixes, .serialized = &view },
            });
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, first ++ second, decoded);
            if (use_hq) try std.testing.expect(profile.emitted_metablocks >= 4);
        }
    }
}
