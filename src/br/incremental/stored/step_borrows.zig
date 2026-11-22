//! Admit the whole step before allocator activation or any stream progress.
//! Retained allocations include spare capacity: growth may release those bytes,
//! and a later block may overwrite them. Immutable readers may share storage.
const std = @import("std");
const overlaps = @import("../../encoder/hq_codec/alias.zig").overlaps;
const max_raw_prefixes = @import("../../shared_dictionary.zig").max_raw_prefixes;
const TotalState = @import("../../encoder/total_budget/state.zig").State;
pub const Error = error{ InvalidBlockPlan, IntegerOverflow };

/// Publish only an executable metadata borrow. Current stream profiles remain
/// writers while accepted plaintext and metadata are flushed by later steps.
pub fn validateMetadata(self: anytype, metadata: []const u8) Error!void {
    try validateProfiles(self, self);
    try validateAllocatorProfile(self);
    try protect(self, "", metadata, false);
}

/// New readers replace the completed stream's readers. Cleanup can still free
/// old owned storage, and activation reports to the actual old budget profile
/// before replacing it. Old dictionary and HQ observer borrows are not inherited.
pub fn validateNextStream(self: anytype, options: anytype) Error!void {
    try validateProfiles(self, &options);
    try validateProfiles(self, &self.memory_binding);
    try validateAllocatorProfile(self);
    if (@hasField(@TypeOf(options.stream), "metadata"))
        try protectNextStream(self, options, options.stream.metadata);
    if (@hasField(@TypeOf(options.stream), "shared_dictionary")) {
        const dictionary = options.stream.shared_dictionary;
        try protectNextStream(self, options, try dictionaryDescriptorBytes(dictionary));
        for (dictionary.raw_prefixes) |prefix| try protectNextStream(self, options, prefix);
        if (dictionary.serialized) |view| {
            try protectNextStream(self, options, std.mem.asBytes(view));
            try protectNextStream(self, options, view.encoded);
        }
    }
}

fn validateAllocatorProfile(self: anytype) Error!void {
    if (TotalState.fromAllocator(self.allocator)) |state| {
        if (state.profile) |profile| try validateProfile(self, profile);
    }
}

fn protectNextStream(self: anytype, options: anytype, reader: []const u8) Error!void {
    if (overlaps(std.mem.asBytes(self), reader) or ownedOverlap(self, reader, false, false) or
        ownedOverlap(&options, reader, true, false)) return error.InvalidBlockPlan;
    if (self.memory_binding.lease) |lease| {
        if (lease.state) |state| {
            if (state.profile) |profile|
                if (overlaps(std.mem.asBytes(profile), reader)) return error.InvalidBlockPlan;
        }
    }
    if (TotalState.fromAllocator(self.allocator)) |state| {
        if (overlaps(std.mem.asBytes(state), reader)) return error.InvalidBlockPlan;
        if (state.profile) |profile|
            if (overlaps(std.mem.asBytes(profile), reader)) return error.InvalidBlockPlan;
    }
}

pub fn validate(self: anytype, input: []const u8, output: []u8) Error!void {
    const receiver = std.mem.asBytes(self);
    if (overlaps(input, output) or overlaps(receiver, input) or overlaps(receiver, output) or
        ownedOverlap(self, input, true, false) or ownedOverlap(self, output, true, false))
        return error.InvalidBlockPlan;
    if (TotalState.fromAllocator(self.allocator)) |state| {
        if (overlaps(std.mem.asBytes(state), input) or overlaps(std.mem.asBytes(state), output))
            return error.InvalidBlockPlan;
        if (state.profile) |profile| {
            if (overlaps(std.mem.asBytes(profile), input) or overlaps(std.mem.asBytes(profile), output))
                return error.InvalidBlockPlan;
            try validateProfile(self, profile);
        }
    }
    try validateProfiles(self, self);
    try protect(self, output, self.pending_metadata, false);
    if (@hasField(@TypeOf(self.options.stream), "metadata"))
        try protect(self, output, self.options.stream.metadata, false);
    if (@hasField(@TypeOf(self.options.stream), "shared_dictionary"))
        try protectDictionary(self, output, self.options.stream.shared_dictionary, false);
    // Reset ends the active borrow. Retained dictionary indices may still hold
    // old numeric/pointer descriptors, which the next prefix replaces.
    if (self.prefix_written) try stateBorrows(self, output, &self.codec_state);
}

fn listBytes(list: anytype) []const u8 {
    return std.mem.sliceAsBytes(list.items.ptr[0..list.capacity]);
}

