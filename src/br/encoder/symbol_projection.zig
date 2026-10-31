//! Project split-planner symbols from the same exact command decisions as emit.
const command_plan = @import("command_plan.zig");
const command_encoding = @import("command_encoding.zig");
const distance = @import("distance.zig");
const compound_wire = @import("compound_wire.zig");

pub const Step = struct {
    command: command_encoding.Encoding,
    distance: ?distance.Encoding = null,
    repeats: [4]usize,
};

pub fn project(comptime S: type, command: command_plan.Command, use_recent: bool, context: S.Context, repeats: [4]usize) S.Error!Step {
    const parameters = distance.Parameters.init(0, 15);
    const format: distance.Format = if (context.large_window) .large_window else .standard;
    const physical = if (command.has_copy) try S.wireDistance(command, context.window_bits, context.compound_dictionary_size, context.initial_output_pos) else 0;
    const exact = try S.resolve(command, physical, parameters, repeats, format);
    const recent = if (exact) |selection|
        selection.recent_symbol
    else if (use_recent and command.has_copy and compound_wire.canUseRecentDistance(command.source))
        S.short(physical, &repeats)
    else
        null;
    const encoding = if (exact) |selection| selection.command else S.forLengthsAndDistance(command.insert_len, command.copy_len, recent == 0) orelse
        S.forLengths(command.insert_len, command.copy_len) orelse return error.InvalidBlockPlan;
    var result: Step = .{ .command = encoding, .repeats = repeats };
    if (command.has_copy and encoding.command.distance_code == -1) {
        result.distance = if (exact) |selection|
            selection.distance orelse return error.InvalidBlockPlan
        else if (recent) |symbol|
            distance.Encoding{ .symbol = symbol }
        else
            distance.encodeWithFormat(physical, parameters, format) orelse return error.InvalidBlockPlan;
    }
    if (exact) |selection|
        result.repeats = selection.repeated_distances
    else if (command.has_copy and compound_wire.updatesRecentDistance(command.source, recent == 0))
        S.push(&result.repeats, physical);
    return result;
}
