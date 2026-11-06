const std = @import("std");
const f = @import("fixtures.zig");
const storage = @import("decoder_storage.zig");

fn checkpoint(comptime Raw: type, allocator: std.mem.Allocator, fixture: f.Fixture, comptime semantic: bool, comptime split_code: bool) !void {
    const history_len = if (semantic) Raw.recommended_history_len else Raw.required_history_len;
    const history = try allocator.alignedAlloc(u8, .@"8", history_len + 1);
    var source_storage_alive = true;
    defer if (source_storage_alive) allocator.free(history);
    @memset(history, 0x59);
    const target_history = try allocator.alignedAlloc(u8, .@"8", history_len);
    defer allocator.free(target_history);
    @memset(target_history, 0xa5);
    const source = try allocator.create(Raw);
    var source_alive = true;
    defer if (source_alive) allocator.destroy(source);
    source.* = try Raw.initWithHistory(.{ .expected_output_len = fixture.plain.len }, history);
    const destination = try allocator.create(Raw);
    defer allocator.destroy(destination);
    destination.* = Raw.init();
    const source_workspace: ?*Raw.SemanticWorkspace = if (semantic) try allocator.create(Raw.SemanticWorkspace) else null;
    var source_workspace_alive = semantic;
    defer if (source_workspace_alive) allocator.destroy(source_workspace.?);
    const target_workspace: ?*Raw.SemanticWorkspace = if (semantic) try allocator.create(Raw.SemanticWorkspace) else null;
    defer if (target_workspace) |workspace| allocator.destroy(workspace);
    if (source_workspace) |workspace| {
        @memset(std.mem.asBytes(workspace), 0x73);
        try source.attachSemanticWorkspace(workspace);
        @memset(std.mem.asBytes(target_workspace.?), 0xa5);
    }
    var first_output: [2]u8 = undefined;
    const first_input = if (split_code) fixture.wire[0..1] else fixture.wire;
    const first = try source.step(first_input, first_output[0..if (semantic) 1 else 2]);
    if (split_code) {
        try std.testing.expectEqual(@as(usize, 0), first.progress.output_written);
        try std.testing.expect(source.code_bits != 0 or source.bit_count != 0);
    } else if (semantic) {
        try std.testing.expectEqual(.fast_dynamic_block, source.phase);
        try std.testing.expect(source.semantic_generated_end > source.semantic_delivered);
    } else {
        try std.testing.expectEqual(.match_copy, source.phase);
        try std.testing.expect(source.match_remaining != 0);
    }
    try std.testing.expectEqual(history_len, source.cloneHistoryLen());
    try storage.matrix(Raw, allocator, source, destination, target_history, history, target_workspace);
    const before_input = source.total_input;
    const before_output = source.total_output;
    try source.cloneInto(destination, .{ .history = target_history, .semantic_workspace = target_workspace });
    try std.testing.expectEqual(before_input, source.total_input);
    try std.testing.expectEqual(before_output, source.total_output);
    try storage.expectRaw(source, destination);
    const remaining_wire = fixture.wire[first.progress.input_read..];
    const remaining_plain = fixture.plain[first.progress.output_written..];
    try storage.continueDecoder(allocator, source, remaining_wire, remaining_plain, if (semantic) fixture.wire.len else 1, 19);
    // Reuse and then release all source storage before continuing the clone.
    // Its compact Huffman fallbacks must point into the stable destination.
    source.reset();
    @memset(history, 0xdb);
    allocator.free(history);
    source_storage_alive = false;
    if (source_workspace) |workspace| {
        @memset(std.mem.asBytes(workspace), 0xdb);
        allocator.destroy(workspace);
        source_workspace_alive = false;
    }
    @memset(std.mem.asBytes(source), 0xdb);
    allocator.destroy(source);
    source_alive = false;
    try storage.continueDecoder(allocator, destination, remaining_wire, remaining_plain, if (semantic) fixture.wire.len else 2, 257);
}

