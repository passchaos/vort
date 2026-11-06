const std = @import("std");
const h = @import("helpers.zig");

/// Invalid storage is rejected before object, history or workspace bytes change.
pub fn reject(allocator: std.mem.Allocator, source: anytype, destination: @TypeOf(source), storage: @TypeOf(source.*).CloneStorage, expected: anyerror) !void {
    const source_bytes = try allocator.dupe(u8, std.mem.asBytes(source));
    defer allocator.free(source_bytes);
    const destination_bytes = try allocator.dupe(u8, std.mem.asBytes(destination));
    defer allocator.free(destination_bytes);
    const history_bytes = try allocator.dupe(u8, storage.history);
    defer allocator.free(history_bytes);
    const raw = h.rawOf(source);
    const source_history = if (raw.semantic_scratch.len != 0) raw.semantic_scratch else raw.history;
    const source_history_bytes = try allocator.dupe(u8, source_history);
    defer allocator.free(source_history_bytes);
    const workspace_bytes = if (storage.semantic_workspace) |workspace|
        try allocator.dupe(u8, std.mem.asBytes(workspace))
    else
        try allocator.alloc(u8, 0);
    defer allocator.free(workspace_bytes);
    const source_workspace_bytes = if (raw.semantic_decoder) |workspace|
        try allocator.dupe(u8, std.mem.asBytes(workspace))
    else
        try allocator.alloc(u8, 0);
    defer allocator.free(source_workspace_bytes);
    try std.testing.expectError(expected, source.cloneInto(destination, storage));
    try std.testing.expectEqualSlices(u8, source_bytes, std.mem.asBytes(source));
    try std.testing.expectEqualSlices(u8, destination_bytes, std.mem.asBytes(destination));
    try std.testing.expectEqualSlices(u8, history_bytes, storage.history);
    try std.testing.expectEqualSlices(u8, source_history_bytes, source_history);
    if (storage.semantic_workspace) |workspace|
        try std.testing.expectEqualSlices(u8, workspace_bytes, std.mem.asBytes(workspace));
    if (raw.semantic_decoder) |workspace|
        try std.testing.expectEqualSlices(u8, source_workspace_bytes, std.mem.asBytes(workspace));
}

pub fn matrix(comptime T: type, allocator: std.mem.Allocator, source: *T, destination: *T, history: []u8, source_history: []u8, workspace: ?*@TypeOf(h.rawOf(source).*).SemanticWorkspace) !void {
    const required = source.cloneHistoryLen();
    const good: T.CloneStorage = .{ .history = history, .semantic_workspace = workspace };
    try reject(allocator, source, source, good, error.OverlappingCloneStorage);
    if (required != 0) {
        try reject(allocator, source, destination, .{ .history = history[0 .. required - 1], .semantic_workspace = workspace }, error.InvalidCloneStorage);
        try reject(allocator, source, destination, .{ .history = source_history[0..required], .semantic_workspace = workspace }, error.OverlappingCloneStorage);
        try reject(allocator, source, destination, .{ .history = source_history[1..][0..required], .semantic_workspace = workspace }, error.OverlappingCloneStorage);
    }
    if (h.rawOf(source).semantic_decoder) |source_workspace| {
        try reject(allocator, source, destination, .{ .history = history }, error.InvalidCloneStorage);
        try reject(allocator, source, destination, .{ .history = history, .semantic_workspace = source_workspace }, error.OverlappingCloneStorage);
        const overlapping_workspace: *@TypeOf(source_workspace.*) = @ptrCast(@alignCast(history.ptr));
        try reject(allocator, source, destination, .{ .history = history, .semantic_workspace = overlapping_workspace }, error.OverlappingCloneStorage);
    } else if (workspace) |_| return error.TestUnexpectedResult;
}

pub fn continueDecoder(allocator: std.mem.Allocator, decoder: anytype, wire: []const u8, expected: []const u8, input_chunk: usize, output_chunk: usize) !void {
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var read: usize = 0;
    var written: usize = 0;
    for (0..expected.len + wire.len + 32) |_| {
        const result = try decoder.step(wire[read..@min(wire.len, read + input_chunk)], output[written..@min(output.len, written + output_chunk)]);
        read += result.progress.input_read;
        written += result.progress.output_written;
        if (result.status == .done) {
            try std.testing.expectEqual(wire.len, read);
            try std.testing.expectEqualSlices(u8, expected, output[0..written]);
            try decoder.finish();
            return;
        }
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    return error.TestUnexpectedResult;
}

pub fn expectRaw(source: anytype, copy: @TypeOf(source)) !void {
    inline for (.{ "options", "phase", "bit_buffer", "bit_count", "code", "code_bits", "final_block", "history_pos", "history_len", "match_remaining", "match_distance", "semantic_prefix_start", "semantic_prefix_len", "semantic_generated_end", "semantic_delivered", "semantic_end_of_block", "total_input", "total_output" }) |field|
        try std.testing.expectEqualDeep(@field(source, field), @field(copy, field));
    try std.testing.expectEqual(source.history.len, copy.history.len);
    try std.testing.expectEqual(source.semantic_scratch.len, copy.semantic_scratch.len);
    if (source.history.len != 0) {
        try std.testing.expect(source.history.ptr != copy.history.ptr);
        try std.testing.expectEqualSlices(u8, source.history, copy.history);
    }
    if (source.semantic_scratch.len != 0) {
        try std.testing.expectEqual(copy.history.ptr, copy.semantic_scratch.ptr);
        try std.testing.expectEqualSlices(u8, source.semantic_scratch, copy.semantic_scratch);
    }
    if (source.semantic_decoder) |source_workspace| {
        const copy_workspace = copy.semantic_decoder.?;
        try std.testing.expect(source_workspace != copy_workspace);
        try std.testing.expectEqual(&copy.dynamic_literal_table, copy_workspace.compact_literal);
        try std.testing.expectEqual(&copy.dynamic_distance_table, copy_workspace.compact_distance);
        if (source.phase == .fast_dynamic_block) {
            try std.testing.expectEqualSlices(u32, &source_workspace.literal, &copy_workspace.literal);
            try std.testing.expectEqualSlices(u32, &source_workspace.distance, &copy_workspace.distance);
            try std.testing.expectEqual(source_workspace.literal_secondary_len, copy_workspace.literal_secondary_len);
            try std.testing.expectEqual(source_workspace.distance_secondary_len, copy_workspace.distance_secondary_len);
        }
    } else try std.testing.expect(copy.semantic_decoder == null);
}
