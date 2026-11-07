//! Dictionary/prefix changes for a synchronous reusable decode handle.
const binding = @import("binding.zig");

pub fn initialize(owner: anytype) void {
    if (owner.options.dictionary_usage == .prefix) {
        if (owner.options.dictionary) |dictionary| owner.prefix_state.install(dictionary);
    }
}

pub fn setDictionary(owner: anytype, dictionary: anytype, comptime validate: anytype) !void {
    if (owner.prefix_state.busy) return error.InvalidStreamState;
    try validate(dictionary);
    owner.options.dictionary = dictionary;
    owner.options.dictionary_set = null;
    owner.options.dictionary_usage = .persistent;
    owner.prefix_state = .{ .configured = true };
}

pub fn setPrefix(owner: anytype, dictionary: anytype, comptime validate: anytype) !void {
    if (owner.prefix_state.busy) return error.InvalidStreamState;
    clear(owner);
    if (binding.hasBytes(dictionary)) {
        // D refPrefix(advanced FULL) drops the previous binding even when
        // loading the replacement metadata fails.
        try validate(dictionary);
        owner.options.dictionary = dictionary;
        owner.options.dictionary_usage = .prefix;
        owner.prefix_state.install(dictionary);
    }
}

pub fn clear(owner: anytype) void {
    owner.options.dictionary = null;
    owner.options.dictionary_set = null;
    owner.options.dictionary_usage = .persistent;
    owner.prefix_state = .{};
}

pub fn resetSession(owner: anytype) void {
    if (owner.prefix_state.busy) return;
    owner.prefix_state.resetSession(&owner.options.dictionary);
}
