const std = @import("std");
const lzip = @import("../lzip.zig");

fn encodeMember(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: lzip.IncrementalEncoder.Options,
    input_chunk: usize,
    output_chunk: usize,
) ![]u8 {
    var encoder = try lzip.IncrementalEncoder.initWithOptions(allocator, options);
    defer encoder.deinit();
    return encodeCurrent(&encoder, allocator, input, input_chunk, output_chunk);
}

fn encodeCurrent(
    encoder: *lzip.IncrementalEncoder,
    allocator: std.mem.Allocator,
    input: []const u8,
    input_chunk: usize,
    output_chunk: usize,
) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + input_chunk);
        while (input_offset < input_end) {
            const stepped = try encoder.step(input[input_offset..input_end], output);
            input_offset += stepped.progress.input_read;
            try encoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
            if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
                return error.TestUnexpectedResult;
        }
    }
    encoder.finish();
    while (true) {
        const stepped = try encoder.step("", output);
        try encoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
            return error.TestUnexpectedResult;
    }
    return encoded.toOwnedSlice(allocator);
}

test "lzip incremental encoder is byte exact across schedules and dictionaries" {
    const allocator = std.testing.allocator;
    const cases = .{
        .{ "", @as(u32, 4096) },
        .{ "lzip incremental encoder\n" ** 256, @as(u32, 300 * 1024) },
        .{ "another lzip block payload" ** 1024, @as(u32, 64 * 1024) },
    };
    inline for (cases) |case| {
        const expected = try lzip.encodeAlloc(allocator, case[0], .{
            .dictionary_size = case[1],
        });
        defer allocator.free(expected);
        const options: lzip.IncrementalEncoder.Options = .{
            .dictionary_size = case[1],
        };
        const one = try encodeMember(allocator, case[0], options, 1, 1);
        defer allocator.free(one);
        const micro = try encodeMember(allocator, case[0], options, 257, 31);
        defer allocator.free(micro);
        try std.testing.expectEqualSlices(u8, expected, one);
        try std.testing.expectEqualSlices(u8, expected, micro);
    }
}

test "lzip incremental encoder supports concatenated members" {
    const allocator = std.testing.allocator;
    const first = "first lzip incremental member\n" ** 64;
    const second = "second lzip incremental member\n" ** 96;
    var encoder = try lzip.IncrementalEncoder.initWithOptions(allocator, .{
        .dictionary_size = 4096,
    });
    defer encoder.deinit();
    const first_wire = try encodeCurrent(&encoder, allocator, first, 5, 7);
    defer allocator.free(first_wire);
    try encoder.nextMember(.{ .dictionary_size = 64 * 1024 });
    const second_wire = try encodeCurrent(&encoder, allocator, second, 11, 13);
    defer allocator.free(second_wire);
    var joined: std.ArrayList(u8) = .empty;
    defer joined.deinit(allocator);
    try joined.appendSlice(allocator, first_wire);
    try joined.appendSlice(allocator, second_wire);
    const expected = try lzip.encodeMembersAlloc(allocator, &.{
        .{ .data = first, .options = .{ .dictionary_size = 4096 } },
        .{ .data = second, .options = .{ .dictionary_size = 64 * 1024 } },
    });
    defer allocator.free(expected);
    try std.testing.expectEqualSlices(u8, expected, joined.items);
    try std.testing.expectEqual(@as(usize, 2), encoder.snapshot().member_count);
}

test "lzip incremental encoder enforces options empty members limits and backpressure" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidLzipOptions,
        lzip.IncrementalEncoder.initWithOptions(allocator, .{ .dictionary_size = 1024 }),
    );

    var empty = try lzip.IncrementalEncoder.init(allocator);
    defer empty.deinit();
    const empty_wire = try encodeCurrent(&empty, allocator, "", 1, 1);
    defer allocator.free(empty_wire);
    try std.testing.expectError(error.InvalidLzipOptions, empty.nextMember(.{}));

    var limited = try lzip.IncrementalEncoder.initWithOptions(allocator, .{
        .max_input_len = 2,
    });
    defer limited.deinit();
    var output: [128]u8 = undefined;
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("abc", &output));

    var pending = try lzip.IncrementalEncoder.initWithOptions(allocator, .{
        .max_pending_output_len = 14,
    });
    defer pending.deinit();
    _ = try pending.step("payload", &output);
    pending.finish();
    while (true) {
        _ = pending.step("", &output) catch |err| {
            try std.testing.expectEqual(error.OutputLimitExceeded, err);
            break;
        };
    }

    var blocked = try lzip.IncrementalEncoder.init(allocator);
    defer blocked.deinit();
    const first = try blocked.step("payload", &.{});
    try std.testing.expectEqual(@import("../core.zig").StepResult.Status.need_output, first.status);
    const second = try blocked.step("", &.{});
    try std.testing.expectEqual(@import("../core.zig").StepResult.Status.need_output, second.status);
}

test "lzip incremental encoder releases every allocation failure path" {
    const allocator = std.testing.allocator;
    const input = "allocation failure lzip encoder" ** 1024;
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            const encoded = try encodeMember(
                failing_allocator,
                bytes,
                .{ .dictionary_size = 64 * 1024 },
                17,
                29,
            );
            defer failing_allocator.free(encoded);
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{input});
}
