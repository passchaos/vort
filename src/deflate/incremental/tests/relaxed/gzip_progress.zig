const Count = @import("../../../../core.zig").StreamCount;
const std = @import("std");
const core = @import("../../../../core.zig");
const checksum = @import("../../../../checksum.zig");
const helpers = @import("gzip_helpers.zig");

pub fn contracts(comptime D: type) !void {
    try fragmented(D);
    try blockBoundaries(D);
    try partialError(D);
}

fn fragmented(comptime D: type) !void {
    const payload = "tiny output drains the final EOB " ** 4;
    const stored = try D.encodeGzipStoredAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(stored);
    const fixed = try D.encodeGzipFixedAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(fixed);
    const dynamic = try D.encodeGzipDynamicWithOptionsAlloc(std.testing.allocator, payload, D.optionsForLevel(.default));
    defer std.testing.allocator.free(dynamic);
    var history: [32 * 1024]u8 = undefined;
    var output: [payload.len]u8 = undefined;
    for ([_][]const u8{ stored, fixed, dynamic }) |encoded| {
        var decoder = try D.GzipIncrementalDecoder.init(.{}, &history);
        var input_offset: usize = 0;
        var output_offset: usize = 0;
        var iterations: usize = 0;
        while (!decoder.snapshot().done) : (iterations += 1) {
            try std.testing.expect(iterations < encoded.len + payload.len + 32);
            const input = encoded[input_offset..][0..@min(1, encoded.len - input_offset)];
            const out = output[output_offset..][0..@min(1, output.len - output_offset)];
            const advanced = try helpers.step(&decoder, input, out);
            input_offset += advanced.progress.input_read;
            output_offset += advanced.progress.output_written;
            try std.testing.expect(advanced.status == .done or advanced.progress.input_read != 0 or advanced.progress.output_written != 0);
        }
        try decoder.finish();
        try std.testing.expectEqual(encoded.len, input_offset);
        try std.testing.expectEqual(payload.len, output_offset);
        try std.testing.expectEqualSlices(u8, payload, &output);
        try std.testing.expectEqual(checksum.Crc32.hash(payload), decoder.crc.digest());
        try std.testing.expectEqual(@as(usize, 8), decoder.snapshot().footer_received);
        try std.testing.expectEqual(@as(?Count, encoded.len), decoder.memberEndOffset());
    }
    const empty = try D.encodeGzipFixedAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    var empty_decoder = try D.GzipIncrementalDecoder.init(.{}, &history);
    const eob = try helpers.step(&empty_decoder, empty, &.{});
    try std.testing.expectEqual(.done, eob.status);
    try std.testing.expectEqual(empty.len, eob.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), eob.progress.output_written);
}

fn blockBoundaries(comptime D: type) !void {
    const template = try D.encodeGzipStoredAlloc(std.testing.allocator, "ab");
    defer std.testing.allocator.free(template);
    // Two byte-aligned stored blocks, first nonfinal and then final.
    const blocks = [_]u8{ 0, 1, 0, 0xfe, 0xff, 'a', 1, 1, 0, 0xfe, 0xff, 'b' };
    const encoded = try helpers.join(&.{ template[0..10], &blocks, template[template.len - 8 ..] });
    defer std.testing.allocator.free(encoded);
    var history: [32 * 1024]u8 = undefined;
    var output: [2]u8 = undefined;
    var decoder = try D.GzipIncrementalDecoder.init(.{}, &history);
    const first = try helpers.boundary(&decoder, encoded, &output);
    try std.testing.expect(first.block_boundary);
    try std.testing.expect(decoder.atBlockBoundary());
    try std.testing.expectEqual(@as(usize, 16), first.progress.input_read);
    try std.testing.expectEqual(@as(usize, 1), first.progress.output_written);
    const second = try helpers.boundary(&decoder, encoded[first.progress.input_read..], output[first.progress.output_written..]);
    try std.testing.expectEqual(.done, second.status);
    try std.testing.expectEqual(encoded.len - first.progress.input_read, second.progress.input_read);
    try std.testing.expectEqual(@as(usize, 1), second.progress.output_written);
    try std.testing.expectEqualSlices(u8, "ab", &output);
    try std.testing.expectEqual(@as(usize, 8), decoder.snapshot().footer_received);
    try std.testing.expect(decoder.atBlockBoundary());
}

