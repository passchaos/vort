const std = @import("std");
const decoder = @import("../decoder.zig");
const fixtures = @import("test_helpers.zig");
const allocator = fixtures.allocator;
const Workspace = decoder.DecodeWorkspace;

test "LZMA one shot contracts known no EOS permits coded tails while unknown EOS is strict" {
    const known = fixtures.known();
    const eos = fixtures.smallEos();
    const known_tail = known ++ "coded unused tail".*;
    const eos_tail = eos ++ "coded unused tail".*;
    var workspace = try Workspace.initWithOptions(allocator, .{ .max_working_memory = 64 * 1024 });
    defer workspace.deinit();
    var known_out: [fixtures.known_plain.len + 2]u8 = @splat(0xa5);
    try std.testing.expectEqual(fixtures.known_plain.len, try workspace.decodeInto(&known_tail, known_out[1 .. known_out.len - 1]));
    try std.testing.expectEqualSlices(u8, fixtures.known_plain, known_out[1 .. known_out.len - 1]);
    try std.testing.expectEqual(@as(u8, 0xa5), known_out[0]);
    try std.testing.expectEqual(@as(u8, 0xa5), known_out[known_out.len - 1]);
    try std.testing.expectEqual(fixtures.known_plain.len, try workspace.decodedSize(&known_tail));
    const legacy = try decoder.decodeAlloc(allocator, &known_tail);
    defer allocator.free(legacy);
    try std.testing.expectEqualSlices(u8, fixtures.known_plain, legacy);
    var output: [fixtures.small_plain.len]u8 = @splat(0xa5);
    try std.testing.expectEqual(output.len, try workspace.decodeInto(&eos, &output));
    try std.testing.expectEqualSlices(u8, fixtures.small_plain, &output);
    @memset(&output, 0xa5);
    try std.testing.expectError(error.TrailingData, workspace.decodeInto(&eos_tail, &output));
    try fixtures.sentinel(&output);
    try std.testing.expectError(error.TrailingData, decoder.decodeInto(allocator, &eos_tail, &output));
    try fixtures.sentinel(&output);
    try std.testing.expectError(error.TrailingData, decoder.decodeAlloc(allocator, &eos_tail));
}

test "LZMA one shot contracts ordinary Into failures leave every caller byte unchanged" {
    const eos = fixtures.smallEos();
    var bad_properties = eos;
    bad_properties[0] = 255;
    var bad_range = eos;
    bad_range[13] = 255;
    const cases = [_]struct { input: []const u8, failure: anyerror }{
        .{ .input = eos[0..12], .failure = error.TruncatedFrame },
        .{ .input = eos[0..17], .failure = error.TruncatedFrame },
        .{ .input = eos[0 .. eos.len - 1], .failure = error.TruncatedFrame },
        .{ .input = &bad_properties, .failure = error.InvalidLzmaHeader },
        .{ .input = &bad_range, .failure = error.InvalidLzmaStream },
    };
    var workspace = Workspace.init(allocator);
    defer workspace.deinit();
    var output: [fixtures.small_plain.len + 1]u8 = @splat(0xa5);
    for (cases) |case| {
        try std.testing.expectError(case.failure, workspace.decodeInto(case.input, &output));
        try fixtures.sentinel(&output);
        try std.testing.expectError(case.failure, decoder.decodeInto(allocator, case.input, &output));
        try fixtures.sentinel(&output);
    }
    try std.testing.expectError(error.OutputTooSmall, workspace.decodeInto(&eos, output[0 .. fixtures.small_plain.len - 1]));
    try fixtures.sentinel(&output);
    try std.testing.expectError(error.OutputTooSmall, decoder.decodeInto(allocator, &eos, output[0 .. fixtures.small_plain.len - 1]));
    try fixtures.sentinel(&output);
    var known_wrong_size = eos;
    std.mem.writeInt(u64, known_wrong_size[5..13], fixtures.small_plain.len + 1, .little);
    try std.testing.expectError(error.SizeMismatch, workspace.decodeInto(&known_wrong_size, &output));
    try fixtures.sentinel(&output);
    try std.testing.expectError(error.SizeMismatch, decoder.decodeInto(allocator, &known_wrong_size, &output));
    try fixtures.sentinel(&output);
    try std.testing.expectEqual(fixtures.small_plain.len, try workspace.decodeInto(&eos, &output));
    try std.testing.expectEqualSlices(u8, fixtures.small_plain, output[0..fixtures.small_plain.len]);
    try std.testing.expectEqual(@as(u8, 0xa5), output[output.len - 1]);
}

