const std = @import("std");
const lzma = @import("../lzma.zig");
const h = @import("large_dictionary_contract_helpers.zig");
const allocator = std.testing.allocator;

test "LZMA large dictionary old default and all twenty preset wire stay fixed" {
    const input = h.legacyPlain();
    const expected_default = h.hexBytes(h.default_hex);
    const actual = try lzma.encodeAlloc(allocator, &input, .{});
    defer allocator.free(actual);
    try std.testing.expectEqualSlices(u8, &expected_default, actual);
    const micro = try lzma.encodeMicroAlloc(allocator, &input, .{});
    defer allocator.free(micro);
    const micro_expected = h.hexBytes(h.micro_default_hex);
    try std.testing.expectEqualSlices(u8, &micro_expected, micro);
    const zip = try lzma.encodeZipPayloadAlloc(allocator, &input, .{});
    defer allocator.free(zip);
    const zip_expected = h.hexBytes(h.zip_default_hex);
    try std.testing.expectEqualSlices(u8, &zip_expected, zip);
    const chd = try lzma.encodeChdPayloadAlloc(allocator, &input, 4096);
    defer allocator.free(chd);
    const chd_expected = h.hexBytes(h.chd_default_hex);
    try std.testing.expectEqualSlices(u8, &chd_expected, chd);
    for (h.preset_wires) |sample| {
        const expected = try h.decodeWire(allocator, sample.hex);
        defer allocator.free(expected);
        var options = try lzma.EncodeOptions.fromPreset(sample.level, sample.extreme);
        options.size_mode = .known;
        const encoded = try lzma.encodeAlloc(allocator, h.preset_plain, options);
        defer allocator.free(encoded);
        try std.testing.expectEqualSlices(u8, expected, encoded);
    }
}

const Format = enum { alone, micro, zip, chd };

fn tinyRoundTrip(backing: std.mem.Allocator, format: Format, sample: h.DictionaryCase) !void {
    const input = h.preset_plain;
    var decoded: [input.len]u8 = undefined;
    switch (format) {
        .alone => {
            const encoded = try lzma.encodeAlloc(backing, input, .{ .dictionary_size = sample.requested, .mode = .literal_only, .size_mode = .known });
            defer backing.free(encoded);
            try std.testing.expectEqual(sample.advertised, try h.aloneDictionary(encoded));
            try std.testing.expectEqual(@as(u64, input.len), std.mem.readInt(u64, encoded[5..13], .little));
            try std.testing.expectEqual(input.len, try lzma.decodeInto(backing, encoded, &decoded));
        },
        .micro => {
            const encoded = try lzma.encodeMicroAlloc(backing, input, .{ .dictionary_size = sample.requested, .mode = .literal_only });
            defer backing.free(encoded);
            try lzma.decodeMicroInto(backing, encoded, &decoded, sample.requested);
        },
        .zip => {
            const encoded = try lzma.encodeZipPayloadAlloc(backing, input, .{ .dictionary_size = sample.requested, .mode = .literal_only });
            defer backing.free(encoded);
            try std.testing.expectEqual(sample.requested, try h.zipDictionary(encoded));
            try std.testing.expectEqual(input.len, try lzma.decodeZipPayloadInto(backing, encoded, input.len, &decoded, h.max_dictionary_size, true));
        },
        .chd => {
            const encoded = try lzma.encodeChdPayloadAlloc(backing, input, sample.requested);
            defer backing.free(encoded);
            const output = try lzma.decodeChdPayloadAllocExactSize(backing, encoded, input.len, sample.requested);
            defer backing.free(output);
            @memcpy(&decoded, output);
        },
    }
    try std.testing.expectEqualSlices(u8, input, &decoded);
}

test "LZMA large dictionary six independent headers round trip all wrappers without full dictionary allocation" {
    try std.testing.expectEqual(@as(usize, h.max_dictionary_size), lzma.max_encode_dictionary_size);
    for (h.dictionary_cases) |sample| {
        for ([_]Format{ .alone, .micro, .zip, .chd }) |format| {
            var ledger = h.HeapLedger.init(allocator, 8 * 1024 * 1024);
            try tinyRoundTrip(ledger.allocator(), format, sample);
            try std.testing.expectEqual(@as(usize, 0), ledger.live);
            try std.testing.expect(ledger.peak > 0 and ledger.peak < 4 * 1024 * 1024);
            try std.testing.expect(ledger.largest_request < 4 * 1024 * 1024);
            try std.testing.expectEqual(@as(usize, 0), ledger.denied_requests);
        }
    }
}

