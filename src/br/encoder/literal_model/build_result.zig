//! Capture only complete literal trees produced by the existing builder.
//! Full candidate headers, CD payload and final alignment remain caller-owned.
const std = @import("std");
const owner_module = @import("owner.zig");
const model_module = @import("model.zig");
const context = @import("../literal_context_split.zig");
const command_plan = @import("../command_plan.zig");
const weighted = @import("../weighted_payload.zig");
const bit_count = @import("../../../io/bit_count.zig");

pub fn copyAlphabets(model: *const model_module.Model, plain: *model_module.Alphabet, contexts: []model_module.Alphabet) void {
    // The ordinary writer also constructs an unused plain encoder for a
    // contextual candidate. Give it a valid tree without rebuilding it.
    copyAlphabet(plain, &model.alphabets[0]);
    if (model.normalized_context != null) {
        std.debug.assert(contexts.len >= model.alphabets.len);
        for (contexts[0..model.alphabets.len], model.alphabets) |*destination, *source|
            copyAlphabet(destination, source);
    }
}

fn copyAlphabet(destination: *model_module.Alphabet, source: *const model_module.Alphabet) void {
    destination.len = source.len;
    @memcpy(destination.symbols[0..source.len], source.symbols[0..source.len]);
}

pub fn capture(owner: *owner_module.Owner, allocator: std.mem.Allocator, input: []const u8, commands: []const command_plan.Command, options: anytype, normalized: ?context.Candidate, frequencies: []const [256]u32, alphabets: []const model_module.Alphabet, lengths: []const [256]u4) owner_module.Error!?*const model_module.Model {
    if (!owner_module.supported(options) or !owner.matchesGroup(input, commands) or owner.len == owner_module.capacity)
        return null;
    if (frequencies.len != alphabets.len or alphabets.len != lengths.len)
        return error.InvalidBlockPlan;
    var literal_count: usize = 0;
    for (commands) |command| {
        if (command.insert_start > input.len or command.insert_len > input.len - command.insert_start)
            return error.InvalidBlockPlan;
        literal_count = std.math.add(usize, literal_count, command.insert_len) catch return error.IntegerOverflow;
    }
    var pure_bits: bit_count.BitCount = 0;
    for (frequencies, alphabets, lengths) |*counts, *alphabet, *tree_lengths|
        pure_bits = try weighted.add(pure_bits, try weighted.histogram(256, counts, alphabet, tree_lengths, false));
    return owner.capture(allocator, input, commands, options, normalized, alphabets, lengths, literal_count, pure_bits);
}