test "LZMA one shot contracts Micro strict and partial retain legacy short output rules" {
    const micro = fixtures.micro();
    var workspace = Workspace.init(allocator);
    defer workspace.deinit();
    const cases = [_]struct { size: usize, failure: ?anyerror }{
        .{ .size = 0, .failure = error.InvalidLzmaStream },
        .{ .size = 1, .failure = error.InvalidLzmaStream },
        .{ .size = 7, .failure = error.InvalidLzmaStream },
        .{ .size = 694, .failure = error.SizeMismatch },
        .{ .size = 695, .failure = null },
        .{ .size = 696, .failure = error.TruncatedFrame },
    };
    var output: [696]u8 = undefined;
    for (cases) |case| {
        @memset(&output, 0xa5);
        if (case.failure) |err| {
            try std.testing.expectError(err, workspace.decodeMicroInto(&micro, output[0..case.size], 32 * 1024));
            try fixtures.sentinel(&output);
            try std.testing.expectError(err, decoder.decodeMicroInto(allocator, &micro, output[0..case.size], 32 * 1024));
            try fixtures.sentinel(&output);
        } else {
            try workspace.decodeMicroInto(&micro, output[0..case.size], 32 * 1024);
            try std.testing.expectEqualSlices(u8, fixtures.micro_plain, output[0..case.size]);
            try fixtures.sentinel(output[case.size..]);
        }
        @memset(&output, 0xa5);
        if (case.size <= fixtures.micro_plain.len) {
            try workspace.decodeMicroIntoWithOptions(&micro, output[0..case.size], .{ .dictionary_size = 32 * 1024, .allow_partial = true });
            try std.testing.expectEqualSlices(u8, fixtures.micro_plain[0..case.size], output[0..case.size]);
            try fixtures.sentinel(output[case.size..]);
        } else {
            try std.testing.expectError(error.TruncatedFrame, workspace.decodeMicroIntoWithOptions(&micro, output[0..case.size], .{ .dictionary_size = 32 * 1024, .allow_partial = true }));
            try fixtures.sentinel(&output);
        }
    }
}

test "LZMA one shot contracts Micro malformed strict input and quotas are caller atomic" {
    const micro = fixtures.micro();
    var bad_properties = micro;
    bad_properties[0] = ~@as(u8, 0x6f);
    const trailing = micro ++ "tail".*;
    const cases = [_]struct { input: []const u8, dictionary: u32 = 32 * 1024, failure: anyerror }{
        .{ .input = micro[0..4], .failure = error.TruncatedFrame },
        .{ .input = micro[0 .. micro.len - 1], .failure = error.TruncatedFrame },
        .{ .input = &bad_properties, .failure = error.InvalidLzmaHeader },
        .{ .input = &trailing, .failure = error.TrailingData },
        .{ .input = &micro, .dictionary = 1024, .failure = error.OutputLimitExceeded },
    };
    var workspace = Workspace.init(allocator);
    defer workspace.deinit();
    var output: [fixtures.micro_plain.len]u8 = @splat(0xa5);
    for (cases) |case| {
        try std.testing.expectError(case.failure, workspace.decodeMicroInto(case.input, &output, case.dictionary));
        try fixtures.sentinel(&output);
        try std.testing.expectError(case.failure, decoder.decodeMicroInto(allocator, case.input, &output, case.dictionary));
        try fixtures.sentinel(&output);
    }
    try std.testing.expectError(error.OutputLimitExceeded, workspace.decodeMicroIntoWithOptions(&micro, &output, .{ .dictionary_size = 32 * 1024, .max_output_len = output.len - 1 }));
    try fixtures.sentinel(&output);
}

