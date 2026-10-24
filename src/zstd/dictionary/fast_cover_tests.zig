const std = @import("std");
const zstd = @import("../../zstd.zig");
const fast = @import("../../dictionary/fast_cover.zig");
const fixtures = @import("../../dictionary/fast_cover_test_helpers.zig");
const working = @import("../../io/working_allocator.zig");
const allocator = fixtures.allocator;

fn complete(bytes: []const u8, id: u32) !void {
    const view = try zstd.inspectStandardDictionary(bytes);
    const summary = try zstd.summarizeStandardDictionary(bytes);
    try std.testing.expectEqual(id, view.id);
    try std.testing.expectEqual(@as(usize, 256), summary.huffman_symbol_count);
    try std.testing.expect(summary.huffman_max_bit_count != 0);
    try std.testing.expect(summary.offset_table_entries != 0 and summary.match_table_entries != 0 and summary.literal_table_entries != 0);
    for (view.repcodes) |distance| try std.testing.expect(distance != 0 and distance <= view.content.len);
}
fn roundTrip(dictionary: zstd.NativeDictionary, payload: []const u8) !void {
    const encoded = try zstd.encodeFrameWithDictionaryAlloc(allocator, payload, dictionary);
    defer allocator.free(encoded);
    const decoded = try zstd.decodeFrameAllocWithDictionary(allocator, encoded, dictionary);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "Zstd FastCover contracts standard output matches actual training subset Huffman FSE and repcode finalization" {
    for ([_]u8{ 1, 2 }) |acceleration| {
        const options: zstd.FastCoverDictionaryTrainOptions = .{ .target_size = 64, .segment_size = 16, .dmer_size = 8, .hash_log = 8, .acceleration = acceleration };
        const content = try fast.trainAlloc(allocator, &fixtures.training, options);
        defer allocator.free(content);
        const count = try fast.standardFinalizeSampleCount(fixtures.training.len, acceleration);
        const expected = try zstd.trainStandardDictionaryFromContentAlloc(allocator, content, fixtures.training[0..count], 0x6031abc1);
        defer expected.deinit(allocator);
        var profile: zstd.FastCoverStandardDictionaryTrainingProfile = .{};
        const actual = try zstd.profileFastCoverStandardDictionaryAlloc(allocator, std.testing.io, &fixtures.training, options, 0x6031abc1, &profile);
        defer actual.deinit(allocator);
        try std.testing.expectEqualSlices(u8, expected.bytes, actual.bytes);
        try std.testing.expectEqual(zstd.DictionaryKind.standard_full, actual.asDictionary().kind());
        try complete(actual.bytes, 0x6031abc1);
        try std.testing.expectEqual(@as(u64, @intCast(count)), profile.finalization_samples);
        var sample_bytes: usize = 0;
        for (fixtures.training[0..count]) |sample| sample_bytes += sample.len;
        try std.testing.expectEqual(@as(u64, @intCast(sample_bytes)), profile.finalization_sample_bytes);
        try std.testing.expect(profile.training.frequency_hashes != 0);
        try roundTrip(actual.asDictionary(), fixtures.validation[0]);
    }
}

test "Zstd FastCover contracts floor zero uses complete prior tables and never restores all training samples" {
    const samples = [_][]const u8{ "abcdefgh01234567", "abcdefgh01234567", "abcdefgh01234567", "abcdefgh01234567", "abcdefgh01234567" };
    const options: zstd.FastCoverDictionaryTrainOptions = .{ .target_size = 8, .segment_size = 8, .dmer_size = 8, .hash_log = 8, .acceleration = 10 };
    var profile: zstd.FastCoverStandardDictionaryTrainingProfile = .{};
    const actual = try zstd.profileFastCoverStandardDictionaryAlloc(allocator, std.testing.io, &samples, options, 0x6715a990, &profile);
    defer actual.deinit(allocator);
    try std.testing.expectEqual(@as(u64, 0), profile.finalization_samples);
    try std.testing.expectEqual(@as(u64, 0), profile.finalization_sample_bytes);
    try complete(actual.bytes, 0x6715a990);
    // A single empty sample passes the old public finalizer validation while
    // supplying exactly the same zero entropy observations as the private
    // zero-sample path; no real training sample is substituted.
    const prior = try zstd.trainStandardDictionaryFromContentAlloc(allocator, actual.view.content, &.{""}, 0x6715a990);
    defer prior.deinit(allocator);
    try std.testing.expectEqualSlices(u8, prior.bytes, actual.bytes);
    try std.testing.expectEqual([3]u32{ 1, 4, 8 }, actual.view.repcodes);
    try roundTrip(actual.asDictionary(), "abcdefgh01234567abcdefgh");
}

test "Zstd FastCover contracts unusable short histories are rejected and optimizer selects a full dictionary" {
    const samples = [_][]const u8{ "aaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaa", "aaaaaaaaaaaaaaaa" };
    const options: zstd.FastCoverDictionaryTrainOptions = .{ .target_size = 256, .segment_size = 64, .dmer_size = 6, .hash_log = 8 };
    try std.testing.expectError(error.InvalidDictionaryTraining, zstd.trainFastCoverStandardDictionaryAlloc(allocator, &samples, options, 1));
    try std.testing.expectError(error.InvalidDictionaryMetadata, zstd.trainFastCoverStandardDictionaryAlloc(allocator, &samples, options, 0));
    const opt: zstd.FastCoverDictionaryOptimizeOptions = .{ .target_size = 256, .segment_sizes = &.{64}, .dmer_sizes = &.{ 6, 8 }, .hash_logs = &.{8}, .shrink_dictionary = true, .shrink_min_size = 1 };
    var result = try zstd.trainOptimizedFastCoverStandardDictionaryAlloc(allocator, &samples, samples[0..1], opt, 0x88110203);
    defer result.deinit(allocator);
    try std.testing.expect(result.view.content.len >= 8);
    try std.testing.expectEqual(@as(u8, 8), result.selected_options.dmer_size);
    try complete(result.bytes, 0x88110203);
    var only_short = opt;
    only_short.dmer_sizes = &.{6};
    try std.testing.expectError(error.InvalidDictionaryTraining, zstd.trainOptimizedFastCoverStandardDictionaryAlloc(allocator, &samples, samples[0..1], only_short, 1));
}

test "Zstd FastCover contracts codec score charges the returned serialized dictionary and actual frames exactly" {
    inline for (.{ false, true }) |repcodes| {
        const options: zstd.FastCoverDictionaryCodecOptimizeOptions = .{
            .fast_cover = .{ .target_size = 64, .segment_sizes = &.{ 16, 32 }, .dmer_sizes = &.{8}, .hash_logs = &.{8}, .accelerations = &.{ 1, 2 }, .threads = 2, .shrink_dictionary = true, .shrink_min_size = 8 },
            .levels = &.{ 1, 9 },
            .candidate_repcodes = repcodes,
        };
        var profile: zstd.FastCoverCodecSearchProfile = .{};
        var result = try zstd.profileCodecOptimizedFastCoverStandardDictionaryAlloc(allocator, std.testing.io, &fixtures.training, &fixtures.validation, options, 0x983204ab, &profile);
        defer result.deinit(allocator);
        try complete(result.bytes, 0x983204ab);
        var exact_bits = result.bytes.len * 8;
        for (options.levels) |level| for (fixtures.validation) |sample| {
            const frame = try zstd.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(allocator, sample, level, .{}, result.asDictionary());
            defer allocator.free(frame);
            exact_bits += frame.len * 8;
        };
        try std.testing.expectEqual(exact_bits, result.validation_score.estimated_bits);
        try std.testing.expectEqual(@as(?usize, result.bytes.len), result.validation_score.dictionary_bytes);
        try std.testing.expect(profile.candidate_finalizations != 0 and profile.candidate_frames != 0);
        try std.testing.expectEqual(@as(u64, 1), profile.winner_finalizations);
        try roundTrip(result.asDictionary(), fixtures.validation[1]);
        var serial_options = options;
        serial_options.fast_cover.threads = 1;
        const serial = try zstd.trainCodecOptimizedFastCoverStandardDictionaryAlloc(allocator, &fixtures.training, &fixtures.validation, serial_options, 0x983204ab);
        defer serial.deinit(allocator);
        try std.testing.expectEqualSlices(u8, serial.bytes, result.bytes);
        try std.testing.expectEqualDeep(serial.validation_score, result.validation_score);
    }
}

const AllocationCase = struct {
    pub fn run(gpa: std.mem.Allocator) !void {
        const value = try zstd.trainFastCoverStandardDictionaryAlloc(gpa, &fixtures.training, .{ .target_size = 64, .segment_size = 16, .dmer_size = 8, .hash_log = 8 }, 0x10671324);
        defer value.deinit(gpa);
        try complete(value.bytes, 0x10671324);
    }
};
test "Zstd FastCover resources finalizer and selected content share exact budget and every OOM path frees storage" {
    const options: zstd.FastCoverDictionaryTrainOptions = .{ .target_size = 64, .segment_size = 16, .dmer_size = 8, .hash_log = 8 };
    var ledger = working.WorkingAllocator.init(allocator, std.math.maxInt(usize));
    var profile: zstd.FastCoverStandardDictionaryTrainingProfile = .{};
    const first = try zstd.profileFastCoverStandardDictionaryAlloc(ledger.allocator(), std.testing.io, &fixtures.training, options, 0x10671324, &profile);
    const expected = try allocator.dupe(u8, first.bytes);
    defer allocator.free(expected);
    try std.testing.expectEqual(first.bytes.len, ledger.live);
    try std.testing.expectEqual(ledger.peak, profile.peak_working_memory);
    const peak = ledger.peak;
    first.deinit(ledger.allocator());
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    inline for (.{ false, true }) |below| {
        var limited = options;
        limited.max_working_memory = peak - @intFromBool(below);
        if (below) try std.testing.expectError(error.WorkingMemoryLimitExceeded, zstd.trainFastCoverStandardDictionaryAlloc(allocator, &fixtures.training, limited, 0x10671324)) else {
            const exact = try zstd.trainFastCoverStandardDictionaryAlloc(allocator, &fixtures.training, limited, 0x10671324);
            defer exact.deinit(allocator);
            try std.testing.expectEqualSlices(u8, expected, exact.bytes);
        }
    }
    try std.testing.checkAllAllocationFailures(allocator, AllocationCase.run, .{});
}

test "Zstd FastCover contracts malformed complete dictionary entropy boundaries are rejected exactly" {
    const value = try zstd.trainFastCoverStandardDictionaryAlloc(allocator, &fixtures.training, .{ .target_size = 64, .segment_size = 16, .hash_log = 8 }, 0x2f01ca77);
    defer value.deinit(allocator);
    const header_len = @intFromPtr(value.view.content.ptr) - @intFromPtr(value.bytes.ptr);
    for ([_]usize{ 0, 3, 7, header_len - 1 }) |cut|
        try std.testing.expectError(error.TruncatedFrame, zstd.inspectStandardDictionary(value.bytes[0..cut]));
    const corrupt = try allocator.dupe(u8, value.bytes);
    defer allocator.free(corrupt);
    corrupt[0] ^= 1;
    try std.testing.expectError(error.InvalidMagic, zstd.inspectStandardDictionary(corrupt));
    @memcpy(corrupt, value.bytes);
    corrupt[8] = 128; // Direct weights with one explicit symbol.
    corrupt[9] = 0xf0; // Weight 15 is invalid, without requiring more input.
    try std.testing.expectError(error.InvalidDictionaryMetadata, zstd.inspectStandardDictionary(corrupt));
}

const codec_validation = [_][]const u8{("service=alpha region=north method=get resource=/items status=ok message=bounded matching\n" ** 160)};
const codec_options: zstd.FastCoverDictionaryCodecOptimizeOptions = .{
    .fast_cover = .{ .target_size = 64, .segment_sizes = &.{16}, .dmer_sizes = &.{8}, .hash_logs = &.{8} },
    .levels = &.{9},
};
const CodecAllocationCase = struct {
    pub fn run(gpa: std.mem.Allocator) !void {
        // The wide path has its separate exact/below budget checks below. OOM
        // enumeration uses short held-out data to cover the same managed
        // scorer/finalizer ownership graph without repeating the expensive
        // level-nine large-block planner at every allocation failure point.
        const value = try zstd.trainCodecOptimizedFastCoverStandardDictionaryAlloc(gpa, &fixtures.training, &fixtures.validation, codec_options, 0x6ba218fc);
        defer value.deinit(gpa);
        try complete(value.bytes, 0x6ba218fc);
    }
};
test "Zstd FastCover resources level nine scoring uses only the shared tracked allocator" {
    var allocation_trace: AllocationTrace = .{ .backing = allocator };
    var ledger = working.WorkingAllocator.init(allocation_trace.allocator(), std.math.maxInt(usize));
    var profile: zstd.FastCoverCodecSearchProfile = .{};
    const result = try zstd.profileCodecOptimizedFastCoverStandardDictionaryAlloc(ledger.allocator(), std.testing.io, &fixtures.training, &codec_validation, codec_options, 0x6ba218fc, &profile);
    const expected = try allocator.dupe(u8, result.bytes);
    defer allocator.free(expected);
    try std.testing.expectEqual(result.bytes.len, ledger.live);
    try std.testing.expectEqual(ledger.peak, profile.peak_allocator_owned_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.thread_stack_reservation_peak);
    const peak = profile.peak_working_memory;
    result.deinit(ledger.allocator());
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    var limited = codec_options;
    limited.fast_cover.max_working_memory = peak;
    const exact = try zstd.trainCodecOptimizedFastCoverStandardDictionaryAlloc(allocator, &fixtures.training, &codec_validation, limited, 0x6ba218fc);
    defer exact.deinit(allocator);
    try std.testing.expectEqualSlices(u8, expected, exact.bytes);
    limited.fast_cover.max_working_memory -= 1;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, zstd.trainCodecOptimizedFastCoverStandardDictionaryAlloc(allocator, &fixtures.training, &codec_validation, limited, 0x6ba218fc));
    try std.testing.checkAllAllocationFailures(allocator, CodecAllocationCase.run, .{});
    // Compare the actual wide/short allocation graphs. Deny the earliest and
    // latest wide-only request (size plus originating return address); if the
    // owners are identical, retain entry/final-transfer denial coverage.
    var short_trace: AllocationTrace = .{ .backing = allocator };
    var short_profile: zstd.FastCoverCodecSearchProfile = .{};
    const short = try zstd.profileCodecOptimizedFastCoverStandardDictionaryAlloc(short_trace.allocator(), std.testing.io, &fixtures.training, &fixtures.validation, codec_options, 0x6ba218fc, &short_profile);
    short.deinit(short_trace.allocator());
    try std.testing.expect(!allocation_trace.overflow and !short_trace.overflow);
    var first_unique: ?usize = null;
    var last_unique: ?usize = null;
    for (allocation_trace.events[0..allocation_trace.count], 0..) |event, index| {
        var found = false;
        for (short_trace.events[0..short_trace.count]) |candidate| {
            if (event.size == candidate.size and event.caller == candidate.caller) {
                found = true;
                break;
            }
        }
        if (!found) {
            if (first_unique == null) first_unique = index;
            last_unique = index;
        }
    }
    const points = [_]usize{ first_unique orelse 0, last_unique orelse allocation_trace.count - 1 };
    for (points, 0..) |point, index| {
        if (index != 0 and point == points[0]) continue;
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = point });
        var failure_profile: zstd.FastCoverCodecSearchProfile = .{};
        try std.testing.expectError(error.OutOfMemory, zstd.profileCodecOptimizedFastCoverStandardDictionaryAlloc(failing.allocator(), std.testing.io, &fixtures.training, &codec_validation, codec_options, 0x6ba218fc, &failure_profile));
        try std.testing.expect(failing.has_induced_failure);
        try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
    }
}

const AllocationTrace = struct {
    const Event = struct { size: usize, caller: usize };
    backing: std.mem.Allocator,
    events: [4096]Event = undefined,
    count: usize = 0,
    overflow: bool = false,

    fn allocator(self: *AllocationTrace) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, size: usize, alignment: std.mem.Alignment, caller: usize) ?[*]u8 {
        const self: *AllocationTrace = @ptrCast(@alignCast(raw));
        if (self.count == self.events.len) self.overflow = true else {
            self.events[self.count] = .{ .size = size, .caller = caller };
            self.count += 1;
        }
        return self.backing.rawAlloc(size, alignment, caller);
    }
    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, size: usize, caller: usize) bool {
        const self: *AllocationTrace = @ptrCast(@alignCast(raw));
        return self.backing.rawResize(bytes, alignment, size, caller);
    }
    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, size: usize, caller: usize) ?[*]u8 {
        const self: *AllocationTrace = @ptrCast(@alignCast(raw));
        return self.backing.rawRemap(bytes, alignment, size, caller);
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, caller: usize) void {
        const self: *AllocationTrace = @ptrCast(@alignCast(raw));
        self.backing.rawFree(bytes, alignment, caller);
    }
};
