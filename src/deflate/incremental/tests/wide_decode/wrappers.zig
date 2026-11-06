const std = @import("std");
const h = @import("helpers.zig");
const wire = @import("wire.zig");

fn wrapperTypes(comptime Decoder: type, comptime gzip: bool) !void {
    try h.localAndWideTypes(Decoder);
    inline for (if (gzip)
        .{ "member_output", "member_count", "member_offset" }
    else
        .{ "stream_output", "stream_count", "stream_offset" }) |field|
        try std.testing.expectEqual(h.Count, @FieldType(Decoder, field));
    try std.testing.expectEqual(?h.Count, @FieldType(Decoder, "member_end_offset"));
    try std.testing.expectEqual(?h.Count, @FieldType(Decoder, "last_error_input_offset"));
    try std.testing.expectEqual(?h.Count, @FieldType(Decoder, "last_error_output_offset"));
    try std.testing.expectEqual(usize, @FieldType(Decoder, "header_received"));
    try std.testing.expectEqual(usize, @FieldType(Decoder, "footer_received"));
    try std.testing.expectEqual(h.Count, @FieldType(Decoder.Snapshot, "total_input"));
    try std.testing.expectEqual(h.Count, @FieldType(Decoder.Snapshot, "total_output"));
    try std.testing.expectEqual(?h.Count, @FieldType(Decoder.Snapshot, "member_end_offset"));
    try std.testing.expectEqual(h.core.Progress, @FieldType(Decoder.Snapshot, "last_step_progress"));
}

fn provePrefix(comptime Decoder: type, comptime gzip: bool) !void {
    const capacity = 32 * 1024;
    const actual_history = try h.allocator.alloc(u8, capacity);
    defer h.allocator.free(actual_history);
    const model_history = try h.allocator.alloc(u8, capacity);
    defer h.allocator.free(model_history);
    var actual = try Decoder.init(.{}, actual_history);
    const header = if (gzip) &h.gzip_header else &h.zlib_header;
    _ = try h.step(&actual, header, &.{});
    var completed: usize = 0;
    for ([_]usize{ 1, 2, 17, capacity + 19 }) |n| {
        while (completed < n) : (completed += 1) {
            var output: [1]u8 = undefined;
            const result = try h.step(&actual, &h.prefix, &output);
            try std.testing.expectEqual(h.prefix.len, result.progress.input_read);
            try std.testing.expectEqualSlices(u8, "x", &output);
        }
        var model = try Decoder.init(.{}, model_history);
        try h.liftWrapper(&model, gzip, @intCast(n));
        try h.expectSameRaw(&actual.raw, &model.raw);
        try std.testing.expectEqual(actual.phase, model.phase);
        try std.testing.expectEqual(actual.total_input, model.total_input);
        try std.testing.expectEqual(actual.total_output, model.total_output);
        if (gzip) {
            try std.testing.expectEqual(actual.member_output, model.member_output);
            try std.testing.expectEqual(actual.crc.digest(), model.crc.digest());
        } else {
            try std.testing.expectEqual(actual.stream_output, model.stream_output);
            try std.testing.expectEqual(actual.adler.digest(), model.adler.digest());
        }
    }
}

fn wrappedSuffix(comptime gzip: bool, blocks: h.Count, suffix: []const u8, output: []const u8) ![]u8 {
    const footer = h.footer(gzip, blocks, output);
    return std.mem.concat(h.allocator, u8, &.{ suffix, &footer });
}