test "LZMA large dictionary tiny modern search respects explicit matcher heap budget" {
    for ([_]u32{ 64 * 1024 * 1024 + 1, h.max_dictionary_size }) |requested| {
        var ledger = h.HeapLedger.init(allocator, 8 * 1024 * 1024);
        var profile: lzma.EncodeWorkProfile = .{};
        const options: lzma.EncodeOptions = .{ .dictionary_size = requested, .size_mode = .known, .mode = .fast, .match_options = .{ .finder = .hc4, .max_working_memory = 2 * 1024 * 1024, .profile = &profile } };
        {
            const encoded = try lzma.encodeAlloc(ledger.allocator(), h.preset_plain, options);
            defer ledger.allocator().free(encoded);
            var decoded: [h.preset_plain.len]u8 = undefined;
            _ = try lzma.decodeInto(ledger.allocator(), encoded, &decoded);
            try std.testing.expectEqualSlices(u8, h.preset_plain, &decoded);
            try std.testing.expect(profile.mf_positions > 0);
            try std.testing.expect(profile.peak_working_memory > 0 and profile.peak_working_memory <= 2 * 1024 * 1024);
        }
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
        try std.testing.expect(ledger.largest_request < 4 * 1024 * 1024);
        var limited = options;
        limited.match_options.?.max_working_memory = 0;
        var output: [128]u8 = @splat(0xa5);
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, lzma.encodeInto(ledger.allocator(), h.preset_plain, &output, limited));
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        try std.testing.expectEqual(@as(usize, 0), ledger.live);
    }
}

test "LZMA large dictionary invalid min max reject before output and allocation across formats" {
    for ([_]u32{ 0, 4095, h.max_dictionary_size + 1, std.math.maxInt(u32) }) |invalid| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
        const backing = failing.allocator();
        var output: [128]u8 = @splat(0xa5);
        try std.testing.expectError(error.InvalidLzmaOptions, lzma.encodeInto(backing, h.preset_plain, &output, .{ .dictionary_size = invalid }));
        try std.testing.expectError(error.InvalidLzmaOptions, lzma.encodeMicroInto(backing, h.preset_plain, &output, .{ .dictionary_size = invalid }));
        try std.testing.expectError(error.InvalidLzmaOptions, lzma.encodeZipPayloadAlloc(backing, h.preset_plain, .{ .dictionary_size = invalid }));
        try std.testing.expectError(error.InvalidLzmaOptions, lzma.encodeChdPayloadAlloc(backing, h.preset_plain, invalid));
        for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        try std.testing.expectEqual(@as(usize, 0), failing.allocated_bytes);
        try std.testing.expect(!failing.has_induced_failure);
    }
}

test "LZMA large dictionary max Into and append support overlapping caller storage" {
    const options: lzma.EncodeOptions = .{ .dictionary_size = h.max_dictionary_size, .mode = .literal_only, .size_mode = .known };
    const expected = try lzma.encodeAlloc(allocator, h.preset_plain, options);
    defer allocator.free(expected);
    var output: [128]u8 = @splat(0xa5);
    @memcpy(output[0..h.preset_plain.len], h.preset_plain);
    const before = output;
    try std.testing.expectError(error.OutputTooSmall, lzma.encodeInto(allocator, output[0..h.preset_plain.len], output[0 .. expected.len - 1], options));
    try std.testing.expectEqualSlices(u8, &before, &output);
    const written = try lzma.encodeInto(allocator, output[0..h.preset_plain.len], &output, options);
    try std.testing.expectEqualSlices(u8, expected, output[0..written]);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, h.preset_plain);
    _ = try lzma.encodeAppend(allocator, &appended, appended.items, options);
    try std.testing.expectEqualSlices(u8, h.preset_plain, appended.items[0..h.preset_plain.len]);
    try std.testing.expectEqualSlices(u8, expected, appended.items[h.preset_plain.len..]);
}

