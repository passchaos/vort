const std = @import("std");
const core = @import("../../core.zig");
const eql = std.testing.expectEqual;
const bytesEqual = std.testing.expectEqualSlices;

const Flavor = enum { owned, copy, literal, stored };

pub fn contracts(comptime Br: type) !void {
    try switching(Br.IncrementalStreamDecoder, .owned);
    try switching(Br.IncrementalCopyStreamDecoder, .copy);
    try switching(Br.IncrementalLiteralStreamDecoder, .literal);
    try switching(Br.IncrementalStoredStreamDecoder, .stored);
}

fn switching(comptime Decoder: type, comptime flavor: Flavor) !void {
    // The upstream [1, 11, 0, 42, 3] fixture is a one-byte metadata
    // block followed by an empty last block. Here we insert a second
    // nonfinal metadata block ("abcd") and end with empty final metadata.
    // The literal decoder needs a compressed first block: this prefix is
    // a 105-bit insert-only "hello" block followed by the partial header.
    const prefix = if (flavor == .literal) "\x40\x00\x00\x00\x34\x5a\x19\xdb\x9b\x40\x21\x00\xa9\x2d" else "\x01\x0b";
    const second_header = "\xd6\x00";
    const last_header = "\x0d";
    const plain = if (flavor == .literal) "hello" else "";
    const Log = Recorder(Decoder);
    const start_0 = Log.start(0, 1, false);
    const start_1 = Log.start(1, 4, false);
    const start_2 = Log.start(2, 0, true);
    const first = Log.chunk(0, 0, "*");
    const chunks = .{ Log.chunk(1, 0, "a"), Log.chunk(1, 1, "b"), Log.chunk(1, 2, "c"), Log.chunk(1, 3, "d") };
    var a: Log = .{ .expected = &.{ start_0, chunks[1] } };
    var b: Log = .{ .expected = &.{ first, start_1, chunks[0], chunks[3], start_2 } };
    var captured: [5]u8 = @splat(0xa5);
    var lengths: [3]usize = @splat(0xaaaa);
    var options: Decoder.Options = .{
        .metadata_output = &captured,
        .metadata_block_lengths = &lengths,
        .max_metadata_bytes = captured.len,
        .max_metadata_blocks = lengths.len,
        .max_output_len = plain.len,
    };
    if (flavor != .stored) options.expected_output_len = plain.len;
    var history: [plain.len]u8 = undefined;
    var decoder = switch (flavor) {
        .owned => Decoder.initWithOptions(std.testing.allocator, options),
        .copy => Decoder.initWithOptions(&history, options),
        .literal, .stored => Decoder.initWithOptions(options),
    };
    defer if (flavor == .owned) decoder.deinit();

    var output: [plain.len]u8 = undefined;
    try retarget(&decoder, b.observer());
    try step(&decoder, prefix, &output, .need_input);
    try bytesEqual(u8, plain, &output);
    try b.seen(0);
    try retarget(&decoder, a.observer()); // Header is still incomplete.
    try step(&decoder, "", &.{}, .need_input);
    try a.seen(0);
    try step(&decoder, "\x00", &.{}, .need_input);
    try a.seen(1);

    try retarget(&decoder, b.observer()); // Start must not replay to B.
    try step(&decoder, "*" ++ second_header ++ "a", &.{}, .need_input);
    try b.seen(3);
    try retarget(&decoder, a.observer());
    try step(&decoder, "b", &.{}, .need_input);
    try a.seen(2);
    try retarget(&decoder, null);
    try step(&decoder, "c", &.{}, .need_input);
    try metadataCounts(flavor, &decoder, 4, 1);
    try bytesEqual(u8, &.{ '*', 'a', 'b', 'c', 0xa5 }, &captured);
    try bytesEqual(usize, &.{ 1, 0xaaaa, 0xaaaa }, &lengths);

    try retarget(&decoder, b.observer());
    try step(&decoder, "", &.{}, .need_input);
    try b.seen(3); // Neither a start nor a skipped chunk was replayed.
    try step(&decoder, "d" ++ last_header, &.{}, .done);
    try decoder.finish();
    try a.seen(2);
    try b.seen(5);
    try metadataCounts(flavor, &decoder, 5, 3);
    try bytesEqual(u8, "*abcd", &captured);
    try bytesEqual(usize, &.{ 1, 4, 0 }, &lengths);

    // Reset must retain B, the latest observer, not the init option (null).
    decoder.reset();
    try b.seen(5);
    b = .{ .expected = &.{ start_0, first, start_1, chunks[0], chunks[1], chunks[2], chunks[3], start_2 } };
    try step(&decoder, prefix ++ "\x00*" ++ second_header, &output, .need_input);
    try bytesEqual(u8, plain, &output);
    for ("abcd") |byte| try step(&decoder, &.{byte}, &.{}, .need_input);
    try step(&decoder, last_header, &.{}, .done);
    try decoder.finish();
    try b.seen(8);
    try a.seen(2);
    try metadataCounts(flavor, &decoder, 5, 3);

    if (flavor != .literal) {
        var next: Log = .{ .expected = &.{ start_0, first } };
        options.metadata_observer = next.observer();
        if (flavor == .stored) try decoder.nextStream(options) else try decoder.nextFrame(options);
        try step(&decoder, "\x01\x0b\x00*\x03", &.{}, .done);
        try decoder.finish();
        try next.seen(2);
        try b.seen(8);
        try metadataCounts(flavor, &decoder, 1, 1);
    }
}

