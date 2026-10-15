const std = @import("std");
const incremental = @import("incremental_writer.zig");
const split_reader = @import("split_incremental_reader.zig");
const split_writer = @import("split_incremental_writer.zig");
const wire = @import("wire.zig");

const TestEntry = struct {
    options: incremental.EntryOptions,
    data: []const u8,
};

const Encoded = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    parts: []const []const u8,

    fn deinit(self: *Encoded) void {
        self.allocator.free(self.parts);
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

fn encode(
    allocator: std.mem.Allocator,
    entries: []const TestEntry,
    options: split_writer.Options,
    input_step: usize,
    output_step: usize,
) !Encoded {
    if (input_step == 0 or output_step == 0) return error.TestUnexpectedResult;
    var writer = try split_writer.Writer.initWithOptions(allocator, options);
    defer writer.deinit();
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    var bases: std.ArrayList(usize) = .empty;
    defer bases.deinit(allocator);
    try bases.append(allocator, 0);
    const output = try allocator.alloc(u8, output_step);
    defer allocator.free(output);

    for (entries) |entry| {
        try writer.beginEntry(entry.options);
        var input_offset: usize = 0;
        while (input_offset < entry.data.len) {
            const input_end = @min(entry.data.len, input_offset + input_step);
            while (input_offset < input_end) {
                const result = try writer.step(entry.data[input_offset..input_end], output);
                input_offset += result.progress.input_read;
                try bytes.appendSlice(allocator, output[0..result.progress.output_written]);
                try recordBoundary(&bases, allocator, bytes.items.len, result.status);
                switch (result.status) {
                    .need_input => {
                        if (input_offset != input_end) return error.TestUnexpectedResult;
                    },
                    .need_output, .part_done => {},
                    .done => return error.TestUnexpectedResult,
                }
                if (result.progress.input_read == 0 and
                    result.progress.output_written == 0 and
                    result.status != .part_done)
                    return error.TestUnexpectedResult;
                if (result.status == .need_input) break;
            }
        }
        try writer.finishEntry();
        while (writer.snapshot().phase != .ready) {
            const result = try writer.step("", output);
            try bytes.appendSlice(allocator, output[0..result.progress.output_written]);
            try recordBoundary(&bases, allocator, bytes.items.len, result.status);
            if (result.status == .done or result.status == .need_input and
                writer.snapshot().phase != .ready)
                return error.TestUnexpectedResult;
            if (result.progress.output_written == 0 and result.status == .need_output)
                return error.TestUnexpectedResult;
        }
    }

    try writer.finishArchive();
    while (true) {
        const result = try writer.step("", output);
        try bytes.appendSlice(allocator, output[0..result.progress.output_written]);
        try recordBoundary(&bases, allocator, bytes.items.len, result.status);
        if (result.status == .done) break;
        if (result.status == .need_input) return error.TestUnexpectedResult;
        if (result.progress.output_written == 0 and result.status == .need_output)
            return error.TestUnexpectedResult;
    }
    const owned_bytes = try bytes.toOwnedSlice(allocator);
    errdefer allocator.free(owned_bytes);
    const parts = try allocator.alloc([]const u8, bases.items.len);
    errdefer allocator.free(parts);
    for (parts, bases.items, 0..) |*part, base, index| {
        const end = if (index + 1 < bases.items.len)
            bases.items[index + 1]
        else
            owned_bytes.len;
        if (base >= end) return error.TestUnexpectedResult;
        part.* = owned_bytes[base..end];
    }
    return .{
        .allocator = allocator,
        .bytes = owned_bytes,
        .parts = parts,
    };
}

fn recordBoundary(
    bases: *std.ArrayList(usize),
    allocator: std.mem.Allocator,
    output_len: usize,
    status: split_writer.StepResult.Status,
) !void {
    if (status != .part_done) return;
    if (output_len == bases.items[bases.items.len - 1])
        return error.TestUnexpectedResult;
    try bases.append(allocator, output_len);
}

fn decodeAll(
    allocator: std.mem.Allocator,
    parts: []const []const u8,
    password: ?[]const u8,
) ![]u8 {
    var reader = try split_reader.Reader.initAlloc(allocator, parts, .{
        .reader_options = .{ .password = password },
        .input_buffer_size = 37,
    });
    defer reader.deinit();
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    while (true) {
        var output: [43]u8 = undefined;
        const result = try reader.step(&output);
        try decoded.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.status == .done) break;
        if (result.status == .need_input) return error.TestUnexpectedResult;
    }
    try reader.finish();
    return decoded.toOwnedSlice(allocator);
}

