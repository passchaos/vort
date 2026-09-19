const std = @import("std");

pub fn fillMultiblockPayload(payload: []u8) void {
    var random_state: u32 = @truncate(0x9e37_79b9 +% 129 *% 0x10001 +% 16 *% 0x101 +% 23);
    for (payload, 0..) |*byte, index| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(random_state >> 16);
    }
    const copy_len = payload.len / 4;
    @memcpy(payload[payload.len - copy_len ..], payload[payload.len / 4 ..][0..copy_len]);
}

fn expectTableEqual(
    mode: anytype,
    expected_rle: anytype,
    actual_rle: @TypeOf(expected_rle),
    expected_fse: anytype,
    actual_fse: @TypeOf(expected_fse),
) !void {
    switch (mode) {
        .rle => try std.testing.expectEqualDeep(expected_rle, actual_rle),
        .compressed => {
            try std.testing.expectEqual(expected_fse.len, actual_fse.len);
            try std.testing.expectEqual(expected_fse.accuracy_log, actual_fse.accuracy_log);
            try std.testing.expectEqualSlices(
                @TypeOf(expected_fse.entries[0]),
                expected_fse.entries[0..expected_fse.len],
                actual_fse.entries[0..actual_fse.len],
            );
        },
        .predefined => {},
        .repeat => return error.UnresolvedRepeatTable,
    }
}

pub fn expectEncoderStateEqual(expected: anytype, actual: @TypeOf(expected)) !void {
    try std.testing.expectEqual(expected.repeated_offsets, actual.repeated_offsets);
    try std.testing.expectEqual(expected.previous_tables != null, actual.previous_tables != null);
    const expected_tables = expected.previous_tables orelse return;
    const actual_tables = actual.previous_tables.?;
    try std.testing.expectEqual(expected_tables.ll_mode, actual_tables.ll_mode);
    try std.testing.expectEqual(expected_tables.of_mode, actual_tables.of_mode);
    try std.testing.expectEqual(expected_tables.ml_mode, actual_tables.ml_mode);
    try expectTableEqual(expected_tables.ll_mode, expected_tables.literal_rle, actual_tables.literal_rle, &expected_tables.literal_fse, &actual_tables.literal_fse);
    try expectTableEqual(expected_tables.of_mode, expected_tables.offset_rle, actual_tables.offset_rle, &expected_tables.offset_fse, &actual_tables.offset_fse);
    try expectTableEqual(expected_tables.ml_mode, expected_tables.match_rle, actual_tables.match_rle, &expected_tables.match_fse, &actual_tables.match_fse);
}

pub fn expectKnownCommitRejectsEstablishedState(
    allocator: std.mem.Allocator,
    candidate: []const u8,
    initial_state: anytype,
    repeated_offsets: [3]usize,
    comptime decoded_commit: anytype,
    comptime known_commit: anytype,
) !void {
    var established = initial_state;
    var seed_output: std.ArrayList(u8) = .empty;
    defer seed_output.deinit(allocator);
    try decoded_commit(allocator, &seed_output, candidate, false, &established);
    const before = established;

    var rejected_output: std.ArrayList(u8) = .empty;
    defer rejected_output.deinit(allocator);
    try std.testing.expectError(
        error.CorruptFrame,
        known_commit(allocator, &rejected_output, candidate, &established, repeated_offsets),
    );
    try std.testing.expectEqual(@as(usize, 0), rejected_output.items.len);
    try expectEncoderStateEqual(before, established);
}

pub fn expectCommitPathsEqual(
    allocator: std.mem.Allocator,
    candidate: []const u8,
    initial_state: anytype,
    repeated_offsets: [3]usize,
    comptime decoded_commit: anytype,
    comptime known_commit: anytype,
) !void {
    var decoded_state = initial_state;
    var decoded_output: std.ArrayList(u8) = .empty;
    defer decoded_output.deinit(allocator);
    try decoded_commit(allocator, &decoded_output, candidate, false, &decoded_state);

    var known_state = initial_state;
    var known_output: std.ArrayList(u8) = .empty;
    defer known_output.deinit(allocator);
    try known_commit(allocator, &known_output, candidate, &known_state, repeated_offsets);
    try std.testing.expectEqualSlices(u8, decoded_output.items, known_output.items);
    try expectEncoderStateEqual(decoded_state, known_state);

    var failed_state = initial_state;
    var failed_output: std.ArrayList(u8) = .empty;
    defer failed_output.deinit(allocator);
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    try std.testing.expectError(
        error.OutOfMemory,
        known_commit(failing.allocator(), &failed_output, candidate, &failed_state, repeated_offsets),
    );
    try std.testing.expectEqual(@as(usize, 0), failed_output.items.len);
    try expectEncoderStateEqual(initial_state, failed_state);
}

pub fn expectFrameSwitchEqual(
    allocator: std.mem.Allocator,
    payload: []const u8,
    options: anytype,
    disabled: *bool,
    hits: *usize,
    comptime encode: anytype,
    comptime decode: anytype,
) !void {
    const direct = try encode(allocator, payload, options);
    defer allocator.free(direct.frame);
    try std.testing.expectEqual(@as(usize, 1), hits.*);
    disabled.* = true;
    const decoded_commit = try encode(allocator, payload, options);
    defer allocator.free(decoded_commit.frame);
    disabled.* = false;
    try std.testing.expectEqualSlices(u8, decoded_commit.frame, direct.frame);
    const decoded = try decode(allocator, direct.frame);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}
