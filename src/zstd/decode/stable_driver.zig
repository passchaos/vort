//! Public stable-output boundaries; the decoder owns frame selection.
const std = @import("std");
const core = @import("../../core.zig");
const stable = @import("stable_output.zig");
const prefix_stream = @import("../prefix/decode_stream.zig");

pub fn validateDictionary(output: []const u8, dictionary: anytype) core.Error!void {
    try stable.validateAlias(output, dictionary.content);
    if (dictionary.standard_bytes) |bytes| try stable.validateAlias(output, bytes);
    if (dictionary.prepared) |prepared| try stable.validateAlias(output, std.mem.asBytes(prepared));
}

pub fn validateDictionarySet(writers: []const []const u8, output: []const u8, dictionary_set: anytype) core.Error!void {
    const entries = dictionary_set.dictionaries;
    const len = std.math.mul(usize, entries.len, @sizeOf(@TypeOf(entries[0]))) catch return error.IntegerOverflow;
    const descriptors = @as([*]const u8, @ptrCast(entries.ptr))[0..len];
    // Stable output must not overwrite the catalog itself. As before, its
    // overlap with an individual dictionary is checked at frame admission.
    try stable.validateAlias(output, descriptors);
    for (writers) |writer| try stable.validateAlias(writer, descriptors);
    for (entries) |dictionary| {
        for (writers) |writer| try validateDictionary(writer, dictionary);
    }
}

pub fn bind(owner: anytype, output: []u8) !void {
    if (!prefix_stream.setterEligible(owner)) return error.InvalidStreamState;
    if (owner.dictionary) |dictionary| try validateDictionary(output, dictionary);
    if (owner.frame_dictionary) |dictionary| try validateDictionary(output, dictionary);
    if (owner.dictionary_set) |dictionary_set| try validateDictionarySet(&.{
        owner.direct_history.allocatedSlice(), owner.decoded_scratch.allocatedSlice(),
    }, output, dictionary_set);
    try stable.validateAlias(output, owner.direct_history.allocatedSlice());
    try stable.validateAlias(output, owner.decoded_scratch.allocatedSlice());
    try stable.validateAlias(output, owner.frame_scratch.allocatedSlice());
    if (owner.dictionary) |dictionary| {
        try stable.validateAlias(dictionary.content, owner.direct_history.allocatedSlice());
        try stable.validateAlias(dictionary.content, owner.decoded_scratch.allocatedSlice());
    }
    try owner.stable_binding.bind(output);
    owner.direct_history.deinit(owner.budget.allocator());
    owner.direct_history = .empty;
    owner.decoded_scratch.deinit(owner.budget.allocator());
    owner.decoded_scratch = .empty;
    owner.stable_origin = owner.output_written;
}

pub fn remember(owner: anytype, bytes: []const u8) core.Error!void {
    if (bytes.len == 0) return;
    const output = owner.stable_binding.buffer orelse return error.InvalidStreamState;
    const first = @intFromPtr(output.ptr);
    const address = @intFromPtr(bytes.ptr);
    if (address < first or address - first > output.len) return error.InvalidBlockPlan;
    const start = address - first;
    if (bytes.len > output.len - start) return error.InvalidBlockPlan;
    const end = start + bytes.len;
    if (end > owner.stable_binding.produced) {
        if (start > owner.stable_binding.produced) return error.InvalidStreamState;
        try owner.stable_binding.advanceProduced(end - owner.stable_binding.produced);
    }
}

pub fn step(owner: anytype, input: []const u8, maximum: usize) !core.StepResult {
    if (owner.stable_step_active) return error.InvalidStreamState;
    owner.last_step_progress = .{};
    const remaining = try owner.stable_binding.remaining();
    try stable.validateAlias(owner.stable_binding.buffer.?, input);
    owner.stable_step_active = true;
    defer owner.stable_step_active = false;
    const result = owner.step(input, remaining[0..@min(remaining.len, maximum)]) catch |err| {
        // The core already reports these actually emitted bytes as progress.
        // Publish them even on a late error; prevalidated staging has not
        // advanced either counter until its validated bytes drain.
        const produced = try core.stream_count.toLocal(owner.output_written - owner.stable_origin);
        if (produced > owner.stable_binding.produced)
            try owner.stable_binding.advanceProduced(produced - owner.stable_binding.produced);
        _ = try owner.stable_binding.publish();
        return err;
    };
    _ = try owner.stable_binding.publish();
    return result;
}
