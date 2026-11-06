const std = @import("std");

pub const prefix = "alpha beta gamma alpha beta gamma\n" ** 5;
pub const left = "left branch preserves the shared prefix\n" ** 3;
pub const right = "right branch has independent history and checksum\n" ** 4;

pub fn rawOf(stream: anytype) if (@hasField(@TypeOf(stream.*), "raw")) @TypeOf(&stream.raw) else @TypeOf(stream) {
    return if (@hasField(@TypeOf(stream.*), "raw")) &stream.raw else stream;
}

pub fn feed(allocator: std.mem.Allocator, encoder: anytype, input: []const u8, wire: *std.ArrayList(u8), output_chunk: usize) !void {
    var scratch: [4096]u8 = undefined;
    var read: usize = 0;
    while (read < input.len) {
        const result = try encoder.step(input[read..@min(input.len, read + 17)], scratch[0..output_chunk]);
        read += result.progress.input_read;
        try wire.appendSlice(allocator, scratch[0..result.progress.output_written]);
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
}

pub fn drain(allocator: std.mem.Allocator, encoder: anytype, wire: *std.ArrayList(u8), output_chunk: usize, finishing: bool) !void {
    var scratch: [4096]u8 = undefined;
    while (true) {
        const result = try encoder.step("", scratch[0..output_chunk]);
        try wire.appendSlice(allocator, scratch[0..result.progress.output_written]);
        const end_status: @TypeOf(result.status) = if (finishing) .done else .need_input;
        if (result.status == end_status) return;
        try std.testing.expectEqual(.need_output, result.status);
        try std.testing.expect(result.progress.output_written != 0);
    }
}

pub fn finish(allocator: std.mem.Allocator, encoder: anytype, wire: *std.ArrayList(u8), output_chunk: usize) !void {
    encoder.finish();
    try drain(allocator, encoder, wire, output_chunk, true);
}

pub fn expectList(source: anytype, copy: @TypeOf(source), independent: bool) !void {
    try std.testing.expectEqual(source.capacity, copy.capacity);
    try std.testing.expectEqualDeep(source.items, copy.items);
    if (independent and source.capacity != 0)
        try std.testing.expect(source.items.ptr != copy.items.ptr);
}

/// Compare meaningful contents rather than padding or unused capacity bytes.
pub fn expectEncoder(source: anytype, copy: @TypeOf(source), independent: bool) !void {
    try std.testing.expectEqualDeep(source.snapshot(), copy.snapshot());
    try std.testing.expectEqualDeep(source.options, copy.options);
    try expectList(source.pending, copy.pending, independent);
    try std.testing.expectEqual(source.pending_offset, copy.pending_offset);
    const raw_source = rawOf(source);
    const raw_copy = rawOf(copy);
    try std.testing.expectEqualDeep(raw_source.snapshot(), raw_copy.snapshot());
    try std.testing.expectEqual(raw_source.expected_input_len, raw_copy.expected_input_len);
    try std.testing.expectEqual(raw_source.state.scratch, raw_copy.state.scratch);
    try std.testing.expectEqual(raw_source.state.bit_index, raw_copy.state.bit_index);
    try expectList(raw_source.state.bytes, raw_copy.state.bytes, independent);
    try expectList(raw_source.plain, raw_copy.plain, independent);
    if (@hasField(@TypeOf(source.*), "raw"))
        try expectList(raw_source.pending, raw_copy.pending, independent);
    if (@hasField(@TypeOf(raw_source.*), "match_finder")) {
        try expectList(raw_source.history, raw_copy.history, independent);
        try expectList(raw_source.plan_tokens, raw_copy.plan_tokens, independent);
        try std.testing.expectEqualDeep(raw_source.matchFinderSnapshot(), raw_copy.matchFinderSnapshot());
        try expectList(raw_source.match_finder.head, raw_copy.match_finder.head, independent);
        try expectList(raw_source.match_finder.head_epoch, raw_copy.match_finder.head_epoch, independent);
        try expectList(raw_source.match_finder.prev, raw_copy.match_finder.prev, independent);
        try std.testing.expectEqualDeep(raw_source.match_finder.dynamic_stats, raw_copy.match_finder.dynamic_stats);
        try std.testing.expectEqual(raw_source.window_limit, raw_copy.window_limit);
        try std.testing.expectEqual(raw_source.retained_window_limit, raw_copy.retained_window_limit);
        try std.testing.expectEqual(raw_source.dictionary.ptr, raw_copy.dictionary.ptr);
    }
    if (@hasField(@TypeOf(source.*), "adler"))
        try std.testing.expectEqualDeep(source.adler, copy.adler);
    if (@hasField(@TypeOf(source.*), "crc"))
        try std.testing.expectEqualDeep(source.crc, copy.crc);
}
