const std = @import("std");
const core = @import("../../core.zig");
const zip_codec = @import("../../zip/incremental_writer/zstd_codec.zig");
const h = @import("helpers.zig");
const a = h.a;

pub fn contracts(comptime Z: type) !void {
    const dictionary = Z.NativeDictionary.init(h.id, h.plain);
    const dictionaries = [_]Z.NativeDictionary{dictionary};
    const set = Z.NativeDictionarySet.init(&dictionaries);
    try singleParallel(Z, dictionary, set);
    try seekable(Z, dictionary, set);
    try zipAdapter(Z, dictionary);
}

fn singleParallel(comptime Z: type, dictionary: Z.NativeDictionary, set: Z.NativeDictionarySet) !void {
    for ([_]Z.FrameFormat{ .standard, .magicless }) |format| {
        for ([_]usize{ 1, 2 }) |workers| {
            const options: Z.NativeFrameOptions = .{ .format = format, .strategy = .fast, .block_size_max = 128, .window_log = 10 };
            const parallel: Z.ParallelOptions = .{ .io = std.testing.io, .worker_count = workers, .job_size = 256, .max_inflight_jobs = 2, .max_inflight_bytes = 512 };
            const kept = try Z.encodeNativeParallelFrameWithDictionaryAlloc(a, h.plain, options, dictionary, parallel);
            defer a.free(kept);
            var omitted_options = options;
            omitted_options.include_dictionary_id = false;
            const omitted = try Z.encodeNativeParallelFrameWithDictionarySetAlloc(a, h.plain, omitted_options, set, dictionary.id, parallel);
            defer a.free(omitted);
            try h.pair(kept, omitted, format, dictionary.id);
            try h.check(Z, omitted, h.plain, format, dictionary);
            const bound = try Z.encodedNativeParallelFrameBoundWithDictionary(h.plain.len, omitted_options, dictionary, parallel);
            try std.testing.expect(omitted.len <= bound);
            const output = try a.alloc(u8, omitted.len + 17);
            defer a.free(output);
            @memset(output, 0xa5);
            const count = try Z.encodeNativeParallelFrameIntoSliceWithDictionarySet(a, h.plain, omitted_options, set, dictionary.id, output, parallel);
            try std.testing.expectEqualSlices(u8, omitted, output[0..count]);
            try h.wire.untouched(output[count..]);
            var out: std.ArrayList(u8) = .empty;
            defer out.deinit(a);
            try out.appendSlice(a, "prefix");
            _ = try Z.encodeNativeParallelFrameAppendWithDictionary(a, &out, h.plain, omitted_options, dictionary, parallel);
            try std.testing.expectEqualSlices(u8, omitted, out.items[6..]);
        }
    }
}

fn seekable(comptime Z: type, dictionary: Z.NativeDictionary, set: Z.NativeDictionarySet) !void {
    const options: Z.NativeSeekableOptions = .{ .frame_size = 128, .frame_options = .{ .selection = .literal_only } };
    const kept = try Z.encodeNativeSeekableStreamWithDictionaryAlloc(a, h.plain, options, dictionary);
    defer a.free(kept);
    var omitted_options = options;
    omitted_options.frame_options.include_dictionary_id = false;
    const omitted = try Z.encodeNativeSeekableStreamWithDictionarySetAlloc(a, h.plain, omitted_options, set, dictionary.id);
    defer a.free(omitted);
    var before = Z.iterateNativeStream(kept);
    var after = Z.iterateNativeStream(omitted);
    var frames: usize = 0;
    while (try before.next()) |member| {
        const peer = (try after.next()).?;
        switch (member) {
            .frame => |frame| {
                try h.pair(frame.bytes, peer.frame.bytes, Z.FrameFormat.standard, dictionary.id);
                frames += 1;
            },
            .skippable => {},
        }
    }
    try std.testing.expectEqual(@as(usize, 4), frames);
    try std.testing.expectEqual(@as(usize, 16), kept.len - omitted.len);
    const output = try Z.decodeNativeSeekableRangeAllocWithDictionary(a, omitted, 111, 257, dictionary);
    defer a.free(output);
    try std.testing.expectEqualSlices(u8, h.plain[111..368], output);
    var encoder = Z.NativeSeekableStreamEncoder.init(a);
    defer encoder.deinit();
    const reusable = try encoder.encodeWithDictionarySetAlloc(h.plain, omitted_options, set, dictionary.id);
    defer a.free(reusable);
    try std.testing.expectEqualSlices(u8, omitted, reusable);
    const bound = try Z.encodedNativeSeekableStreamBoundWithDictionary(h.plain.len, omitted_options, dictionary);
    try std.testing.expect(omitted.len <= bound);
}

const AdapterDrive = struct {
    state: *zip_codec.State,
    pub fn snapshot(self: *const AdapterDrive) struct { input_read: core.StreamCount, output_written: core.StreamCount } {
        return switch (self.state.*) {
            inline else => |*encoder| .{ .input_read = encoder.snapshot().input_read, .output_written = encoder.snapshot().output_written },
        };
    }
    pub fn step(self: *AdapterDrive, input: []const u8, output: []u8) !core.StepResult {
        return self.state.step(input, output);
    }
    pub fn finish(self: *AdapterDrive) void {
        self.state.finish();
    }
};

fn zipAdapter(comptime Z: type, dictionary: Z.NativeDictionary) !void {
    for ([_]bool{ false, true }) |parallel| {
        for ([_]bool{ false, true }) |known| {
            const policy: ?zip_codec.ParallelOptions = if (parallel) .{ .io = std.testing.io, .worker_count = 2, .job_size = 256, .max_inflight_jobs = 2, .max_inflight_bytes = 512 } else null;
            const options: Z.NativeFrameOptions = .{ .dictionary_id = dictionary.id, .selection = .literal_only, .block_size_max = 128, .window_log = 10 };
            const expected: ?core.StreamCount = if (known) h.plain.len else null;
            var kept = try zip_codec.State.init(a, options, policy, dictionary, expected);
            defer kept.deinit();
            var before_drive: AdapterDrive = .{ .state = &kept };
            const before = try h.wire.encodeDrive(a, &before_drive, h.plain);
            defer a.free(before);
            var omitted_options = options;
            omitted_options.include_dictionary_id = false;
            const resolved = try zip_codec.resolvedOptions(omitted_options, dictionary);
            try std.testing.expectEqual(dictionary.id, resolved.dictionary_id);
            try std.testing.expect(!resolved.include_dictionary_id);
            var omitted = try zip_codec.State.init(a, omitted_options, policy, dictionary, expected);
            defer omitted.deinit();
            var after_drive: AdapterDrive = .{ .state = &omitted };
            const after = try h.wire.encodeDrive(a, &after_drive, h.plain);
            defer a.free(after);
            try h.pair(before, after, Z.FrameFormat.standard, dictionary.id);
            try h.check(Z, after, h.plain, .standard, dictionary);
        }
    }
}
