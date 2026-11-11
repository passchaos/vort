const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const method = args.next() orelse "init";
    var history: [32768]u8 = @splat(0xa5);
    for (history[0..32], 0..) |*byte, index| byte.* = @intCast(index);
    const expected = history[5..15].*;
    std.debug.print("source_revision=9a41b4e43e6258f8e10d602b3d7d5312cd683d1f public_module=src/root.zig mode=Debug operation={s} source=H[5..15] destination=H[0..10]\n", .{method});
    std.debug.print("expected_bytes={any}\n", .{expected});
    var decoder = if (std.mem.eql(u8, method, "init"))
        try vort.RawDeflateIncrementalFixedLiteralDecoder.initWithDictionary(.{}, &history, history[5..15])
    else seed: {
        var raw = try vort.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{}, &history);
        raw.seedDictionary(history[5..15]);
        break :seed raw;
    };
    std.debug.print("actual_bytes={any} history_len={d} history_pos={d}\n", .{history[0..10].*, decoder.history_len, decoder.history_pos});
    if (!std.mem.eql(u8, &expected, history[0..10])) return error.DictionarySnapshotMismatch;
    if (decoder.history_len != 10 or decoder.history_pos != 10) return error.DictionaryMetadataMismatch;
    decoder.reset();
}
