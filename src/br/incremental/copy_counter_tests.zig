const std = @import("std");
const core = @import("../../core.zig");
const shared_dictionary = @import("../shared_dictionary.zig");
const progressive_bits = @import("bit_reader.zig");
const incremental = @import("copy_decoder.zig");

// Tiny symbols isolate cumulative accounting from Brotli compression choices.
// The header and literal still cross the real progressive reservoir machinery.
const CounterCodec = struct {
    pub const Error = core.Error;
    pub const max_stream_header_bytes = 32;
    pub const DecodeOptions = struct {
        allow_large_window: bool = false,
        shared_dictionary: shared_dictionary.Dictionary = .{},
    };
    pub const Header = struct { decoded_len: core.StreamCount, final: bool };
    pub const ParsedHeader = struct { header: Header, bits_read: usize };
    pub const Command = struct { insert_len: usize, copy_len: usize, implicit_last_distance: bool };

    pub fn parseMetaBlockHeader(_: []const u8, bit_len: usize, decoded_len: core.StreamCount, final: bool, _: bool) Error!ParsedHeader {
        if (bit_len < 1) return error.TruncatedFrame;
        return .{ .header = .{ .decoded_len = decoded_len, .final = final }, .bits_read = 1 };
    }

    pub fn commandState(_: *const Header) void {}
    pub fn restoreCommandState(_: *Header, _: void) void {}
    pub const literalState = commandState;
    pub const restoreLiteralState = restoreCommandState;
    pub const distanceState = commandState;
    pub const restoreDistanceState = restoreCommandState;

    pub fn readCommand(_: *Header, reader: anytype) Error!Command {
        _ = try reader.readBits(u1, 1);
        return .{ .insert_len = 1, .copy_len = 0, .implicit_last_distance = false };
    }
    pub fn readLiteral(_: *Header, reader: anytype, _: u8, _: u8) Error!u8 {
        return reader.readBits(u8, 8);
    }
    pub fn readDistance(_: *Header, reader: anytype, _: usize, _: *const [4]usize) Error!struct { distance: usize, update_ring: bool } {
        return .{ .distance = @as(usize, try reader.readBits(u2, 2)) + 1, .update_ring = false };
    }
    pub fn dictionaryContext(_: *Header, _: u8, _: u8) Error!usize {
        return 0;
    }
    pub fn maxBackwardDistance(window_bits: u5, output_len: core.StreamCount) usize {
        return core.stream_count.bounded(output_len, (@as(usize, 1) << window_bits) - 16);
    }
};

const Decoder = incremental.Decoder(CounterCodec);
const Counter = Decoder.Counter;
const boundary: Counter = @as(Counter, 1) << 32;

test "Brotli copy counters cross 4 GiB through stored output and diagnostics" {
    try std.testing.expectEqual(core.StreamCount, Counter);
    try std.testing.expectEqual(std.math.maxInt(Counter), (Decoder.Options{}).max_output_len);
    var history: [3]u8 = undefined;
    var decoder = Decoder.initWithOptions(&history, .{ .expected_output_len = boundary + 1 });
    decoder.phase = .stored;
    decoder.stored_remaining = 2;
    decoder.total_input = boundary - 1;
    decoder.total_output = boundary - 1;
    decoder.frame_count = boundary - 1;
    var output: [2]u8 = undefined;
    const stepped = try decoder.step("ab", &output);
    try std.testing.expectEqual(@as(usize, 2), stepped.progress.input_read);
    try std.testing.expectEqual(@as(usize, 2), stepped.progress.output_written);
    try std.testing.expectEqualSlices(u8, "ab", &output);
    try std.testing.expectEqual(@as(Counter, boundary + 1), decoder.snapshot().input_read);
    try std.testing.expectEqual(@as(Counter, boundary + 1), decoder.diagnostics().output_written);
    try std.testing.expectEqual(@as(usize, history.len), decoder.snapshot().history_bytes);
    const end = try decoder.step(&.{0x03}, &.{});
    try std.testing.expectEqual(.done, end.status);
    try std.testing.expectEqual(boundary, decoder.snapshot().frame_count);
    try decoder.nextFrame(.{});
    try std.testing.expectEqual(boundary, decoder.frame_count);
    try std.testing.expectEqual(boundary + 1, decoder.operation_output);
    try std.testing.expectEqual(@as(Counter, 0), decoder.snapshot().output_written);
    decoder.reset();
    try std.testing.expectEqual(@as(Counter, 0), decoder.snapshot().total_output);
}

