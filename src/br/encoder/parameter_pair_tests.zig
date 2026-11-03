//! Candidate-level wire and publication tests for shared distance parameters.
const std = @import("std");
const fixtures = @import("parameter_pair_tests/fixtures.zig");
const oracle = @import("parameter_pair_tests/oracle.zig");
const distance = @import("distance.zig");
const context = @import("literal_context_split.zig");
const key_tests = @import("parameter_pair_tests/keys.zig");
const resource_tests = @import("parameter_pair_tests/resources.zig");

const parameters = [_]distance.Parameters{
    distance.Parameters.init(0, 0),  distance.Parameters.init(0, 15),
    distance.Parameters.init(1, 0),  distance.Parameters.init(1, 1),
    distance.Parameters.init(1, 15), distance.Parameters.init(3, 1),
    distance.Parameters.init(3, 15),
};

pub fn run(comptime C: type) !void {
    try wire(C);
    try keys(C);
    try resources(C);
}

pub fn wire(comptime C: type) !void {
    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(usize, 79), @typeInfo(@TypeOf(@as(C.Common, undefined).distance_lengths)).array.len);
    try std.testing.expectEqual(@as(usize, 520), @typeInfo(@TypeOf(@as(C.State, undefined).distance_lengths)).array.len);
    for (1..5) |symbols| {
        const data = try fixtures.small(allocator, symbols);
        defer data.deinit(allocator);
        var session: oracle.Session(C) = undefined;
        try session.init(allocator, data, .{});
        defer session.deinit(allocator);
        try std.testing.expectEqual(symbols, session.common.value.command_alphabet.len);
        try std.testing.expectEqual(@as(usize, 1), session.common.value.distance_alphabet.len);
        try std.testing.expectEqual(@as(usize, 1), session.literal.value.tree_count);
        try std.testing.expectEqual(symbols, session.literal.value.alphabets[0].len);
        for (parameters) |shape| try session.candidate(allocator, data, shape);
    }
    for ([_]usize{ 4, 5, 256 }) |alphabet| {
        const data = try fixtures.literalOnly(allocator, alphabet);
        defer data.deinit(allocator);
        var session: oracle.Session(C) = undefined;
        try session.init(allocator, data, .{});
        defer session.deinit(allocator);
        for (parameters) |shape| try session.candidate(allocator, data, shape);
    }
    for ([_]usize{ 127, 128, 129 }) |count| {
        const data = try fixtures.rich(allocator, count, true);
        defer data.deinit(allocator);
        var session: oracle.Session(C) = undefined;
        try session.init(allocator, data, .{ .window_bits = 16 });
        defer session.deinit(allocator);
        try std.testing.expect(session.common.value.command_alphabet.len > 4);
        try std.testing.expect(session.common.value.distance_alphabet.len > 4);
        if (count == 129) {
            // All 64 legal shapes; the production chooser and strict ties stay
            // intact. These independently emitted candidates include 79/520.
            for (0..4) |postfix| {
                for (0..16) |direct| {
                    try session.candidate(allocator, data, distance.Parameters.init(@intCast(postfix), @intCast(direct)));
                }
            }
        } else for (parameters) |shape| try session.candidate(allocator, data, shape);
    }
    const shallow = try fixtures.rich(allocator, 129, false);
    defer shallow.deinit(allocator);
    for ([_]C.Options{
        .{ .window_bits = 10 },
        .{ .window_bits = 24, .initial_output_pos = (@as(u64, 1) << 32) + 17, .initial_previous = .{ 13, 250 }, .starting_last_distances = .{ 64, 29, 11, 4 } },
        .{ .window_bits = 16, .initial_previous = .{ 0xe3, 0x80 }, .literal_context_candidate = context.Candidate.suffix(2, 56, 0) },
        .{ .window_bits = 16, .initial_previous = .{ 0xe0, 0xbf }, .use_utf8_text_contexts = true, .utf8_context_cutoff = 48, .literal_context_mode = 2 },
        .{ .window_bits = 16, .initial_previous = .{ '/', 0 }, .optimize_literal_tree_wire = true, .literal_context_mode = 3 },
    }) |options| {
        var session: oracle.Session(C) = undefined;
        try session.init(allocator, shallow, options);
        defer session.deinit(allocator);
        for (parameters) |shape| try session.candidate(allocator, shallow, shape);
    }
    for ([_]fixtures.Command.Source{ .compound, .static }) |source| {
        const data = try fixtures.dictionary(allocator, source);
        defer data.deinit(allocator);
        var session: oracle.Session(C) = undefined;
        try session.init(allocator, data, .{ .window_bits = 16, .compound_dictionary_size = 8, .initial_previous = .{ 17, 93 } });
        defer session.deinit(allocator);
        for (parameters) |shape| try session.candidate(allocator, data, shape);
    }
}

pub fn keys(comptime C: type) !void {
    try key_tests.check(C);
}

pub fn resources(comptime C: type) !void {
    try resource_tests.check(C);
}

pub fn controller(comptime C: type) !void {
    try @import("parameter_pair_tests/controller.zig").check(C);
}
