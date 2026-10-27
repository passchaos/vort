//! Public q8/generic wire regression consumer. Import from a root under src/.
const std = @import("std");
const br = @import("../br.zig");
const checksum = @import("../checksum.zig");
const command_plan = @import("../br/encoder/command_plan.zig");
const distance = @import("../br/encoder/distance.zig");
const prepared = @import("../br/encoder/prepared_command_distance.zig");
const core = @import("../core.zig");

var input: [65536]u8 = undefined;
var wire: []u8 = &.{};
var command_count: u32 = 0;
var command_entries: u32 = 0;
var complex_command_trees: u32 = 0;
var recent_copies: u32 = 0;
var shared_group_witnesses: u32 = 0;

fn fillInput() void {
    var state: u32 = 0x243f_6a88;
    var position: usize = 0;
    var record: usize = 0;
    const repeated = " repeated common value: the quick brown fox jumps over the lazy dog";
    while (position < input.len) : (record += 1) {
        // Four consecutive records have the same span, creating reusable recent
        // distances; group lengths still vary to require complex command trees.
        const group = record / 4;
        for (0..4 + group % 19) |_| {
            if (position == input.len) break;
            state = state *% 1664525 +% 1013904223;
            const random: u8 = @truncate(state >> 24);
            input[position] = if (record & 1 == 0) 128 | (random & 63) else 'a' + random % 26;
            position += 1;
        }
        for (0..16 + (group * 7) % 48) |index| {
            if (position == input.len) break;
            input[position] = repeated[index];
            position += 1;
        }
    }
}

export fn brPreparedWideKeySmoke() callconv(.c) u32 {
    var commands = [_]command_plan.Command{.{ .insert_start = 0, .insert_len = 1 }};
    const wide: core.StreamCount = (@as(core.StreamCount, 1) << 32) + 17;
    const Options = struct {
        window_bits: u5 = 16,
        distance_parameters: distance.Parameters = distance.Parameters.init(0, 15),
        compound_dictionary_size: usize = 0,
        initial_output_pos: core.StreamCount,
        starting_last_distances: [4]usize = .{ 16, 15, 11, 4 },
        use_recent_distances: bool = true,
        optimize_same_last_distance: bool = true,
    };
    var options: Options = .{ .initial_output_pos = wide };
    const key = prepared.Key.init(options, &commands);
    if (key.initial_output_pos != wide or !key.matches(options, &commands)) return 1;
    options.initial_output_pos = 17;
    if (key.matches(options, &commands)) return 2;
    return 0;
}

export fn brPreparedEncodeSmoke() callconv(.c) u32 {
    const allocator = std.heap.page_allocator;
    if (wire.len != 0) allocator.free(wire);
    wire = &.{};
    fillInput();
    const encoded = br.encodePlannedStreamWithOptionsAlloc(allocator, &input, .{ .quality = 8, .mode = .generic }) catch return 1;
    var retained = false;
    defer if (!retained) allocator.free(encoded);
    const decoded = br.decodeStreamAllocExactSize(allocator, encoded, input.len) catch return 2;
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, &input, decoded)) return 3;
    const summary = br.summarizeStreamAlloc(allocator, encoded) catch return 4;
    command_count = @intCast(summary.command_count);
    recent_copies = @intCast(summary.implicit_distance_copy_count + summary.short_distance_copy_count);
    if (summary.window_bits != 16 or command_count <= 128 or recent_copies == 0) return 5;

    const io = std.Io.Threaded.global_single_threaded.io();
    const headers = br.profileCompressedHeaders(io, allocator, encoded, 1) catch return 6;
    const family = headers.families[@intFromEnum(br.CompressedHeaderFamily.command)];
    command_entries = @intCast(family.active_entries);
    complex_command_trees = @intCast(family.complex_trees);
    if (command_entries <= 4 or complex_command_trees == 0) return 7;

    const profile = allocator.create(br.QualityQ8Profile) catch return 8;
    defer allocator.destroy(profile);
    profile.* = .{};
    const profiled = br.benchmarkQualityQ8ProfileAlloc(allocator, &input, io, profile) catch return 9;
    defer allocator.free(profiled);
    if (!std.mem.eql(u8, encoded, profiled)) return 10;
    if (profile.events_truncated or !profile.wire_attempt_coverage_complete) return 11;
    shared_group_witnesses = 0;
    const events = profile.recordedEvents();
    for (events) |group| {
        if (group.stage != .preferred_context or group.command_count <= 128) continue;
        var eligible: usize = 0;
        for (events) |event| {
            if (event.stage != .wire or event.parent_id != group.id) continue;
            const config = event.config;
            if (event.command_count != group.command_count or !config.use_recent_distances or config.large_window or
                config.npostfix != 0 or config.ndirect_high != 15 or config.context_trees < 2 or
                config.literal_split or config.adaptive_literal_split or config.joint_literal_contexts or
                config.command_split or config.adaptive_command_split or config.distance_split or config.adaptive_distance_split)
                continue;
            eligible += 1;
        }
        if (eligible >= 2) shared_group_witnesses += 1;
    }
    if (shared_group_witnesses == 0) return 12;
    wire = encoded;
    retained = true;
    return 0;
}

export fn brPreparedInputPtr() callconv(.c) usize {
    return @intFromPtr(&input);
}
export fn brPreparedInputLen() callconv(.c) usize {
    return input.len;
}
export fn brPreparedWirePtr() callconv(.c) usize {
    return @intFromPtr(wire.ptr);
}
export fn brPreparedWireLen() callconv(.c) usize {
    return wire.len;
}
export fn brPreparedWireCrc32() callconv(.c) u32 {
    return checksum.crc32(wire);
}
export fn brPreparedCommandCount() callconv(.c) u32 {
    return command_count;
}
export fn brPreparedCommandEntries() callconv(.c) u32 {
    return command_entries;
}
export fn brPreparedComplexCommandTrees() callconv(.c) u32 {
    return complex_command_trees;
}
export fn brPreparedRecentCopies() callconv(.c) u32 {
    return recent_copies;
}
export fn brPreparedSharedGroupWitnesses() callconv(.c) u32 {
    return shared_group_witnesses;
}

test "Brotli prepared public wasm fixture exercises actual complex and shared candidate groups" {
    try std.testing.expectEqual(@as(u32, 0), brPreparedWideKeySmoke());
    const status = brPreparedEncodeSmoke();
    std.debug.print("prepared probe status={d} commands={d} entries={d} complex={d} recent={d} groups={d}\n", .{ status, command_count, command_entries, complex_command_trees, recent_copies, shared_group_witnesses });
    try std.testing.expectEqual(@as(u32, 0), status);
    std.heap.page_allocator.free(wire);
    wire = &.{};
}
