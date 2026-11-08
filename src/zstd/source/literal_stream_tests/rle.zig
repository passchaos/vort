const std = @import("std");
const common = @import("common.zig");
const literal_stream = common.literal_stream;

fn initReadsOnceAndCopiesWithoutSourceAccess() !void {
    var source = common.TrackingSource{ .bytes = "Z" };
    const decoded = try common.layout(&source, .rle, 37);
    var page_storage: [12]u8 = @splat(0x73);
    page_storage[0] = 0x39;
    page_storage[11] = 0xc6;
    var stream = try literal_stream.init(
        common.DummyCodec,
        decoded,
        null,
        page_storage[1..11],
    );
    try std.testing.expectEqual(@as(usize, 1), source.calls);
    try std.testing.expectEqual(literal_stream.Kind.rle, std.meta.activeTag(stream));
    try std.testing.expectEqual(literal_stream.Kind.rle, stream.snapshot().kind);
    try std.testing.expect(stream.snapshot().huffman == null);

    var output_storage: [39]u8 = @splat(0xd8);
    output_storage[0] = 0x51;
    output_storage[output_storage.len - 1] = 0xae;
    const output = output_storage[1 .. output_storage.len - 1];
    var committed: usize = 99;
    try stream.copyNext(output[0..0], &committed);
    try std.testing.expectEqual(@as(usize, 0), committed);
    try stream.copyNext(output[0..13], &committed);
    try std.testing.expectEqual(@as(usize, 13), committed);
    try stream.copyNext(output[13..], &committed);
    try std.testing.expectEqual(@as(usize, 24), committed);
    try stream.expectEnd();
    try stream.expectEnd();
    try std.testing.expect(stream.isFinished());
    try std.testing.expectEqual(@as(usize, 1), source.calls);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 'Z'), byte);
    try common.expectPageCanaries(&page_storage, 10);
    try common.expectOutputCanaries(&output_storage);
}

fn initFailuresCanRetry() !void {
    inline for (.{ common.Mode.zero, .excessive, .fail }) |mode| {
        var source = common.TrackingSource{
            .bytes = "R",
            .mode = mode,
            .fault_call = 1,
        };
        const decoded = try common.layout(&source, .rle, 5);
        var page_storage: [11]u8 = @splat(0x42);
        page_storage[0] = 0x39;
        page_storage[10] = 0xc6;
        try std.testing.expectError(
            common.expectedError(mode),
            literal_stream.init(
                common.DummyCodec,
                decoded,
                null,
                page_storage[1..10],
            ),
        );
        try std.testing.expectEqual(@as(usize, 1), source.calls);
        try common.expectPageCanaries(&page_storage, 9);

        source.clearFault();
        var stream = try literal_stream.init(
            common.DummyCodec,
            decoded,
            null,
            page_storage[1..10],
        );
        var output: [5]u8 = undefined;
        var committed: usize = 99;
        try stream.copyNext(&output, &committed);
        try std.testing.expectEqual(output.len, committed);
        try std.testing.expectEqualStrings("RRRRR", &output);
        try common.expectPageCanaries(&page_storage, 9);
    }
}

fn aliasPriorityAndCombinationContracts() !void {
    var source = common.TrackingSource{ .bytes = "Q" };
    var decoded = try common.layout(&source, .rle, 2);
    var page: [9]u8 = @splat(0xa5);
    var stream = try literal_stream.init(common.DummyCodec, decoded, null, &page);
    source.resetTelemetry();
    const before = stream.snapshot();
    var committed: usize = 99;
    try std.testing.expectError(
        error.CorruptFrame,
        stream.copyNext(page[0..3], &committed),
    );
    try std.testing.expectEqual(@as(usize, 0), committed);
    try std.testing.expectEqualDeep(before, stream.snapshot());
    try std.testing.expectError(
        error.InvalidStreamState,
        stream.copyNext(page[2..4], &committed),
    );
    try std.testing.expectEqual(@as(usize, 0), committed);
    try std.testing.expectEqualDeep(before, stream.snapshot());
    try std.testing.expectEqual(@as(usize, 0), source.calls);

    const pending = common.source_huffman.Prepared(common.DummyCodec){
        .table = 0,
        .origin = .new_tree,
        .description = null,
        .description_bytes = 0,
        .replace_on_block_success = true,
    };
    try std.testing.expectError(
        error.CorruptFrame,
        literal_stream.init(common.DummyCodec, decoded, &pending, &page),
    );
    decoded.literal_payload = try decoded.literal_payload.subrange(0, 0);
    try std.testing.expectError(
        error.CorruptFrame,
        literal_stream.init(common.DummyCodec, decoded, null, &page),
    );
}

fn zeroLengthStillReadsValueAndTerminalizes() !void {
    var source = common.TrackingSource{ .bytes = "0" };
    const decoded = try common.layout(&source, .rle, 0);
    var page: [9]u8 = undefined;
    var stream = try literal_stream.init(common.DummyCodec, decoded, null, &page);
    try std.testing.expectEqual(@as(usize, 1), source.calls);
    var committed: usize = 99;
    try stream.copyNext(page[0..0], &committed);
    try std.testing.expectEqual(@as(usize, 0), committed);
    try std.testing.expect(stream.isFinished());
    try stream.expectEnd();
}

pub fn contracts() !void {
    try initReadsOnceAndCopiesWithoutSourceAccess();
    try initFailuresCanRetry();
    try aliasPriorityAndCombinationContracts();
    try zeroLengthStillReadsValueAndTerminalizes();
}
