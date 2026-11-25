const core = @import("../../../core.zig");
const Decoder = @import("../../../deflate.zig").GzipIncrementalDecoder;
const t = @import("std").testing;
const Count = core.StreamCount;

// RFC 1952 fixtures: stored 'A', fixed-Huffman 'B', and a stored empty member.
const header = "\x1f\x8b\x08\x00\x00\x00\x00\x00\x00\xff";
const first = header ++ "\x01\x01\x00\xfe\xffA\x8b\x9e\xd9\xd3\x01\x00\x00\x00";
const second = header ++ "\x73\x02\x00\x31\xcf\xd0\x4a\x01\x00\x00\x00";
const empty = header ++ "\x01\x00\x00\xff\xff\x00\x00\x00\x00\x00\x00\x00\x00";
const padding = "\x00" ** 17;

fn expectMember(decoder: *const Decoder, total_input: Count, member_count: Count, member_offset: Count, member_input: Count) !void {
    const state = decoder.snapshot();
    try t.expectEqual(total_input, state.total_input);
    try t.expectEqual(member_count, state.member_count);
    try t.expectEqual(member_count - 1, state.member_index);
    try t.expectEqual(member_offset, state.member_offset);
    try t.expectEqual(member_input, state.member_input);
    try t.expectEqual(@as(?Count, member_offset + member_input), state.member_end_offset);
    try t.expectEqual(state.member_end_offset, decoder.memberEndOffset());
}

test "Gzip zero padding accepts complete and fragmented tails at exact limits" {
    const cases = [_]struct {
        wire: []const u8,
        plain: []const u8,
        member_count: Count,
        last_member: []const u8,
    }{
        .{ .wire = first ++ padding, .plain = "A", .member_count = 1, .last_member = first },
        .{ .wire = empty ++ padding, .plain = "", .member_count = 1, .last_member = empty },
        .{ .wire = first ++ second ++ empty ++ padding, .plain = "AB", .member_count = 3, .last_member = empty },
    };
    var history: [32 * 1024]u8 = undefined;
    for (cases) |case| {
        for ([_]bool{ false, true }) |fragmented| {
            var decoder = try Decoder.init(.{
                .allow_concatenated = case.member_count > 1,
                .allow_trailing_zero_padding = true,
                .max_members = case.member_count,
                .max_output_len = case.plain.len,
                .expected_output_len = case.plain.len,
            }, &history);
            var output: [2]u8 = undefined;
            var input_pos: usize = 0;
            var output_pos: usize = 0;
            while (input_pos < case.wire.len) {
                const input = case.wire[input_pos..];
                const available = output[output_pos..case.plain.len];
                const stepped = try decoder.step(
                    if (fragmented) input[0..1] else input,
                    if (fragmented) available[0..@min(1, available.len)] else available,
                );
                try t.expect(stepped.progress.input_read != 0 or stepped.progress.output_written != 0);
                try t.expect(stepped.status != .done);
                input_pos += stepped.progress.input_read;
                output_pos += stepped.progress.output_written;
            }
            try t.expectEqual(case.wire.len, input_pos);
            try t.expectEqualStrings(case.plain, output[0..output_pos]);
            try t.expectEqual(@as(Count, case.plain.len), decoder.snapshot().total_output);
            const last_offset = case.wire.len - padding.len - case.last_member.len;
            try expectMember(&decoder, case.wire.len, case.member_count, last_offset, case.last_member.len);
            try t.expect(!decoder.snapshot().done);

            try decoder.finish();
            try t.expect(decoder.snapshot().done);
            try expectMember(&decoder, case.wire.len, case.member_count, last_offset, case.last_member.len);
            try t.expectEqualStrings("", decoder.trailingPrefix());
            const finished = try decoder.step(&.{}, &.{});
            try t.expectEqual(.done, finished.status);
            try t.expectEqual(core.Progress{}, finished.progress);
        }
    }
}