const AliasAllocationGraph = struct {
    pub fn run(backing: std.mem.Allocator, expected: []const u8) !void {
        const options: lzma.EncodeOptions = .{ .dictionary_size = h.max_dictionary_size, .mode = .fast, .size_mode = .known, .match_options = .{ .finder = .hc4, .max_working_memory = 2 * 1024 * 1024 } };
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(backing);
        try output.appendSlice(backing, h.preset_plain);
        _ = lzma.encodeAppend(backing, &output, output.items, options) catch |err| {
            try std.testing.expectEqualSlices(u8, h.preset_plain, output.items);
            return err;
        };
        try std.testing.expectEqualSlices(u8, expected, output.items[h.preset_plain.len..]);
    }
};

test "LZMA large dictionary tiny allocation graph propagates real OOM without alias writes" {
    const expected = try lzma.encodeAlloc(allocator, h.preset_plain, .{ .dictionary_size = h.max_dictionary_size, .mode = .fast, .size_mode = .known, .match_options = .{ .finder = .hc4, .max_working_memory = 2 * 1024 * 1024 } });
    defer allocator.free(expected);
    try std.testing.checkAllAllocationFailures(allocator, AliasAllocationGraph.run, .{expected});
}

test "LZMA large dictionary known tiny and empty streams preserve header through owned reset" {
    const stream_helpers = @import("../xz/large_chunk_contract_helpers.zig");
    var ledger = h.HeapLedger.init(allocator, 8 * 1024 * 1024);
    const options: lzma.IncrementalEncoder.Options = .{ .dictionary_size = h.max_dictionary_size, .mode = .literal_only, .size_mode = .known };
    {
        const expected = try lzma.encodeAlloc(ledger.allocator(), h.preset_plain, .{ .dictionary_size = h.max_dictionary_size, .mode = .literal_only, .size_mode = .known });
        defer ledger.allocator().free(expected);
        var original = try lzma.IncrementalEncoder.initExactSize(ledger.allocator(), options, h.preset_plain.len);
        var transferred = false;
        defer if (!transferred) original.deinit();
        const first = try stream_helpers.drive(lzma.IncrementalEncoder, ledger.allocator(), &original, h.preset_plain, 1, 1);
        defer ledger.allocator().free(first);
        try std.testing.expectEqualSlices(u8, expected, first);
        original.reset();
        var moved = original;
        original = undefined;
        transferred = true;
        defer moved.deinit();
        const second = try stream_helpers.drive(lzma.IncrementalEncoder, ledger.allocator(), &moved, h.preset_plain, 17, 31);
        defer ledger.allocator().free(second);
        try std.testing.expectEqualSlices(u8, expected, second);
    }
    {
        var empty = try lzma.IncrementalEncoder.initExactSize(ledger.allocator(), options, 0);
        defer empty.deinit();
        const encoded = try stream_helpers.drive(lzma.IncrementalEncoder, ledger.allocator(), &empty, "", 1, 1);
        defer ledger.allocator().free(encoded);
        try std.testing.expectEqual(h.max_dictionary_size, try h.aloneDictionary(encoded));
        try std.testing.expectEqual(@as(usize, 0), try lzma.decodeInto(ledger.allocator(), encoded, &.{}));
    }
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expect(ledger.peak < 4 * 1024 * 1024 and ledger.largest_request < 4 * 1024 * 1024);
}

test "LZMA large dictionary bounded aligned Micro uses caller cap without dictionary sized allocation" {
    var ledger = h.HeapLedger.init(allocator, 8 * 1024 * 1024);
    const options: lzma.MicroEncodeOptions = .{ .dictionary_size = h.max_dictionary_size, .mode = .literal_only, .match_options = .{ .max_working_memory = 0 } };
    var output: [128]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutputTooSmall, lzma.encodeMicroDestSizeInto(ledger.allocator(), h.preset_plain, output[0..5], options));
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    const result = try lzma.encodeMicroAlignedDestSizeInto(ledger.allocator(), h.preset_plain, &output, 16, options);
    try std.testing.expectEqual(h.preset_plain.len, result.consumed);
    try std.testing.expect(result.written <= output.len);
    var decoded: [h.preset_plain.len]u8 = undefined;
    try lzma.decodeMicroInto(ledger.allocator(), output[0..result.written], &decoded, h.max_dictionary_size);
    try std.testing.expectEqualSlices(u8, h.preset_plain, &decoded);
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expect(ledger.peak < 4 * 1024 * 1024);
}
