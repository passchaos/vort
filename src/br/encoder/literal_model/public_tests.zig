//! Public full-wire gold and scope controls for literal-model reuse.
const std = @import("std");
const a = std.testing.allocator;

const Fixture = struct { name: []const u8, input: []const u8, wire: []const u8, input_sha256: []const u8, wire_sha256: []const u8, target: bool };
const fixtures = [_]Fixture{
    .{
        .name = "mozilla",
        .input = @embedFile("testdata/mozilla-64k.plain"),
        .wire = @embedFile("testdata/mozilla-64k.br"),
        .input_sha256 = "b0050240663f54371d372303eeaba0a59ab0758bcd565f4f639d06561e6bc996",
        .wire_sha256 = "29686649968e0dadd3dec91675d545298aa37fbbb58c00e3b6277881f9a6d2eb",
        .target = true,
    },
    .{
        .name = "xray",
        .input = @embedFile("testdata/xray-64k.plain"),
        .wire = @embedFile("testdata/xray-64k.br"),
        .input_sha256 = "b5a07146616bcd7c2d10071d41e07d204de0ac629c4ca37d8e867ff00574d0d8",
        .wire_sha256 = "53c68176c0cb8c2ffd1759afa6f786fc277750d1108fe12037c822e0d19df288",
        .target = true,
    },
    .{
        .name = "nci",
        .input = @embedFile("testdata/nci-64k.plain"),
        .wire = @embedFile("testdata/nci-64k.br"),
        .input_sha256 = "b01b411ac3b5ce2fbf37242c0c59d2d236d2f7039937c1b1a0f18f4cc02549fe",
        .wire_sha256 = "5e82ff1682e22f8b9e9bbe0f06f49e43b6679bcc736f691a24261295a1d13615",
        .target = false,
    },
    .{
        .name = "xml",
        .input = @embedFile("testdata/xml-64k.plain"),
        .wire = @embedFile("testdata/xml-64k.br"),
        .input_sha256 = "e32aff2bebf00105a17dd57f5490c1986d17543cee837b42eb56b3e0e6f8e7f1",
        .wire_sha256 = "e6446e2083669a87277a22328ceae0f3a3b4e227129c401c10bde2f110d28658",
        .target = false,
    },
};

pub fn run(comptime Api: type) !void {
    try realGold(Api);
    try scopes(Api);
}

fn realGold(comptime Api: type) !void {
    const options: Api.PublicOptions = .{ .quality = 8, .window_bits = 16 };
    var target_hits: usize = 0;
    for (fixtures) |fixture| {
        try std.testing.expectEqual(@as(usize, 65536), fixture.input.len);
        try sha(fixture.input, fixture.input_sha256);
        try sha(fixture.wire, fixture.wire_sha256);
        const old = try Api.encodePublic(a, fixture.input, options, true);
        defer a.free(old.wire);
        const shared = try Api.encodePublic(a, fixture.input, options, false);
        defer a.free(shared.wire);
        try std.testing.expectEqualSlices(u8, fixture.wire, old.wire);
        try std.testing.expectEqualSlices(u8, fixture.wire, shared.wire);
        try std.testing.expectEqual(@as(usize, 0), old.groups);
        try noCounters(old.counters);
        for ([_][]const u8{ fixture.wire, old.wire, shared.wire }) |wire| {
            const decoded = try Api.decode(a, wire);
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, fixture.input, decoded);
        }
        try sha(fixture.input, fixture.input_sha256);
        if (fixture.target and shared.groups > 0 and shared.counters.hits > 0) target_hits += 1;
        std.debug.print("literal_model_public corpus={s} wire_bytes={d} groups={d} hits={d} builds={d} misses={d}\n", .{
            fixture.name, shared.wire.len, shared.groups, shared.counters.hits, shared.counters.builds, shared.counters.misses,
        });
    }
    // No fallback-only pass: Mozilla or Xray must execute a real group and
    // consume at least one literal model produced by an earlier candidate.
    try std.testing.expect(target_hits > 0);
}

fn scopes(comptime Api: type) !void {
    const mozilla = fixtures[0].input;
    var options: Api.PublicOptions = .{ .quality = 8, .window_bits = 16 };
    const short = [_][]const u8{ "", "abcd0abcd1abcd2abcd3abcd4abcd5abcd6abcd7" };
    for (short) |input| try oldRoute(Api, input, options, true);
    var opaque_bytes: [1024]u8 = undefined;
    var state: u32 = 0x2a15f701;
    for (&opaque_bytes) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
    try oldRoute(Api, &opaque_bytes, options, true);
    options.window_bits = null;
    try oldRoute(Api, mozilla, options, true);
    options = .{ .quality = 4, .window_bits = 16 };
    try oldRoute(Api, mozilla, options, true);
    options = .{ .quality = 11, .window_bits = 16, .command_state_max_input_kib = 8 };
    try oldRoute(Api, mozilla[0..8192], options, true);
    options = .{ .level = .ratio, .window_bits = 16 };
    try oldRoute(Api, mozilla[0..8192], options, true);
    options = .{ .quality = 8, .window_bits = 16, .metadata = "literal model scope control" };
    try oldRoute(Api, mozilla[0..8192], options, true);
    options = .{ .quality = 8, .window_bits = 16, .mode = .text };
    try oldRoute(Api, mozilla[0..8192], options, true);
    options = .{ .quality = 8, .window_bits = 16, .large_window = true };
    // The supplied public decoder retains its standard-window policy. Compare
    // complete extension wires and group exclusion without a fake wide decode.
    try oldRoute(Api, mozilla[0..8192], options, false);
    options = .{
        .quality = 10,
        .window_bits = 16,
        .command_state_max_input_kib = 8,
        .hq = .{ .search_depth = 8, .nice_len = 16, .beam_width = 1, .iterations = 1, .block_len = 4096 },
    };
    try oldRoute(Api, short[1], options, true);
    var ascii: [8192]u8 = undefined;
    const ascii_phrase = "literal model excludes shared dictionaries\n";
    for (&ascii, 0..) |*byte, index| byte.* = ascii_phrase[index % ascii_phrase.len];
    options = .{ .quality = 8, .window_bits = 16, .shared_dictionary = .{ .raw_prefixes = &.{"\x00"} } };
    // A zero RAW prefix cannot match this nonzero ASCII fixture. This checks
    // the shared-dictionary route, not shared-dictionary match semantics.
    try oldRoute(Api, &ascii, options, true);
}

fn oldRoute(comptime Api: type, input: []const u8, options: Api.PublicOptions, decode: bool) !void {
    const old = try Api.encodePublic(a, input, options, true);
    defer a.free(old.wire);
    const shared = try Api.encodePublic(a, input, options, false);
    defer a.free(shared.wire);
    try std.testing.expectEqualSlices(u8, old.wire, shared.wire);
    try std.testing.expectEqual(@as(usize, 0), old.groups);
    try std.testing.expectEqual(@as(usize, 0), shared.groups);
    try noCounters(old.counters);
    try noCounters(shared.counters);
    if (decode) {
        const decoded = try Api.decode(a, shared.wire);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

fn noCounters(counters: anytype) !void {
    inline for (comptime std.meta.fieldNames(@TypeOf(counters))) |field|
        try std.testing.expectEqual(@as(usize, 0), @field(counters, field));
}

fn sha(bytes: []const u8, hex: []const u8) !void {
    var expected: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&expected, hex);
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
    try std.testing.expectEqualSlices(u8, &expected, &actual);
}
