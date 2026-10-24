//! One-shot and reusable HQ calls exercise the public incremental core. Source
//! chunks stay borrowed until the complete detached wire has been constructed.
const std = @import("std");

pub fn encodeAlloc(comptime Encoder: type, allocator: std.mem.Allocator, chunks: []const []const u8, options: Encoder.Options) Encoder.Error![]u8 {
    var encoder = Encoder.initWithOptions(allocator, options);
    defer encoder.deinit();
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    const profile = if (options.stream.hq) |hq| hq.profile else null;
    const emitted = if (profile) |p| p.emitted() else null;
    errdefer if (profile) |p| p.restoreEmitted(emitted.?);
    var output: [16 * 1024]u8 = undefined;
    for (chunks) |chunk| {
        var offset: usize = 0;
        while (offset != chunk.len) {
            const step = try encoder.step(chunk[offset..], &output);
            offset += step.progress.input_read;
            try frame.appendSlice(allocator, output[0..step.progress.output_written]);
            if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.InvalidBlockPlan;
        }
    }
    try encoder.finish();
    while (true) {
        const step = try encoder.step("", &output);
        try frame.appendSlice(allocator, output[0..step.progress.output_written]);
        if (step.status == .done) break;
        if (step.progress.output_written == 0) return error.InvalidBlockPlan;
    }
    return frame.toOwnedSlice(allocator);
}
