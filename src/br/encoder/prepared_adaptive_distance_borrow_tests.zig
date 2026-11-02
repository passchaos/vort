//! Borrowed command-model equivalence. All distance artifacts and projected
//! streams remain independent owned values; no root codec import is needed.
const std = @import("std");
const command_plan = @import("command_plan.zig");
const command_encoding = @import("command_encoding.zig");
const prepared_command = @import("prepared_command_distance.zig");
const distance = @import("distance.zig");
const split_plan = @import("block_split_plan.zig");
const prepared_literal = @import("prepared_literal.zig");
const huffman = @import("../../huffman.zig");
const bit_writer = @import("bit_writer.zig");
const counting_writer = @import("counting_writer.zig");

const BorrowOptions = struct {
    adaptive_distance_split: ?*const split_plan.Plan = null,
    window_bits: u5 = 16,
    large_window: bool = false,
    distance_parameters: distance.Parameters = distance.Parameters.init(0, 15),
    compound_dictionary_size: usize = 0,
    initial_output_pos: u64 = 0,
    starting_last_distances: [4]usize = .{ 16, 15, 11, 4 },
    use_recent_distances: bool = true,
    optimize_same_last_distance: bool = false,
    initial_previous: [2]u8 = .{ 0, 0 },
    literal_context_candidate: ?@import("literal_context_split.zig").Candidate = null,
    use_utf8_text_contexts: bool = false,
    literal_context_mode: u2 = 0,
    utf8_context_cutoff: u6 = 56,
    optimize_literal_tree_wire: bool = false,
    write_stream_prefix: bool = true,
    final_meta_block: bool = true,
    metadata: []const u8 = "",
};

const Strategy = struct {
    pub const Error = anyerror;
    pub const Options = BorrowOptions;
    pub fn supported(options: BorrowOptions, commands: []const command_plan.Command) bool {
        return options.adaptive_distance_split != null and options.use_recent_distances and !options.large_window and commands.len != 0;
    }
    pub fn wireDistance(command: command_plan.Command, _: u5, _: usize, _: u64) Error!usize {
        if (command.distance == 0) return error.InvalidBlockPlan;
        return command.distance;
    }
    pub fn recentDistance(value: usize, last: *[4]usize) ?u4 {
        for (last, 0..) |prior, index| if (value == prior) return @intCast(index);
        return null;
    }
    pub fn pushDistance(last: *[4]usize, value: usize) void {
        last.* = .{ value, last[0], last[1], last[2] };
    }
    pub fn literalEncoder(lengths: *const [256]u4, _: anytype) !huffman.HuffmanTable(256).Encoder {
        return huffman.HuffmanTable(256).Encoder.init(lengths);
    }
    pub fn header(allocator: std.mem.Allocator, writer: anytype, _: []const u8, _: BorrowOptions, common: anytype, _: *const prepared_literal.State) Error!void {
        // Serialize complete model contents so both pointer-backed and inline
        // accessors participate in an exact counted/physical wire comparison.
        const alphabet = common.commandAlphabet();
        try writer.writeBits(allocator, alphabet.len, 10);
        for (alphabet.symbols[0..alphabet.len]) |symbol| {
            try writer.writeBits(allocator, symbol, 10);
            try writer.writeBits(allocator, common.commandLengths()[symbol], 4);
        }
        for (common.distance_alphabets, common.distance_lengths) |*tree, *lengths| {
            try writer.writeBits(allocator, tree.len, 7);
            for (tree.symbols[0..tree.len]) |symbol| {
                try writer.writeBits(allocator, symbol, 7);
                try writer.writeBits(allocator, lengths[symbol], 4);
            }
        }
    }
};

fn explicitCount(commands: []const command_plan.Command, options: BorrowOptions) !usize {
    var last = options.starting_last_distances;
    var count: usize = 0;
    for (commands) |command| {
        const recent = if (command.has_copy) Strategy.recentDistance(command.distance, &last) else null;
        const encoding = command_encoding.forLengths(command.insert_len, command.copy_len, recent == 0) orelse
            command_encoding.forLengths(command.insert_len, command.copy_len, false) orelse return error.InvalidBlockPlan;
        if (command.has_copy and encoding.command.distance_code == -1) count += 1;
        if (command.has_copy and recent != 0) Strategy.pushDistance(&last, command.distance);
    }
    return count;
}

fn fixture(seed: usize, commands: []command_plan.Command, input: []u8) usize {
    var position: usize = 0;
    for (commands, 0..) |*command, index| {
        const inserted = 1 + (index + seed) % 12;
        const copied = 4 + (index * 7 + seed) % 24;
        command.* = .{
            .insert_start = position,
            .insert_len = inserted,
            .copy_len = copied,
            .distance = ([_]usize{ 5, 11, 65, 1025, 33, 23, 4, 15 })[(index + seed) % 8],
            .has_copy = true,
        };
        position += inserted + copied;
    }
    for (input[0..position], 0..) |*byte, index| byte.* = @intCast((index * 17 + seed) % 256);
    return position;
}

