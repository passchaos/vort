//! Streaming prefix transitions happen at the first complete frame header.
const binding = @import("binding.zig");

pub fn setterEligible(owner: anytype) bool {
    if (owner.failure != null or owner.required_dictionary_id != null) return false;
    return owner.phase == .done or (owner.phase == .frame and owner.frame_scratch.items.len == 0 and !owner.prefix_header_selected);
}

pub fn setDictionary(owner: anytype, dictionary: anytype, comptime validate: anytype) !void {
    if (!setterEligible(owner)) return error.InvalidStreamState;
    try validate(dictionary);
    owner.dictionary = dictionary;
    owner.dictionary_set = null;
    owner.options.dictionary_usage = .persistent;
    owner.prefix_state = .{ .configured = true };
}

pub fn setPrefix(owner: anytype, dictionary: anytype, comptime validate: anytype) !void {
    if (!setterEligible(owner)) return error.InvalidStreamState;
    clear(owner);
    if (binding.hasBytes(dictionary)) {
        try validate(dictionary);
        owner.dictionary = dictionary;
        owner.options.dictionary_usage = .prefix;
        owner.prefix_state.install(dictionary);
    }
}

pub fn clear(owner: anytype) void {
    owner.dictionary = null;
    owner.dictionary_set = null;
    owner.options.dictionary_usage = .persistent;
    owner.prefix_state = .{};
}

pub fn complete(owner: anytype) void {
    if (owner.prefix_state.phase == .active) {
        owner.prefix_state.complete(&owner.dictionary);
        owner.options.dictionary_usage = .persistent;
        owner.direct_dictionary_history = &.{};
    }
    owner.prefix_state.busy = false;
    owner.prefix_header_selected = false;
}

pub fn initialize(owner: anytype) void {
    if (owner.options.dictionary_usage == .prefix) {
        if (owner.dictionary) |dictionary| {
            if (binding.hasBytes(dictionary)) owner.prefix_state.install(dictionary) else {
                owner.dictionary = null;
                owner.options.dictionary_usage = .persistent;
            }
        }
    }
}
