//! A reusable decoder takes its selected prefix once per public call, while
//! parsing every member in that call with the same selected dictionary.
const binding = @import("binding.zig");

pub fn effective(stored: anytype, state: *const binding.State, requested: @TypeOf(stored.*)) @TypeOf(stored.*) {
    var options = requested;
    if (options.dictionary == null and options.dictionary_set == null and options.dictionary_usage == .persistent and (state.phase == .pending or state.configured)) {
        options.dictionary = stored.dictionary;
        options.dictionary_set = null;
        options.dictionary_usage = if (state.phase == .pending) .prefix else .persistent;
    }
    return options;
}

pub fn begin(stored: anytype, state: *binding.State, requested: @TypeOf(stored.*)) error{InvalidStreamState}!@TypeOf(stored.*) {
    if (state.busy) return error.InvalidStreamState;
    const options = effective(stored, state, requested);
    if (options.dictionary_usage == .prefix) {
        if (options.dictionary) |dictionary| state.install(dictionary) else state.* = .{};
        _ = state.activate(.call);
        // The local options carry the selection for the whole call. Erase the
        // stored copy before publication/allocator callbacks can observe it.
        stored.dictionary = null;
        stored.dictionary_set = null;
        stored.dictionary_usage = .persistent;
    } else if (state.phase == .pending) {
        stored.dictionary = null;
        stored.dictionary_set = null;
        stored.dictionary_usage = .persistent;
        state.* = .{};
    }
    state.busy = true;
    return options;
}

pub fn end(state: *binding.State) void {
    if (state.phase == .active) {
        state.phase = .none;
        state.id = 0;
        state.configured = false;
    }
    state.busy = false;
}
