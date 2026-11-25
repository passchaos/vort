//! Full-stream integration for complex fixed block-length alphabets.
const std = @import("std");
const command_plan = @import("../command_plan.zig");
const literal = @import("../literal_block_split.zig");
const command = @import("../command_block_split.zig");
const distance = @import("../distance_block_split.zig");

pub const Dimension = enum { literal, command, distance };
const region_lengths = [_]usize{ 1, 5, 9, 17, 49, 113 };

pub fn split(comptime T: type, regions: usize) T {
    var ends: [5]usize = undefined;
    var count: usize = 0;
    for (0..5) |i| {
        count += region_lengths[i];
        ends[i] = count;
    }
    return .{
        .split = ends[0],
        .second_split = if (regions > 2) ends[1] else null,
        .third_split = if (regions > 3) ends[2] else null,
        .fourth_split = if (regions > 4) ends[3] else null,
        .fifth_split = if (regions > 5) ends[4] else null,
        .savings_bits = 0,
    };
}

fn exportWire(dimension: Dimension, regions: usize, input: []const u8, wire: []const u8) !void {
    const a = std.testing.allocator;
    const directory = std.testing.environ.getAlloc(a, "VORT_FIXED_LENGTH_EXPORT") catch |err| switch (err) {
        error.EnvironmentVariableMissing => return,
        else => return err,
    };
    defer a.free(directory);
    inline for (.{ .{ "plain", input }, .{ "br", wire } }) |part| {
        const name = try std.fmt.allocPrint(a, "{s}-{d}.{s}", .{ @tagName(dimension), regions, part[0] });
        defer a.free(name);
        const path = try std.fs.path.join(a, &.{ directory, name });
        defer a.free(path);
        try std.Io.Dir.cwd().writeFile(std.testing.io, .{ .sub_path = path, .data = part[1] });
    }
}

pub fn run(comptime Api: type) !void {
    inline for (.{ Dimension.literal, Dimension.command, Dimension.distance }) |dimension| {
        try runDimension(Api, dimension);
    }
}

fn runDimension(comptime Api: type, comptime dimension: Dimension) !void {
    const a = std.testing.allocator;
    for (5..7) |regions| {
        var symbol_count: usize = 0;
        for (region_lengths[0..regions]) |length| symbol_count += length;
        const input_len = if (dimension == .literal) symbol_count else 1 + 2 * symbol_count;
        const input = try a.alloc(u8, input_len);
        defer a.free(input);
        const commands = try a.alloc(command_plan.Command, if (dimension == .literal) 1 else symbol_count);
        defer a.free(commands);
        if (comptime dimension == .literal) {
            for (input, 0..) |*byte, i| byte.* = @truncate(i * 7 + 13);
            commands[0] = .{ .insert_start = 0, .insert_len = input.len };
        } else {
            @memset(input, 'a');
            for (commands, 0..) |*entry, i| entry.* = .{
                .insert_start = if (i == 0) 0 else 1 + 2 * i,
                .insert_len = if (i == 0) 1 else 0,
                .copy_len = 2,
                .distance = 1,
                .has_copy = true,
            };
        }
        const wire = try Api.encode(a, input, commands, dimension, regions);
        defer a.free(wire);
        const info = try Api.summary(a, wire);
        const types = switch (dimension) {
            .literal => info.max_literal_block_types,
            .command => info.max_command_block_types,
            .distance => info.max_distance_block_types,
        };
        try std.testing.expectEqual(@as(usize, regions), types);
        const decoded = try Api.decode(a, wire, input.len);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        try exportWire(dimension, regions, input, wire);
    }
}

pub const LiteralSplit = literal.Result;
pub const CommandSplit = command.Result;
pub const DistanceSplit = distance.Result;
