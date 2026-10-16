const std = @import("std");
const lzip = @import("../lzip.zig");

const first_payload = "hello lzip\nhello lzip\n";
const second_payload = "second member data";
const first_hex = "4c5a4950010c00341949ee8de9148a6a3e85eb7b90eba1fffffbfde0003a319d3216000000000000003100000000000000";
const second_hex = "4c5a4950010c0039994891b1699607da1f9626254cb362ec39fab33c54ffff69500000ba2ac21512000000000000003700000000000000";

fn fixture(comptime hex: []const u8) [hex.len / 2]u8 {
    var bytes: [hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, hex) catch unreachable;
    return bytes;
}

fn decodeSchedule(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    input_chunk: usize,
    output_chunk: usize,
    options: lzip.IncrementalDecoder.Options,
) ![]u8 {
    var decoder = lzip.IncrementalDecoder.initWithOptions(allocator, options);
    defer decoder.deinit();
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var finish_sent = false;
    var iterations: usize = 0;
    while (true) {
        iterations += 1;
        if (iterations > encoded.len * 64 + 4096) return error.TestUnexpectedResult;
        const input_end = @min(encoded.len, input_offset + input_chunk);
        const stepped = try decoder.step(encoded[input_offset..input_end], output);
        input_offset += stepped.progress.input_read;
        try decoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        var just_finished = false;
        if (!finish_sent and input_offset == encoded.len) {
            decoder.finish();
            finish_sent = true;
            just_finished = true;
        }
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0 and
            !(stepped.status == .need_input and (!finish_sent or just_finished)))
            return error.TestUnexpectedResult;
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    return decoded.toOwnedSlice(allocator);
}

test "lzip incremental decoder validates split reference and concatenated members" {
    const allocator = std.testing.allocator;
    const first = fixture(first_hex);
    const second = fixture(second_hex);
    var concatenated: [first.len + second.len]u8 = undefined;
    @memcpy(concatenated[0..first.len], &first);
    @memcpy(concatenated[first.len..], &second);
    const expected = first_payload ++ second_payload;

    const tiny = try decodeSchedule(allocator, &concatenated, 1, 1, .{});
    defer allocator.free(tiny);
    const micro = try decodeSchedule(allocator, &concatenated, 7, 11, .{});
    defer allocator.free(micro);
    try std.testing.expectEqualSlices(u8, expected, tiny);
    try std.testing.expectEqualSlices(u8, expected, micro);

    var decoder = lzip.IncrementalDecoder.init(allocator);
    defer decoder.deinit();
    var output: [expected.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < concatenated.len) {
        const stepped = try decoder.step(
            concatenated[input_offset..],
            output[output_offset..],
        );
        input_offset += stepped.progress.input_read;
        output_offset += stepped.progress.output_written;
    }
    decoder.finish();
    const done = try decoder.step("", output[output_offset..]);
    output_offset += done.progress.output_written;
    try std.testing.expectEqual(coreStatusDone(), done.status);
    try std.testing.expectEqualSlices(u8, expected, output[0..output_offset]);
    try std.testing.expectEqual(@as(usize, 2), decoder.snapshot().member_count);
}

test "lzip incremental decoder validates Vort members limits and trailers" {
    const allocator = std.testing.allocator;
    const members = [_]lzip.EncodeMember{
        .{ .data = "first incremental lzip member" ** 32, .options = .{ .dictionary_size = 4096 } },
        .{ .data = "second incremental lzip member" ** 48, .options = .{ .dictionary_size = 64 * 1024 } },
    };
    const encoded = try lzip.encodeMembersAlloc(allocator, &members);
    defer allocator.free(encoded);
    const expected = members[0].data ++ members[1].data;
    const decoded = try decodeSchedule(allocator, encoded, 3, 5, .{
        .expected_output_len = expected.len,
    });
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);

    inline for (.{
        .{ @as(usize, encoded.len - 20), error.ChecksumMismatch },
        .{ @as(usize, encoded.len - 16), error.SizeMismatch },
        .{ @as(usize, encoded.len - 8), error.SizeMismatch },
    }) |case| {
        var corrupt = try allocator.dupe(u8, encoded);
        defer allocator.free(corrupt);
        corrupt[case[0]] ^= 1;
        try expectDecodeError(corrupt, case[1]);
    }

    try expectOptionsError(encoded, .{ .max_output_len = expected.len - 1 }, error.OutputLimitExceeded);
    try expectOptionsError(encoded, .{ .max_member_output_len = members[0].data.len - 1 }, error.OutputLimitExceeded);
    try expectOptionsError(encoded, .{ .max_dictionary_size = 4096 }, error.OutputLimitExceeded);
    try expectOptionsError(encoded, .{ .max_members = 1 }, error.OutputLimitExceeded);
    try expectOptionsError(encoded, .{ .expected_output_len = expected.len + 1 }, error.SizeMismatch);
}

test "lzip incremental decoder rejects truncation empty multimember and trailing data" {
    const allocator = std.testing.allocator;
    const first = fixture(first_hex);
    const empty_hex = "4c5a4950010c0083fffbffffc00000000000000000000000000000002400000000000000";
    const empty = fixture(empty_hex);

    const empty_decoded = try decodeSchedule(allocator, &empty, 1, 1, .{});
    defer allocator.free(empty_decoded);
    try std.testing.expectEqual(@as(usize, 0), empty_decoded.len);

    var invalid: [empty.len + first.len]u8 = undefined;
    @memcpy(invalid[0..empty.len], &empty);
    @memcpy(invalid[empty.len..], &first);
    try expectDecodeError(&invalid, error.InvalidLzipStream);

    try expectDecodeError(first[0 .. first.len - 1], error.TruncatedFrame);
    var trailing: [first.len + 1]u8 = undefined;
    @memcpy(trailing[0..first.len], &first);
    trailing[first.len] = 0;
    try expectDecodeError(&trailing, error.TruncatedFrame);
}

test "lzip incremental decoder releases every allocation failure path" {
    const allocator = std.testing.allocator;
    const members = [_]lzip.EncodeMember{
        .{ .data = "allocation failure lzip one" ** 128 },
        .{ .data = "allocation failure lzip two" ** 192 },
    };
    const encoded = try lzip.encodeMembersAlloc(allocator, &members);
    defer allocator.free(encoded);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            const decoded = try decodeSchedule(failing_allocator, bytes, 11, 17, .{});
            defer failing_allocator.free(decoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{encoded});
}

fn expectDecodeError(encoded: []const u8, expected: anyerror) !void {
    return expectOptionsError(encoded, .{}, expected);
}

fn expectOptionsError(
    encoded: []const u8,
    options: lzip.IncrementalDecoder.Options,
    expected: anyerror,
) !void {
    var decoder = lzip.IncrementalDecoder.initWithOptions(std.testing.allocator, options);
    defer decoder.deinit();
    var output: [257]u8 = undefined;
    var input_offset: usize = 0;
    var finish_sent = false;
    while (true) {
        const stepped = decoder.step(encoded[input_offset..], &output) catch |err| {
            try std.testing.expectEqual(expected, err);
            return;
        };
        input_offset += stepped.progress.input_read;
        if (stepped.status == .done) return error.TestUnexpectedResult;
        if (!finish_sent and input_offset == encoded.len) {
            decoder.finish();
            finish_sent = true;
        }
    }
}

fn coreStatusDone() @import("../core.zig").StepResult.Status {
    return .done;
}
