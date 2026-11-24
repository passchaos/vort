//! Byte-aligned bodies can begin with whole bytes a Huffman lookup accepted
//! earlier. The caller must never be asked to re-offer those bytes.
const std = @import("std");
const core = @import("../../core.zig");
const t = std.testing;
const Count = core.StreamCount;

pub fn contracts(comptime B: type) !void {
    const Decoder = B.IncrementalCopyStreamDecoder;
    try emptyMetadata(Decoder);
    try stored(Decoder);
    try metadata(Decoder);
    try badPadding(Decoder);
}

fn emptyMetadata(comptime Decoder: type) !void {
    var decoder = Decoder.init(&.{});
    decoder.phase = .trailer;
    decoder.total_input = 2;
    // Six bits of an empty nonfinal metadata marker, followed by the whole
    // final-empty byte already staged by a literal Huffman lookup.
    decoder.stream_bits = 2;
    decoder.staged_bits = 0b000110 | (@as(u128, 0x03) << 6);
    decoder.staged_bit_count = 14;
    const step = try decoder.step("", &.{});
    try t.expectEqual(.done, step.status);
    try t.expectEqualDeep(core.Progress{}, step.progress);
    try t.expectEqual(@as(Count, 2), decoder.snapshot().input_read);
    try t.expectEqual(@as(Count, 1), decoder.snapshot().metadata_block_count);
    try decoder.finish();
}

fn badPadding(comptime Decoder: type) !void {
    var decoder = Decoder.init(&.{});
    decoder.phase = .trailer;
    decoder.next_header_state = .alignment;
    decoder.metadata = true;
    decoder.stream_bits = 7;
    decoder.staged_bit_count = 9;
    decoder.staged_bits = 1 | (@as(u128, 0x03) << 1);
    try t.expectError(error.CorruptFrame, decoder.step("", &.{}));
    try t.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
    try t.expectEqual(@as(Count, 0), decoder.snapshot().metadata_block_count);
}

fn stored(comptime Decoder: type) !void {
    var history: [3]u8 = undefined;
    var decoder = Decoder.initWithOptions(&history, .{ .expected_output_len = 3 });
    decoder.phase = .trailer;
    decoder.next_header_state = .alignment;
    decoder.final_meta_block = false;
    decoder.stored_remaining = 3;
    decoder.stream_bits = 21;
    decoder.staged_bits = (@as(u128, 'a') << 3) | (@as(u128, 'b') << 11);
    decoder.staged_bit_count = 19;
    decoder.total_input = 5; // Three header bytes and two already offered body bytes.

    const held = try decoder.step("c\x03", &.{});
    try t.expectEqual(.need_output, held.status);
    try t.expectEqualDeep(core.Progress{}, held.progress);

    var output: [3]u8 = undefined;
    const first = try decoder.step("", output[0..1]);
    try t.expectEqual(.need_output, first.status);
    try t.expectEqualDeep(core.Progress{ .output_written = 1 }, first.progress);
    const last = try decoder.step("c\x03", output[1..]);
    try t.expectEqual(.done, last.status);
    try t.expectEqualDeep(core.Progress{ .input_read = 2, .output_written = 2 }, last.progress);
    try t.expectEqualStrings("abc", &output);
    try t.expectEqualStrings("abc", &history);
    try t.expectEqual(@as(Count, 7), decoder.snapshot().input_read);
    try decoder.finish();
}

fn metadata(comptime Decoder: type) !void {
    const Collector = struct {
        seen_start: bool = false,
        chunks: usize = 0,
        len: usize = 0,
        bytes: [3]u8 = undefined,
        bad: bool = false,

        fn observe(context: ?*anyopaque, event: Decoder.MetadataEvent) void {
            const self: *@This() = @ptrCast(@alignCast(context.?));
            switch (event) {
                .start => |block| {
                    self.bad = self.bad or self.seen_start or block.final or block.block_index != 0 or block.len != self.bytes.len;
                    self.seen_start = true;
                },
                .chunk => |chunk| {
                    if (!self.seen_start or chunk.block_index != 0 or chunk.offset != self.len or
                        chunk.bytes.len > self.bytes.len - self.len)
                    {
                        self.bad = true;
                        return;
                    }
                    @memcpy(self.bytes[self.len..][0..chunk.bytes.len], chunk.bytes);
                    self.len += chunk.bytes.len;
                    self.chunks += 1;
                },
            }
        }
    };
    var observed: Collector = .{};
    var capture: [3]u8 = @splat(0xa5);
    var lengths: [1]usize = @splat(99);
    var decoder = Decoder.initWithOptions(&.{}, .{
        .metadata_observer = .{ .context = &observed, .on_event = Collector.observe },
        .metadata_output = &capture,
        .metadata_block_lengths = &lengths,
        .max_metadata_bytes = 3,
        .max_metadata_blocks = 1,
    });
    decoder.phase = .trailer;
    decoder.next_header_state = .alignment;
    decoder.final_meta_block = false;
    decoder.metadata = true;
    decoder.metadata_remaining = 3;
    decoder.stream_bits = 21;
    decoder.staged_bits = (@as(u128, 'a') << 3) | (@as(u128, 'b') << 11);
    decoder.staged_bit_count = 19;
    decoder.total_input = 5;

    const first = try decoder.step("", &.{});
    try t.expectEqual(.need_input, first.status);
    try t.expectEqualDeep(core.Progress{}, first.progress);
    try t.expectEqualStrings("ab", capture[0..2]);
    try t.expectEqual(@as(usize, 99), lengths[0]);
    const last = try decoder.step("c\x03", &.{});
    try t.expectEqual(.done, last.status);
    try t.expectEqualDeep(core.Progress{ .input_read = 2 }, last.progress);
    try t.expectEqualStrings("abc", &capture);
    try t.expectEqual(@as(usize, 3), lengths[0]);
    try t.expectEqual(@as(Count, 7), decoder.snapshot().input_read);
    try t.expectEqual(@as(Count, 3), decoder.snapshot().metadata_total);
    try t.expect(observed.seen_start and !observed.bad);
    try t.expectEqual(@as(usize, 2), observed.chunks);
    try t.expectEqualStrings("abc", observed.bytes[0..observed.len]);
    try decoder.finish();
}
