//! Admit all caller borrows before a drain, buffer growth, or history update.
//! Capacity tails belong to the encoder even when their logical list is empty.
const std = @import("std");
const alias = @import("../../decoder/output_alias.zig");

const Error = error{InvalidBlockPlan};
const Storage = struct {
    spans: [9][]const u8 = undefined,
    len: usize = 0,

    fn add(self: *Storage, list: anytype) void {
        self.spans[self.len] = std.mem.sliceAsBytes(list.allocatedSlice());
        self.len += 1;
    }

    fn addRaw(self: *Storage, raw: anytype) void {
        // Deflate64 shares the stored core and keeps its bit state inline.
        if (comptime @hasField(@TypeOf(raw.state), "bytes")) self.add(raw.state.bytes);
        self.add(raw.plain);
        self.add(raw.pending);
        if (comptime @hasField(@TypeOf(raw.*), "history")) {
            self.add(raw.history);
            self.add(raw.plan_tokens);
            self.add(raw.match_finder.head);
            self.add(raw.match_finder.head_epoch);
            self.add(raw.match_finder.prev);
        }
    }
};

/// Output is the countable caller window. The complete input remains a borrow
/// even if output backpressure will make this call consume only a prefix.
pub fn validate(encoder: anytype, input: []const u8, output: []const u8) Error!void {
    const receiver = std.mem.asBytes(encoder);
    if (alias.overlaps(receiver, input) or alias.overlaps(receiver, output) or
        alias.overlaps(input, output)) return error.InvalidBlockPlan;

    const storage = retainedStorage(encoder);
    for (storage.spans[0..storage.len]) |span| {
        if (alias.overlaps(span, input) or alias.overlaps(span, output))
            return error.InvalidBlockPlan;
    }

    // Dictionaries and header metadata remain immutable borrows across reset
    // and member continuation; protect them from every encoder-owned writer.
    if (comptime @hasField(@TypeOf(encoder.*), "dictionary"))
        try validateBorrow(receiver, &storage, output, encoder.dictionary);
    if (comptime @hasField(@TypeOf(encoder.*), "raw")) {
        try validateBorrow(receiver, &storage, output, encoder.raw.dictionary);
        if (comptime @hasField(@TypeOf(encoder.options), "header")) {
            inline for (.{ "extra", "filename", "comment" }) |field| {
                if (@field(encoder.options.header, field)) |bytes|
                    try validateBorrow(receiver, &storage, output, bytes);
            }
        }
    }
}

/// A completed stream replaces its previous immutable configuration. Admit
/// the new dictionary against every storage region that reset can modify.
pub fn validateDictionaryTransition(encoder: anytype, dictionary: []const u8) Error!void {
    const storage = retainedStorage(encoder);
    try validateBorrow(std.mem.asBytes(encoder), &storage, "", dictionary);
}

pub fn validateHeaderTransition(encoder: anytype, header: anytype) Error!void {
    const storage = retainedStorage(encoder);
    inline for (.{ "extra", "filename", "comment" }) |field| {
        if (@field(header, field)) |bytes|
            try validateBorrow(std.mem.asBytes(encoder), &storage, "", bytes);
    }
}

fn retainedStorage(encoder: anytype) Storage {
    var storage: Storage = .{};
    if (comptime @hasField(@TypeOf(encoder.*), "raw")) {
        storage.addRaw(&encoder.raw);
        storage.add(encoder.pending);
    } else storage.addRaw(encoder);
    return storage;
}

fn validateBorrow(receiver: []const u8, storage: *const Storage, output: []const u8, borrowed: []const u8) Error!void {
    if (alias.overlaps(receiver, borrowed) or alias.overlaps(output, borrowed))
        return error.InvalidBlockPlan;
    for (storage.spans[0..storage.len]) |span| {
        if (alias.overlaps(span, borrowed)) return error.InvalidBlockPlan;
    }
}
