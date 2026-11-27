//! Actual adaptive -> joint producer and borrowed consumer wire oracles.
//! No fabricated plans: corpus commands use the real lazy planner, while the
//! established off-grid positive uses a legal terminal literal-only command.
const std = @import("std");
const gpa = std.testing.allocator;

const Fixture = struct { name: []const u8, input: []const u8 };
const fixtures = [_]Fixture{
    .{ .name = "mozilla", .input = @embedFile("literal_model/testdata/mozilla-64k.plain") },
    .{ .name = "xray", .input = @embedFile("literal_model/testdata/xray-64k.plain") },
    .{ .name = "nci", .input = @embedFile("literal_model/testdata/nci-64k.plain") },
    .{ .name = "xml", .input = @embedFile("literal_model/testdata/xml-64k.plain") },
};

pub fn run(comptime Codec: type) !void {
    var corpus_nonnull: usize = 0;
    for (fixtures) |fixture| {
        const plan = try Codec.buildCommands(gpa, fixture.input);
        defer plan.deinit(gpa);
        const counters = try oracle(Codec, fixture.name, fixture.input, plan.commands, false);
        corpus_nonnull += @intFromBool(counters.joint_hits > counters.joint_null_hits);
    }
    std.debug.print("split_plan_joint real_lazy_corpus_nonnull={d}/4\n", .{corpus_nonnull});
    if (corpus_nonnull == 0)
        std.debug.print("split_plan_joint corpus has no non-null hit; established off-grid literal-only positive follows\n", .{});

    // Same geometry as the existing adaptive literal off-grid non-cyclic test.
    // Periodic32 bytes would be mostly removed by lazy matching, so keep all
    // 8192 literal symbols explicitly instead of pretending this is a parser
    // positive. The original adaptive and joint choosers still build the plans.
    var input: [8192]u8 = undefined;
    fillOffGrid(&input);
    const commands = [_]Codec.Command{.{ .insert_start = 0, .insert_len = input.len }};
    _ = try oracle(Codec, "off-grid-literal-only", &input, &commands, true);
}

fn fillOffGrid(input: []u8) void {
    const boundaries = [_]usize{ 901, 2305, 5179, 7001 };
    const regions = [_]usize{ 0, 1, 0, 2, 0 };
    const bases = [_]u8{ 0, 96, 192 };
    var region: usize = 0;
    for (input, 0..) |*byte, index| {
        if (region < boundaries.len and index == boundaries[region]) region += 1;
        byte.* = bases[regions[region]] + @as(u8, @intCast(index & 31));
    }
}

fn roundTrip(comptime Codec: type, input: []const u8, wire: []const u8) !void {
    const decoded = try Codec.decode(gpa, wire);
    defer gpa.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

fn oracle(
    comptime Codec: type,
    name: []const u8,
    input: []const u8,
    commands: []const Codec.Command,
    require_nonnull: bool,
) !Codec.Counters {
    const options: Codec.WireOptions = .{
        .try_adaptive_literal_split = true,
        .try_joint_literal_contexts = true,
        .try_literal_contexts = true,
        .try_clustered_literal_contexts = true,
        .try_recent_distances = true,
        .force_recent_distances = true,
        .window_bits = 16,
    };
    var expected_stats: Codec.Stats = .{};
    const expected = try Codec.encodeLower(gpa, input, commands, options, null, &expected_stats);
    defer gpa.free(expected);
    try roundTrip(Codec, input, expected);

    var owner = Codec.Owner.init(input, commands, 64 * 1024);
    defer owner.deinit(gpa);
    var cold_stats: Codec.Stats = .{};
    const cold = try Codec.encodeLower(gpa, input, commands, options, &owner, &cold_stats);
    defer gpa.free(cold);
    try std.testing.expectEqualSlices(u8, expected, cold);
    try std.testing.expectEqualDeep(expected_stats, cold_stats);
    try roundTrip(Codec, input, cold);
    const after_cold = owner.counters;

    var warm_stats: Codec.Stats = .{};
    const warm = try Codec.encodeLower(gpa, input, commands, options, &owner, &warm_stats);
    defer gpa.free(warm);
    try std.testing.expectEqualSlices(u8, expected, warm);
    try std.testing.expectEqualDeep(expected_stats, warm_stats);
    try roundTrip(Codec, input, warm);
    const before_deinit = owner.counters;
    try std.testing.expect(before_deinit.joint_null_hits <= before_deinit.joint_hits);
    if (after_cold.joint_captures != 0)
        try std.testing.expect(before_deinit.joint_hits > after_cold.joint_hits);
    if (require_nonnull) {
        // Counter hits are produced only by encodeLower's actual getJoint path;
        // hits > null_hits requires a real non-null chooser result/consumer.
        try std.testing.expect(before_deinit.joint_captures > 0);
        try std.testing.expect(before_deinit.joint_hits > 0);
        try std.testing.expect(before_deinit.joint_hits > before_deinit.joint_null_hits);
        try std.testing.expectEqual(@as(usize, 0), before_deinit.cap_refusals);
    }
    var literal_count: usize = 0;
    for (commands) |command| literal_count += command.insert_len;
    std.debug.print("split_plan_joint case={s} input={d} commands={d} literals={d} joint_captures={d} joint_hits={d} joint_null_hits={d} retained={d}\n", .{
        name,                     input.len,                     commands.len,                   literal_count, before_deinit.joint_captures,
        before_deinit.joint_hits, before_deinit.joint_null_hits, owner.retainedRequestedBytes(),
    });
    owner.deinit(gpa);
    try std.testing.expectEqual(@as(usize, 0), owner.retainedRequestedBytes());
    try std.testing.expectEqual(@as(usize, 0), owner.counters.retained_payload_bytes);
    return before_deinit;
}
