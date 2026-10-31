const std = @import("std");
const command = @import("../command_plan.zig");
const enc = @import("../command_encoding.zig");
const distance = @import("../distance.zig");
const history = @import("../../decoder/distance_history.zig");
const context = @import("../literal_context_split.zig");
const P = @import("../prepared_command_distance.zig");
const params = distance.Parameters.init(0, 15);

fn require(value: bool) error{ExactPreparedMismatch}!void {
    if (!value) return error.ExactPreparedMismatch;
}

pub const Fixture = struct {
    input: []u8,
    commands: []command.Command,
    pub fn deinit(self: Fixture, a: std.mem.Allocator) void {
        a.free(self.input);
        a.free(self.commands);
    }
};

pub fn fixture(a: std.mem.Allocator, count: usize) !Fixture {
    var len: usize = 16 + 3;
    for (0..count) |i| len += (if (i == 0) @as(usize, 0) else 1 + i % 3) + 2 + i % 7;
    const input = try a.alloc(u8, len);
    errdefer a.free(input);
    const commands = try a.alloc(command.Command, count + 1);
    errdefer a.free(commands);
    var position: usize = 0;
    var repeats: [4]usize = .{ 16, 15, 11, 4 };
    for (commands[0..count], 0..) |*item, i| {
        const inserts: usize = if (i == 0) 16 else 1 + i % 3;
        for (input[position..][0..inserts], 0..) |*byte, k| byte.* = @intCast('A' + (i * 11 + k * 7) % 52);
        const copies = 2 + i % 7;
        const code: usize = switch (i % 4) {
            0 => 0,
            1 => repeats[3] + 15,
            2 => 1,
            else => 11,
        };
        var physical: usize = if (code >= 16) code - 15 else undefined;
        if (code < 16) try history.resolveShortInto(@intCast(code), &repeats, &physical);
        const entry = enc.forLengths(inserts, copies, false).?;
        item.* = .{
            .insert_start = position,
            .insert_len = inserts,
            .copy_len = copies,
            .has_copy = true,
            .distance = physical,
            .hq_encoding = .{ .command_symbol = entry.symbol, .distance_code = code, .distance_parameters = params, .distance_encoding = if (code < 16) .{ .symbol = @intCast(code) } else distance.encodeWithFormat(physical, params, .standard).? },
        };
        position += inserts;
        for (0..copies) |_| {
            input[position] = input[position - physical];
            position += 1;
        }
        if (code != 0) history.push(&repeats, physical);
    }
    @memcpy(input[position..][0..3], "END");
    commands[count] = .{ .insert_start = position, .insert_len = 3, .copy_len = 258, .hq_encoding = .{ .command_symbol = enc.forLengths(3, 258, false).?.symbol, .distance_parameters = params } };
    return .{ .input = input, .commands = commands };
}

fn sameCommon(left: *const P.Prepared, right: *const P.Prepared, command_count: usize) !void {
    try require(left.ready and right.ready);
    try require(left.payload_extra_bits == right.payload_extra_bits);
    try require(std.mem.eql(u32, &left.command_frequencies, &right.command_frequencies));
    try require(std.mem.eql(u32, &left.distance_frequencies, &right.distance_frequencies));
    try require(std.mem.eql(u4, &left.command_lengths, &right.command_lengths));
    try require(std.mem.eql(u4, &left.distance_lengths, &right.distance_lengths));
    try require(std.mem.eql(u16, left.command_alphabet.symbols[0..left.command_alphabet.len], right.command_alphabet.symbols[0..right.command_alphabet.len]));
    try require(std.mem.eql(u16, left.distance_alphabet.symbols[0..left.distance_alphabet.len], right.distance_alphabet.symbols[0..right.distance_alphabet.len]));
    for (left.command_alphabet.symbols[0..left.command_alphabet.len]) |symbol| {
        try require(left.command_encoder.codes[symbol] == right.command_encoder.codes[symbol] and left.command_encoder.bits[symbol] == right.command_encoder.bits[symbol]);
    }
    for (left.distance_alphabet.symbols[0..left.distance_alphabet.len]) |symbol| {
        try require(left.distance_encoder.codes[symbol] == right.distance_encoder.codes[symbol] and left.distance_encoder.bits[symbol] == right.distance_encoder.bits[symbol]);
    }
    if (command_count <= P.symbol_capacity) try require(std.mem.eql(u16, left.command_symbols[0..command_count], right.command_symbols[0..command_count]));
}

