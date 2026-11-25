const std = @import("std");
const api = @import("root.zig");
const sample = @import("android_ota/puffin_codec_tests/real_sample.zig");
const counts = @import("android_ota/puffin_codec_tests/malformed_count.zig");
pub fn main(init: std.process.Init.Minimal) !void {
    const a = std.heap.page_allocator;
    var args = init.args.iterate();
    _ = args.next();
    if (args.next() != null) {
        const result = api.puffAndroidDeflatePaddedAlloc(a, &counts.raw, 0, counts.raw.len * 8, 4096) catch |err| {
            std.debug.print("counts rejected {s}\n", .{@errorName(err)});
            return;
        };
        defer a.free(result.bytes);
        std.debug.print("counts accepted\n", .{});
        return;
    }
    if (api.puffAndroidDeflatePaddedAlloc(a, &sample.raw, 0, sample.raw.len * 8, 4096)) |result| {
        defer a.free(result.bytes);
        std.debug.print("puff accepted exact_bits={d} puff_bytes={d}\n", .{ result.consumed_bits, result.bytes.len });
    } else |err| std.debug.print("puff rejected {s}\n", .{@errorName(err)});
    if (api.huffAndroidDeflateAlloc(a, &sample.puff, 0, sample.exact_bits)) |bytes| {
        defer a.free(bytes);
        std.debug.print("huff accepted bytes={d} bit_exact={}\n", .{ bytes.len, std.mem.eql(u8, bytes, &sample.raw) });
    } else |err| std.debug.print("huff rejected {s}\n", .{@errorName(err)});
}
