const std = @import("std");
const deflate = @import("../../../deflate.zig");
const core = @import("../../../core.zig");

fn feed(encoder: anytype, input: []const u8, wire: *std.ArrayList(u8), scratch: []u8) !void {
    var offset: usize = 0;
    while (offset < input.len) {
        const result = try encoder.step(input[offset..], scratch);
        try wire.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        offset += result.progress.input_read;
        if (result.progress.input_read == 0 and result.progress.output_written == 0)
            return error.TestUnexpectedResult;
    }
}

fn drainBoundary(encoder: anytype, wire: *std.ArrayList(u8), scratch: []u8) !void {
    while (true) {
        const result = try encoder.step("", scratch);
        try wire.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .need_input) return;
        try std.testing.expectEqual(.need_output, result.status);
    }
}

fn finish(encoder: anytype, wire: *std.ArrayList(u8), scratch: []u8) !void {
    encoder.finish();
    while (true) {
        const result = try encoder.step("", scratch);
        try wire.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) return;
        try std.testing.expectEqual(.need_output, result.status);
    }
}

fn makeRecoverableWire(first: []const u8, second: []const u8) ![]u8 {
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(
        std.testing.allocator,
        .{
            .block_len = 4096,
            .compression = deflate.optionsForLevel(.default),
        },
    );
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(std.testing.allocator);
    var scratch: [13]u8 = undefined;
    try feed(&encoder, first, &wire, &scratch);
    encoder.fullFlush();
    try drainBoundary(&encoder, &wire, &scratch);
    try feed(&encoder, second, &wire, &scratch);
    try finish(&encoder, &wire, &scratch);
    return wire.toOwnedSlice(std.testing.allocator);
}

test "raw deflate sync recovery decodes the independent suffix" {
    const first = "corrupt prefix before the full flush marker 0123456789\n" ** 31;
    const second = "recoverable suffix after the full flush marker abcdefghijklmnopqrstuvwxyz\n" ** 37;
    const original = try makeRecoverableWire(first, second);
    defer std.testing.allocator.free(original);
    const point = deflate.findRawDeflateSyncPoint(original).?;
    try std.testing.expectEqualSlices(u8, "\x00\x00\xff\xff", original[point.marker_offset..point.resume_offset]);

    const corrupt = try std.testing.allocator.dupe(u8, original);
    defer std.testing.allocator.free(corrupt);
    corrupt[0] = (corrupt[0] & ~@as(u8, 0x06)) | 0x06; // reserved BTYPE.
    try std.testing.expectError(
        error.InvalidDeflateBlockType,
        deflate.decodeRawAutoAlloc(std.testing.allocator, corrupt),
    );

    var output: [second.len]u8 = undefined;
    const recovered = try deflate.decodeRawDeflateAfterSync(corrupt, &output);
    try std.testing.expectEqualDeep(point, recovered.sync_point);
    try std.testing.expectEqual(corrupt.len, recovered.input_read);
    try std.testing.expectEqual(second.len, recovered.output_written);
    try std.testing.expectEqualSlices(u8, second, &output);

    const owned = try deflate.decodeRawDeflateAfterSyncAlloc(
        std.testing.allocator,
        corrupt,
    );
    defer owned.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, second, owned.bytes);
    try std.testing.expectEqual(corrupt.len, owned.input_read);
}

test "raw deflate sync recovery enforces marker and output limits" {
    const first = "damaged segment\n" ** 8;
    const second = "bounded recovered segment\n" ** 11;
    const wire = try makeRecoverableWire(first, second);
    defer std.testing.allocator.free(wire);
    try std.testing.expectError(
        error.DeflateSyncPointNotFound,
        deflate.decodeRawDeflateAfterSyncAlloc(std.testing.allocator, "no marker"),
    );
    try std.testing.expectError(
        error.OutputTooSmall,
        deflate.decodeRawDeflateAfterSync(wire, &.{}),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        deflate.decodeRawDeflateAfterSyncAllocLimited(
            std.testing.allocator,
            wire,
            second.len - 1,
        ),
    );
}

test "raw deflate sync scanner preserves offsets across arbitrary chunks" {
    const bytes = "prefix\x00\x00\xff\xffsuffix";
    var scanner: deflate.RawDeflateSyncScanner = .{};
    var offset: usize = 0;
    var point: ?deflate.RawDeflateSyncPoint = null;
    const sizes = [_]usize{ 1, 2, 1, 3 };
    var index: usize = 0;
    while (offset < bytes.len and point == null) {
        const len = @min(sizes[index % sizes.len], bytes.len - offset);
        const result = scanner.scan(bytes[offset..][0..len]);
        offset += result.input_read;
        point = result.point;
        index += 1;
    }
    try std.testing.expectEqual(@as(usize, 6), point.?.marker_offset);
    try std.testing.expectEqual(@as(usize, 10), point.?.resume_offset);
}

test "incremental raw decoder resumes after an external sync scan" {
    const first = "incremental corrupt segment before recovery\n" ** 19;
    const second = "incremental recovered suffix after marker 0123456789\n" ** 23;
    const wire = try makeRecoverableWire(first, second);
    defer std.testing.allocator.free(wire);
    const corrupt = try std.testing.allocator.dupe(u8, wire);
    defer std.testing.allocator.free(corrupt);
    corrupt[0] = (corrupt[0] & ~@as(u8, 0x06)) | 0x06;

    var history: [32 * 1024]u8 = undefined;
    var decoder = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(
        .{ .expected_output_len = second.len },
        &history,
    );
    var output: [second.len]u8 = undefined;
    try std.testing.expectError(
        error.InvalidDeflateBlockType,
        decoder.step(corrupt, &output),
    );
    const error_input = try core.stream_count.toLocal(decoder.diagnostics().frame_input_read.?);
    var scanner: deflate.RawDeflateSyncScanner = .{};
    const scan = scanner.scan(corrupt[error_input..]);
    const point = scan.point orelse return error.TestUnexpectedResult;
    try decoder.resumeAfterSync(scan.input_read);
    try std.testing.expectEqual(
        error_input + point.resume_offset,
        decoder.diagnostics().frame_input_read.?,
    );
    var input_offset = error_input + scan.input_read;
    var output_offset: usize = 0;
    while (true) {
        const result = try decoder.step(
            corrupt[input_offset..],
            output[output_offset..],
        );
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        if (result.status == .done) break;
        if (result.progress.input_read == 0 and result.progress.output_written == 0)
            return error.TestUnexpectedResult;
    }
    try decoder.finish();
    try std.testing.expectEqual(wire.len, input_offset);
    try std.testing.expectEqualSlices(u8, second, output[0..output_offset]);
}