test "Brotli copy counters use wide positions for scalar and bulk history rings" {
    inline for (.{ 3, 17, 47 }) |len| {
        var history: [5]u8 = undefined;
        var decoder = Decoder.init(&history);
        decoder.phase = .copy;
        decoder.total_output = boundary - 1;
        decoder.decoded_len = decoder.total_output + len;
        decoder.pending_copy = len;
        decoder.copy_distance = 3;
        decoder.final_meta_block = false;
        for (0..3) |i| history[core.stream_count.ringIndex(decoder.total_output - 3 + i, history.len)] = "abc"[i];
        var output: [len]u8 = undefined;
        const stepped = try decoder.step(&.{}, &output);
        try std.testing.expectEqual(@as(usize, len), stepped.progress.output_written);
        for (output, 0..) |byte, i| try std.testing.expectEqual("abc"[i % 3], byte);
        try std.testing.expectEqual(boundary - 1 + len, decoder.total_output);
        const retained: usize = @min(len, history.len);
        for (0..retained) |i| {
            const position = decoder.total_output - retained + i;
            try std.testing.expectEqual(output[len - retained + i], history[core.stream_count.ringIndex(position, history.len)]);
        }
    }
}

test "Brotli copy counters widen compressed meta-block endpoints and wrap bit phases" {
    var history: [3]u8 = undefined;
    var decoder = Decoder.initWithOptions(&history, .{ .expected_output_len = boundary });
    decoder.phase = .trailer;
    decoder.total_output = boundary - 1;
    decoder.stream_bits = std.math.maxInt(usize) - 7;
    // Last nonempty MLEN=1 block: 20 header bits, one synthetic tree bit,
    // one synthetic command bit, then a literal and two padding bits.
    const wire = [_]u8{ 0x01, 0x00, 0x40, 0x16 };
    var output: [1]u8 = undefined;
    var input_read: usize = 0;
    while (decoder.phase != .done) {
        const stepped = try decoder.step(wire[input_read..], &output);
        input_read += stepped.progress.input_read;
        try std.testing.expect(stepped.progress.input_read != 0 or stepped.progress.output_written != 0 or stepped.status == .done);
    }
    try std.testing.expectEqual(boundary, decoder.decoded_len);
    try std.testing.expectEqual(boundary, decoder.header.decoded_len);
    try std.testing.expectEqual(boundary, decoder.total_output);
    try std.testing.expectEqual(@as(usize, 22), decoder.stream_bits);
    try std.testing.expectEqual(@as(u8, 'Y'), output[0]);
}

test "Brotli copy counters metadata totals and block counts cross 4 GiB" {
    var history: [1]u8 = undefined;
    var capture: [1]u8 = undefined;
    var lengths = [_]usize{77};
    var decoder = Decoder.initWithOptions(&history, .{ .metadata_output = &capture, .metadata_block_lengths = &lengths });
    decoder.phase = .metadata;
    decoder.metadata = true;
    decoder.metadata_remaining = 2;
    decoder.metadata_total = boundary - 1;
    decoder.metadata_block_count = boundary - 1;
    const stepped = try decoder.step("ab", &.{});
    try std.testing.expectEqual(@as(usize, 2), stepped.progress.input_read);
    const snap = decoder.snapshot();
    try std.testing.expectEqual(boundary + 1, snap.metadata_total);
    try std.testing.expectEqual(boundary, snap.metadata_block_count);
    try std.testing.expectEqual(@as(usize, 1), snap.metadata_written);
    try std.testing.expectEqual(@as(usize, 1), snap.metadata_blocks_captured);
    try std.testing.expectEqual(@as(u8, 'a'), capture[0]);
    try std.testing.expectEqual(@as(usize, 77), lengths[0]);
}