fn geometry(comptime Raw: type, allocator: std.mem.Allocator) !void {
    const source = try allocator.create(Raw);
    defer allocator.destroy(source);
    source.* = Raw.init();
    const destination = try allocator.create(Raw);
    defer allocator.destroy(destination);
    destination.* = Raw.init();
    try std.testing.expectEqual(@as(usize, 0), source.cloneHistoryLen());
    try source.cloneInto(destination, .{});
    try storage.expectRaw(source, destination);
    try storage.reject(allocator, source, destination, .{ .history = std.mem.asBytes(source) }, error.OverlappingCloneStorage);
    try storage.reject(allocator, source, destination, .{ .history = std.mem.asBytes(destination) }, error.OverlappingCloneStorage);
    const source_workspace = try allocator.create(Raw.SemanticWorkspace);
    defer allocator.destroy(source_workspace);
    const destination_workspace = try allocator.create(Raw.SemanticWorkspace);
    defer allocator.destroy(destination_workspace);
    @memset(std.mem.asBytes(source_workspace), 0x63);
    @memset(std.mem.asBytes(destination_workspace), 0xa5);
    try storage.reject(allocator, source, destination, .{ .semantic_workspace = destination_workspace }, error.InvalidCloneStorage);
    // Workspace attachment before the first block is valid even without a
    // two-window history. The clone preserves it and rebinds the table owners.
    try source.attachSemanticWorkspace(source_workspace);
    try storage.reject(allocator, source, destination, .{}, error.InvalidCloneStorage);
    try source.cloneInto(destination, .{ .semantic_workspace = destination_workspace });
    try storage.expectRaw(source, destination);
    const empty = [_]u8{ 3, 0 };
    try storage.continueDecoder(allocator, source, &empty, "", 1, 1);
    try storage.continueDecoder(allocator, destination, &empty, "", 2, 1);
}

fn wide(comptime Raw: type, allocator: std.mem.Allocator) !void {
    const Count = @FieldType(Raw, "total_output");
    const count: Count = (@as(Count, 1) << 32) - 1;
    const source_history = try allocator.alloc(u8, Raw.required_history_len);
    defer allocator.free(source_history);
    const copy_history = try allocator.alloc(u8, Raw.required_history_len);
    defer allocator.free(copy_history);
    var source = try Raw.initWithHistory(.{}, source_history);
    var copy = Raw.init();
    const prefix = [_]u8{ 0, 1, 0, 0xfe, 0xff, 'x' };
    var first_output: [1]u8 = undefined;
    const first = try source.step(&prefix, &first_output);
    try std.testing.expectEqual(prefix.len, first.progress.input_read);
    try std.testing.expect(source.atBlockBoundary());
    // This lawful prefix model summarizes repeated complete, byte-aligned
    // stored blocks. Both physical suffixes execute normally across 2^32.
    source.total_input = count * prefix.len;
    source.total_output = count;
    source.history_len = source.history.len;
    source.history_pos = @intCast(count % source.history.len);
    @memset(source.history, 'x');
    try source.cloneInto(&copy, .{ .history = copy_history });
    try storage.expectRaw(&source, &copy);
    source.options.expected_output_len = count + 2;
    copy.options.expected_output_len = count + 3;
    const left = [_]u8{ 1, 2, 0, 0xfd, 0xff, 'a', 'b' };
    const right = [_]u8{ 1, 3, 0, 0xfc, 0xff, 'x', 'y', 'z' };
    try storage.continueDecoder(allocator, &source, &left, "ab", 1, 1);
    try storage.continueDecoder(allocator, &copy, &right, "xyz", 3, 2);
    try std.testing.expectEqual(count + 2, source.total_output);
    try std.testing.expectEqual(count + 3, copy.total_output);
    try std.testing.expectEqual(count * prefix.len + left.len, source.total_input);
    try std.testing.expectEqual(count * prefix.len + right.len, copy.total_input);
}

pub fn contracts(comptime D: type, allocator: std.mem.Allocator) !void {
    const Raw = D.RawDeflateIncrementalFixedLiteralDecoder;
    try std.testing.expectEqual(error{ InvalidCloneStorage, OverlappingCloneStorage }, Raw.CloneError);
    try geometry(Raw, allocator);
    const fixed = try f.fixedMatch(allocator);
    defer fixed.deinit(allocator);
    try checkpoint(Raw, allocator, fixed, false, true);
    try checkpoint(Raw, allocator, fixed, false, false);
    const dynamic = try f.dynamicGenerations(allocator);
    defer dynamic.deinit(allocator);
    try checkpoint(Raw, allocator, dynamic, true, false);
    try wide(Raw, allocator);
}
