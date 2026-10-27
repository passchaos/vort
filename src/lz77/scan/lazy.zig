//! One lazy parser shared by the original backwards and indexed match sources.
const std = @import("std");
const Index = @import("byte_index.zig").Index;
const PrefixIndex = @import("prefix_index.zig").Index;

pub fn reverse(tokens: anytype, allocator: std.mem.Allocator, input: []const u8, options: anytype, initial_stats: anytype, comptime Context: type) !@TypeOf(initial_stats) {
    return parse(tokens, allocator, input, options, initial_stats, Context, {});
}

pub fn indexed(tokens: anytype, allocator: std.mem.Allocator, input: []const u8, options: anytype, initial_stats: anytype, comptime Context: type) !@TypeOf(initial_stats) {
    // Bounded stack scratch; no new heap allocation or changed token ownership.
    var index = Index{};
    return parse(tokens, allocator, input, options, initial_stats, Context, &index);
}

pub fn prefixed(tokens: anytype, allocator: std.mem.Allocator, input: []const u8, options: anytype, initial_stats: anytype, comptime Context: type) !@TypeOf(initial_stats) {
    var index = PrefixIndex{};
    return parse(tokens, allocator, input, options, initial_stats, Context, &index);
}

fn search(index: anytype, input: []const u8, pos: usize, options: anytype, comptime Context: type) @TypeOf(Context.reverse(input, pos, options)) {
    if (comptime @TypeOf(index) == void) return Context.reverse(input, pos, options);
    index.advance(input, pos);
    if (comptime @TypeOf(index) == *PrefixIndex) return Context.prefixed(index, input, pos, options);
    return Context.indexed(index, input, pos, options);
}

fn parse(tokens: anytype, allocator: std.mem.Allocator, input: []const u8, options: anytype, initial_stats: anytype, comptime Context: type, index: anytype) !@TypeOf(initial_stats) {
    tokens.clearRetainingCapacity();
    var stats = initial_stats;
    var pos: usize = 0;
    while (pos < input.len) {
        const best = search(index, input, pos, options, Context);
        if (!Context.accept(input, pos, best.length, best.distance, options)) {
            try tokens.append(allocator, .{ .literal = input[pos] });
            stats.literals += 1;
            pos += 1;
            continue;
        }
        if (pos + 1 < input.len) {
            const next = search(index, input, pos + 1, options, Context);
            if (next.length >= best.length + options.lazy_min_gain and Context.accept(input, pos + 1, next.length, next.distance, options)) {
                try tokens.append(allocator, .{ .literal = input[pos] });
                stats.literals += 1;
                pos += 1;
                continue;
            }
        }
        try tokens.append(allocator, .{ .match = .{ .length = @intCast(best.length), .distance = @intCast(best.distance) } });
        stats.matches += 1;
        stats.matched_bytes += best.length;
        pos += best.length;
    }
    return stats;
}