test "Brotli copy counters preserve wide operation caps across nextFrame" {
    var history: [3]u8 = undefined;
    var decoder = Decoder.initWithOptions(&history, .{ .max_total_output_len = boundary + 1 });
    decoder.phase = .done;
    decoder.total_output = boundary;
    try std.testing.expectError(error.OutputLimitExceeded, decoder.nextFrame(.{ .max_total_output_len = boundary - 1 }));
    try std.testing.expectEqual(Decoder.Phase.done, decoder.phase);
    try std.testing.expectEqual(boundary, decoder.total_output);
    try decoder.nextFrame(.{});
    try std.testing.expectEqual(boundary + 1, decoder.options.max_total_output_len);
    decoder.phase = .stored;
    decoder.stored_remaining = 2;
    var output = [_]u8{0xa5} ** 2;
    try std.testing.expectError(error.OutputLimitExceeded, decoder.step("ab", &output));
    try std.testing.expectEqual(@as(usize, 1), decoder.last_step_progress.input_read);
    try std.testing.expectEqual(@as(usize, 1), decoder.last_step_progress.output_written);
    try std.testing.expectEqual(boundary + 1, decoder.error_output_offset.?);
    try std.testing.expectEqualSlices(u8, &.{ 'a', 0xa5 }, &output);
}

test "Brotli copy counters check compound dictionary spans before cursor writes" {
    const dictionary: shared_dictionary.Dictionary = .{ .raw_prefixes = &.{"abc"} };
    inline for (.{ false, true }) |overflow| {
        var history: [3]u8 = undefined;
        var decoder = Decoder.initWithOptions(&history, .{ .decode = .{ .shared_dictionary = dictionary } });
        decoder.phase = .dictionary;
        decoder.dictionary_source = .compound;
        decoder.compound_cursor = try dictionary.cursor(0, 3);
        decoder.pending_copy = 3;
        decoder.total_output = if (overflow) std.math.maxInt(Counter) else boundary - 1;
        decoder.decoded_len = if (overflow) decoder.total_output else boundary + 2;
        decoder.final_meta_block = false;
        var output = [_]u8{0xa5} ** 3;
        if (overflow) {
            try std.testing.expectError(error.IntegerOverflow, decoder.step(&.{}, &output));
            try std.testing.expectEqual(@as(usize, 3), decoder.compound_cursor.remaining());
            try std.testing.expectEqual(@as(usize, 3), decoder.pending_copy);
            try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 3), &output);
        } else {
            const first = try decoder.step(&.{}, output[0..1]);
            try std.testing.expectEqual(.need_output, first.status);
            try std.testing.expectEqual(@as(usize, 2), decoder.pending_copy);
            const rest = try decoder.step(&.{}, output[1..]);
            try std.testing.expectEqual(@as(usize, 2), rest.progress.output_written);
            try std.testing.expectEqual(boundary + 2, decoder.total_output);
            try std.testing.expectEqualSlices(u8, "abc", &output);
            try std.testing.expectEqualSlices(u8, "abc", &history);
        }
    }
}

test "Brotli copy counters reject offered input overflow before parsing" {
    inline for (.{ false, true }) |operation| {
        var history: [1]u8 = undefined;
        var decoder = Decoder.init(&history);
        if (operation) decoder.operation_input = std.math.maxInt(Counter) else decoder.total_input = std.math.maxInt(Counter);
        var output = [_]u8{0xa5};
        try std.testing.expectError(error.IntegerOverflow, decoder.step("x", &output));
        try std.testing.expectEqual(Decoder.Phase.window, decoder.phase);
        try std.testing.expectEqual(@as(usize, 0), decoder.last_step_progress.input_read);
        try std.testing.expectEqual(std.math.maxInt(Counter), decoder.error_input_offset.?);
        try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
    }
}

test "Brotli copy counters reject copy output overflow before writing or advancing" {
    inline for (.{ false, true }) |operation| {
        var history = [_]u8{'x'} ** 3;
        var decoder = Decoder.init(&history);
        decoder.phase = .copy;
        decoder.pending_copy = 17;
        decoder.copy_distance = 1;
        decoder.total_output = if (operation) 1 else std.math.maxInt(Counter);
        if (operation) decoder.operation_output = std.math.maxInt(Counter) - 1;
        var output = [_]u8{0xa5} ** 17;
        try std.testing.expectError(error.IntegerOverflow, decoder.step(&.{}, &output));
        try std.testing.expectEqual(@as(usize, 17), decoder.pending_copy);
        try std.testing.expectEqual(@as(usize, 0), decoder.last_step_progress.output_written);
        try std.testing.expectEqual(std.math.maxInt(Counter), decoder.error_output_offset.?);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 17), &output);
        try std.testing.expectEqualSlices(u8, "xxx", &history);
    }
}

