const std = @import("std");
const settings = @import("../../lzma/encode_options.zig");
const core_encoder = @import("../../lzma/encoder.zig");
const writer = @import("../writer.zig");
const raw_writer = @import("../lzma2_writer.zig");
const raw_incremental = @import("../lzma2_incremental_encoder.zig");
const incremental = @import("../incremental_encoder.zig");
const container = @import("../container.zig");
const allocator = std.testing.allocator;

fn incrementalAlloc(comptime Encoder: type, alloc: std.mem.Allocator, input: []const u8, options: Encoder.Options, input_chunk: usize, output_chunk: usize) ![]u8 {
    var encoder = try Encoder.initExactSize(alloc, options, input.len);
    defer encoder.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);
    var scratch: [31]u8 = undefined;
    var position: usize = 0;
    while (position < input.len) {
        const end = position + @min(input_chunk, input.len - position);
        const step = try encoder.step(input[position..end], scratch[0..output_chunk]);
        position += step.progress.input_read;
        try output.appendSlice(alloc, scratch[0..step.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const step = try encoder.step(&.{}, scratch[0..output_chunk]);
        try output.appendSlice(alloc, scratch[0..step.progress.output_written]);
        if (step.status == .done) break;
    }
    return output.toOwnedSlice(alloc);
}
fn rawDecode(payload: []const u8, input: []const u8, dictionary_size: usize) !void {
    const decoded = try container.decode7zPayloadAllocLimited(allocator, payload, try raw_writer.dictionaryProperty(dictionary_size), input.len, 64 * 1024 * 1024);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

fn validateChunkProperties(payload: []const u8, properties: settings.Properties) !void {
    var position: usize = 0;
    var properties_seen: usize = 0;
    while (payload[position] != 0) {
        const control = payload[position];
        if (control < 0x80) {
            const len = @as(usize, std.mem.readInt(u16, payload[position + 1 ..][0..2], .big)) + 1;
            position += 3 + len;
        } else {
            const packed_len = @as(usize, std.mem.readInt(u16, payload[position + 3 ..][0..2], .big)) + 1;
            const has_properties = control >= 0xc0;
            if (has_properties) {
                try std.testing.expectEqual(try core_encoder.propertyByte(properties), payload[position + 5]);
                properties_seen += 1;
            }
            position += 5 + @as(usize, @intFromBool(has_properties)) + packed_len;
        }
        try std.testing.expect(position < payload.len);
    }
    try std.testing.expect(properties_seen != 0);
}

test "XZ encode controls preset options copy concrete parser properties dictionary and matching settings" {
    for (0..10) |level| inline for (.{ false, true }) |extreme| {
        const preset = try settings.resolvePreset(@intCast(level), extreme);
        const options = try writer.EncodeOptions.fromPreset(@intCast(level), extreme);
        const stream_options = try incremental.Encoder.Options.fromPreset(@intCast(level), extreme);
        const raw_options = try raw_writer.EncodeOptions.fromPreset(@intCast(level), extreme);
        const raw_stream_options = try raw_incremental.Encoder.Options.fromPreset(@intCast(level), extreme);
        try std.testing.expectEqual(preset.mode, options.parser);
        try std.testing.expectEqual(preset.properties, options.properties);
        try std.testing.expectEqual(@as(usize, preset.dictionary_size), options.dictionary_size);
        try std.testing.expectEqualDeep(preset.match_options, options.match_options.?);
        try std.testing.expectEqualDeep(options, stream_options.writerOptions());
        try std.testing.expectEqualDeep(raw_options, raw_stream_options.chunkOptions());
        try std.testing.expectEqual(writer.Check.crc64, options.check);
        try std.testing.expectEqual(@as(usize, 1024 * 1024), options.block_size);
    };
    try std.testing.expectError(error.InvalidLzmaOptions, writer.EncodeOptions.fromPreset(10, false));
}

test "LZMA2 encode controls advanced modes and all match finders emit actual nondefault properties" {
    const input = "properties and matchers share the actual range-coded history\n" ** 12;
    for ([_]settings.Mode{ .fast, .normal }) |mode| {
        for ([_]settings.MatchFinder{ .hc3, .hc4, .bt2, .bt3, .bt4 }) |finder| {
            const options: raw_writer.EncodeOptions = .{ .dictionary_size = 8192, .parser = mode, .properties = .{ .lc = 2, .lp = 1, .pb = 1 }, .match_options = .{ .finder = finder, .nice_len = 16, .depth = 8 } };
            var encoded: std.ArrayList(u8) = .empty;
            defer encoded.deinit(allocator);
            _ = try raw_writer.appendCompressedPayloadWithAdvancedOptions(allocator, &encoded, input, options);
            try validateChunkProperties(encoded.items, options.properties);
            try rawDecode(encoded.items, input, options.dictionary_size);
            const streamed = try incrementalAlloc(raw_incremental.Encoder, allocator, input, .{ .dictionary_size = options.dictionary_size, .parser = options.parser, .properties = options.properties, .match_options = options.match_options }, 7, 1);
            defer allocator.free(streamed);
            try std.testing.expectEqualSlices(u8, encoded.items, streamed);
        }
    }
}

test "LZMA2 encode controls advanced stored fallback preserves wide committed dictionary and property reset" {
    const input = try allocator.alloc(u8, 72000 + 4096);
    defer allocator.free(input);
    var random: u32 = 0x10395be1;
    for (input[0..72000]) |*byte| {
        random = random *% 1664525 +% 1013904223;
        byte.* = @truncate(random >> 24);
    }
    @memcpy(input[72000..], input[17..][0..4096]);
    const options: raw_writer.EncodeOptions = .{ .dictionary_size = 128 * 1024, .parser = .fast, .properties = .{ .lc = 1, .lp = 2, .pb = 3 }, .match_options = .{ .finder = .hc4, .nice_len = 32, .depth = 16 } };
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    _ = try raw_writer.appendCompressedPayloadWithAdvancedOptions(allocator, &encoded, input, options);
    try std.testing.expectEqual(@as(u8, 1), encoded.items[0]);
    try std.testing.expectEqual(@as(u8, 0xc0), encoded.items[3 + raw_writer.max_uncompressed_chunk]);
    try validateChunkProperties(encoded.items, options.properties);
    try rawDecode(encoded.items, input, options.dictionary_size);
    const streamed = try incrementalAlloc(raw_incremental.Encoder, allocator, input, .{ .dictionary_size = options.dictionary_size, .parser = options.parser, .properties = options.properties, .match_options = options.match_options }, 257, 17);
    defer allocator.free(streamed);
    try std.testing.expectEqualSlices(u8, encoded.items, streamed);
    try std.testing.expect(encoded.items.len < input.len - 2048);
    for ([_]settings.Mode{ .greedy, .lazy }) |mode| {
        var legacy: std.ArrayList(u8) = .empty;
        defer legacy.deinit(allocator);
        _ = try raw_writer.appendCompressedPayloadWithOptions(allocator, &legacy, input, options.dictionary_size, mode);
        const legacy_streamed = try incrementalAlloc(raw_incremental.Encoder, allocator, input, .{ .dictionary_size = options.dictionary_size, .parser = mode }, 257, 17);
        defer allocator.free(legacy_streamed);
        try std.testing.expectEqualSlices(u8, legacy.items, legacy_streamed);
    }
}

test "LZMA2 encode controls compressed stored compressed resets only model and keeps properties history" {
    const chunk_len = raw_writer.max_uncompressed_chunk;
    const input = try allocator.alloc(u8, chunk_len * 3);
    defer allocator.free(input);
    for (input[0..chunk_len], 0..) |*byte, index| byte.* = "reset framing uses committed history"[index % 36];
    var random: u32 = 0x574810a2;
    for (input[chunk_len .. chunk_len * 2]) |*byte| {
        random = random *% 1664525 +% 1013904223;
        byte.* = @truncate(random >> 24);
    }
    @memcpy(input[chunk_len * 2 ..], input[0..chunk_len]);
    const options: raw_writer.EncodeOptions = .{ .dictionary_size = chunk_len * 2, .parser = .fast, .properties = .{ .lc = 1, .lp = 1, .pb = 3 }, .match_options = .{ .finder = .hc4, .nice_len = 32, .depth = 16 } };
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    _ = try raw_writer.appendCompressedPayloadWithAdvancedOptions(allocator, &encoded, input, options);
    try std.testing.expectEqual(@as(u8, 0xe0), encoded.items[0]);
    const first_packed = @as(usize, std.mem.readInt(u16, encoded.items[3..5], .big)) + 1;
    const stored_start = 6 + first_packed;
    try std.testing.expectEqual(@as(u8, 2), encoded.items[stored_start]);
    const third_start = stored_start + 3 + chunk_len;
    try std.testing.expectEqual(@as(u8, 0xa0), encoded.items[third_start]);
    try validateChunkProperties(encoded.items, options.properties);
    try rawDecode(encoded.items, input, options.dictionary_size);
    const streamed = try incrementalAlloc(raw_incremental.Encoder, allocator, input, .{ .dictionary_size = options.dictionary_size, .parser = options.parser, .properties = options.properties, .match_options = options.match_options }, 1024, 31);
    defer allocator.free(streamed);
    try std.testing.expectEqualSlices(u8, encoded.items, streamed);
}

test "XZ encode controls advanced blocks filters and checks match incremental tiny output" {
    const input = "incremental XZ parsers share properties filters and checks\n" ** 23;
    const filter_chain = [_]writer.Filter{try writer.Filter.delta(3)};
    for ([_]settings.Mode{ .literal_only, .fast, .normal }) |mode| {
        const options: writer.EncodeOptions = .{ .check = .sha256, .block_size = 257, .dictionary_size = 8192, .parser = mode, .properties = .{ .lc = 0, .lp = 0, .pb = 4 }, .match_options = .{ .finder = .bt2, .nice_len = 2, .depth = 4 }, .filters = &filter_chain };
        const expected = try writer.encodeAlloc(allocator, input, options);
        defer allocator.free(expected);
        const streamed = try incrementalAlloc(incremental.Encoder, allocator, input, .{ .check = options.check, .block_size = options.block_size, .dictionary_size = options.dictionary_size, .parser = options.parser, .properties = options.properties, .match_options = options.match_options, .filters = options.filters }, 11, 1);
        defer allocator.free(streamed);
        try std.testing.expectEqualSlices(u8, expected, streamed);
        const decoded = try container.decodeAlloc(allocator, streamed);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "LZMA2 encode controls support full literal contexts and maximum dictionary metadata" {
    const input = "context boundary literal coding remains interoperable\n" ** 9;
    for ([_]settings.Properties{ .{ .lc = 4, .lp = 0, .pb = 0 }, .{ .lc = 0, .lp = 4, .pb = 4 } }) |properties| {
        const options: raw_writer.EncodeOptions = .{ .dictionary_size = 64 * 1024 * 1024, .parser = .literal_only, .properties = properties };
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(allocator);
        _ = try raw_writer.appendCompressedPayloadWithAdvancedOptions(allocator, &encoded, input, options);
        try validateChunkProperties(encoded.items, properties);
        try rawDecode(encoded.items, input, options.dictionary_size);
        const streamed = try incrementalAlloc(raw_incremental.Encoder, allocator, input, .{ .dictionary_size = options.dictionary_size, .parser = options.parser, .properties = properties }, 3, 1);
        defer allocator.free(streamed);
        try std.testing.expectEqualSlices(u8, encoded.items, streamed);
    }
}

test "XZ encode controls advanced options validate before writes and explicit lazy retains matcher controls" {
    const bad: writer.EncodeOptions = .{ .parser = .normal, .properties = .{ .lc = 3, .lp = 2 } };
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "prefix");
    try std.testing.expectError(error.InvalidLzmaOptions, writer.encodeAppend(failing.allocator(), &output, "invalid", bad));
    try std.testing.expectEqualStrings("prefix", output.items);
    var options: writer.EncodeOptions = .{ .parser = .fast, .properties = .{ .lc = 0, .lp = 0, .pb = 0 }, .match_options = .{ .finder = .bt3, .nice_len = 16, .depth = 8 } };
    const input = "caller-selected matcher survives explicit lazy API\n" ** 12;
    const lazy = try writer.encodeLazyAlloc(allocator, input, options);
    defer allocator.free(lazy);
    options.parser = .lazy;
    const explicit = try writer.encodeAlloc(allocator, input, options);
    defer allocator.free(explicit);
    try std.testing.expectEqualSlices(u8, explicit, lazy);
    const decoded = try container.decodeAlloc(allocator, lazy);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    var sentinel: [1]u8 = .{0xa5};
    try std.testing.expectError(error.OutputTooSmall, writer.encodeInto(allocator, input, &sentinel, options));
    try std.testing.expectEqual(@as(u8, 0xa5), sentinel[0]);
}

const AllocationCase = struct {
    pub fn run(a: std.mem.Allocator) !void {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(a);
        try output.appendSlice(a, "prefix");
        _ = writer.encodeAppend(a, &output, "preset controlled allocation ownership\n" ** 8, .{ .parser = .fast, .properties = .{ .lc = 2, .lp = 1, .pb = 1 }, .match_options = .{ .finder = .hc3, .nice_len = 16, .depth = 4 } }) catch |err| {
            try std.testing.expectEqualStrings("prefix", output.items);
            return err;
        };
    }
};
test "XZ encode controls advanced allocation failures release all parser matcher and frame ownership" {
    try std.testing.checkAllAllocationFailures(allocator, AllocationCase.run, .{});
}

test "XZ encode controls empty and stored entrypoints refresh only effective profile settings" {
    const before: settings.EncodeWorkProfile = .{ .mf_positions = 7, .parser_windows = 11, .literals = 9, .mf_peak_working_memory = 12345, .peak_working_memory = 67890 };
    var profile = before;
    var expected = before;
    expected.finder = .bt3;
    expected.effective_nice_len = 3;
    expected.effective_depth = 17;
    const match_options: settings.MatchOptions = .{ .finder = .bt3, .nice_len = 2, .profile = &profile };
    const options: writer.EncodeOptions = .{ .parser = .normal, .match_options = match_options };
    try options.validate();
    try std.testing.expectEqualDeep(before, profile);
    const empty = try writer.encodeAlloc(allocator, &.{}, options);
    defer allocator.free(empty);
    try std.testing.expectEqualDeep(expected, profile);
    profile = before;
    const stored = try writer.encodeStoredAlloc(allocator, &.{}, options);
    defer allocator.free(stored);
    try std.testing.expectEqualDeep(expected, profile);
    profile = before;
    var raw: std.ArrayList(u8) = .empty;
    defer raw.deinit(allocator);
    _ = try raw_writer.appendCompressedPayloadWithAdvancedOptions(allocator, &raw, &.{}, .{ .parser = .normal, .match_options = match_options });
    try std.testing.expectEqualSlices(u8, &.{0}, raw.items);
    try std.testing.expectEqualDeep(expected, profile);
    profile = before;
    var encoder = try incremental.Encoder.initWithOptions(allocator, .{ .parser = .normal, .match_options = match_options });
    defer encoder.deinit();
    try std.testing.expectEqualDeep(expected, profile);
    profile = before;
    _ = try encoder.step(&.{}, &.{});
    try std.testing.expectEqualDeep(expected, profile);
    profile = before;
    encoder.reset();
    try std.testing.expectEqualDeep(expected, profile);
    profile = before;
    var raw_encoder = try raw_incremental.Encoder.initExactSize(allocator, .{ .mode = .stored, .parser = .normal, .match_options = match_options }, 0);
    defer raw_encoder.deinit();
    try std.testing.expectEqualDeep(expected, profile);
    profile = before;
    _ = try raw_encoder.step(&.{}, &.{});
    try std.testing.expectEqualDeep(expected, profile);
    profile = before;
    try raw_encoder.reset();
    try std.testing.expectEqualDeep(expected, profile);
}

/// Keep released bytes poisoned until test teardown so a stale borrowed input
/// produces deterministic bad data rather than relying on allocator reuse.
const StoredAliasAllocator = struct {
    const Retired = struct { bytes: []u8, alignment: std.mem.Alignment, return_address: usize };
    backing: std.mem.Allocator,
    fail_index: usize = std.math.maxInt(usize),
    attempts: usize = 0,
    active_bytes: usize = 0,
    retired: [8]Retired = undefined,
    retired_len: usize = 0,

    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(context));
        const index = self.attempts;
        self.attempts += 1;
        if (index == self.fail_index) return null;
        const memory = self.backing.rawAlloc(len, alignment, return_address) orelse return null;
        self.active_bytes += len;
        return memory;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(context: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, return_address: usize) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        std.debug.assert(self.retired_len < self.retired.len);
        @memset(bytes, 0xcc);
        self.retired[self.retired_len] = .{ .bytes = bytes, .alignment = alignment, .return_address = return_address };
        self.retired_len += 1;
        self.active_bytes -= bytes.len;
    }
    fn deinit(self: *@This()) void {
        std.debug.assert(self.active_bytes == 0);
        for (self.retired[0..self.retired_len]) |entry|
            self.backing.rawFree(entry.bytes, entry.alignment, entry.return_address);
    }
};

test "LZMA2 encode controls stored append snapshots aliased input across growth and preserves caller on both allocation failures" {
    const input = try allocator.alloc(u8, raw_writer.max_uncompressed_chunk + 17);
    defer allocator.free(input);
    for (input, 0..) |*byte, index| byte.* = @truncate(index *% 41 +% 19);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    _ = try raw_writer.appendStoredPayload(allocator, &expected, input);

    // Initial output owns exactly the source length, so append must relocate.
    for ([_]usize{ std.math.maxInt(usize), 1, 2 }) |failure| {
        var moving: StoredAliasAllocator = .{ .backing = allocator };
        defer moving.deinit();
        const a = moving.allocator();
        var output: std.ArrayList(u8) = .empty;
        try output.ensureTotalCapacityPrecise(a, input.len);
        output.appendSliceAssumeCapacity(input);
        const original_pointer = output.items.ptr;
        moving.fail_index = failure;
        if (failure == std.math.maxInt(usize)) {
            const size = try raw_writer.appendStoredPayload(a, &output, output.items);
            try std.testing.expect(output.items.ptr != original_pointer);
            try std.testing.expectEqual(expected.items.len, size);
            try std.testing.expectEqualSlices(u8, input, output.items[0..input.len]);
            try std.testing.expectEqualSlices(u8, expected.items, output.items[input.len..]);
            try std.testing.expectEqual(@as(usize, 3), moving.attempts);
        } else {
            // Failure 1 is the input snapshot; failure 2 is destination growth.
            try std.testing.expectError(error.OutOfMemory, raw_writer.appendStoredPayload(a, &output, output.items));
            try std.testing.expectEqual(input.len, output.items.len);
            try std.testing.expectEqual(original_pointer, output.items.ptr);
            try std.testing.expectEqualSlices(u8, input, output.items);
            try std.testing.expectEqual(input.len, moving.active_bytes);
        }
        output.deinit(a);
    }

    // Ordinary external input requires only destination growth, with no copy.
    var moving: StoredAliasAllocator = .{ .backing = allocator };
    defer moving.deinit();
    const a = moving.allocator();
    var output: std.ArrayList(u8) = .empty;
    try output.ensureTotalCapacityPrecise(a, input.len);
    output.appendSliceAssumeCapacity(input);
    _ = try raw_writer.appendStoredPayload(a, &output, input);
    try std.testing.expectEqual(@as(usize, 2), moving.attempts);
    try std.testing.expectEqualSlices(u8, expected.items, output.items[input.len..]);
    output.deinit(a);
}
