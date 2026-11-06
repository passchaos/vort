//! Small runtime contract consumer for wasm32-wasi and freestanding exports.
const std = @import("std");
const zstd = @import("zstd");
const a = std.heap.page_allocator;

fn require(ok: bool) error{IgnoreChecksumContractMismatch}!void {
    if (!ok) return error.IgnoreChecksumContractMismatch;
}

pub fn contracts(comptime Z: type, allocator: std.mem.Allocator) !void {
    var payload: [512]u8 = undefined;
    for ([_]bool{ false, true }) |rle| {
        for (&payload, 0..) |*byte, index| byte.* = if (rle) 'R' else @truncate(index *% 29 + 7);
        const frame = try Z.encodeRawOrRleFrameWithOptionsAlloc(allocator, &payload, .{ .content_checksum = true });
        defer allocator.free(frame);
        frame[frame.len - 1] ^= 0x80;
        for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
            const wire = if (format == .standard) frame else frame[4..];
            if (Z.decodeFrameAllocWithOptions(allocator, wire, .{ .format = format })) |unexpected| {
                allocator.free(unexpected);
                return error.ExpectedChecksumMismatch;
            } else |err| try require(err == error.ChecksumMismatch);
            const decoded = try Z.decodeFrameAllocWithOptions(allocator, wire, .{ .format = format, .ignore_content_checksum = true });
            defer allocator.free(decoded);
            try require(std.mem.eql(u8, &payload, decoded));
            for ([_]Z.NativeIncrementalFrameDecoder.Options{
                .{ .format = format, .ignore_content_checksum = true },
                .{ .format = format, .ignore_content_checksum = true, .input_policy = .prevalidated_frame },
            }) |options| {
                var decoder = Z.NativeIncrementalFrameDecoder.initWithOptions(allocator, options);
                defer decoder.deinit();
                var output: [payload.len + 17]u8 = @splat(0xa5);
                var written: usize = 0;
                for (0..wire.len) |index| {
                    const step = try decoder.step(wire[index..][0..1], output[written..payload.len]);
                    try require(step.progress.input_read == 1);
                    written += step.progress.output_written;
                    if (index + 1 != wire.len) try require(step.status != .done);
                }
                try decoder.finish();
                try require(written == payload.len and std.mem.eql(u8, &payload, output[0..written]));
                for (output[written..]) |byte| try require(byte == 0xa5);
                try require(decoder.snapshot().input_received == wire.len and decoder.snapshot().data_frame_count == 1);
            }
            if (Z.decodeFrameAllocWithOptions(allocator, wire[0 .. wire.len - 1], .{ .format = format, .ignore_content_checksum = true })) |unexpected| {
                allocator.free(unexpected);
                return error.ExpectedTruncatedFooter;
            } else |err| try require(err == error.TruncatedFrame);
        }
    }
}

export fn zstdIgnoreChecksumWasmContracts() u32 {
    contracts(zstd, a) catch return 1;
    return 0;
}

pub fn main(init: std.process.Init) !void {
    _ = init;
    try contracts(zstd, a);
}
