const std = @import("std");
const archive = @import("archive.zig");
const auto = @import("incremental_auto_reader.zig");
const compressed = @import("compressed.zig");
const lz4_legacy = @import("../lz4_legacy.zig");
const mixed = @import("incremental_mixed_reader.zig");
const writer = @import("writer.zig");

const formats = [_]auto.Format{
    .raw_cpio,
    .gzip,
    .bzip2,
    .brotli,
    .compress_z,
    .lzma,
    .xz,
    .lz4,
    .lz4_legacy,
    .zstandard,
    .lzf,
    .lzip,
    .lzop,
};

const Fixture = struct {
    bytes: []u8,
    starts: [formats.len]usize,
    sizes: [formats.len]usize,
    padding: usize,

    fn deinit(self: Fixture, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

fn compressionFor(format: auto.Format) ?compressed.Compression {
    return switch (format) {
        .raw_cpio => null,
        .gzip => .gzip,
        .bzip2 => .bzip2,
        .brotli => .brotli,
        .compress_z => .compress_z,
        .lzma => .lzma,
        .xz => .xz,
        .lz4 => .lz4,
        .zstandard => .zstandard,
        .lzf => .lzf,
        .lzip => .lzip,
        .lzop => .lzop,
        else => unreachable,
    };
}

fn requiresDeclaredInputSize(format: auto.Format) bool {
    return format == .compress_z or format == .lz4_legacy;
}

fn declareMemberBoundary(reader: *mixed.Reader, fixture: Fixture, index: usize) !void {
    if (index < formats.len and requiresDeclaredInputSize(formats[index]))
        try reader.setNextMemberInputSize(fixture.sizes[index]);
}

fn makeFixture(allocator: std.mem.Allocator) !Fixture {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendNTimes(allocator, 0, 3);
    var starts: [formats.len]usize = undefined;
    var sizes: [formats.len]usize = undefined;
    var padding: usize = 3;
    for (formats, 0..) |format, index| {
        const name = try std.fmt.allocPrint(allocator, "payload-{d}", .{index});
        defer allocator.free(name);
        const data = try std.fmt.allocPrint(allocator, "member-{d}-data", .{index});
        defer allocator.free(data);
        const entries = [_]writer.EncodeEntry{.{ .name = name, .data = data }};
        const encoded = switch (format) {
            .raw_cpio => try writer.encodeAlloc(allocator, &entries, .{
                .format = .crc,
                .block_size = 512,
            }),
            .lz4_legacy => encoded: {
                const raw = try writer.encodeAlloc(allocator, &entries, .{});
                defer allocator.free(raw);
                break :encoded try lz4_legacy.encodeAlloc(allocator, raw, .{
                    .block_size = 1024,
                });
            },
            else => encoded: {
                const compression = compressionFor(format).?;
                var options = compressed.EncodeOptions{ .compression = compression };
                if (compression == .lzf) options.lzf_options.eof_marker = true;
                break :encoded try compressed.encodeAlloc(allocator, &entries, options);
            },
        };
        defer allocator.free(encoded);
        starts[index] = output.items.len;
        sizes[index] = encoded.len;
        try output.appendSlice(allocator, encoded);
        const extra = index % 4;
        try output.appendNTimes(allocator, 0, extra);
        padding += extra;
        if (format == .raw_cpio) {
            const parsed = try archive.parse(encoded);
            padding += encoded.len - parsed.archive_end;
            sizes[index] = parsed.archive_end;
        }
    }
    try output.appendNTimes(allocator, 0, 9);
    padding += 9;
    return .{
        .bytes = try output.toOwnedSlice(allocator),
        .starts = starts,
        .sizes = sizes,
        .padding = padding,
    };
}

fn exercise(
    allocator: std.mem.Allocator,
    fixture: Fixture,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    var reader = try mixed.Reader.initWithOptions(allocator, .{
        .decoder_input_chunk_size = 64 * 1024,
        .max_replay_size = 64 * 1024,
    });
    defer reader.deinit();
    const output = try allocator.alloc(u8, output_chunk);
    defer allocator.free(output);
    var current: std.ArrayList(u8) = .empty;
    defer current.deinit(allocator);
    var input_offset: usize = 0;
    var entry_index: usize = 0;
    var member_index: usize = 0;
    var finish_sent = false;
    var recovered_any = false;
    try declareMemberBoundary(&reader, fixture, member_index);
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
                const data = try std.fmt.bufPrint(&expected_data, "member-{d}-data", .{entry_index});
                try std.testing.expectEqualSlices(u8, data, current.items);
                entry_index += 1;
            },
            .archive_done => {
                const info = reader.lastArchive() orelse return error.TestUnexpectedResult;
                try std.testing.expectEqual(member_index, info.index);
                try std.testing.expectEqual(formats[member_index], info.format);
                try std.testing.expectEqual(@as(u64, fixture.starts[member_index]), info.input_offset);
                try std.testing.expectEqual(@as(u64, fixture.sizes[member_index]), info.input_size);
                const declared: ?u64 = if (requiresDeclaredInputSize(formats[member_index]))
                    fixture.sizes[member_index]
                else
                    null;
                try std.testing.expectEqual(declared, info.declared_input_size);
                recovered_any = recovered_any or info.recovered_suffix_size != 0;
                member_index += 1;
                try declareMemberBoundary(&reader, fixture, member_index);
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
            !(stepped.status == .need_input and input_offset == fixture.bytes.len))
        {
            return error.TestUnexpectedResult;
        }
    }
    try std.testing.expectEqual(fixture.bytes.len, input_offset);
    try std.testing.expectEqual(formats.len, member_index);
    try std.testing.expectEqual(formats.len, entry_index);
    try std.testing.expectEqual(@as(u64, fixture.padding), reader.snapshot().padding_bytes);
    if (input_chunk > 1) try std.testing.expect(recovered_any);
}

