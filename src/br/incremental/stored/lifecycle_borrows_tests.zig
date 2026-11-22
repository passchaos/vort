const std = @import("std");
const br = @import("../../../br.zig");
const tracking = @import("../../../tests/br_total_memory_helpers.zig");
const a = std.testing.allocator;

fn reject(encoder: anytype, ledger: *tracking.TrackingAllocator, profile: *br.EncodeMemoryProfile, metadata: []const u8, options: ?@TypeOf(encoder.*).Options) !void {
    const before = try a.dupe(u8, std.mem.asBytes(encoder));
    defer a.free(before);
    const source = try a.dupe(u8, metadata);
    defer a.free(source);
    const allocator_before = try a.dupe(u8, std.mem.asBytes(ledger));
    defer a.free(allocator_before);
    const observer = profile.*;
    const memory = encoder.memorySnapshot();
    if (options) |next| {
        try std.testing.expectError(error.InvalidBlockPlan, encoder.nextStream(next));
    } else try std.testing.expectError(error.InvalidBlockPlan, encoder.writeMetadata(metadata));
    try std.testing.expectEqualSlices(u8, before, std.mem.asBytes(encoder));
    try std.testing.expectEqualSlices(u8, source, metadata);
    try std.testing.expectEqualSlices(u8, allocator_before, std.mem.asBytes(ledger));
    try std.testing.expectEqualDeep(observer, profile.*);
    try std.testing.expectEqualDeep(memory, encoder.memorySnapshot());
}

fn finish(encoder: anytype, plain: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(a);
    var output: [3]u8 = undefined;
    var offset: usize = 0;
    while (offset < plain.len) {
        const step = try encoder.step(plain[offset..], &output);
        offset += step.progress.input_read;
        try encoded.appendSlice(a, output[0..step.progress.output_written]);
        try std.testing.expect(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try encoder.finish();
    for (0..256) |_| {
        const step = try encoder.step("", &output);
        try encoded.appendSlice(a, output[0..step.progress.output_written]);
        if (step.status == .done) return encoded.toOwnedSlice(a);
        try std.testing.expect(step.status == .need_output and step.progress.output_written != 0);
    }
    return error.TestUnexpectedResult;
}

fn checkMetadata(comptime Encoder: type) !void {
    var ledger = tracking.TrackingAllocator.init(a);
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = Encoder.initWithOptions(ledger.allocator(), .{
        .stream = .{ .memory_profile = &profile, .max_total_working_memory = 64 * 1024 * 1024 },
        .block_len = 8,
    });
    defer encoder.deinit();
    try reject(&encoder, &ledger, &profile, std.mem.asBytes(&encoder.flush_requested), null);
    try reject(&encoder, &ledger, &profile, std.mem.asBytes(&encoder.metadata_requested), null);
    var output: [32]u8 = undefined;
    const step = try encoder.step("abc", &output);
    try std.testing.expectEqual(@as(usize, 3), step.progress.input_read);
    try reject(&encoder, &ledger, &profile, encoder.plain.items, null);
    const allocator = encoder.memory_binding.current(encoder.allocator);
    try encoder.plain.ensureTotalCapacity(allocator, 128);
    try encoder.pending.ensureTotalCapacity(allocator, 128);
    try reject(&encoder, &ledger, &profile, encoder.plain.allocatedSlice()[127..128], null);
    try reject(&encoder, &ledger, &profile, encoder.pending.allocatedSlice()[127..128], null);
    try reject(&encoder, &ledger, &profile, std.mem.asBytes(&profile), null);
    if (encoder.memory_binding.lease) |lease| {
        if (lease.state) |state| try reject(&encoder, &ledger, &profile, std.mem.asBytes(state), null);
    }
    // A disjoint retry succeeds without reset and preserves accepted plaintext.
    try encoder.writeMetadata("M");
    const wire = try finish(&encoder, "");
    defer a.free(wire);
    const summary = try br.summarizeStream(wire);
    try std.testing.expectEqual(@as(br.Counter, 1), summary.metadata_bytes);
    const decoded = try br.decodeStreamAllocExactSize(a, wire, 3);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, "abc", decoded);
    try std.testing.expect(!encoder.snapshot().metadata_pending);
}

fn checkNextStream(comptime Encoder: type) !void {
    var ledger = tracking.TrackingAllocator.init(a);
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = Encoder.initWithOptions(ledger.allocator(), .{
        .stream = .{ .memory_profile = &profile, .max_total_working_memory = 64 * 1024 * 1024 },
        .block_len = 8,
    });
    defer encoder.deinit();
    const previous = try finish(&encoder, "abc");
    defer a.free(previous);
    var options = encoder.options;
    options.stream.metadata = std.mem.asBytes(&encoder.done);
    try reject(&encoder, &ledger, &profile, options.stream.metadata, options);
    options.stream.metadata = encoder.plain.allocatedSlice()[encoder.plain.capacity - 1 ..];
    try reject(&encoder, &ledger, &profile, options.stream.metadata, options);
    options.stream.metadata = encoder.pending.allocatedSlice()[encoder.pending.capacity - 1 ..];
    try reject(&encoder, &ledger, &profile, options.stream.metadata, options);
    options.stream.metadata = std.mem.asBytes(&profile);
    try reject(&encoder, &ledger, &profile, options.stream.metadata, options);
    if (encoder.memory_binding.lease) |lease| {
        if (lease.state) |state| {
            state.last_failure_was_limit = true;
            options.stream.metadata = std.mem.asBytes(state);
            try reject(&encoder, &ledger, &profile, options.stream.metadata, options);
        }
    }
    options.stream.metadata = "M";
    try encoder.nextStream(options);
    const next = try finish(&encoder, "xyz");
    defer a.free(next);
    const decoded = try br.decodeStreamAllocExactSize(a, next, 3);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, "xyz", decoded);
    const summary = try br.summarizeStream(next);
    try std.testing.expectEqual(@as(br.Counter, 1), summary.metadata_bytes);
}

