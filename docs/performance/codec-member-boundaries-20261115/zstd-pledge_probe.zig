const std = @import("std");
const zstd = @import("zstd");
const frame = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0x20, 0x00, 0x01, 0x00, 0x00 };
pub fn main() !void {
    const allocator = std.heap.page_allocator;
    for ([_]@TypeOf((zstd.NativeIncrementalFrameDecoder.Options{}).input_policy){ .prevalidated_frame, .block_stream }) |policy| {
        for ([_]bool{ false, true }) |fragmented| {
            var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(allocator, .{ .input_policy = policy, .expected_output_len = 0 });
            defer decoder.deinit();
            const first = decoder.step(if (fragmented) frame[0..1] else &frame, &.{}) catch |err| {
                std.debug.print("policy={s} fragmented={} error={s} accepted={d}\n", .{ @tagName(policy), fragmented, @errorName(err), decoder.snapshot().input_received });
                continue;
            };
            std.debug.print("policy={s} fragmented={} first_status={s} accepted={d}\n", .{ @tagName(policy), fragmented, @tagName(first.status), first.progress.input_read });
            if (fragmented) {
                const second = try decoder.step(frame[1..], &.{});
                std.debug.print("  second_status={s} accepted={d}\n", .{ @tagName(second.status), second.progress.input_read });
            }
            try decoder.finish();
        }
    }
    std.debug.print("one-shot decoded={d}\n", .{try zstd.decodeFrameInto(&frame, &.{})});
}