test "CPIO mixed reader streams raw and twelve compressed member formats" {
    const allocator = std.testing.allocator;
    const fixture = try makeFixture(allocator);
    defer fixture.deinit(allocator);
    try exercise(allocator, fixture, 1, 1);
    try exercise(allocator, fixture, 64 * 1024, 17);
}

test "CPIO mixed reader rejects formats without exact member boundaries" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "abc" }};
    inline for (.{
        compressed.Compression.compress_z,
    }) |compression| {
        const encoded = try compressed.encodeAlloc(allocator, &entries, .{
            .compression = compression,
        });
        defer allocator.free(encoded);
        var reader = try mixed.Reader.init(allocator);
        defer reader.deinit();
        var output: [32]u8 = undefined;
        var offset: usize = 0;
        while (true) {
            const stepped = reader.step(encoded[offset..], &output) catch |err| {
                try std.testing.expectEqual(error.UnsupportedCpioSequenceCompression, err);
                break;
            };
            offset += stepped.input_read;
        }
    }

    const raw = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(raw);
    const legacy = try lz4_legacy.encodeAlloc(allocator, raw, .{ .block_size = 1024 });
    defer allocator.free(legacy);
    var legacy_reader = try mixed.Reader.init(allocator);
    defer legacy_reader.deinit();
    var output: [32]u8 = undefined;
    try std.testing.expectError(
        error.UnsupportedCpioSequenceCompression,
        legacy_reader.step(legacy, &output),
    );
}

