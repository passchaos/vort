//! Explicit persistent parallel frame encoder with a movable public handle.
const std = @import("std");
const core = @import("../../core.zig");
const types = @import("types.zig");
const settings = @import("options.zig");
const owners = @import("owner.zig");
const memory = @import("../../io/threaded_working_memory.zig");

pub fn Encoder(comptime Codec: type) type {
    return struct {
        const Self = @This();
        const Owner = owners.Owner(Codec);
        pub const Error = Codec.Error;
        pub const Count = core.StreamCount;
        pub const Options = types.EncoderOptions(Codec.Options);
        pub const Snapshot = Owner.Snapshot;
        pub const MemorySnapshot = memory.Snapshot;
        pub const ParallelOptions = types.ParallelOptions;
        pub const ParallelProfile = types.Profile;
        pub const ParallelSnapshot = types.Snapshot;

        /// Frame, parallel policy and profile destinations are captured until
        /// nextFrame. The four stream limits may be changed between steps;
        /// `max_job_count` must remain nonzero.
        options: Options,
        owner: *Owner,

        pub fn validateOptions(options: Options, expected: ?Count, dictionary: ?Codec.Dictionary) Error!void {
            try Owner.validate(options, expected, dictionary, null);
        }

        pub fn validateOptionsWithDictionary(options: Options, expected: ?Count, dictionary_id: u32) Error!void {
            try Owner.validate(options, expected, null, dictionary_id);
        }

        pub fn init(allocator: std.mem.Allocator, options: Options) Error!Self {
            return create(allocator, options, null, null, null);
        }

        pub fn initExactSize(allocator: std.mem.Allocator, options: Options, expected_input_len: Count) Error!Self {
            return create(allocator, options, expected_input_len, null, null);
        }

        /// Metadata-only Dictionary_ID is supported by raw/RLE frames.
        pub fn initWithDictionary(allocator: std.mem.Allocator, options: Options, dictionary_id: u32) Error!Self {
            return create(allocator, options, null, null, dictionary_id);
        }

        pub fn initExactSizeWithDictionary(allocator: std.mem.Allocator, options: Options, expected_input_len: Count, dictionary_id: u32) Error!Self {
            return create(allocator, options, expected_input_len, null, dictionary_id);
        }

        /// Borrow raw or full preset bytes until deinit or successful nextFrame.
        pub fn initWithPresetDictionary(allocator: std.mem.Allocator, options: Options, dictionary: Codec.Dictionary) Error!Self {
            return create(allocator, options, null, dictionary, null);
        }

        pub fn initExactSizeWithPresetDictionary(allocator: std.mem.Allocator, options: Options, expected_input_len: Count, dictionary: Codec.Dictionary) Error!Self {
            return create(allocator, options, expected_input_len, dictionary, null);
        }

        pub fn initWithDictionarySet(allocator: std.mem.Allocator, options: Options, dictionary_set: Codec.DictionarySet, dictionary_id: u32) Error!Self {
            return initWithPresetDictionary(allocator, options, try selected(dictionary_set, dictionary_id));
        }

        pub fn initExactSizeWithDictionarySet(allocator: std.mem.Allocator, options: Options, expected_input_len: Count, dictionary_set: Codec.DictionarySet, dictionary_id: u32) Error!Self {
            return initExactSizeWithPresetDictionary(allocator, options, expected_input_len, try selected(dictionary_set, dictionary_id));
        }

        fn create(allocator: std.mem.Allocator, options: Options, expected: ?Count, dictionary: ?Codec.Dictionary, metadata_id: ?u32) Error!Self {
            const owner = try Owner.create(allocator, options, expected, dictionary, metadata_id);
            return .{ .options = owner.options, .owner = owner };
        }

        pub fn deinit(self: *Self) void {
            self.owner.deinit();
            self.* = undefined;
        }

        /// Discard the current frame while retaining allocated capacity. Frame
        /// and parallel configuration stay captured; legal stream limits persist.
        pub fn reset(self: *Self) void {
            self.owner.reset(settings.limits(Codec, self.options));
            self.options = self.owner.options;
        }

        pub fn nextFrame(self: *Self, options: Options) Error!void {
            try self.next(options, null, null, null);
        }

        pub fn nextFrameExactSize(self: *Self, options: Options, expected_input_len: Count) Error!void {
            try self.next(options, expected_input_len, null, null);
        }

        pub fn nextFrameWithDictionary(self: *Self, options: Options, dictionary_id: u32) Error!void {
            try self.next(options, null, null, dictionary_id);
        }

        pub fn nextFrameExactSizeWithDictionary(self: *Self, options: Options, expected_input_len: Count, dictionary_id: u32) Error!void {
            try self.next(options, expected_input_len, null, dictionary_id);
        }

        pub fn nextFrameWithPresetDictionary(self: *Self, options: Options, dictionary: Codec.Dictionary) Error!void {
            try self.next(options, null, dictionary, null);
        }

        pub fn nextFrameExactSizeWithPresetDictionary(self: *Self, options: Options, expected_input_len: Count, dictionary: Codec.Dictionary) Error!void {
            try self.next(options, expected_input_len, dictionary, null);
        }

        pub fn nextFrameWithDictionarySet(self: *Self, options: Options, dictionary_set: Codec.DictionarySet, dictionary_id: u32) Error!void {
            try self.nextFrameWithPresetDictionary(options, try selected(dictionary_set, dictionary_id));
        }

        pub fn nextFrameExactSizeWithDictionarySet(self: *Self, options: Options, expected_input_len: Count, dictionary_set: Codec.DictionarySet, dictionary_id: u32) Error!void {
            try self.nextFrameExactSizeWithPresetDictionary(options, expected_input_len, try selected(dictionary_set, dictionary_id));
        }

        fn next(self: *Self, options: Options, expected: ?Count, dictionary: ?Codec.Dictionary, metadata_id: ?u32) Error!void {
            try self.owner.nextFrame(options, expected, dictionary, metadata_id);
            self.options = self.owner.options;
        }

        fn selected(dictionary_set: Codec.DictionarySet, dictionary_id: u32) Error!Codec.Dictionary {
            if (dictionary_id == 0) return error.NeedDictionary;
            try dictionary_set.validate();
            return dictionary_set.find(dictionary_id) orelse error.NeedDictionary;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            return self.owner.step(input, output, settings.limits(Codec, self.options));
        }

        pub fn flush(self: *Self) void {
            self.owner.flush();
        }

        /// An undersized exact pledge becomes a sticky SizeMismatch on step;
        /// reset discards that frame. Finishing accepts no further input.
        pub fn finish(self: *Self) void {
            self.owner.finish();
        }

        pub fn writeSkippable(self: *Self, skippable_id: u4, payload: []const u8) Error!void {
            try self.owner.writeSkippable(skippable_id, payload, settings.limits(Codec, self.options));
        }

        pub fn snapshot(self: *const Self) Snapshot {
            return self.owner.snapshot();
        }

        pub fn memorySnapshot(self: *const Self) MemorySnapshot {
            return self.owner.memorySnapshot();
        }

        /// Errors report exactly this call's committed input and output, even
        /// when no StepResult was returned. Successful calls clear this record.
        pub fn failedProgress(self: *const Self) ?core.Progress {
            return self.owner.failedProgress();
        }
    };
}