/// The explicit field groups mirror the stored/static/planned owners. No
/// allocator context or borrowed dictionary pointer is followed as ownership.
fn ownedOverlap(object: anytype, bytes: []const u8, profiles: bool, skip_snapshot: bool) bool {
    if (bytes.len == 0) return false;
    const T = @TypeOf(object.*);
    inline for (.{ "plain", "pending", "tokens", "commands", "history", "candidate_wire", "best_wire", "adaptive_single_wire", "adaptive_split_wire", "adaptive_grid_wire", "adaptive_grid_candidate_wire", "history_snapshot", "adaptive_split_history", "adaptive_grid_history", "prev", "head", "table" }) |field| {
        if (@hasField(T, field)) {
            const F = @TypeOf(@field(object.*, field));
            if (@typeInfo(F) == .@"struct" and @hasField(F, "items") and @hasField(F, "capacity"))
                if (overlaps(listBytes(@field(object.*, field)), bytes)) return true;
        }
    }
    inline for (.{ "buckets", "heads", "entries", "heads2", "heads3", "heads4", "nodes", "candidates", "words" }) |field| {
        if (@hasField(T, field))
            if (overlaps(std.mem.sliceAsBytes(@field(object.*, field)), bytes)) return true;
    }
    inline for (.{ "input_storage", "descriptors", "data", "serialized_storage" }) |field| {
        if (@hasField(T, field)) {
            if (@field(object.*, field)) |storage|
                if (overlaps(std.mem.sliceAsBytes(storage), bytes)) return true;
        }
    }
    inline for (.{ "budget", "model", "serialized_view", "state" }) |field| {
        if (@hasField(T, field)) {
            const F = @TypeOf(@field(object.*, field));
            if (@typeInfo(F) == .optional) {
                if (@field(object.*, field)) |owned|
                    if (overlaps(std.mem.asBytes(owned), bytes)) return true;
            } else if (overlaps(std.mem.asBytes(@field(object.*, field)), bytes)) return true;
        }
    }
    if (profiles) {
        inline for (.{ "profile", "memory_profile" }) |field| {
            if (@hasField(T, field)) {
                if (@field(object.*, field)) |profile|
                    if (overlaps(std.mem.asBytes(profile), bytes)) return true;
            }
        }
    }
    inline for (.{ "codec_state", "memory_binding", "options", "stream", "greedy_scratch", "dictionary_greedy_scratch", "fragment_scratch", "hq_state", "compound", "serialized", "chunk_storage", "raw_storage" }) |field| {
        if (@hasField(T, field)) {
            const F = @TypeOf(@field(object.*, field));
            if (@typeInfo(F) == .@"struct")
                if (ownedOverlap(&@field(object.*, field), bytes, profiles, skip_snapshot)) return true;
        }
    }
    inline for (.{ "compound_matcher", "serialized_matcher", "matcher", "provider", "builtin", "lease", "hq" }) |field| {
        if (@hasField(T, field)) {
            if (@field(object.*, field)) |*nested|
                if (ownedOverlap(nested, bytes, profiles, skip_snapshot)) return true;
        }
    }
    if (!skip_snapshot and @hasField(T, "alias_snapshot")) {
        if (object.alias_snapshot) |*snapshot|
            if (ownedOverlap(snapshot, bytes, profiles, false)) return true;
    }
    // The lease control also retains its profile after options are replaced.
    if (profiles and @hasField(T, "state")) {
        if (object.state) |state| {
            if (state.profile) |profile|
                if (overlaps(std.mem.asBytes(profile), bytes)) return true;
        }
    }
    return false;
}

fn validateProfile(self: anytype, profile: anytype) Error!void {
    const bytes = std.mem.asBytes(profile);
    if (overlaps(std.mem.asBytes(self), bytes) or ownedOverlap(self, bytes, false, false))
        return error.InvalidBlockPlan;
}

fn validateProfiles(self: anytype, object: anytype) Error!void {
    const T = @TypeOf(object.*);
    inline for (.{ "profile", "memory_profile" }) |field| {
        if (@hasField(T, field)) {
            if (@field(object.*, field)) |profile| try validateProfile(self, profile);
        }
    }
    inline for (.{ "codec_state", "memory_binding", "options", "stream", "hq_state" }) |field| {
        if (@hasField(T, field)) try validateProfiles(self, &@field(object.*, field));
    }
    inline for (.{ "matcher", "provider", "hq", "lease" }) |field| {
        if (@hasField(T, field)) {
            if (@field(object.*, field)) |*nested| try validateProfiles(self, nested);
        }
    }
    if (@hasField(T, "state")) {
        if (object.state) |state| {
            if (state.profile) |profile| try validateProfile(self, profile);
        }
    }
}