fn crossing(comptime Decoder: type, comptime gzip: bool, suffix: []const u8, output: []const u8, semantic_workspace: bool) !void {
    const history = try h.allocator.alloc(u8, if (semantic_workspace) 64 * 1024 else 32 * 1024);
    defer h.allocator.free(history);
    const blocks = h.boundary - 1;
    var decoder = try Decoder.init(.{ .expected_output_len = blocks + output.len }, history);
    const Raw = @TypeOf(decoder.raw);
    var workspace: ?*Raw.SemanticWorkspace = null;
    defer if (workspace) |storage| h.allocator.destroy(storage);
    if (semantic_workspace) {
        workspace = try h.allocator.create(Raw.SemanticWorkspace);
        try decoder.raw.attachSemanticWorkspace(workspace.?);
    }
    try h.liftWrapper(&decoder, gzip, blocks);
    const payload = try wrappedSuffix(gzip, blocks, suffix, output);
    defer h.allocator.free(payload);
    try h.drain(&decoder, payload, output, if (semantic_workspace) payload.len else 1, if (semantic_workspace) output.len else 3);
    try decoder.finish();
    const expected_input = blocks * 6 + (if (gzip) @as(h.Count, 10) else 2) + payload.len;
    try std.testing.expectEqual(expected_input, decoder.total_input);
    try std.testing.expectEqual(blocks + output.len, decoder.total_output);
    try std.testing.expectEqual(@as(?h.Count, expected_input), decoder.memberEndOffset());
    const snapshot = decoder.snapshot();
    try std.testing.expectEqual(expected_input, snapshot.total_input);
    try std.testing.expectEqual(blocks + output.len, snapshot.total_output);
    try std.testing.expectEqual(@as(?h.Count, expected_input), snapshot.member_end_offset);
    const diagnostic = decoder.diagnostics();
    try std.testing.expectEqual(expected_input, diagnostic.frame_input_read);
    try std.testing.expectEqual(blocks + output.len, diagnostic.output_written);
    try std.testing.expectEqual(@as(?h.Count, blocks + output.len), diagnostic.expected_output_len);
    try std.testing.expectEqual(@as(?h.core.Progress, decoder.last_step_progress), diagnostic.last_step_progress);
    if (gzip) {
        try std.testing.expectEqual(blocks + output.len, snapshot.member_output);
        try std.testing.expectEqual(expected_input, snapshot.member_input);
    } else {
        try std.testing.expectEqual(blocks + output.len, snapshot.stream_output);
        try std.testing.expectEqual(expected_input, snapshot.stream_input);
    }
    if (semantic_workspace) try std.testing.expect(decoder.raw.semanticBlocksStarted() != 0);
    const history_storage = decoder.raw.history.ptr;
    const attachment = decoder.raw.semantic_decoder;
    decoder.reset();
    try std.testing.expectEqual(@as(h.Count, 0), decoder.snapshot().total_input);
    try std.testing.expectEqual(@as(h.Count, 0), decoder.snapshot().total_output);
    try std.testing.expectEqual(@as(?h.Count, null), decoder.memberEndOffset());
    try std.testing.expectEqual(history_storage, decoder.raw.history.ptr);
    try std.testing.expectEqual(attachment, decoder.raw.semantic_decoder);
}

fn concatAndTail(comptime Decoder: type, comptime gzip: bool) !void {
    const history = try h.allocator.alloc(u8, 32 * 1024);
    defer h.allocator.free(history);
    const blocks = h.boundary - 1;
    var decoder = try Decoder.init(.{
        .allow_concatenated = true,
        .allow_trailing_data = true,
        .expected_output_len = blocks + 4,
    }, history);
    try h.liftWrapper(&decoder, gzip, blocks);
    const first = try wrappedSuffix(gzip, blocks, &h.final_stored, "xx");
    defer h.allocator.free(first);
    try h.drain(&decoder, first, "xx", 1, 1);
    const first_end = decoder.total_input;
    const header = if (gzip) &h.gzip_header else &h.zlib_header;
    const second_footer = h.footer(gzip, 0, "xx");
    const second = try std.mem.concat(h.allocator, u8, &.{ header, &h.final_stored, &second_footer });
    defer h.allocator.free(second);
    try h.drain(&decoder, second, "xx", 1, 1);
    const end = first_end + second.len;
    try std.testing.expectEqual(end, decoder.total_input);
    try std.testing.expectEqual(blocks + 4, decoder.total_output);
    try std.testing.expectEqual(@as(?h.Count, end), decoder.memberEndOffset());
    if (gzip) {
        try std.testing.expectEqual(@as(h.Count, 2), decoder.member_count);
        try std.testing.expectEqual(first_end, decoder.snapshot().member_offset);
        try std.testing.expectEqual(@as(h.Count, second.len), decoder.snapshot().member_input);
    } else {
        try std.testing.expectEqual(@as(h.Count, 2), decoder.stream_count);
        try std.testing.expectEqual(first_end, decoder.snapshot().stream_offset);
        try std.testing.expectEqual(@as(h.Count, second.len), decoder.snapshot().stream_input);
    }
    // A split candidate accepts one byte. A rejecting continuation consumes
    // zero bytes, and memberEndOffset excludes the earlier accepted candidate.
    const candidate = [_]u8{if (gzip) 0x1f else 0x78};
    const accepted = try h.step(&decoder, &candidate, &.{});
    try std.testing.expectEqual(@as(usize, 1), accepted.progress.input_read);
    try std.testing.expectEqual(.need_input, accepted.status);
    try std.testing.expectEqual(end + 1, decoder.total_input);
    try std.testing.expectEqual(@as(?h.Count, end), decoder.memberEndOffset());
    const rejected = try h.step(&decoder, "!", &.{});
    try std.testing.expectEqual(.done, rejected.status);
    try std.testing.expectEqual(@as(usize, 0), rejected.progress.input_read);
    try std.testing.expectEqualSlices(u8, &candidate, decoder.trailingPrefix());
    try std.testing.expectEqual(end + 1, decoder.snapshot().total_input);
    try std.testing.expectEqual(@as(?h.Count, end), decoder.snapshot().member_end_offset);
    try decoder.finish();
}

