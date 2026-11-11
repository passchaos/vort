const std = @import("std");
const vort = @import("vort");

pub fn main() !void {
    var history: [32768]u8 = @splat(0xa5);
    var decoder = try vort.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{}, &history);
    var backing: [19]u8 = .{ 0x00, 0x03, 0x00, 0xfc, 0xff, 'a', 'b', 'c', 0x01, 0x03, 0x00, 0xfc, 0xff, 'd', 'e', 'f', 0xaa, 0xaa, 0xaa };
    const result = try decoder.step(backing[0..16], backing[13..19]);
    std.debug.print("revision=17058d8150af5b5ae3178def85b2e227f55df686 public_module=src/root.zig mode=Debug Zig=0.16.0\n", .{});
    std.debug.print("expected_status=done expected_input=16 expected_output=6 expected_bytes=abcdef\n", .{});
    std.debug.print("actual_status={s} actual_input={d} actual_output={d} actual_bytes={s}\n", .{ @tagName(result.status), result.progress.input_read, result.progress.output_written, backing[13..19] });
    if (!std.mem.eql(u8, backing[13..19], "abcdef")) return error.OutputMismatch;
}
