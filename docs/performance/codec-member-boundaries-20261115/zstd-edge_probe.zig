const std = @import("std");
const zstd = @import("zstd");
const Policy = @TypeOf((zstd.NativeIncrementalFrameDecoder.Options{}).input_policy);
fn run(name: []const u8, bytes: []const u8, policy: Policy) void {
    var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(std.heap.page_allocator, .{ .input_policy = policy, .expected_output_len = 0 });
    defer decoder.deinit();
    const result = decoder.step(bytes, &.{}) catch |err| {
        std.debug.print("{s} policy={s}: step_error={s} read={d}\n", .{name, @tagName(policy), @errorName(err), decoder.snapshot().input_received});
        return;
    };
    std.debug.print("{s} policy={s}: status={s} read={d}\n", .{name, @tagName(policy), @tagName(result.status), result.progress.input_read});
    decoder.finish() catch |err| {
        std.debug.print("  finish_error={s}\n", .{@errorName(err)});
        return;
    };
    std.debug.print("  finish=ok\n", .{});
}
pub fn main() void {
    const unknown_empty = [_]u8{0x28,0xb5,0x2f,0xfd,0,0,0x15,0,0,0,0};
    const valid_checksum = [_]u8{0x28,0xb5,0x2f,0xfd,0x24,0,1,0,0,0x99,0xe9,0xd8,0x51};
    const bad_checksum = [_]u8{0x28,0xb5,0x2f,0xfd,0x24,0,1,0,0,0,0,0,0};
    const nonempty = [_]u8{0x28,0xb5,0x2f,0xfd,0x20,1,9,0,0,'a'};
    for ([_]Policy{.prevalidated_frame,.block_stream}) |policy| {
        run("unknown FCS empty compressed",&unknown_empty,policy);
        run("checksum valid empty",&valid_checksum,policy);
        run("checksum truncated empty",valid_checksum[0..12],policy);
        run("checksum mismatch empty",&bad_checksum,policy);
        run("known FCS nonempty no output",&nonempty,policy);
    }
    run("zero input poll",&.{},.prevalidated_frame);
}