fn zeroOutput(comptime Decoder: type, comptime gzip: bool) !void {
    const history = try h.allocator.alloc(u8, 32 * 1024);
    defer h.allocator.free(history);
    var decoder = try Decoder.init(.{ .expected_output_len = h.boundary }, history);
    try h.liftWrapper(&decoder, gzip, h.boundary);
    const empty = try wire.fixedEmpty();
    defer h.allocator.free(empty);
    const suffix = try wrappedSuffix(gzip, h.boundary, empty, "");
    defer h.allocator.free(suffix);
    const result = try h.step(&decoder, suffix, &.{});
    try std.testing.expectEqual(.done, result.status);
    try std.testing.expectEqual(suffix.len, result.progress.input_read);
    try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
    try decoder.finish();
    try std.testing.expectEqual(h.boundary, decoder.total_output);
}

fn dictionary(comptime Decoder: type) !void {
    const history = try h.allocator.alloc(u8, 32 * 1024);
    defer h.allocator.free(history);
    const dictionary_bytes = "borrowed dictionary seed";
    var decoder = try Decoder.initWithDictionary(.{ .expected_output_len = h.boundary + 2 }, history, dictionary_bytes);
    var dict_header = [_]u8{ 0x78, 0x20, 0, 0, 0, 0 };
    std.mem.writeInt(u32, dict_header[2..6], h.checksum.Adler32.hash(dictionary_bytes), .big);
    const accepted = try h.step(&decoder, &dict_header, &.{});
    try std.testing.expectEqual(dict_header.len, accepted.progress.input_read);
    try std.testing.expectEqual(@as(?u32, null), decoder.requiredDictionaryId());
    var first_output: [1]u8 = undefined;
    const first = try h.step(&decoder, &h.prefix, &first_output);
    try std.testing.expectEqual(h.prefix.len, first.progress.input_read);
    try std.testing.expectEqualSlices(u8, "x", &first_output);
    try std.testing.expect(decoder.atBlockBoundary());
    h.applyRaw(&decoder.raw, h.boundary - 1);
    decoder.total_input = (h.boundary - 1) * 6 + dict_header.len;
    decoder.total_output = h.boundary - 1;
    decoder.stream_output = h.boundary - 1;
    const digest = h.repeatedAdler(h.boundary - 1);
    decoder.adler = .{ .a = digest & 0xffff, .b = digest >> 16 };
    const fixed = try wire.fixedMatch();
    defer h.allocator.free(fixed);
    const suffix = try wrappedSuffix(false, h.boundary - 1, fixed, "xxx");
    defer h.allocator.free(suffix);
    try h.drain(&decoder, suffix, "xxx", 1, 1);
    try decoder.finish();
    try std.testing.expectEqual(h.boundary + 2, decoder.total_output);
    decoder.reset();
    try std.testing.expectEqualSlices(u8, dictionary_bytes, decoder.dictionary);
    try std.testing.expectEqual(@as(h.Count, 0), decoder.total_output);
}

fn applyClosedMembers(decoder: anytype, comptime gzip: bool, members: h.Count, member_len: usize) void {
    // Complete identical empty members reset raw history and checksum state.
    // Keep the physically decoded final member and summarize earlier members.
    decoder.total_input = members * member_len;
    decoder.member_end_offset = decoder.total_input;
    if (gzip) {
        decoder.member_count = members;
        decoder.member_offset = (members - 1) * member_len;
    } else {
        decoder.stream_count = members;
        decoder.stream_offset = (members - 1) * member_len;
    }
}