fn expectedCounts(comptime Br: type, common: *const P.Prepared, commands: []const command.Command, options: Br.ExactPreparedTestSupport.Options) !void {
    const S = Br.ExactPreparedTestSupport;
    var commands_hist: [704]u32 = @splat(0);
    var distances_hist: [79]u32 = @splat(0);
    var extra: u64 = 0;
    var repeats = options.starting_last_distances;
    for (commands, 0..) |item, index| {
        const physical = if (item.has_copy) try S.wireDistance(item, options.window_bits, options.compound_dictionary_size, options.initial_output_pos) else 0;
        const selected = (try S.resolve(item, physical, options.distance_parameters, repeats, .standard)).?;
        commands_hist[selected.command.symbol] += 1;
        extra += selected.command.command.insert_extra_bits + @as(u64, selected.command.command.copy_extra_bits);
        if (selected.distance) |encoded| {
            distances_hist[encoded.symbol] += 1;
            extra += encoded.extra_bits;
        }
        if (commands.len <= P.symbol_capacity) try require(common.command_symbols[index] == selected.command.symbol);
        repeats = selected.repeated_distances;
    }
    try require(common.payload_extra_bits == extra and std.mem.eql(u32, &commands_hist, &common.command_frequencies) and std.mem.eql(u32, &distances_hist, &common.distance_frequencies));
}

pub fn compatibility(comptime Br: type, a: std.mem.Allocator, count: usize) !void {
    const S = Br.ExactPreparedTestSupport;
    const data = try fixture(a, count);
    defer data.deinit(a);
    const immutable_input = try a.dupe(u8, data.input);
    defer a.free(immutable_input);
    const immutable_commands = try a.dupe(command.Command, data.commands);
    defer a.free(immutable_commands);
    var options: S.Options = .{ .use_recent_distances = true, .optimize_same_last_distance = false };
    var common = S.Common.init(options, data.commands);
    options.prepared_common = &common;
    var stats: S.Stats = .{};
    const first = try S.write(a, data.input, data.commands, null, &stats, options);
    defer a.free(first);
    try expectedCounts(Br, &common, data.commands, options);
    const saved = common;
    for (0..4) |mode| {
        options.literal_context_candidate = if (mode == 0) null else context.Candidate.suffix(@intCast(mode - 1), 56, 0);
        options.optimize_literal_tree_wire = mode == 3;
        var plain_options = options;
        plain_options.prepared_common = null;
        var cold_stats: S.Stats = .{};
        var warm_stats: S.Stats = .{};
        const cold = try S.write(a, data.input, data.commands, null, &cold_stats, plain_options);
        defer a.free(cold);
        const warm = try S.write(a, data.input, data.commands, null, &warm_stats, options);
        defer a.free(warm);
        try require(std.mem.eql(u8, cold, warm));
        try require(std.meta.eql(cold_stats, warm_stats));
        var literal: S.Literal = undefined;
        try S.capture(a, data.input, data.commands, options, &literal);
        const emitted = try S.emit(a, data.input, data.commands, options, &literal);
        defer a.free(emitted);
        try require(std.mem.eql(u8, cold, emitted));
        const guarded = try a.alloc(u8, warm.len + 32);
        defer a.free(guarded);
        @memset(guarded, 0xa5);
        const written = try S.writeInto(a, guarded[16 .. 16 + warm.len], data.input, data.commands, &stats, options);
        try require(written == warm.len and std.mem.eql(u8, warm, guarded[16 .. 16 + written]));
        for (guarded[0..16]) |byte| try require(byte == 0xa5);
        for (guarded[16 + written ..]) |byte| try require(byte == 0xa5);
        const decoded = try Br.decodeStreamAllocExactSize(a, emitted, data.input.len);
        defer a.free(decoded);
        try require(std.mem.eql(u8, data.input, decoded));
        try sameCommon(&saved, &common, data.commands.len);
        var rebuilt = S.Common.init(plain_options, data.commands);
        plain_options.prepared_common = &rebuilt;
        const independent = try S.write(a, data.input, data.commands, null, &stats, plain_options);
        defer a.free(independent);
        try require(std.mem.eql(u8, independent, cold));
        try sameCommon(&saved, &rebuilt, data.commands.len);
    }
    // Dirty scratch is never read after reset; the next cold pass reinitializes
    // every published histogram/codebook and exact cached command symbol.
    common.reset();
    common.command_frequencies = @splat(0xa5a5a5a5);
    common.distance_frequencies = @splat(0x5a5a5a5a);
    const clean = try S.write(a, data.input, data.commands, null, &stats, options);
    defer a.free(clean);
    try sameCommon(&saved, &common, data.commands.len);
    try require(std.mem.eql(u8, immutable_input, data.input));
    for (immutable_commands, data.commands) |before, after| try require(std.meta.eql(before, after));
}