test "split incremental writer is deterministic across backpressure" {
    const allocator = std.testing.allocator;
    const password = "incremental split password";
    const salt = [_]u8{0x3c} ** 16;
    const stored = "incremental split stored crossing payload\n" ** 173;
    const deflated = "incremental split Deflate crossing payload\n" ** 997;
    const aes = "incremental split WinZip AES payload\n" ** 113;
    const entries = [_]TestEntry{
        .{
            .options = .{
                .name = "stored.bin",
                .method = .stored,
                .expected_size = stored.len,
                .traditional_encryption = .{
                    .password = password,
                    .header_random = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
                },
            },
            .data = stored,
        },
        .{
            .options = .{
                .name = "deflated.txt",
                .method = .deflate,
                .expected_size = deflated.len,
            },
            .data = deflated,
        },
        .{
            .options = .{
                .name = "aes.txt",
                .method = .deflate,
                .expected_size = aes.len,
                .winzip_aes = .{
                    .password = password,
                    .salt = &salt,
                    .strength = .aes256,
                    .version = .ae2,
                },
            },
            .data = aes,
        },
        .{
            .options = .{
                .name = "empty.bin",
                .method = .stored,
                .expected_size = 0,
            },
            .data = "",
        },
    };
    inline for (.{ incremental.Zip64Mode.never, .always }) |zip64_mode| {
        const options: split_writer.Options = .{
            .writer_options = .{
                .archive_comment = "incremental split archive",
                .zip64 = zip64_mode,
            },
            .max_part_size = 512,
        };
        var tiny = try encode(allocator, &entries, options, 257, 1);
        defer tiny.deinit();
        var wider = try encode(allocator, &entries, options, 4096, 97);
        defer wider.deinit();
        try std.testing.expect(tiny.parts.len > 4);
        try std.testing.expectEqual(tiny.parts.len, wider.parts.len);
        try std.testing.expectEqualSlices(u8, tiny.bytes, wider.bytes);
        for (tiny.parts, wider.parts) |part, wide_part| {
            try std.testing.expect(part.len <= options.max_part_size);
            try std.testing.expectEqual(part.len, wide_part.len);
        }
        try std.testing.expectEqual(
            @as(u32, wire.data_descriptor_signature),
            std.mem.readInt(u32, tiny.parts[0][0..4], .little),
        );
        const decoded = try decodeAll(allocator, tiny.parts, password);
        defer allocator.free(decoded);
        try std.testing.expectEqual(stored.len + deflated.len + aes.len, decoded.len);
        try std.testing.expectEqualSlices(u8, stored, decoded[0..stored.len]);
        try std.testing.expectEqualSlices(
            u8,
            deflated,
            decoded[stored.len..][0..deflated.len],
        );
        try std.testing.expectEqualSlices(u8, aes, decoded[stored.len + deflated.len ..]);
    }
}

test "split incremental writer covers empty archives and limits" {
    const allocator = std.testing.allocator;
    inline for (.{ incremental.Zip64Mode.never, .always }) |zip64_mode| {
        var empty = try encode(allocator, &.{}, .{
            .writer_options = .{ .zip64 = zip64_mode },
            .max_part_size = if (zip64_mode == .always) 98 else 22,
        }, 1, 1);
        defer empty.deinit();
        try std.testing.expectEqual(@as(usize, 2), empty.parts.len);
        const decoded = try decodeAll(allocator, empty.parts, null);
        defer allocator.free(decoded);
        try std.testing.expectEqual(@as(usize, 0), decoded.len);
    }
    try std.testing.expectError(
        error.InvalidZipSplitSize,
        split_writer.Writer.initWithOptions(allocator, .{ .max_part_size = 3 }),
    );
    try std.testing.expectError(
        error.ZipSplitLimitExceeded,
        split_writer.Writer.initWithOptions(allocator, .{ .max_parts = 0 }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        split_writer.Writer.initWithOptions(allocator, .{ .max_archive_size = 3 }),
    );
}

test "split incremental writer handles allocation failures" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const data = "allocation-safe incremental split writer" ** 7;
            const entries = [_]TestEntry{.{
                .options = .{
                    .name = "oom.bin",
                    .method = .stored,
                    .expected_size = data.len,
                },
                .data = data,
            }};
            var encoded = try encode(allocator, &entries, .{
                .max_part_size = 80,
            }, 17, 19);
            defer encoded.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Test.run, .{});
}