fn retarget(decoder: anytype, observer: anytype) !void {
    const before = decoder.snapshot();
    const diagnostics = decoder.diagnostics();
    decoder.setMetadataObserver(observer);
    try std.testing.expectEqualDeep(before, decoder.snapshot());
    try std.testing.expectEqualDeep(diagnostics, decoder.diagnostics());
}

fn step(decoder: anytype, input: []const u8, output: []u8, status: core.StepResult.Status) !void {
    try eql(core.StepResult{
        .status = status,
        .progress = .{ .input_read = input.len, .output_written = output.len },
    }, try decoder.step(input, output));
}

fn metadataCounts(comptime flavor: Flavor, decoder: anytype, bytes: usize, blocks: usize) !void {
    const snap = if (flavor == .owned) decoder.progressive.?.snapshot() else decoder.snapshot();
    try eql(@as(core.StreamCount, bytes), snap.metadata_total);
    try eql(@as(core.StreamCount, blocks), snap.metadata_block_count);
    try eql(bytes, snap.metadata_written);
    try eql(blocks, snap.metadata_blocks_captured);
}

fn Recorder(comptime Decoder: type) type {
    return struct {
        const Self = @This();
        const Event = Decoder.MetadataEvent;

        expected: []const Event,
        count: usize = 0,
        failure: ?anyerror = null,

        fn start(index: core.StreamCount, len: usize, final: bool) Event {
            return .{ .start = .{ .block_index = index, .len = len, .final = final } };
        }
        fn chunk(index: core.StreamCount, offset: usize, bytes: []const u8) Event {
            return .{ .chunk = .{ .block_index = index, .offset = offset, .bytes = bytes } };
        }
        fn observer(self: *Self) Decoder.MetadataObserver {
            return .{ .context = self, .on_event = onEvent };
        }
        fn onEvent(context: ?*anyopaque, event: Event) void {
            const self: *Self = @ptrCast(@alignCast(context.?));
            if (self.failure != null) return;
            if (self.count == self.expected.len) {
                self.failure = error.TestUnexpectedResult;
                return;
            }
            // Compare the borrowed chunk bytes in the callback; never retain them.
            std.testing.expectEqualDeep(self.expected[self.count], event) catch |err| {
                self.failure = err;
            };
            self.count += 1;
        }
        fn seen(self: *const Self, count: usize) !void {
            if (self.failure) |err| return err;
            try eql(count, self.count);
        }
    };
}