fn protect(self: anytype, output: []const u8, reader: []const u8, snapshot_reader: bool) Error!void {
    if (overlaps(std.mem.asBytes(self), reader) or overlaps(output, reader) or
        ownedOverlap(self, reader, true, snapshot_reader)) return error.InvalidBlockPlan;
    if (TotalState.fromAllocator(self.allocator)) |state| {
        if (overlaps(std.mem.asBytes(state), reader)) return error.InvalidBlockPlan;
        if (state.profile) |profile|
            if (overlaps(std.mem.asBytes(profile), reader)) return error.InvalidBlockPlan;
    }
}

fn dictionaryDescriptorBytes(dictionary: anytype) Error![]const u8 {
    // Cached dictionaries do not pass through options validation again. Bound
    // their outer table before computing bytes or visiting any descriptor.
    // Match the encoder facade's mapping of TooManyRawPrefixes to InvalidBlockPlan.
    if (dictionary.raw_prefixes.len > max_raw_prefixes) return error.InvalidBlockPlan;
    const serialized_slot: usize = if (dictionary.serialized) |view| @intFromBool(view.raw_prefix.len != 0) else 0;
    if (dictionary.raw_prefixes.len + serialized_slot > max_raw_prefixes) return error.InvalidBlockPlan;
    const descriptor_len = std.math.mul(usize, dictionary.raw_prefixes.len, @sizeOf([]const u8)) catch
        return error.IntegerOverflow;
    return @as([*]const u8, @ptrCast(dictionary.raw_prefixes.ptr))[0..descriptor_len];
}

fn protectDictionary(self: anytype, output: []const u8, dictionary: anytype, snapshot_reader: bool) Error!void {
    try protect(self, output, try dictionaryDescriptorBytes(dictionary), snapshot_reader);
    for (dictionary.raw_prefixes) |prefix| try protect(self, output, prefix, snapshot_reader);
    if (dictionary.serialized) |view| try protectSerialized(self, output, view, snapshot_reader);
}

fn protectSerialized(self: anytype, output: []const u8, view: anytype, snapshot_reader: bool) Error!void {
    try protect(self, output, std.mem.asBytes(view), snapshot_reader);
    try protect(self, output, view.encoded, snapshot_reader);
}

/// Cached descriptors are inline writers already covered by the receiver;
/// their immutable bytes remain borrowed even if options change before drain.
fn stateBorrows(self: anytype, output: []const u8, state: anytype) Error!void {
    const T = @TypeOf(state.*);
    const snapshot_reader = if (@hasField(@TypeOf(self.codec_state), "hq_state"))
        self.codec_state.hq_state.alias_snapshot != null
    else
        false;
    if (@hasField(T, "shared_dictionary"))
        try protectDictionary(self, output, state.shared_dictionary, snapshot_reader);
    if (@hasField(T, "dictionary")) {
        const D = @TypeOf(state.dictionary);
        if (@typeInfo(D) == .@"struct") {
            try protectDictionary(self, output, state.dictionary, snapshot_reader);
        } else if (state.dictionary) |view| try protectSerialized(self, output, view, snapshot_reader);
    }
    if (@hasField(T, "chunk_count")) {
        for (state.chunks[0..state.chunk_count]) |chunk| try protect(self, output, chunk, snapshot_reader);
    }
    if (@hasField(T, "raw_prefix_count")) {
        for (state.raw_prefixes[0..state.raw_prefix_count]) |prefix| try protect(self, output, prefix, snapshot_reader);
        if (state.serialized_dictionary) |view| try protectSerialized(self, output, view, snapshot_reader);
    }
    if (@hasField(T, "encoded_ptr")) {
        if (state.encoded_ptr) |ptr| try protect(self, output, ptr[0..state.encoded_len], snapshot_reader);
    }
    if (@hasField(T, "source")) {
        try protect(self, output, state.source.history, snapshot_reader);
        try protect(self, output, state.source.input, snapshot_reader);
    }
    if (@hasField(T, "literal_position_prices")) {
        if (state.literal_position_prices) |prices|
            try protect(self, output, std.mem.sliceAsBytes(prices), snapshot_reader);
    }
    if (@hasField(T, "hq_state")) try stateBorrows(self, output, &state.hq_state);
    inline for (.{ "compound", "serialized" }) |field| {
        if (@hasField(T, field)) try stateBorrows(self, output, &@field(state.*, field));
    }
    inline for (.{ "compound_matcher", "serialized_matcher", "matcher", "provider" }) |field| {
        if (@hasField(T, field)) {
            if (@field(state.*, field)) |*nested| try stateBorrows(self, output, nested);
        }
    }
    if (@hasField(T, "model")) {
        if (state.model) |model| try stateBorrows(self, output, model);
    }
}