test "Brotli copy counters preserve accepted prefixes before later output overflow" {
    var history: [3]u8 = undefined;
    var decoder = Decoder.init(&history);
    decoder.phase = .stored;
    decoder.stored_remaining = 2;
    decoder.total_input = boundary;
    decoder.total_output = std.math.maxInt(Counter) - 1;
    var output = [_]u8{0xa5} ** 2;
    try std.testing.expectError(error.IntegerOverflow, decoder.step("ab", &output));
    try std.testing.expectEqual(@as(usize, 1), decoder.last_step_progress.input_read);
    try std.testing.expectEqual(@as(usize, 1), decoder.last_step_progress.output_written);
    try std.testing.expectEqual(boundary + 1, decoder.total_input);
    try std.testing.expectEqual(std.math.maxInt(Counter), decoder.total_output);
    try std.testing.expectEqual(@as(u8, 'a'), output[0]);
    try std.testing.expectEqual(@as(u8, 0xa5), output[1]);
}

test "Brotli copy counters reject metadata and completed-frame overflow before commit" {
    inline for (.{ false, true }) |blocks| {
        var history: [1]u8 = undefined;
        var capture = [_]u8{0xa5};
        var lengths = [_]usize{77};
        var decoder = Decoder.initWithOptions(&history, .{ .metadata_output = &capture, .metadata_block_lengths = &lengths });
        decoder.phase = .metadata;
        decoder.metadata = true;
        decoder.metadata_remaining = 1;
        if (blocks) decoder.metadata_block_count = std.math.maxInt(Counter) else decoder.metadata_total = std.math.maxInt(Counter);
        try std.testing.expectError(error.IntegerOverflow, decoder.step("x", &.{}));
        try std.testing.expectEqual(@as(usize, 0), decoder.last_step_progress.input_read);
        try std.testing.expectEqual(@as(usize, 1), decoder.metadata_remaining);
        try std.testing.expectEqual(@as(u8, 0xa5), capture[0]);
        try std.testing.expectEqual(@as(usize, 77), lengths[0]);
    }
    var decoder = Decoder.init(&.{});
    decoder.phase = .padding;
    decoder.frame_count = std.math.maxInt(Counter);
    try std.testing.expectError(error.IntegerOverflow, decoder.step(&.{}, &.{}));
    try std.testing.expectEqual(Decoder.Phase.padding, decoder.phase);
    try std.testing.expectEqual(std.math.maxInt(Counter), decoder.snapshot().frame_count);
}

test "Brotli copy counters bit checkpoints wrap without limiting absolute bytes" {
    const input = [_]u8{ 0xa5, 0x5a };
    var input_read: usize = 0;
    var staged: u128 = 0;
    var staged_count: u8 = 0;
    var stream_bits: usize = std.math.maxInt(usize);
    var reader = progressive_bits.Reader.init(&input, &input_read, &staged, &staged_count, &stream_bits);
    const saved = reader.checkpoint();
    try std.testing.expectEqual(@as(u8, 5), try reader.readBits(u8, 3));
    try std.testing.expectEqual(@as(usize, 2), stream_bits);
    try reader.restoreKeepingInput(saved);
    try std.testing.expectEqual(std.math.maxInt(usize), stream_bits);
    try std.testing.expectEqual(@as(usize, 1), input_read);
    try std.testing.expectEqual(@as(u8, 0xa5), try reader.readBits(u8, 8));
    try std.testing.expectEqual(@as(usize, 7), stream_bits);
    const second = reader.checkpoint();
    try std.testing.expectEqual(@as(u8, 0x5a), try reader.readBits(u8, 8));
    reader.restore(second);
    try std.testing.expectEqual(@as(usize, 7), stream_bits);
    try std.testing.expectEqual(@as(usize, 1), input_read);
}
