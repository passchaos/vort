const std = @import("std");
const zstd = @import("vort_zstd");
const Tracker = @import("tracking_allocator.zig").Tracker;
const input = @embedFile("input.bin");
const expected_hex = "795448b31e4039831d40f1ee39d322865f8d32ef9f673d99d73aca17d4827c92";

pub fn main() !void {
    var tracker: Tracker = .{ .backing = std.heap.page_allocator };
    const allocator = tracker.allocator();
    const output = try zstd.encodeFrameWithLevelAlloc(allocator, input, 3);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(output, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    if (output.len != 5078 or !std.mem.eql(u8, &hex, expected_hex)) return error.WireChanged;
    std.debug.print("RETURN {{\"input_bytes\":{d},\"output_bytes\":{d},\"output_sha256\":\"{s}\",\"peak_requested\":{d},\"live_after_return\":{d},\"alloc_attempts\":{d},\"successful_allocations\":{d},\"resize_attempts\":{d},\"remap_attempts\":{d},\"successful_resizes\":{d},\"successful_remaps\":{d},\"increased_bytes\":{d},\"released_bytes\":{d},\"tracker_size\":{d}}}\n", .{ input.len, output.len, hex, tracker.peak, tracker.live, tracker.alloc_attempts, tracker.successful_allocations, tracker.resize_attempts, tracker.remap_attempts, tracker.successful_resizes, tracker.successful_remaps, tracker.increased_bytes, tracker.released_bytes, @sizeOf(Tracker) });
    allocator.free(output);
    std.debug.print("CLEANUP {{\"live_after_caller_free\":{d},\"increased_bytes\":{d},\"released_bytes\":{d},\"free_calls\":{d}}}\n", .{ tracker.live, tracker.increased_bytes, tracker.released_bytes, tracker.free_calls });
    if (tracker.live != 0 or tracker.increased_bytes != tracker.released_bytes) return error.LeakedAllocation;
    // Optional tiny backing-OOM check; no second XML encoding is performed.
    var failing: Tracker = .{ .backing = std.heap.page_allocator, .fail_alloc_at = 0, .phase = "small_oom" };
    if (zstd.encodeFrameWithLevelAlloc(failing.allocator(), "tiny allocation probe " ** 4, 3)) |unexpected| {
        failing.allocator().free(unexpected);
        return error.ExpectedOutOfMemory;
    } else |err| if (err != error.OutOfMemory) return err;
    std.debug.print("OOM {{\"result\":\"OutOfMemory\",\"live\":{d},\"alloc_attempts\":{d}}}\n", .{ failing.live, failing.alloc_attempts });
    if (failing.live != 0) return error.LeakedAllocation;
}