test "Brotli lifecycle borrows stored rejects metadata before publishing" {
    try checkMetadata(br.IncrementalStoredStreamEncoder);
}
test "Brotli lifecycle borrows planned rejects metadata before publishing" {
    try checkMetadata(br.IncrementalPlannedStreamEncoder);
}
test "Brotli lifecycle borrows static dictionary rejects metadata before publishing" {
    try checkMetadata(br.IncrementalStaticDictionaryStreamEncoder);
}
test "Brotli lifecycle borrows stored rejects next stream before reset" {
    try checkNextStream(br.IncrementalStoredStreamEncoder);
}
test "Brotli lifecycle borrows planned rejects next stream before reset" {
    try checkNextStream(br.IncrementalPlannedStreamEncoder);
}
test "Brotli lifecycle borrows static dictionary rejects next stream before reset" {
    try checkNextStream(br.IncrementalStaticDictionaryStreamEncoder);
}

fn checkOwnedList(encoder: anytype, ledger: *tracking.TrackingAllocator, profile: *br.EncodeMemoryProfile, list: anytype) !void {
    try list.ensureTotalCapacity(encoder.memory_binding.current(encoder.allocator), 16);
    const bytes = std.mem.sliceAsBytes(list.allocatedSlice());
    try reject(encoder, ledger, profile, bytes[bytes.len - 1 ..], null);
    const previous = try finish(encoder, "abc");
    defer a.free(previous);
    var options = encoder.options;
    const retained = std.mem.sliceAsBytes(list.allocatedSlice());
    options.stream.metadata = retained[retained.len - 1 ..];
    try reject(encoder, ledger, profile, options.stream.metadata, options);
    options.stream.metadata = "M";
    try encoder.nextStream(options);
}

test "Brotli lifecycle borrows protect planned and static spare command storage" {
    var ledger = tracking.TrackingAllocator.init(a);
    var profile: br.EncodeMemoryProfile = .{};
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(ledger.allocator(), .{
        .stream = .{ .memory_profile = &profile, .max_total_working_memory = 64 * 1024 * 1024 },
        .block_len = 8,
    });
    defer encoder.deinit();
    try checkOwnedList(&encoder, &ledger, &profile, &encoder.codec_state.tokens);
    encoder.reset();
    try checkOwnedList(&encoder, &ledger, &profile, &encoder.codec_state.commands);
    var static_encoder = br.IncrementalStaticDictionaryStreamEncoder.initWithOptions(ledger.allocator(), .{ .block_len = 8 });
    defer static_encoder.deinit();
    try checkOwnedList(&static_encoder, &ledger, &profile, &static_encoder.codec_state.commands);
}

