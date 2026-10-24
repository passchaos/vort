//! Exact requested heap represented by retained encoder buffers. Inline state
//! arrays and borrowed dictionaries are excluded from this adoption count.
const std = @import("std");
pub const Error = error{IntegerOverflow};

fn add(bytes: *usize, amount: usize) Error!void {
    bytes.* = std.math.add(usize, bytes.*, amount) catch return error.IntegerOverflow;
}

fn list(bytes: *usize, value: anytype) Error!void {
    const Item = @typeInfo(@TypeOf(value.items)).pointer.child;
    try add(bytes, std.math.mul(usize, value.capacity, @sizeOf(Item)) catch return error.IntegerOverflow);
}

pub fn codec(state: anytype) Error!usize {
    var bytes: usize = 0;
    inline for (.{ "tokens", "commands", "history", "candidate_wire", "best_wire", "adaptive_single_wire", "adaptive_split_wire", "adaptive_grid_wire", "adaptive_grid_candidate_wire", "history_snapshot", "adaptive_split_history", "adaptive_grid_history" }) |field|
        try list(&bytes, @field(state, field));
    try list(&bytes, state.greedy_scratch.prev);
    try list(&bytes, state.dictionary_greedy_scratch.head);
    try list(&bytes, state.dictionary_greedy_scratch.prev);
    try add(&bytes, state.fragment_scratch.retainedCapacity());
    if (state.compound_matcher) |*matcher| try add(&bytes, matcher.retainedCapacity());
    if (state.serialized_matcher) |*matcher| try add(&bytes, matcher.retainedCapacity());
    if (state.hq_state.budget) |budget| try add(&bytes, budget.live);
    return bytes;
}

pub fn reusable(state: anytype) Error!usize {
    var bytes = try codec(&state.stream_state);
    try list(&bytes, state.tokens);
    try list(&bytes, state.commands);
    try list(&bytes, state.output);
    try list(&bytes, state.greedy_scratch.prev);
    try add(&bytes, state.compound_matcher.retainedCapacity());
    try add(&bytes, state.serialized_matcher.retainedCapacity());
    return bytes;
}