fn modelFromOwned(common: *prepared_command.Prepared, owned: anytype, options: BorrowOptions, commands: []const command_plan.Command) !void {
    common.* = prepared_command.Prepared.init(options, commands);
    var frequencies: [704]u32 = @splat(0);
    for (owned.command_symbols) |symbol| frequencies[symbol] += 1;
    var distance_frequencies: [79]u32 = @splat(0);
    distance_frequencies[0] = 1;
    var alphabet: command_plan.PrefixAlphabetFor(79) = undefined;
    try command_plan.alphabetFromFrequenciesInto(79, &alphabet, &distance_frequencies);
    const lengths: [79]u4 = @splat(0);
    try common.captureCounted(&frequencies, owned.commandAlphabet(), owned.commandLengths(), &distance_frequencies, &alphabet, &lengths, 0, null);
}

fn expectModel(expected: *const prepared_command.Prepared, actual: *const prepared_command.Prepared) !void {
    try std.testing.expectEqual(expected.ready, actual.ready);
    try std.testing.expectEqualDeep(expected.key, actual.key);
    try std.testing.expectEqual(expected.has_exact_commands, actual.has_exact_commands);
    try std.testing.expectEqualSlices(u32, &expected.command_frequencies, &actual.command_frequencies);
    try std.testing.expectEqual(expected.command_alphabet.len, actual.command_alphabet.len);
    try std.testing.expectEqualSlices(u16, expected.command_alphabet.symbols[0..expected.command_alphabet.len], actual.command_alphabet.symbols[0..actual.command_alphabet.len]);
    try std.testing.expectEqualSlices(u4, &expected.command_lengths, &actual.command_lengths);
    try expectEncoder(&expected.command_encoder, &actual.command_encoder, &expected.command_alphabet);
}

fn expectEncoder(expected: anytype, actual: @TypeOf(expected), alphabet: anytype) !void {
    // Sparse encoders initialize only their active code slots; small alphabets
    // use simpleCode instead of the encoder. Never inspect inactive storage.
    if (alphabet.len > 4) {
        for (alphabet.symbols[0..alphabet.len]) |symbol| {
            try std.testing.expectEqual(expected.codes[symbol], actual.codes[symbol]);
            try std.testing.expectEqual(expected.bits[symbol], actual.bits[symbol]);
        }
    }
}

fn expectPrepared(expected: anytype, actual: @TypeOf(expected)) !void {
    try std.testing.expectEqualSlices(u16, expected.command_symbols, actual.command_symbols);
    try std.testing.expectEqualDeep(expected.distance_encodings, actual.distance_encodings);
    try std.testing.expectEqual(expected.distance_count, actual.distance_count);
    try std.testing.expectEqual(expected.command_symbol_count, actual.command_symbol_count);
    try std.testing.expectEqual(expected.distance_symbol_count, actual.distance_symbol_count);
    try std.testing.expectEqual(expected.payload_bits, actual.payload_bits);
    try std.testing.expectEqual(expected.commandAlphabet().len, actual.commandAlphabet().len);
    try std.testing.expectEqualSlices(u16, expected.commandAlphabet().symbols[0..expected.commandAlphabet().len], actual.commandAlphabet().symbols[0..actual.commandAlphabet().len]);
    try std.testing.expectEqualSlices(u4, expected.commandLengths(), actual.commandLengths());
    try expectEncoder(expected.commandEncoder(), actual.commandEncoder(), expected.commandAlphabet());
    for (expected.distance_alphabets, actual.distance_alphabets) |*a, *b| {
        try std.testing.expect(a != b);
        try std.testing.expectEqual(a.len, b.len);
        try std.testing.expectEqualSlices(u16, a.symbols[0..a.len], b.symbols[0..b.len]);
    }
    try std.testing.expectEqualDeep(expected.distance_lengths, actual.distance_lengths);
    try std.testing.expect(expected.split_code.block_lengths.ptr != actual.split_code.block_lengths.ptr);
    try std.testing.expectEqualDeep(expected.split_code.block_lengths, actual.split_code.block_lengths);
    try std.testing.expectEqualSlices(u16, expected.split_code.type_model.symbols, actual.split_code.type_model.symbols);
    try std.testing.expectEqualSlices(u4, &expected.split_code.type_lengths, &actual.split_code.type_lengths);
    try std.testing.expectEqualSlices(u4, &expected.split_code.length_lengths, &actual.split_code.length_lengths);
    try std.testing.expectEqual(expected.context_map.tree_count, actual.context_map.tree_count);
    try std.testing.expectEqual(expected.context_map.contexts_per_type, actual.context_map.contexts_per_type);
    try std.testing.expectEqual(expected.context_map.bit_cost, actual.context_map.bit_cost);
    try std.testing.expectEqualSlices(u4, &expected.context_map.lengths, &actual.context_map.lengths);
    for (expected.distance_encoders, actual.distance_encoders, expected.distance_alphabets) |*a, *b, *alphabet| {
        try expectEncoder(a, b, alphabet);
    }
}