test "Brotli lifecycle borrows allow immutable source metadata and completed stream storage reuse" {
    for ([_][]const u8{ "M", "" }) |metadata| {
        inline for (.{ br.IncrementalStoredStreamEncoder, br.IncrementalPlannedStreamEncoder, br.IncrementalStaticDictionaryStreamEncoder }) |Encoder| {
            var bytes: [32]u8 = @splat('d');
            const prefixes = [_][]const u8{bytes[0..16]};
            var options: Encoder.Options = .{ .block_len = 8 };
            if (@hasField(@TypeOf(options.stream), "shared_dictionary"))
                options.stream.shared_dictionary = .{ .raw_prefixes = &prefixes };
            var encoder = Encoder.initWithOptions(a, options);
            defer encoder.deinit();
            var output: [32]u8 = undefined;
            const step = try encoder.step(bytes[0..6], &output);
            try std.testing.expectEqual(@as(usize, 0), step.progress.output_written);
            // External metadata may overlap an immutable configured dictionary.
            try encoder.writeMetadata(if (metadata.len != 0) bytes[0..16] else std.mem.asBytes(&encoder.done)[0..0]);
            const wire = try finish(&encoder, "");
            defer a.free(wire);
            const decoded = try br.decodeStreamAllocExactSizeWithOptions(a, wire, 6, .{
                .shared_dictionary = if (@hasField(@TypeOf(options.stream), "shared_dictionary")) options.stream.shared_dictionary else .{},
            });
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, bytes[0..6], decoded);
            options.stream.metadata = if (metadata.len != 0) bytes[0..16] else "M";
            if (@hasField(@TypeOf(options.stream), "shared_dictionary")) options.stream.shared_dictionary = .{};
            try encoder.nextStream(options);
            // Old RAW bytes can become new metadata or caller output, according
            // to the new borrow. The old cached dictionary does not survive.
            const destination = if (metadata.len != 0) bytes[16..] else bytes[0..16];
            const prefix = try encoder.step("", destination);
            var next: std.ArrayList(u8) = .empty;
            defer next.deinit(a);
            try next.appendSlice(a, destination[0..prefix.progress.output_written]);
            const tail = try finish(&encoder, "xyz");
            defer a.free(tail);
            try next.appendSlice(a, tail);
            const content = try br.decodeStreamAllocExactSize(a, next.items, 3);
            defer a.free(content);
            try std.testing.expectEqualSlices(u8, "xyz", content);
        }
    }
}

test "Brotli lifecycle borrows reject new observer overlap and preserve old observer before handoff" {
    inline for (.{ br.IncrementalStoredStreamEncoder, br.IncrementalPlannedStreamEncoder }) |Encoder| {
        var ledger = tracking.TrackingAllocator.init(a);
        var old: br.EncodeMemoryProfile = .{};
        var replacement: br.EncodeMemoryProfile = .{};
        var encoder = Encoder.initWithOptions(ledger.allocator(), .{
            .stream = .{ .memory_profile = &old, .max_total_working_memory = 64 * 1024 * 1024 },
            .block_len = 8,
        });
        defer encoder.deinit();
        const previous = try finish(&encoder, "abc");
        defer a.free(previous);
        var options = encoder.options;
        options.stream.memory_profile = &replacement;
        options.stream.max_total_working_memory = 128 * 1024 * 1024;
        options.stream.metadata = std.mem.asBytes(&old);
        try reject(&encoder, &ledger, &old, options.stream.metadata, options);
        try std.testing.expectEqualDeep(br.EncodeMemoryProfile{}, replacement);
        options.stream.metadata = std.mem.asBytes(&replacement);
        try reject(&encoder, &ledger, &old, options.stream.metadata, options);
        try std.testing.expectEqualDeep(br.EncodeMemoryProfile{}, replacement);
        options.stream.metadata = "M";
        options.stream.memory_profile = @ptrCast(&encoder);
        try reject(&encoder, &ledger, &old, options.stream.metadata, options);
        options.stream.memory_profile = &replacement;
        options.stream.metadata = "M";
        try encoder.nextStream(options);
        const next = try finish(&encoder, "xyz");
        defer a.free(next);
    }
}

