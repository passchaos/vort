const std = @import("std");
const adapter = @import("../../archive_stream/incremental_decoder_codecs.zig").Zstandard;
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    const frame = try h.frame(Z, .standard);
    defer a.free(frame);
    var state = try adapter.init(a, .{ .dictionary_usage = .prefix });
    defer adapter.deinit(&state);
    try state.setPrefix(h.prefix);
    try h.pending(state.prefixSnapshot(), 0, false);
    var input: usize = 0;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(a);
    for (0..frame.len * 32 + 8192) |_| {
        var buffer: [3]u8 = @splat(0xa5);
        const step = try adapter.step(&state, frame[input..@min(frame.len, input + 1)], &buffer);
        input += step.progress.input_read;
        try output.appendSlice(a, buffer[0..step.progress.output_written]);
        try h.wire.untouched(buffer[step.progress.output_written..]);
        if (step.status == .done) break;
    }
    try adapter.finish(&state);
    try std.testing.expectEqual(frame.len, input);
    try std.testing.expectEqualSlices(u8, h.payload, output.items);
    try h.cleared(state.prefixSnapshot());
    try std.testing.expectEqual(@as(usize, 0), adapter.trailingInput(&state).len);
}
