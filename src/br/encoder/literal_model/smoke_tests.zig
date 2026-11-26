const std = @import("std");
const context = @import("../literal_context_split.zig");
const literal_context = @import("../literal_context.zig");

pub fn run(comptime Api: type) !void {
    const allocator = std.testing.allocator;
    var input: [8192]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = 'a' + @as(u8, @intCast(index % 8));
    const commands = [_]Api.Command{.{
        .insert_start = 0,
        .insert_len = 8,
        .copy_len = input.len - 8,
        .distance = 8,
        .has_copy = true,
    }};
    var owner = Api.Owner.init(&input, &commands);
    defer owner.deinit(allocator);
    var options = Api.Options{
        .window_bits = 16,
        .literal_context_candidate = context.Candidate.suffix(literal_context.mode_utf8, 56, 0),
    };
    var cold_stats: Api.Stats = .{};
    const cold = try Api.encode(allocator, &input, &commands, options, &cold_stats);
    defer allocator.free(cold);
    options.shared_literal_models = &owner;
    var capture_stats: Api.Stats = .{};
    const captured = try Api.encode(allocator, &input, &commands, options, &capture_stats);
    defer allocator.free(captured);
    try std.testing.expectEqualSlices(u8, cold, captured);
    try std.testing.expectEqualDeep(cold_stats, capture_stats);
    try std.testing.expectEqual(@as(usize, 1), owner.len);

    options.use_recent_distances = true;
    options.shared_literal_models = null;
    var reference_stats: Api.Stats = .{};
    const reference = try Api.encode(allocator, &input, &commands, options, &reference_stats);
    defer allocator.free(reference);
    options.shared_literal_models = &owner;
    var reused_stats: Api.Stats = .{};
    const reused = try Api.encode(allocator, &input, &commands, options, &reused_stats);
    defer allocator.free(reused);
    try std.testing.expectEqualSlices(u8, reference, reused);
    try std.testing.expectEqualDeep(reference_stats, reused_stats);
    try std.testing.expect(owner.counters.hits > 0);
    const decoded = try Api.decode(allocator, reused);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}
