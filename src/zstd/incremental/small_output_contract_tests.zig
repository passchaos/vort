//! Decoder caller contract: drain tiny output before final EOF validation.
//! The17-byte standard frame has one RLE literal a and one131-byte match.
//! It uses LL/OF RLE modes and ML predefined mode; no dictionary or checksum.
const std = @import("std");
const frame = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0x20, 132, 0x45, 0, 0, 9, 'a', 1, 0x50, 1, 0, 0, 0x2a };
pub fn check(comptime Z: type) !void {
    var decoder = Z.IncrementalFrameDecoder.init(std.testing.allocator);
    defer decoder.deinit();
    var input: usize = 0;
    var output: usize = 0;
    var storage: [65]u8 = @splat(0xa5);
    var saw_output = false;
    var early = false;
    for (0..1000) |call| {
        @memset(&storage, 0xa5);
        const result = try decoder.step(frame[input..], storage[32..33]);
        input += result.progress.input_read;
        const n = result.progress.output_written;
        if (n == 1) {
            try std.testing.expectEqual(@as(u8, 'a'), storage[32]);
            output += 1;
        }
        for (storage[0..32]) |b| try std.testing.expectEqual(@as(u8, 0xa5), b);
        for (storage[32 + n ..]) |b| try std.testing.expectEqual(@as(u8, 0xa5), b);
        if (result.status == .need_output) saw_output = true;
        if (input == frame.len and result.status == .need_output and !early) {
            try std.testing.expectError(error.OutputTooSmall, decoder.finish());
            early = true;
        }
        if (result.status == .done or (input == frame.len and result.status == .need_input and n == 0)) {
            try decoder.finish();
            try std.testing.expectEqual(frame.len, input);
            try std.testing.expectEqual(@as(usize, 132), output);
            try std.testing.expect(saw_output and early);
            return;
        }
        if (call == 999) return error.TestUnexpectedResult;
    }
}
