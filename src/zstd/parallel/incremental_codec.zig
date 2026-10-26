//! Bounded immutable Jobs and stream helpers for the explicit parallel encoder.
const std = @import("std");
const core = @import("../../core.zig");
const zstd = @import("../../zstd.zig");
const base = @import("codec.zig").Codec;
const support = zstd.ParallelCodecSupport;

pub const IncrementalCodec = struct {
    pub const Error = zstd.ParallelError;
    pub const Options = zstd.NativeFrameOptions;
    pub const Dictionary = zstd.NativeDictionary;
    pub const DictionarySet = zstd.NativeDictionarySet;
    pub const Profile = zstd.EncoderControlProfile;
    pub const State = base.State;
    pub const Count = core.StreamCount;
    pub const JobView = base.JobView;
    pub const Hash = @import("../../checksum/xxh64_stream.zig").XxHash64;
    pub const blockSize = base.blockSize;
    pub const blockCount = base.blockCount;
    pub const initialState = base.initialState;
    pub const deinitState = base.deinitState;
    pub const encodeOwnedJob = base.encodeOwnedJob;
    pub const encodeOwned = base.encodeOwned;
    pub const appendOwnedJob = base.appendOwnedJob;
    pub const prepareOptions = base.prepareOptions;
    pub const profileOptions = base.profileOptions;
    pub const validateStream = support.validateStream;
    pub const writeStreamHeader = support.writeStreamHeader;
    pub const streamWindowLimit = support.streamWindowLimit;
    pub const streamBlockSize = support.streamBlockSize;
    pub const writeSkippable = support.writeSkippable;

    pub fn stripProfiles(options: Options) Options {
        var inner = options;
        inner.control_profile = null;
        inner.memory_profile = null;
        inner.max_total_working_memory = null;
        return inner;
    }

    pub fn validateDictionaryMetadata(dictionary: ?Dictionary) Error!void {
        _ = try support.initialDecodeState(dictionary);
    }

    pub fn historyLen(options: Options) Error!usize {
        if (options.selection == .raw_or_rle) return 0;
        return support.encoderWindow(options);
    }

    /// Validate first, then reset only the coding value and logical lengths.
    /// Every caller-owned scratch allocation remains at its stable capacity.
    pub fn resetStateRetainingCapacity(state: *State, dictionary: ?Dictionary) Error!void {
        const initial = try support.initialDecodeState(dictionary);
        state.actual.previous_huffman_plan = null;
        state.actual.sequence_state.previous_tables = initial.previous_tables;
        state.actual.sequence_state.repeated_offsets = initial.repeated_offsets;
        state.actual.sequence_state_initialized = true;
        state.actual.hq_entropy = null;
        state.values.clearRetainingCapacity();
        state.literals.clearRetainingCapacity();
        state.candidate.clearRetainingCapacity();
        inline for (std.meta.fields(@TypeOf(state.scratch))) |field| {
            if (comptime field.type == bool)
                @field(state.scratch, field.name) = false
            else
                @field(state.scratch, field.name).clearRetainingCapacity();
        }
    }

    pub fn writeStreamChecksum(allocator: std.mem.Allocator, out: *std.ArrayList(u8), hash: *Hash, options: Options) Error!void {
        try support.writeStreamChecksum(allocator, out, options, hash);
    }
    pub const appendChecksum = writeStreamChecksum;

    pub fn publishWork(baseline: Profile, queued: Profile, adapter: Profile, delivered: Profile.Emitted) Profile {
        var result = baseline;
        result.mergeWork(queued);
        result.mergeWork(adapter);
        result.mergeEmitted(delivered);
        return result;
    }
};