pub fn keys(comptime Br: type, a: std.mem.Allocator) !void {
    const S = Br.ExactPreparedTestSupport;
    const data = try fixture(a, 32);
    defer data.deinit(a);
    var options: S.Options = .{ .use_recent_distances = true };
    var common = S.Common.init(options, data.commands);
    options.prepared_common = &common;
    var stats: S.Stats = .{};
    const wire = try S.write(a, data.input, data.commands, null, &stats, options);
    defer a.free(wire);
    try require(common.matches(options, data.commands));
    var changed = options;
    // Literal history changes recollected literal context histograms, not the
    // command/distance preparation. It is not synthetic frame history here.
    changed.initial_previous = .{ 'x', 'y' };
    try require(common.matches(changed, data.commands));
    changed = options;
    changed.initial_output_pos += 17;
    try require(!common.matches(changed, data.commands));
    changed = options;
    changed.window_bits += 1;
    try require(!common.matches(changed, data.commands));
    changed = options;
    changed.compound_dictionary_size += 1;
    try require(!common.matches(changed, data.commands));
    changed = options;
    changed.starting_last_distances[0] += 1;
    try require(!common.matches(changed, data.commands));
    changed = options;
    changed.optimize_same_last_distance = false;
    try require(!common.matches(changed, data.commands));
    changed = options;
    changed.use_recent_distances = false;
    try require(!common.matches(changed, data.commands));
    changed = options;
    changed.distance_parameters = distance.Parameters.init(0, 0);
    try require(!P.supported(changed, true));
    changed = options;
    changed.large_window = true;
    try require(!P.supported(changed, true));
    changed = options;
    changed.write_stream_prefix = false;
    try require(!P.supported(changed, true));
    changed = options;
    changed.final_meta_block = false;
    try require(!P.supported(changed, true));
    changed = options;
    changed.metadata = "cache scope";
    try require(!P.supported(changed, true));
    var model: @import("../hq_parser/prices.zig").Model = .{};
    changed = options;
    changed.hq_model_output = &model;
    try require(!P.supported(changed, true));
    var final_state: std.meta.Child(@typeInfo(@FieldType(S.Options, "final_wire_state")).optional.child) = .{};
    changed = options;
    changed.final_wire_state = &final_state;
    try require(!P.supported(changed, true));
    try require(!common.matches(options, data.commands[0 .. data.commands.len - 1]));
    const other = try a.dupe(command.Command, data.commands);
    defer a.free(other);
    try require(!common.matches(options, other));
    var literal: S.Literal = undefined;
    try S.capture(a, data.input, data.commands, options, &literal);
    changed = options;
    changed.window_bits += 1;
    if (S.emit(a, data.input, data.commands, changed, &literal)) |bad| {
        a.free(bad);
        return error.ExactPreparedMismatch;
    } else |err| try require(err == error.InvalidBlockPlan);
}

pub fn dictionaries(comptime Br: type, a: std.mem.Allocator) !void {
    const S = Br.ExactPreparedTestSupport;
    const word = @import("../../static_dictionary.zig").baseWord(4, 0).?;
    for ([_]command.Source{ .static, .compound }) |source| {
        var input: [7]u8 = undefined;
        @memcpy(input[0..4], if (source == .static) word else "aaaa");
        @memcpy(input[4..], "END");
        var options: S.Options = .{ .use_recent_distances = true, .compound_dictionary_size = if (source == .compound) 4 else 0 };
        const physical: usize = if (source == .static) 1 else 4;
        const commands = [_]command.Command{
            .{ .insert_start = 0, .insert_len = 0, .copy_len = 4, .source = source, .has_copy = true, .dictionary_output_len = if (source == .static) 4 else 0, .dictionary_address = 0, .hq_encoding = .{ .command_symbol = enc.forLengths(0, 4, false).?.symbol, .distance_code = physical + 15, .distance_parameters = params, .distance_encoding = distance.encodeWithFormat(physical, params, .standard).? } },
            .{ .insert_start = 4, .insert_len = 3, .copy_len = 258, .hq_encoding = .{ .command_symbol = enc.forLengths(3, 258, false).?.symbol, .distance_parameters = params } },
        };
        const selection = (try S.resolve(commands[0], physical, params, options.starting_last_distances, .standard)).?;
        var expected_repeats = options.starting_last_distances;
        if (source == .compound) history.push(&expected_repeats, physical);
        try require(std.mem.eql(usize, &selection.repeated_distances, &expected_repeats));
        var stats: S.Stats = .{};
        const cold = try S.write(a, &input, &commands, null, &stats, options);
        defer a.free(cold);
        var common = S.Common.init(options, &commands);
        options.prepared_common = &common;
        const primed = try S.write(a, &input, &commands, null, &stats, options);
        defer a.free(primed);
        try require(common.ready and std.mem.eql(u8, cold, primed));
        try expectedCounts(Br, &common, &commands, options);
        var literal: S.Literal = undefined;
        try S.capture(a, &input, &commands, options, &literal);
        const emitted = try S.emit(a, &input, &commands, options, &literal);
        defer a.free(emitted);
        try require(std.mem.eql(u8, cold, emitted));
        const decoded = try Br.decodeStreamAllocExactSizeWithOptions(a, emitted, input.len, .{
            .shared_dictionary = .{ .raw_prefixes = if (source == .compound) &.{"aaaa"} else &.{} },
        });
        defer a.free(decoded);
        try require(std.mem.eql(u8, &input, decoded));
    }
}
