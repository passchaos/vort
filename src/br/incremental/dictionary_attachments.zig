//! Frame-local dictionary attachments, borrowed for the current stream.
//! No pointer to the inline RAW array is retained across calls.
const std = @import("std");
const shared = @import("../shared_dictionary.zig");
const serialized = @import("../serialized_dictionary.zig");
const alias = @import("../decode/alias.zig");
const Error = error{ CorruptFrame, IntegerOverflow, InvalidBlockPlan, InvalidStreamState };

pub const State = struct {
    prefixes: [shared.max_raw_prefixes][]const u8 = undefined,
    len: u4 = 0,
    serialized_view: ?*const serialized.Dictionary = null,

    pub fn view(self: *const State, configured: shared.Dictionary) shared.Dictionary {
        return .{
            .raw_prefixes = if (self.len == 0) configured.raw_prefixes else self.prefixes[0..self.len],
            .serialized = if (self.serialized_view) |attached| attached else configured.serialized,
        };
    }

    pub fn append(self: *State, configured: shared.Dictionary, prefix: []const u8, writers: []const []const u8) Error!usize {
        std.debug.assert(prefix.len != 0);
        const current = self.view(configured);
        const old_size = try dictionarySize(current);
        if (current.compoundChunkCount() == shared.max_raw_prefixes) return error.CorruptFrame;
        const size = std.math.add(usize, old_size, prefix.len) catch return error.IntegerOverflow;
        if (size > shared.max_raw_size) return error.CorruptFrame;
        for (writers) |writer| if (alias.overlaps(prefix, writer)) return error.InvalidBlockPlan;

        const slot = current.raw_prefixes.len;
        if (self.len == 0) @memmove(self.prefixes[0..slot], current.raw_prefixes);
        self.prefixes[slot] = prefix;
        self.len = @intCast(slot + 1);
        return size;
    }

    pub fn attachSerialized(self: *State, configured: shared.Dictionary, dictionary: *const serialized.Dictionary, writers: []const []const u8) Error!usize {
        var next = self.view(configured);
        if (next.serialized != null) return error.InvalidStreamState;
        if (!alias.serializedCountsSafe(dictionary)) return error.CorruptFrame;
        next.serialized = dictionary;
        const size = try dictionarySize(next);
        for (writers) |writer| if (alias.serializedDictionaryOverlaps(writer, dictionary)) return error.InvalidBlockPlan;

        self.serialized_view = dictionary;
        return size;
    }
};

fn dictionarySize(dictionary: shared.Dictionary) Error!usize {
    return dictionary.totalSize() catch |err| switch (err) {
        error.IntegerOverflow => error.IntegerOverflow,
        error.TooManyRawPrefixes, error.RawDictionaryTooLarge => error.CorruptFrame,
    };
}
