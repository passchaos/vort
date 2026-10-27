//! Emit a validated winning ordinary literal preparation using actual storage.
const std = @import("std");
const huffman = @import("../../huffman.zig");
const prepared_command_distance = @import("prepared_command_distance.zig");
const prepared_literal = @import("prepared_literal.zig");
const literal_context_split = @import("literal_context_split.zig");
const literal_context = @import("literal_context.zig");
const compound_wire = @import("compound_wire.zig");
const encoder_distance = @import("distance.zig");
const command_plan = @import("command_plan.zig");

pub fn write(comptime S: type, allocator: std.mem.Allocator, writer: anytype, input: []const u8, commands: []const command_plan.Command, io: ?std.Io, stats: *S.Stats, options: S.Options, common: *const prepared_command_distance.Prepared, state: *const prepared_literal.State) S.Error!void {
    const header_start = if (io) |active| std.Io.Clock.awake.now(active) else null;
    try S.header(allocator, writer, input, options, common, state);
    if (io) |active| stats.header_ns = S.elapsed(header_start.?, active);
    const encoder_start = if (io) |active| std.Io.Clock.awake.now(active) else null;
    var literal_encoders: [literal_context_split.max_trees]huffman.HuffmanTable(256).Encoder = undefined;
    for (literal_encoders[0..state.tree_count], state.alphabets[0..state.tree_count], state.lengths[0..state.tree_count]) |*encoder, *alphabet, *lengths|
        encoder.* = try S.literalEncoder(lengths, alphabet);
    if (io) |active| stats.encoder_ns = S.elapsed(encoder_start.?, active);
    const payload_start = if (io) |active| std.Io.Clock.awake.now(active) else null;
    var last_distances = options.starting_last_distances;
    for (commands, 0..) |command, index| {
        const wire_distance = if (command.has_copy) try S.wireDistance(command, options.window_bits, options.compound_dictionary_size, options.initial_output_pos) else 0;
        const recent_symbol = if (command.has_copy and compound_wire.canUseRecentDistance(command.source))
            S.recentDistance(wire_distance, &last_distances)
        else
            null;
        const encoding = try S.commandEncoding(common, index, commands.len, command, recent_symbol);
        if (common.command_alphabet.len > 1) {
            if (common.command_alphabet.len <= 4) {
                const code = common.command_alphabet.simpleCode(encoding.symbol).?;
                try writer.writeHuffmanBits(allocator, code.code, code.bits);
            } else try writer.writeHuffmanBits(allocator, common.command_encoder.codes[encoding.symbol], common.command_encoder.bits[encoding.symbol]);
        }
        try S.writeExtras(allocator, writer, encoding, command.insert_len, command.copy_len);
        for (input[command.insert_start..][0..command.insert_len], command.insert_start..) |literal, position| {
            const tree = if (state.normalized_context) |candidate| blk: {
                const history = S.history(input, position, options.initial_previous);
                break :blk candidate.treeFor(literal_context.value(candidate.mode, history[0], history[1]));
            } else 0;
            const encoder = &literal_encoders[tree];
            if (encoder.bits[literal] != 0) try writer.writeHuffmanBits(allocator, encoder.codes[literal], encoder.bits[literal]);
        }
        if (command.has_copy and encoding.command.distance_code == -1) {
            const distance = if (recent_symbol) |symbol| encoder_distance.Encoding{ .symbol = symbol } else encoder_distance.encodeWithFormat(wire_distance, options.distance_parameters, .standard) orelse return error.InvalidBlockPlan;
            if (common.distance_alphabet.len > 1) {
                if (common.distance_alphabet.len <= 4) {
                    const code = common.distance_alphabet.simpleCode(distance.symbol).?;
                    try writer.writeHuffmanBits(allocator, code.code, code.bits);
                } else try writer.writeHuffmanBits(allocator, common.distance_encoder.codes[distance.symbol], common.distance_encoder.bits[distance.symbol]);
            }
            if (distance.extra_bits != 0) try writer.writeBits(allocator, distance.extra, distance.extra_bits);
        }
        if (command.has_copy and compound_wire.updatesRecentDistance(command.source, recent_symbol == 0))
            S.pushDistance(&last_distances, wire_distance);
    }
    if (writer.bit_index != 0) writer.alignToByte();
    if (io) |active| stats.payload_ns = S.elapsed(payload_start.?, active);
}
