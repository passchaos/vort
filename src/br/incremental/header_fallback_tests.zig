const std = @import("std");
const core = @import("../../core.zig");
const dictionary = @import("../shared_dictionary.zig");
const incremental = @import("copy_decoder.zig");
const bitstream = @import("../../bitstream.zig");

fn FixtureCodec(comptime consumed_bits: usize) type {
    return struct {
        pub const Error = core.Error;
        pub const max_stream_header_bytes = 32;
        pub const DecodeOptions = struct { allow_large_window: bool = false, shared_dictionary: dictionary.Dictionary = .{} };
        pub const Header = struct { decoded_len: core.StreamCount, final: bool };
        pub const ParsedHeader = struct { header: Header, bits_read: usize };
        pub const Command = struct { insert_len: usize, copy_len: usize, implicit_last_distance: bool };
        pub fn parseMetaBlockHeader(_: []const u8, _: usize, _: core.StreamCount, _: bool, _: bool) Error!ParsedHeader {
            return .{ .header = .{ .decoded_len = 77, .final = false }, .bits_read = consumed_bits };
        }
        pub fn commandState(_: *const Header) void {}
        pub fn restoreCommandState(_: *Header, _: void) void {}
        pub const literalState = commandState;
        pub const restoreLiteralState = restoreCommandState;
        pub const distanceState = commandState;
        pub const restoreDistanceState = restoreCommandState;
        pub fn readCommand(_: *Header, _: anytype) Error!Command {
            return .{ .insert_len = 0, .copy_len = 0, .implicit_last_distance = false };
        }
        pub fn readLiteral(_: *Header, _: anytype, _: u8, _: u8) Error!u8 {
            return 0;
        }
        pub fn readDistance(_: *Header, _: anytype, _: usize, _: *const [4]usize) Error!struct { distance: usize, update_ring: bool } {
            return .{ .distance = 1, .update_ring = false };
        }
        pub fn dictionaryContext(_: *Header, _: u8, _: u8) Error!usize {
            return 0;
        }
        pub fn maxBackwardDistance(_: u5, _: core.StreamCount) usize {
            return 1;
        }
    };
}

const ValidCodec = struct {
    const Fixture = FixtureCodec(1);
    pub const Error = Fixture.Error;
    pub const max_stream_header_bytes = Fixture.max_stream_header_bytes;
    pub const DecodeOptions = Fixture.DecodeOptions;
    pub const Header = Fixture.Header;
    pub const ParsedHeader = Fixture.ParsedHeader;
    pub const Command = Fixture.Command;
    pub const commandState = Fixture.commandState;
    pub const restoreCommandState = Fixture.restoreCommandState;
    pub const literalState = Fixture.literalState;
    pub const restoreLiteralState = Fixture.restoreLiteralState;
    pub const distanceState = Fixture.distanceState;
    pub const restoreDistanceState = Fixture.restoreDistanceState;
    pub const readCommand = Fixture.readCommand;
    pub const readLiteral = Fixture.readLiteral;
    pub const readDistance = Fixture.readDistance;
    pub const dictionaryContext = Fixture.dictionaryContext;
    pub const maxBackwardDistance = Fixture.maxBackwardDistance;

    pub fn parseMetaBlockHeader(input: []const u8, bit_len: usize, decoded_len: core.StreamCount, final: bool, _: bool) Error!ParsedHeader {
        var reader = bitstream.BitReader.initBitLength(input, bit_len);
        if (try reader.readBits(u1, 1) != 0) return error.CorruptFrame;
        return .{ .header = .{ .decoded_len = decoded_len, .final = final }, .bits_read = 1 };
    }
};

test "Brotli returned header fallback accepts wide offers and preserves caller trailing bytes" {
    const Decoder = incremental.Decoder(ValidCodec);
    try std.testing.expect(!@hasDecl(ValidCodec, "resumeMetaBlockHeader"));
    try std.testing.expect(!@hasDecl(ValidCodec, "parseMetaBlockHeaderInto"));
    var input = [_]u8{0xd3} ** 32;
    input[0] = 0; // One zero header bit, followed by seven zero padding bits.
    const original_input = input;
    var expected_result: core.StepResult = undefined;
    var expected_snapshot: Decoder.Snapshot = undefined;
    for ([_]usize{ 1, 17, 32 }) |offered| {
        var history = [_]u8{0x9b} ** 3;
        var output = [_]u8{0xa7} ** 17;
        var decoder = Decoder.initWithOptions(&history, .{ .allow_trailing_data = true });
        // Isolate the returned-header contract after the meta-block preamble.
        // A zero-length final block needs only the header and byte padding.
        decoder.phase = .compressed_header;
        decoder.decoded_len = 0;
        decoder.final_meta_block = true;
        const result = try decoder.step(input[0..offered], output[4..13]);
        try std.testing.expectEqual(core.StepResult{ .progress = .{ .input_read = 1 }, .status = .done }, result);
        try std.testing.expectEqual(@as(core.StreamCount, 0), decoder.header.decoded_len);
        try std.testing.expect(decoder.header.final);
        try std.testing.expectEqual(@as(?core.Error, null), decoder.fatal_error);
        try std.testing.expectEqualSlices(u8, &original_input, &input);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa7} ** 17), &output);
        try std.testing.expectEqualSlices(u8, &([_]u8{0x9b} ** 3), &history);
        try std.testing.expectEqual(@as(usize, 0), decoder.trailingInput().len);
        const snapshot = decoder.snapshot();
        if (offered == 1) {
            expected_result = result;
            expected_snapshot = snapshot;
        } else {
            try std.testing.expectEqualDeep(expected_result, result);
            try std.testing.expectEqualDeep(expected_snapshot, snapshot);
            try std.testing.expectEqualSlices(u8, original_input[1..offered], input[result.progress.input_read..offered]);
        }
        try decoder.finish();
        const again = try decoder.step(input[1..offered], output[4..13]);
        try std.testing.expectEqual(core.StepResult{ .status = .done }, again);
        try std.testing.expectEqual(@as(core.StreamCount, 1), decoder.snapshot().input_read);
        try std.testing.expectEqual(@as(?core.Error, null), decoder.fatal_error);
        try std.testing.expectEqualSlices(u8, &original_input, &input);
        try std.testing.expectEqualSlices(u8, &([_]u8{0xa7} ** 17), &output);
    }
}

test "Brotli fallback invalid consumed bits preserve prior inactive header and publish zero progress" {
    inline for (.{ @as(usize, 2), @as(usize, 0) }) |consumed| {
        const Codec = FixtureCodec(consumed);
        var history: [1]u8 = undefined;
        var decoder = incremental.Decoder(Codec).init(&history);
        decoder.phase = .compressed_header;
        decoder.header = .{ .decoded_len = 19, .final = true };
        decoder.header_bit_count = if (consumed == 0) 128 else 1;
        decoder.header_len = (decoder.header_bit_count + 7) / 8;
        try std.testing.expectError(error.CorruptFrame, decoder.step(&.{}, &.{}));
        try std.testing.expectEqual(@as(core.StreamCount, 19), decoder.header.decoded_len);
        try std.testing.expect(decoder.header.final);
        try std.testing.expectEqualDeep(core.Progress{}, decoder.last_step_progress);
        try std.testing.expectEqual(incremental.Decoder(Codec).Phase.compressed_header, decoder.phase);
        try std.testing.expectEqual(error.CorruptFrame, decoder.fatal_error.?);
    }
}