fn partialError(comptime D: type) !void {
    const template = try D.encodeGzipStoredAlloc(std.testing.allocator, "abc");
    defer std.testing.allocator.free(template);
    // Output a complete nonfinal stored block, then fail at reserved BTYPE=3
    // during the same raw call. There is no valid footer on this member.
    const blocks = [_]u8{ 0, 3, 0, 0xfc, 0xff, 'a', 'b', 'c', 7 };
    const encoded = try helpers.join(&.{ template[0..10], &blocks });
    defer std.testing.allocator.free(encoded);
    var history: [32 * 1024]u8 = undefined;
    var output: [16]u8 = undefined;
    var decoder = try D.GzipIncrementalDecoder.init(.{ .ignore_crc32 = true, .ignore_isize = true }, &history);
    try helpers.stepError(error.InvalidDeflateBlockType, &decoder, encoded, &output);
    const snapshot = decoder.snapshot();
    try std.testing.expectEqualSlices(u8, "abc", output[0..3]);
    try std.testing.expectEqual(@as(usize, 3), snapshot.total_output);
    try std.testing.expectEqual(@as(usize, 3), snapshot.member_output);
    try std.testing.expectEqual(encoded.len, snapshot.total_input);
    try std.testing.expectEqual(encoded.len, snapshot.member_input);
    try std.testing.expectEqual(core.Progress{ .input_read = encoded.len, .output_written = 3 }, snapshot.last_step_progress);
    try std.testing.expectEqual(checksum.Crc32.hash("abc"), decoder.crc.digest());
    try std.testing.expectEqual(D.GzipIncrementalDecoder.Phase.raw, snapshot.last_error_phase.?);
    try std.testing.expectEqualStrings("raw", decoder.diagnostics().last_error_phase_name);
    try std.testing.expectEqual(@as(?Count, null), decoder.memberEndOffset());
    decoder.reset();
    const reset = decoder.snapshot();
    try std.testing.expectEqual(@as(usize, 0), reset.total_input);
    try std.testing.expectEqual(@as(usize, 0), reset.total_output);
    try std.testing.expectEqual(core.Progress{}, reset.last_step_progress);
    try std.testing.expectEqual(@as(?Count, null), reset.last_error_input_offset);
    try std.testing.expectEqual(@as(?Count, null), reset.last_error_output_offset);
    try std.testing.expectEqualStrings("", reset.last_error_name);
    try std.testing.expectEqual(@as(?core.StreamCount, null), decoder.diagnostics().error_input_offset);
    try std.testing.expectEqual(@as(?core.StreamCount, null), decoder.diagnostics().error_output_offset);
    try std.testing.expectEqualStrings("none", decoder.diagnostics().recoverability_hint_name);
    try std.testing.expectEqual(.done, (try helpers.step(&decoder, template, &output)).status);

    var fragmented_error = try D.GzipIncrementalDecoder.init(.{}, &history);
    const first = try helpers.step(&fragmented_error, encoded, output[0..2]);
    try std.testing.expectEqual(.need_output, first.status);
    try std.testing.expectEqual(@as(usize, 2), first.progress.output_written);
    try helpers.stepError(error.InvalidDeflateBlockType, &fragmented_error, encoded[first.progress.input_read..], output[2..3]);
    try std.testing.expectEqualSlices(u8, "abc", output[0..3]);
    try std.testing.expectEqual(@as(usize, 1), fragmented_error.snapshot().last_step_progress.output_written);
    try std.testing.expectEqual(@as(usize, 3), fragmented_error.snapshot().total_output);
    try std.testing.expectEqual(encoded.len, fragmented_error.snapshot().total_input);
    try std.testing.expectEqual(checksum.Crc32.hash("abc"), fragmented_error.crc.digest());
}
