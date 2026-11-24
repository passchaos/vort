//! Frame-local RAW attachments. Only descriptors are copied; no pointer to
//! this inline array is retained by the decoder across calls.
const std = @import("std");
const shared = @import("../shared_dictionary.zig");
const overlaps = @import("../decode/alias.zig").overlaps;

pub const State = struct {
    prefixes: [shared.max_raw_prefixes][]const u8 = undefined,
    len: u4 = 0,

    pub fn view(self: *const State, configured: shared.Dictionary) shared.Dictionary {
        if (self.len == 0) return configured;
        return .{ .raw_prefixes = self.prefixes[0..self.len], .serialized = configured.serialized };
    }

    pub fn append(self: *State, configured: shared.Dictionary, prefix: []const u8, writers: []const []const u8) error{ CorruptFrame, IntegerOverflow, InvalidBlockPlan }!usize {
        std.debug.assert(prefix.len != 0);
        const current = self.view(configured);
        const old_size = current.totalSize() catch |err| switch (err) {
            error.IntegerOverflow => return error.IntegerOverflow,
            error.TooManyRawPrefixes, error.RawDictionaryTooLarge => return error.CorruptFrame,
        };
        if (current.compoundChunkCount() == shared.max_raw_prefixes) return error.CorruptFrame;
        const size = std.math.add(usize, old_size, prefix.len) catch return error.IntegerOverflow;
        if (size > shared.max_raw_size) return error.CorruptFrame;
        for (writers) |writer| if (overlaps(prefix, writer)) return error.InvalidBlockPlan;

        const slot = current.raw_prefixes.len;
        if (self.len == 0) @memmove(self.prefixes[0..slot], current.raw_prefixes);
        self.prefixes[slot] = prefix;
        self.len = @intCast(slot + 1);
        return size;
    }
};