fn memberCountCrossing(comptime Decoder: type, comptime gzip: bool) !void {
    const history = try h.allocator.alloc(u8, 32 * 1024);
    defer h.allocator.free(history);
    const model_history = try h.allocator.alloc(u8, 32 * 1024);
    defer h.allocator.free(model_history);
    const header = if (gzip) &h.gzip_header else &h.zlib_header;
    const empty_footer = h.footer(gzip, 0, "");
    const empty_member = try std.mem.concat(h.allocator, u8, &.{ header, &h.empty_final_stored, &empty_footer });
    defer h.allocator.free(empty_member);
    var actual = try Decoder.init(.{ .allow_concatenated = true }, history);
    var completed: usize = 0;
    var scratch: [1]u8 = undefined;
    for ([_]usize{ 1, 2, 17 }) |members| {
        while (completed < members) : (completed += 1) {
            const result = try h.step(&actual, empty_member, &scratch);
            try std.testing.expectEqual(empty_member.len, result.progress.input_read);
            try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
        }
        var model = try Decoder.init(.{ .allow_concatenated = true }, model_history);
        _ = try h.step(&model, empty_member, &scratch);
        applyClosedMembers(&model, gzip, @intCast(members), empty_member.len);
        try std.testing.expectEqual(actual.total_input, model.total_input);
        try std.testing.expectEqual(actual.total_output, model.total_output);
        try std.testing.expectEqual(actual.phase, model.phase);
        try std.testing.expectEqual(actual.memberEndOffset(), model.memberEndOffset());
        try h.expectSameRaw(&actual.raw, &model.raw);
        if (gzip) {
            try std.testing.expectEqual(actual.member_count, model.member_count);
            try std.testing.expectEqual(actual.member_offset, model.member_offset);
            try std.testing.expectEqual(actual.member_output, model.member_output);
            try std.testing.expectEqual(actual.crc.digest(), model.crc.digest());
        } else {
            try std.testing.expectEqual(actual.stream_count, model.stream_count);
            try std.testing.expectEqual(actual.stream_offset, model.stream_offset);
            try std.testing.expectEqual(actual.stream_output, model.stream_output);
            try std.testing.expectEqual(actual.adler.digest(), model.adler.digest());
        }
    }
    var decoder = try Decoder.init(.{ .allow_concatenated = true, .expected_output_len = 2 }, model_history);
    _ = try h.step(&decoder, empty_member, &scratch);
    const members = h.boundary - 1;
    applyClosedMembers(&decoder, gzip, members, empty_member.len);
    const start = decoder.total_input;
    const next_footer = h.footer(gzip, 0, "xx");
    const next = try std.mem.concat(h.allocator, u8, &.{ header, &h.final_stored, &next_footer });
    defer h.allocator.free(next);
    try h.drain(&decoder, next, "xx", 1, 1);
    try decoder.finish();
    try std.testing.expectEqual(start + next.len, decoder.total_input);
    try std.testing.expectEqual(@as(h.Count, 2), decoder.total_output);
    try std.testing.expectEqual(@as(?h.Count, start + next.len), decoder.memberEndOffset());
    if (gzip) {
        try std.testing.expectEqual(h.boundary, decoder.snapshot().member_count);
        try std.testing.expectEqual(start, decoder.snapshot().member_offset);
        try std.testing.expectEqual(members, decoder.snapshot().member_index);
    } else {
        try std.testing.expectEqual(h.boundary, decoder.snapshot().stream_count);
        try std.testing.expectEqual(start, decoder.snapshot().stream_offset);
        try std.testing.expectEqual(members, decoder.snapshot().stream_index);
    }
}

pub fn contracts(comptime D: type) !void {
    const fixed = try wire.fixedMatch();
    defer h.allocator.free(fixed);
    const dynamic = try wire.dynamicMatch(false);
    defer h.allocator.free(dynamic);
    const output = try h.allocator.alloc(u8, wire.dynamic_output_len);
    defer h.allocator.free(output);
    @memset(output, 'x');
    inline for (.{ false, true }) |gzip| {
        const Decoder = if (gzip) D.GzipIncrementalDecoder else D.ZlibIncrementalDecoder;
        try wrapperTypes(Decoder, gzip);
        try provePrefix(Decoder, gzip);
        try crossing(Decoder, gzip, &h.final_stored, "xx", false);
        try crossing(Decoder, gzip, fixed, "xxx", false);
        try crossing(Decoder, gzip, dynamic, output, false);
        try crossing(Decoder, gzip, dynamic, output, true);
        try concatAndTail(Decoder, gzip);
        try memberCountCrossing(Decoder, gzip);
        try zeroOutput(Decoder, gzip);
    }
    try dictionary(D.ZlibIncrementalDecoder);
}
