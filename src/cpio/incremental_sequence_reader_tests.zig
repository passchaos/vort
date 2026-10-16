const std = @import("std");
const archive = @import("archive.zig");
const sequence = @import("incremental_sequence_reader.zig");
const writer = @import("writer.zig");

const Fixture = struct {
    bytes: []u8,
    starts: [5]usize,
    sizes: [5]usize,
    formats: [5]archive.Format,
    padding: usize,

    fn deinit(self: Fixture, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

fn makeFixture(allocator: std.mem.Allocator) !Fixture {
    const formats = std.meta.tags(archive.Format).*;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, 3);
    var starts: [5]usize = undefined;
    var sizes: [5]usize = undefined;
    var padding: usize = 3;
    for (formats, 0..) |format, index| {
        const name = try std.fmt.allocPrint(allocator, "payload-{d}", .{index});
        defer allocator.free(name);
        const data = try std.fmt.allocPrint(allocator, "archive-{d}-data", .{index});
        defer allocator.free(data);
        const encoded = try writer.encodeAlloc(
            allocator,
            &.{.{ .name = name, .data = data }},
            .{ .format = format, .block_size = 512 },
        );
        defer allocator.free(encoded);
        const parsed = try archive.parse(encoded);
        starts[index] = output.items.len;
        sizes[index] = parsed.archive_end;
        try output.appendSlice(allocator, encoded);
        padding += encoded.len - parsed.archive_end;
        const extra = index % 3;
        try output.appendNTimes(allocator, 0, extra);
        padding += extra;
    }
    try output.appendNTimes(allocator, 0, 7);
    padding += 7;
    return .{
        .bytes = try output.toOwnedSlice(allocator),
        .starts = starts,
        .sizes = sizes,
        .formats = formats,
        .padding = padding,
    };
}

fn exercise(
    allocator: std.mem.Allocator,
    fixture: Fixture,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    var reader = sequence.Reader.init(allocator);
    defer reader.deinit();
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    var current: std.ArrayList(u8) = .empty;
    defer current.deinit(allocator);
    var input_offset: usize = 0;
    var entry_index: usize = 0;
    var archive_index: usize = 0;
    var finish_sent = false;
    while (true) {
        const input_end = @min(fixture.bytes.len, input_offset + input_chunk);
        const stepped = try reader.step(fixture.bytes[input_offset..input_end], output);
        input_offset += stepped.input_read;
        try current.appendSlice(allocator, output[0..stepped.output_written]);
        switch (stepped.status) {
            .entry_header => {
                const info = reader.currentEntry() orelse return error.TestUnexpectedResult;
                var expected_name: [32]u8 = undefined;
                const name = try std.fmt.bufPrint(&expected_name, "payload-{d}", .{entry_index});
                try std.testing.expectEqualStrings(name, info.name);
                current.clearRetainingCapacity();
            },
            .entry_done => {
                var expected_data: [32]u8 = undefined;
                const data = try std.fmt.bufPrint(&expected_data, "archive-{d}-data", .{entry_index});
                try std.testing.expectEqualSlices(u8, data, current.items);
                entry_index += 1;
            },
            .archive_done => {
                const info = reader.lastArchive() orelse return error.TestUnexpectedResult;
                try std.testing.expectEqual(archive_index, info.index);
                try std.testing.expectEqual(fixture.formats[archive_index], info.format);
                try std.testing.expectEqual(@as(u64, fixture.starts[archive_index]), info.input_offset);
                try std.testing.expectEqual(@as(u64, fixture.sizes[archive_index]), info.input_size);
                try std.testing.expectEqual(@as(usize, 1), info.entry_count);
                archive_index += 1;
            },
            .need_input => if (input_offset == fixture.bytes.len and !finish_sent) {
                try reader.finish();
                finish_sent = true;
            },
            .need_output => {},
            .done => break,
        }
        if (stepped.input_read == 0 and stepped.output_written == 0 and
            stepped.status != .entry_header and stepped.status != .entry_done and
            stepped.status != .archive_done and
            !(stepped.status == .need_input and !finish_sent))
        {
            return error.TestUnexpectedResult;
        }
    }
    try std.testing.expectEqual(fixture.bytes.len, input_offset);
    try std.testing.expectEqual(@as(usize, 5), archive_index);
    try std.testing.expectEqual(@as(usize, 5), entry_index);
    const snapshot = reader.snapshot();
    try std.testing.expectEqual(@as(u64, fixture.padding), snapshot.padding_bytes);
    try std.testing.expectEqual(@as(usize, 5), snapshot.archive_count);
}

test "CPIO sequence reader streams mixed raw formats and padding" {
    const allocator = std.testing.allocator;
    const fixture = try makeFixture(allocator);
    defer fixture.deinit(allocator);
    try exercise(allocator, fixture, 1, 1);
    try exercise(allocator, fixture, 17, 23);
}

test "CPIO sequence reader accepts an empty padded sequence" {
    var reader = sequence.Reader.init(std.testing.allocator);
    defer reader.deinit();
    var output: [1]u8 = undefined;
    const zeros = [_]u8{0} ** 31;
    const stepped = try reader.step(&zeros, &output);
    try std.testing.expectEqual(sequence.Status.need_input, stepped.status);
    try std.testing.expectEqual(zeros.len, stepped.input_read);
    try reader.finish();
    try std.testing.expectEqual(sequence.Status.done, (try reader.step("", &output)).status);
    try std.testing.expectEqual(@as(usize, 0), reader.snapshot().archive_count);
}

test "CPIO sequence reader enforces archive padding input and output limits" {
    const allocator = std.testing.allocator;
    const fixture = try makeFixture(allocator);
    defer fixture.deinit(allocator);
    const Cases = struct {
        fn expectLimit(bytes: []const u8, options: sequence.Options) !void {
            var reader = sequence.Reader.initWithOptions(std.testing.allocator, options);
            defer reader.deinit();
            var output: [64]u8 = undefined;
            var offset: usize = 0;
            while (true) {
                const stepped = reader.step(bytes[offset..], &output) catch |err| {
                    try std.testing.expectEqual(error.OutputLimitExceeded, err);
                    return;
                };
                offset += stepped.input_read;
                if (stepped.status == .need_input and offset == bytes.len)
                    try reader.finish();
                if (stepped.status == .done) return error.TestUnexpectedResult;
            }
        }
    };
    try Cases.expectLimit(fixture.bytes, .{ .max_archives = 1 });
    try Cases.expectLimit(fixture.bytes, .{ .max_padding_size = 1 });
    try Cases.expectLimit(fixture.bytes, .{
        .max_total_input_size = fixture.bytes.len - 1,
    });
    try Cases.expectLimit(fixture.bytes, .{ .max_total_output_size = 1 });
}

test "CPIO sequence reader rejects truncated and corrupt following archives" {
    const allocator = std.testing.allocator;
    const encoded = try writer.encodeAlloc(
        allocator,
        &.{.{ .name = "payload", .data = "abc" }},
        .{ .block_size = 0 },
    );
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    const short = encoded[0 .. parsed.archive_end - 1];
    var truncated = sequence.Reader.init(allocator);
    defer truncated.deinit();
    var output: [32]u8 = undefined;
    var offset: usize = 0;
    while (offset != short.len) {
        const stepped = try truncated.step(short[offset..], &output);
        offset += stepped.input_read;
    }
    try std.testing.expectError(error.TruncatedFrame, truncated.finish());
    try std.testing.expectError(error.CpioSequenceReaderPoisoned, truncated.step("", &output));

    const joined = try allocator.alloc(u8, parsed.archive_end + 4);
    defer allocator.free(joined);
    @memcpy(joined[0..parsed.archive_end], encoded[0..parsed.archive_end]);
    @memcpy(joined[parsed.archive_end..], "JUNK");
    var corrupt = sequence.Reader.init(allocator);
    defer corrupt.deinit();
    offset = 0;
    while (true) {
        const stepped = corrupt.step(joined[offset..], &output) catch |err| {
            try std.testing.expectEqual(error.InvalidMagic, err);
            break;
        };
        offset += stepped.input_read;
    }
}

test "CPIO sequence reader releases every allocation failure" {
    const allocator = std.testing.allocator;
    const long_name = "nested/" ++ "component-" ** 20 ++ "payload";
    const first = try writer.encodeAlloc(
        allocator,
        &.{.{ .name = long_name, .data = "first" }},
        .{ .format = .newc, .block_size = 0 },
    );
    defer allocator.free(first);
    const second = try writer.encodeAlloc(
        allocator,
        &.{.{ .name = long_name, .data = "second" }},
        .{ .format = .odc, .block_size = 0 },
    );
    defer allocator.free(second);
    const joined = try allocator.alloc(u8, first.len + 3 + second.len);
    defer allocator.free(joined);
    @memcpy(joined[0..first.len], first);
    @memset(joined[first.len..][0..3], 0);
    @memcpy(joined[first.len + 3 ..], second);

    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, bytes: []const u8) !void {
            var reader = sequence.Reader.init(failing_allocator);
            defer reader.deinit();
            var output: [31]u8 = undefined;
            var offset: usize = 0;
            var finish_sent = false;
            while (true) {
                const stepped = try reader.step(bytes[offset..], &output);
                offset += stepped.input_read;
                if (stepped.status == .done) break;
                if (!finish_sent and offset == bytes.len) {
                    try reader.finish();
                    finish_sent = true;
                }
            }
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{joined});
}