test "Brotli lifecycle borrows protect tracked allocator observers across all facades" {
    const total = @import("../../encoder/total_budget.zig");
    inline for (.{ br.IncrementalStoredStreamEncoder, br.IncrementalPlannedStreamEncoder, br.IncrementalStaticDictionaryStreamEncoder }) |Encoder| {
        var ledger = tracking.TrackingAllocator.init(a);
        var profile: br.EncodeMemoryProfile = .{};
        var parent = try total.Lease.init(ledger.allocator(), 64 * 1024 * 1024, &profile, 0);
        defer parent.deinit();
        var encoder = Encoder.initWithOptions(parent.allocator(), .{ .block_len = 8 });
        defer encoder.deinit();
        try reject(&encoder, &ledger, &profile, std.mem.asBytes(&profile), null);
        const previous = try finish(&encoder, "abc");
        defer a.free(previous);
        var options = encoder.options;
        options.stream.metadata = std.mem.asBytes(&profile);
        try reject(&encoder, &ledger, &profile, options.stream.metadata, options);
    }
}

test "Brotli lifecycle borrows allow explicitly detached old memory profile storage" {
    inline for (.{ br.IncrementalStoredStreamEncoder, br.IncrementalPlannedStreamEncoder, br.IncrementalStaticDictionaryStreamEncoder }) |Encoder| {
        var profile: br.EncodeMemoryProfile = .{};
        var encoder = Encoder.initWithOptions(a, .{
            .stream = .{ .memory_profile = &profile, .max_total_working_memory = 64 * 1024 * 1024 },
            .block_len = 8,
        });
        defer encoder.deinit();
        const previous = try finish(&encoder, "abc");
        defer a.free(previous);
        if (encoder.memory_binding.lease) |lease| try lease.setProfile(null);
        var options = encoder.options;
        options.stream.memory_profile = null;
        options.stream.metadata = std.mem.asBytes(&profile);
        const before = try a.dupe(u8, options.stream.metadata);
        defer a.free(before);
        try encoder.nextStream(options);
        try std.testing.expectEqualSlices(u8, before, options.stream.metadata);
        const next = try finish(&encoder, "xyz");
        defer a.free(next);
        try std.testing.expectEqualSlices(u8, before, options.stream.metadata);
    }
}

test "Brotli lifecycle borrows validate prospective dictionary and HQ profile readers" {
    var ledger = tracking.TrackingAllocator.init(a);
    var profile: br.EncodeMemoryProfile = .{};
    var hq_profile: br.HqProfile = .{};
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(ledger.allocator(), .{
        .stream = .{ .memory_profile = &profile, .max_total_working_memory = 64 * 1024 * 1024, .quality = 10, .hq = .{ .profile = &hq_profile, .block_len = 16 } },
        .block_len = 16,
    });
    defer encoder.deinit();
    try reject(&encoder, &ledger, &profile, std.mem.asBytes(&hq_profile), null);
    const previous = try finish(&encoder, "time time");
    defer a.free(previous);
    var options = encoder.options;
    options.stream.metadata = std.mem.asBytes(&hq_profile);
    try reject(&encoder, &ledger, &profile, options.stream.metadata, options);
    options.stream.quality = 0;
    options.stream.hq = null;
    options.stream.metadata = "";
    const raw = [_][]const u8{encoder.plain.allocatedSlice()[encoder.plain.capacity - 1 ..]};
    options.stream.shared_dictionary = .{ .raw_prefixes = &raw };
    try reject(&encoder, &ledger, &profile, "", options);
    options.stream.shared_dictionary = .{};
    // HQ cleanup reports frees to the total-memory profile, not HqProfile.
    // Its completed observer can safely become a new metadata reader.
    options.stream.metadata = std.mem.asBytes(&hq_profile);
    const old_hq = try a.dupe(u8, options.stream.metadata);
    defer a.free(old_hq);
    try encoder.nextStream(options);
    try std.testing.expectEqualSlices(u8, old_hq, options.stream.metadata);
    const next = try finish(&encoder, "xyz");
    defer a.free(next);
    try std.testing.expectEqualSlices(u8, old_hq, options.stream.metadata);
}
