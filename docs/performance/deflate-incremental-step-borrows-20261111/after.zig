const std = @import("std");
const vort = @import("vort");

pub fn main() !void {
    var history: [32768]u8 = @splat(0xa5);
    var decoder = try vort.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{}, &history);
    var backing: [19]u8 = .{ 0, 3, 0, 0xfc, 0xff, 'a', 'b', 'c', 1, 3, 0, 0xfc, 0xff, 'd', 'e', 'f', 0xaa, 0xaa, 0xaa };
    const before = backing;
    const history_before = history;
    var state: [@sizeOf(@TypeOf(decoder))]u8 = undefined;
    @memcpy(&state, std.mem.asBytes(&decoder));
    if (decoder.step(backing[0..16], backing[13..19])) |_| {
        return error.ExpectedBorrowRefusal;
    } else |err| if (err != error.InvalidBlockPlan) return err;
    if (!std.mem.eql(u8, &before, &backing) or
        !std.mem.eql(u8, &history_before, &history) or
        !std.mem.eql(u8, &state, std.mem.asBytes(&decoder)))
        return error.RefusalModifiedState;
    var output: [6]u8 = undefined;
    const result = try decoder.step(backing[0..16], &output);
    if (result.status != .done or result.progress.input_read != 16 or
        result.progress.output_written != 6 or !std.mem.eql(u8, "abcdef", &output))
        return error.RetryMismatch;
    std.debug.print("public_module=src/root.zig mode=Debug alias=InvalidBlockPlan state=input=history=unchanged retry=done input=16 output=6 bytes=abcdef\n", .{});
}
