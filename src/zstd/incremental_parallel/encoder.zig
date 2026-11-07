//! Explicit persistent parallel frame encoder with a movable public handle.
const std = @import("std");
const core = @import("../../core.zig");
const types = @import("types.zig");
const settings = @import("options.zig");
const owners = @import("owner.zig");
const memory = @import("../../io/threaded_working_memory.zig");
const prefix = @import("../prefix/binding.zig");

pub fn Encoder(comptime Codec: type) type {
    return struct {
        const Self = @This();
        const Owner = owners.Owner(Codec);
        pub const Error = Codec.Error;
        pub const Count = core.StreamCount;
        pub const Options = types.EncoderOptions(Codec.Options);
        pub const Snapshot = Owner.Snapshot;
        pub const PrefixSnapshot = prefix.Snapshot;
        pub const Directive = prefix.Directive;
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

        /// Borrow preset bytes until deinit or successful nextFrame. Setting
        /// frame.dictionary_usage=.prefix limits the borrow to one active frame.
        pub fn initWithPresetDictionary(allocator: std.mem.Allocator, options: Options, dictionary: Codec.Dictionary) Error!Self {
            return create(allocator, options, null, dictionary, null);
        }

        pub fn initExactSizeWithPresetDictionary(allocator: std.mem.Allocator, options: Options, expected_input_len: Count, dictionary: Codec.Dictionary) Error!Self {
            return create(allocator, options, expected_input_len, dictionary, null);
        }

        pub fn initWithPrefix(allocator: std.mem.Allocator, options: Options, bytes: []const u8) Error!Self {
            var configured = options;
            configured.frame.dictionary_usage = .prefix;
            configured.frame.dictionary_id = 0;
            return create(allocator, configured, null, Codec.rawPrefix(bytes), null);
        }

        pub fn initExactSizeWithPrefix(allocator: std.mem.Allocator, options: Options, expected_input_len: Count, bytes: []const u8) Error!Self {
            var configured = options;
            configured.frame.dictionary_usage = .prefix;
            configured.frame.dictionary_id = 0;
            return create(allocator, configured, expected_input_len, Codec.rawPrefix(bytes), null);
        }

        pub fn setPrefix(self: *Self, bytes: []const u8) Error!void {
            try self.owner.setPrefix(bytes);
            self.options = self.owner.options;
        }

        pub fn setPrefixWithDictionary(self: *Self, dictionary: Codec.Dictionary) Error!void {
            try self.owner.setPrefixWithDictionary(dictionary);
            self.options = self.owner.options;
        }

        pub fn setDictionary(self: *Self, dictionary: Codec.Dictionary) Error!void {
            try self.owner.setDictionary(dictionary);
            self.options = self.owner.options;
        }

        pub fn clearDictionary(self: *Self) Error!void {
            try self.owner.clearDictionary();
            self.options = self.owner.options;
        }

        pub fn prefixSnapshot(self: *const Self) prefix.Snapshot {
            return self.owner.prefixSnapshot();
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
            self.resetSession();
        }

        pub fn resetSession(self: *Self) void {
            self.owner.resetSession(settings.limits(Codec, self.options));
            self.options = self.owner.options;
        }

        pub fn resetParameters(self: *Self) Error!void {
            try self.owner.resetParameters();
            self.options = self.owner.options;
        }

        pub fn resetAll(self: *Self) void {
            self.owner.resetAll(settings.limits(Codec, self.options));
            self.options = self.owner.options;
        }

        pub fn nextFrame(self: *Self, options: Options) Error!void {
            try self.nextRetainingPrefix(options, null);
        }

        pub fn nextFrameExactSize(self: *Self, options: Options, expected_input_len: Count) Error!void {
            try self.nextRetainingPrefix(options, expected_input_len);
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
            try self.owner.nextFrame(options, expected, dictionary, metadata_id, true);
            self.options = self.owner.options;
        }

        fn nextRetainingPrefix(self: *Self, options: Options, expected: ?Count) Error!void {
            try self.owner.nextFrame(options, expected, null, null, false);
            self.options = self.owner.options;
        }

        fn selected(dictionary_set: Codec.DictionarySet, dictionary_id: u32) Error!Codec.Dictionary {
            if (dictionary_id == 0) return error.NeedDictionary;
            try dictionary_set.validate();
            return dictionary_set.find(dictionary_id) orelse error.NeedDictionary;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            defer self.options.frame.dictionary_id = self.owner.options.frame.dictionary_id;
            return self.owner.step(input, output, settings.limits(Codec, self.options));
        }

        pub fn stepWithDirective(self: *Self, input: []const u8, output: []u8, directive: prefix.Directive) Error!core.StepResult {
            defer self.options.frame.dictionary_id = self.owner.options.frame.dictionary_id;
            return self.owner.stepWithDirective(input, output, settings.limits(Codec, self.options), directive);
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
            defer self.options.frame.dictionary_id = self.owner.options.frame.dictionary_id;
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