fn literalState(input: []const u8, commands: []const command_plan.Command, options: BorrowOptions) !prepared_literal.State {
    var frequencies: [256]u32 = @splat(0);
    for (commands) |command| for (input[command.insert_start..][0..command.insert_len]) |byte| {
        frequencies[byte] += 1;
    };
    var alphabet: prepared_literal.Alphabet = undefined;
    try command_plan.alphabetFromFrequenciesInto(256, &alphabet, &frequencies);
    const lengths = huffman.treeCodeLengths(256, &frequencies, 15);
    var state: prepared_literal.State = undefined;
    try state.capture(input, options, null, &.{alphabet}, &.{lengths}, 0, 0);
    return state;
}

fn wirePair(comptime Module: type, input: []const u8, commands: []const command_plan.Command, options: BorrowOptions, owned: *const Module.Prepared, borrowed: *const Module.Prepared) !void {
    const literals = try literalState(input, commands, options);
    var first: std.ArrayList(u8) = .empty;
    defer first.deinit(std.testing.allocator);
    var second: std.ArrayList(u8) = .empty;
    defer second.deinit(std.testing.allocator);
    var a: bit_writer.Writer = .{ .out = &first };
    var b: bit_writer.Writer = .{ .out = &second };
    try Module.write(Strategy, std.testing.allocator, &a, input, commands, options, owned, &literals);
    try Module.write(Strategy, std.testing.allocator, &b, input, commands, options, borrowed, &literals);
    try std.testing.expectEqualSlices(u8, first.items, second.items);
    var count_a = counting_writer.Writer.init(0);
    var count_b = counting_writer.Writer.init(0);
    try Module.write(Strategy, std.testing.allocator, &count_a, input, commands, options, owned, &literals);
    try Module.write(Strategy, std.testing.allocator, &count_b, input, commands, options, borrowed, &literals);
    try std.testing.expectEqual(try count_a.checkedBitPosition(), try count_b.checkedBitPosition());
    try std.testing.expectEqual(first.items.len, try count_b.checkedByteCount());
}

fn run(comptime Module: type, seed: usize) !void {
    var commands: [18]command_plan.Command = undefined;
    var input: [2048]u8 = undefined;
    const input_len = fixture(seed, &commands, &input);
    const commands_before = commands;
    var options: BorrowOptions = .{};
    const count = try explicitCount(&commands, options);
    const lengths = [_]u32{ @intCast(count / 2), @intCast(count - count / 2) };
    const types = [_]u8{ 0, 1 };
    const split = try split_plan.Plan.initCopy(std.testing.allocator, &lengths, &types, 2, count, 0);
    defer split.deinit(std.testing.allocator);
    options.adaptive_distance_split = &split;
    options.optimize_same_last_distance = seed & 1 != 0;
    Module.resetTestCounters();
    var owned = try Module.Prepared.init(Strategy, std.testing.allocator, &commands, options);
    defer owned.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), Module.testCounters().command_model_builds);
    var common: prepared_command.Prepared = undefined;
    try modelFromOwned(&common, &owned, options, &commands);
    const before = common;
    Module.resetTestCounters();
    var borrowed = try Module.Prepared.initBorrowedCommand(Strategy, std.testing.allocator, &commands, options, &common);
    var deinitialized = false;
    defer if (!deinitialized) borrowed.deinit(std.testing.allocator);
    try std.testing.expect(borrowed.commandAlphabet() == &common.command_alphabet);
    try std.testing.expect(borrowed.commandLengths() == &common.command_lengths);
    try std.testing.expect(borrowed.commandEncoder() == &common.command_encoder);
    try std.testing.expect(borrowed.matches(options, &commands));
    const counters = Module.testCounters();
    try std.testing.expectEqual(@as(usize, 1), counters.command_scans);
    try std.testing.expectEqual(@as(usize, 0), counters.command_model_builds);
    try std.testing.expectEqual(@as(usize, 1), counters.borrowed_command_models);
    try std.testing.expectEqual(@as(usize, 1), counters.distance_histogram_passes);
    try std.testing.expectEqual(@as(usize, 1), counters.distance_tree_build_passes);
    try std.testing.expectEqual(@as(usize, 2), counters.distance_trees_built);
    try expectPrepared(@as(*const Module.Prepared, &owned), @as(*const Module.Prepared, &borrowed));
    try wirePair(Module, input[0..input_len], &commands, options, &owned, &borrowed);
    try std.testing.expectEqualDeep(commands_before, commands);
    try expectModel(&before, &common);
    common.ready = false;
    try std.testing.expect(!borrowed.matches(options, &commands));
    const literal = try literalState(input[0..input_len], &commands, options);
    var untouched_counter = counting_writer.Writer.init(0);
    var no_alloc = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidBlockPlan, Module.write(Strategy, no_alloc.allocator(), &untouched_counter, input[0..input_len], &commands, options, &borrowed, &literal));
    try std.testing.expectEqual(@as(u64, 0), try untouched_counter.checkedBitPosition());
    try std.testing.expectEqual(@as(usize, 0), no_alloc.alloc_index);
    common.ready = true;
    borrowed.deinit(std.testing.allocator);
    deinitialized = true;
    try expectModel(&before, &common);
}