test "LZMA one shot contracts ZIP EOS caller size is a ceiling and nonmarker size is exact" {
    const eos = fixtures.smallEos();
    const payload = try fixtures.zipFromAlone(&eos);
    defer allocator.free(payload);
    var workspace = Workspace.init(allocator);
    defer workspace.deinit();
    var output: [fixtures.small_plain.len + 2]u8 = @splat(0xa5);
    const ceiling = fixtures.small_plain.len + 1;
    const legacy = try decoder.decodeZipPayloadAllocLimited(allocator, payload, ceiling, 4096, true);
    defer allocator.free(legacy);
    try std.testing.expectEqualSlices(u8, fixtures.small_plain, legacy);
    try std.testing.expectEqual(fixtures.small_plain.len, try workspace.decodeZipPayloadInto(payload, ceiling, &output, 4096, true));
    try std.testing.expectEqualSlices(u8, fixtures.small_plain, output[0..fixtures.small_plain.len]);
    try fixtures.sentinel(output[fixtures.small_plain.len..]);
    @memset(&output, 0xa5);
    try std.testing.expectError(error.OutputLimitExceeded, workspace.decodeZipPayloadInto(payload, fixtures.small_plain.len - 1, &output, 4096, true));
    try fixtures.sentinel(&output);
    try std.testing.expectError(error.OutputLimitExceeded, decoder.decodeZipPayloadInto(allocator, payload, fixtures.small_plain.len - 1, &output, 4096, true));
    try fixtures.sentinel(&output);
    try std.testing.expectError(error.SizeMismatch, workspace.decodeZipPayloadInto(payload, ceiling, &output, 4096, false));
    try fixtures.sentinel(&output);
    try std.testing.expectError(error.SizeMismatch, decoder.decodeZipPayloadAllocLimited(allocator, payload, ceiling, 4096, false));
    const with_tail = try allocator.alloc(u8, payload.len + 4);
    defer allocator.free(with_tail);
    @memcpy(with_tail[0..payload.len], payload);
    @memcpy(with_tail[payload.len..], "tail");
    try std.testing.expectError(error.TrailingData, workspace.decodeZipPayloadInto(with_tail, ceiling, &output, 4096, true));
    try fixtures.sentinel(&output);
    try std.testing.expectEqual(fixtures.small_plain.len, try workspace.decodeZipPayloadInto(with_tail, fixtures.small_plain.len, &output, 4096, false));
    try std.testing.expectEqualSlices(u8, fixtures.small_plain, output[0..fixtures.small_plain.len]);
}

test "LZMA one shot contracts ZIP proper no EOS payload and malformed headers preserve legacy Into" {
    const known = fixtures.known();
    const payload = try fixtures.zipFromAlone(&known);
    defer allocator.free(payload);
    var workspace = Workspace.init(allocator);
    defer workspace.deinit();
    var output: [fixtures.known_plain.len]u8 = @splat(0xa5);
    // ZIP encoder version bytes were ignored by the legacy raw payload API.
    payload[0] = 255;
    payload[1] = 255;
    try std.testing.expectEqual(output.len, try workspace.decodeZipPayloadInto(payload, output.len, &output, 4096, false));
    try std.testing.expectEqualSlices(u8, fixtures.known_plain, &output);
    @memset(&output, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, workspace.decodeZipPayloadInto(payload, output.len, output[0 .. output.len - 1], 4096, false));
    try fixtures.sentinel(&output);
    try std.testing.expectError(error.OutputLimitExceeded, workspace.decodeZipPayloadInto(payload, output.len, &output, 1024, false));
    try fixtures.sentinel(&output);
    try std.testing.expectError(error.TruncatedFrame, workspace.decodeZipPayloadInto(payload[0..8], output.len, &output, 4096, false));
    try fixtures.sentinel(&output);
    try std.testing.expectError(error.TruncatedFrame, decoder.decodeZipPayloadInto(allocator, payload[0..9], output.len, &output, 4096, false));
    try fixtures.sentinel(&output);
    payload[2] = 6;
    try std.testing.expectError(error.InvalidLzmaHeader, workspace.decodeZipPayloadInto(payload, output.len, &output, 4096, false));
    try fixtures.sentinel(&output);
    try std.testing.expectError(error.InvalidLzmaHeader, decoder.decodeZipPayloadInto(allocator, payload, output.len, &output, 4096, false));
    try fixtures.sentinel(&output);
}

test "LZMA one shot contracts aliasing known coded tail copies only the consumed prefix" {
    const known = fixtures.known();
    const storage = try allocator.alloc(u8, known.len + 32 * 1024);
    defer allocator.free(storage);
    @memset(storage, 0xa5);
    @memcpy(storage[0..known.len], &known);
    var workspace = try Workspace.initWithOptions(allocator, .{ .max_dictionary_size = 4096, .max_working_memory = 40 * 1024 });
    defer workspace.deinit();
    try std.testing.expectEqual(fixtures.known_plain.len, try workspace.decodeInto(storage, storage[0..fixtures.known_plain.len]));
    try std.testing.expectEqualSlices(u8, fixtures.known_plain, storage[0..fixtures.known_plain.len]);
    try fixtures.sentinel(storage[fixtures.known_plain.len..]);
    const snap = workspace.snapshot();
    try std.testing.expect(snap.input_copy_capacity <= known.len + 16);
    try std.testing.expect(snap.last_input_read <= known.len);
    try std.testing.expectEqual(fixtures.known_plain.len, snap.last_decoded_len);
}