test "Gzip zero padding rejects junk and further members after the first zero" {
    const wires = [_][]const u8{ first ++ padding ++ "!", first ++ padding ++ second };
    const prefix_len = first.len + padding.len;
    var history: [32 * 1024]u8 = undefined;
    var output: [2]u8 = undefined;
    for ([_]bool{ false, true }) |concatenated| {
        for (wires) |wire| {
            for ([_]usize{ 0, prefix_len }) |split| {
                var decoder = try Decoder.init(.{
                    .allow_concatenated = concatenated,
                    .allow_trailing_zero_padding = true,
                }, &history);
                const prefix = try decoder.step(wire[0..split], &output);
                try t.expectEqual(split, prefix.progress.input_read);
                try t.expectEqual(.need_input, prefix.status);
                try t.expectError(error.TrailingData, decoder.step(wire[split..], output[prefix.progress.output_written..]));
                try expectMember(&decoder, prefix_len, 1, 0, first.len);
                try t.expectEqual(prefix_len - split, decoder.snapshot().last_step_progress.input_read);
                try t.expectEqualSlices(u8, "A", output[0..1]);
            }
        }
    }
}

test "Gzip zero padding requires a validated member" {
    var history: [32 * 1024]u8 = undefined;
    for ([_]bool{ false, true }) |concatenated| {
        var decoder = try Decoder.init(.{
            .allow_concatenated = concatenated,
            .allow_trailing_zero_padding = true,
        }, &history);
        _ = try decoder.step(padding[0 .. header.len - 1], &.{});
        try t.expectError(error.TruncatedFrame, decoder.finish());
        try t.expectEqual(@as(Count, 0), decoder.snapshot().member_count);
        decoder.reset();
        try t.expectError(error.BadGzipHeader, decoder.step(padding, &.{}));
        try t.expectEqual(@as(Count, 0), decoder.snapshot().member_count);
    }
}

test "Gzip zero padding is opt-in and incompatible with arbitrary trailing data" {
    var history: [32 * 1024]u8 = undefined;
    var output: [1]u8 = undefined;
    var single = try Decoder.init(.{}, &history);
    try t.expectError(error.TrailingData, single.step(first ++ padding, &output));

    var concat = try Decoder.init(.{ .allow_concatenated = true }, &history);
    try t.expectError(error.BadGzipHeader, concat.step(first ++ padding, &output));

    try t.expectError(error.InvalidBlockPlan, Decoder.init(.{
        .allow_trailing_data = true,
        .allow_trailing_zero_padding = true,
    }, &history));
}

test "Gzip zero padding leaves single-member mode single-member" {
    var history: [32 * 1024]u8 = undefined;
    var output: [1]u8 = undefined;
    var decoder = try Decoder.init(.{ .allow_trailing_zero_padding = true }, &history);
    _ = try decoder.step(first, &output);
    try decoder.finish();
    try t.expect(decoder.snapshot().done);
    try expectMember(&decoder, first.len, 1, 0, first.len);

    decoder.reset();
    try t.expectError(error.TrailingData, decoder.step(first ++ second, &output));
}

test "Gzip zero padding preserves footer and exact-size checks" {
    var history: [32 * 1024]u8 = undefined;
    var output: [1]u8 = undefined;
    var corrupt: [first.len + padding.len]u8 = undefined;
    @memcpy(&corrupt, first ++ padding);
    corrupt[first.len - 8] ^= 1;
    var decoder = try Decoder.init(.{ .allow_trailing_zero_padding = true }, &history);
    try t.expectError(error.ChecksumMismatch, decoder.step(&corrupt, &output));

    decoder = try Decoder.init(.{
        .allow_concatenated = true,
        .allow_trailing_zero_padding = true,
        .expected_output_len = 2,
    }, &history);
    const stepped = try decoder.step(first ++ padding, &output);
    try t.expectEqual(first.len + padding.len, stepped.progress.input_read);
    try t.expectError(error.SizeMismatch, decoder.finish());
}