fn invalidAndFailures(comptime Module: type) !void {
    var commands: [18]command_plan.Command = undefined;
    var input: [2048]u8 = undefined;
    _ = fixture(0, &commands, &input);
    var options: BorrowOptions = .{};
    const count = try explicitCount(&commands, options);
    const split = try split_plan.Plan.initCopy(std.testing.allocator, &.{ @intCast(count / 2), @intCast(count - count / 2) }, &.{ 0, 1 }, 2, count, 0);
    defer split.deinit(std.testing.allocator);
    options.adaptive_distance_split = &split;
    var owned = try Module.Prepared.init(Strategy, std.testing.allocator, &commands, options);
    defer owned.deinit(std.testing.allocator);
    var common: prepared_command.Prepared = undefined;
    try modelFromOwned(&common, &owned, options, &commands);
    const before = common;
    var unavailable = common;
    unavailable.ready = false;
    var exact = common;
    exact.has_exact_commands = true;
    for ([_]*const prepared_command.Prepared{ &unavailable, &exact }) |invalid| {
        var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
        try std.testing.expectError(error.InvalidBlockPlan, Module.Prepared.initBorrowedCommand(Strategy, heap.allocator(), &commands, options, invalid));
        try std.testing.expectEqual(@as(usize, 0), heap.alloc_index);
    }
    inline for (.{ "window_bits", "compound_dictionary_size", "initial_output_pos", "optimize_same_last_distance" }) |field| {
        var changed = options;
        if (comptime @TypeOf(@field(changed, field)) == bool) @field(changed, field) = !@field(changed, field) else @field(changed, field) += 1;
        var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
        try std.testing.expectError(error.InvalidBlockPlan, Module.Prepared.initBorrowedCommand(Strategy, heap.allocator(), &commands, changed, &common));
        try std.testing.expectEqual(@as(usize, 0), heap.alloc_index);
    }
    var changed = options;
    changed.distance_parameters = distance.Parameters.init(0, 14);
    var no_alloc = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidBlockPlan, Module.Prepared.initBorrowedCommand(Strategy, no_alloc.allocator(), &commands, changed, &common));
    changed = options;
    changed.use_recent_distances = false;
    try std.testing.expectError(error.InvalidBlockPlan, Module.Prepared.initBorrowedCommand(Strategy, no_alloc.allocator(), &commands, changed, &common));
    for (0..4) |index| {
        changed = options;
        changed.starting_last_distances[index] += 1;
        try std.testing.expectError(error.InvalidBlockPlan, Module.Prepared.initBorrowedCommand(Strategy, no_alloc.allocator(), &commands, changed, &common));
    }
    var other_commands = commands;
    try std.testing.expectError(error.InvalidBlockPlan, Module.Prepared.initBorrowedCommand(Strategy, no_alloc.allocator(), &other_commands, options, &common));
    try std.testing.expectEqual(@as(usize, 0), no_alloc.alloc_index);
    const Run = struct {
        fn allocation(allocator: std.mem.Allocator, source: []const command_plan.Command, settings: BorrowOptions, owner: *const prepared_command.Prepared) !void {
            var borrowed = try Module.Prepared.initBorrowedCommand(Strategy, allocator, source, settings, owner);
            defer borrowed.deinit(allocator);
            try std.testing.expect(borrowed.matches(settings, source));
        }
    };
    try std.testing.checkAllAllocationFailures(std.testing.allocator, Run.allocation, .{ &commands, options, &common });
    try expectModel(&before, &common);
}

pub fn check(comptime Module: type) !void {
    for (0..18) |seed| try run(Module, seed);
    try invalidAndFailures(Module);
    std.debug.print("adaptive_distance_borrow model_cases=18 key_rejections=13 revoked_owner_writes=18\n", .{});
}
