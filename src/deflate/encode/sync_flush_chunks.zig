//! Chunked fixed sync-flush emission over stable original contiguous runs.
const std = @import("std");
const alias_runs = @import("sync_flush_chunks/alias_runs.zig");
const history_buffer = @import("sync_flush_chunks/history.zig");

pub fn encode(comptime C: type, scratch_allocator: std.mem.Allocator, output_allocator: std.mem.Allocator, output: *std.ArrayList(u8), chunks: []const []const u8, options: C.Options) !usize {
    // Snapshot before even rebinding output descriptors. Output growth can
    // invalidate data and descriptor slices anywhere in its allocated capacity.
    var runs = try alias_runs.Prepared.init(scratch_allocator, chunks, output.allocatedSlice());
    defer runs.deinit(scratch_allocator);
    const start = output.items.len;
    var writer = C.Writer{ .bytes = output.* };
    output.* = .empty;
    defer output.* = writer.bytes;
    errdefer writer.bytes.shrinkRetainingCapacity(start);
    const history_limit = @min(options.lz77_options.window_len, C.history_len);
    var history: std.ArrayList(u8) = .empty;
    defer history.deinit(scratch_allocator);
    var wrote_block = false;
    while (runs.next()) |run| {
        if (!wrote_block) try C.writeHeader(output_allocator, &writer, false);
        const plan = try C.plan(scratch_allocator, run, history.items, options);
        defer plan.deinit(scratch_allocator);
        try C.writeTokens(output_allocator, &writer, plan.tokens);
        try history_buffer.append(scratch_allocator, &history, run, history_limit);
        wrote_block = true;
    }
    if (!wrote_block) try C.writeHeader(output_allocator, &writer, false);
    try C.writeEnd(output_allocator, &writer);
    try C.writeStored(output_allocator, &writer, "", false);
    return writer.bytes.items.len - start;
}