test "CPIO mixed reader validates declared member boundaries" {
    const allocator = std.testing.allocator;
    const entries = [_]writer.EncodeEntry{.{ .name = "payload", .data = "abc" }};
    const raw_padded = try writer.encodeAlloc(allocator, &entries, .{});
    defer allocator.free(raw_padded);
    const parsed = try archive.parse(raw_padded);
    const raw = raw_padded[0..parsed.archive_end];
    const joined = try std.mem.concat(allocator, u8, &.{ raw, "N" });
    defer allocator.free(joined);

    var oversized = try mixed.Reader.init(allocator);
    defer oversized.deinit();
    try std.testing.expectError(
        error.InvalidCpioMixedReaderState,
        oversized.setNextMemberInputSize(0),
    );
    try oversized.setNextMemberInputSize(raw.len + 1);
    try std.testing.expectError(
        error.InvalidCpioMixedReaderState,
        oversized.setNextMemberInputSize(raw.len),
    );
    var output: [17]u8 = undefined;
    var offset: usize = 0;
    while (true) {
        const stepped = oversized.step(joined[offset..], &output) catch |err| {
            try std.testing.expectEqual(error.CpioMemberInputSizeMismatch, err);
            break;
        };
        offset += stepped.input_read;
    }

    var active = try mixed.Reader.init(allocator);
    defer active.deinit();
    const first = try active.step(raw[0..1], &output);
    try std.testing.expectEqual(@as(usize, 1), first.input_read);
    try std.testing.expectError(
        error.InvalidCpioMixedReaderState,
        active.setNextMemberInputSize(raw.len),
    );

    var missing = try mixed.Reader.init(allocator);
    defer missing.deinit();
    try missing.setNextMemberInputSize(raw.len);
    try std.testing.expectError(error.CpioMemberInputSizeMismatch, missing.finish());
}

test "CPIO mixed reader enforces sequence and replay limits" {
    const allocator = std.testing.allocator;
    const fixture = try makeFixture(allocator);
    defer fixture.deinit(allocator);
    const Cases = struct {
        fn expectLimit(fixture_value: Fixture, options: mixed.Options) !void {
            var reader = try mixed.Reader.initWithOptions(std.testing.allocator, options);
            defer reader.deinit();
            var output: [64]u8 = undefined;
            var offset: usize = 0;
            var member_index: usize = 0;
            try declareMemberBoundary(&reader, fixture_value, member_index);
            while (true) {
                const stepped = reader.step(fixture_value.bytes[offset..], &output) catch |err| {
                    try std.testing.expectEqual(error.OutputLimitExceeded, err);
                    return;
                };
                offset += stepped.input_read;
                if (stepped.status == .archive_done) {
                    member_index += 1;
                    try declareMemberBoundary(&reader, fixture_value, member_index);
                }
                if (stepped.status == .need_input and offset == fixture_value.bytes.len)
                    try reader.finish();
                if (stepped.status == .done) return error.TestUnexpectedResult;
            }
        }
    };
    try Cases.expectLimit(fixture, .{ .max_members = 1 });
    try Cases.expectLimit(fixture, .{ .max_padding_size = 1 });
    try Cases.expectLimit(fixture, .{
        .max_total_input_size = fixture.bytes.len - 1,
    });
    try Cases.expectLimit(fixture, .{ .max_total_output_size = 1 });
    try std.testing.expectError(
        error.InvalidCpioMixedReaderState,
        mixed.Reader.initWithOptions(allocator, .{ .decoder_input_chunk_size = 0 }),
    );
}

test "CPIO mixed reader releases every allocation failure" {
    const allocator = std.testing.allocator;
    const fixture = try makeFixture(allocator);
    defer fixture.deinit(allocator);
    const Test = struct {
        fn run(failing_allocator: std.mem.Allocator, fixture_value: Fixture) !void {
            var reader = try mixed.Reader.initWithOptions(failing_allocator, .{
                .decoder_input_chunk_size = 64 * 1024,
            });
            defer reader.deinit();
            var output: [31]u8 = undefined;
            var offset: usize = 0;
            var member_index: usize = 0;
            var finish_sent = false;
            try declareMemberBoundary(&reader, fixture_value, member_index);
            while (true) {
                const stepped = try reader.step(fixture_value.bytes[offset..], &output);
                offset += stepped.input_read;
                if (stepped.status == .done) break;
                if (stepped.status == .archive_done) {
                    member_index += 1;
                    try declareMemberBoundary(&reader, fixture_value, member_index);
                }
                if (!finish_sent and offset == fixture_value.bytes.len) {
                    try reader.finish();
                    finish_sent = true;
                }
            }
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{fixture});
}
