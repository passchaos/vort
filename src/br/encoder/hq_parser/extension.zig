const std = @import("std");
const types = @import("../hq_types.zig");
const command_plan = @import("../command_plan.zig");
const length = @import("../../length.zig");
const prices = @import("prices.zig");

/// length is decoded output advancement. Static copy_len remains the raw word
/// length in the original command and is never replaced with this value.
pub const Result = struct { length: usize, encoding: types.ExactEncoding };

/// Compare complete commands and a valid literal-only continuation through
/// the meta-block end. Copy-code boundaries can also change implicit rep0 into
/// explicit distance zero, so retaining only a copy-length price is unsafe.
pub fn choose(command: command_plan.Command, maximum: usize, source: types.Source, model: *const prices.Model, literal_prefix: []const u64) !Result {
    const old_encoding = command.hq_encoding orelse return error.InvalidBlockPlan;
    const copy_start = command.insert_start + command.insert_len;
    const old_end = copy_start + command.outputLen();
    const full = @min(maximum, source.input.len - copy_start);
    var result: Result = .{ .length = command.outputLen(), .encoding = old_encoding };
    if (command.isStatic() or full <= command.copy_len) return result;
    const old_choices = try model.commandCosts(command.insert_len, command.copy_len, old_encoding.distance_code);
    var original_cost: ?u64 = null;
    for (old_choices.slice()) |choice| if (std.meta.eql(choice.encoding, old_encoding)) {
        original_cost = choice.cost;
    };
    const original = original_cost orelse return error.InvalidBlockPlan;
    const tail_len = source.input.len - old_end;
    var best = try plus(original, literal_prefix[source.input.len] - literal_prefix[old_end]);
    if (tail_len != 0) best = try plus(best, (try model.terminal(tail_len)).cost);
    var considered = command.copy_len;
    for (0..24) |code| {
        const spec = length.copySpec(@intCast(code));
        if (spec.base > full) break;
        const copy_len = @min(full, spec.base + (@as(usize, 1) << spec.extra_bits) - 1);
        if (copy_len <= considered) continue;
        considered = copy_len;
        const choices = try model.commandCosts(command.insert_len, copy_len, old_encoding.distance_code);
        const end = copy_start + copy_len;
        for (choices.slice()) |choice| {
            var cost = try plus(choice.cost, literal_prefix[source.input.len] - literal_prefix[end]);
            if (end != source.input.len) cost = try plus(cost, (try model.terminal(source.input.len - end)).cost);
            if (cost < best) {
                best = cost;
                result = .{ .length = copy_len, .encoding = choice.encoding };
            }
        }
    }
    return result;
}
fn plus(a: u64, b: u64) !u64 {
    return std.math.add(u64, a, b) catch error.IntegerOverflow;
}
