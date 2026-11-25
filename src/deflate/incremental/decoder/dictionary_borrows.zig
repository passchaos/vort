//! A temporary dictionary is consumed before receiver metadata is updated.
//! Protect only the history ranges actually written by the operation.
const overlaps = @import("../../decoder/output_alias.zig").overlaps;

pub fn validateSeed(receiver: []const u8, history: []u8, dictionary: []const u8) error{InvalidBlockPlan}!void {
    const keep = @min(history.len, dictionary.len);
    if (overlaps(receiver, history[0..keep])) return error.InvalidBlockPlan;
}

pub fn validateAppend(receiver: []const u8, workspace: []const u8, history: []u8, position: usize, dictionary: []const u8) error{InvalidBlockPlan}!void {
    if (dictionary.len >= history.len) {
        // Replacing the entire ring uses one memmove, even with an aliased tail.
        if (overlaps(receiver, history) or overlaps(workspace, history)) return error.InvalidBlockPlan;
        return;
    }
    const first = @min(dictionary.len, history.len - position);
    for ([_][]u8{ history[position..][0..first], history[0 .. dictionary.len - first] }) |writer| {
        if (overlaps(receiver, writer) or overlaps(workspace, writer) or overlaps(dictionary, writer))
            return error.InvalidBlockPlan;
    }
}
