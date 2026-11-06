const std = @import("std");
const h = @import("common.zig");
const Z = h.Z;

pub fn run(init: std.process.Init, input: []const u8, c: h.Config, dict: Z.NativeDictionary, set: Z.NativeDictionarySet, s: *h.State) ![]u8 {
    if (std.mem.eql(u8, c.api, "incremental")) return @import("incremental.zig").serial(init, input, c, dict, set, s);
    if (std.mem.eql(u8, c.api, "incremental_parallel")) return @import("incremental.zig").parallel(init, input, c, dict, set, s);
    if (std.mem.startsWith(u8, c.api, "seekable_")) return @import("seekable.zig").run(init, input, c, dict, set, s);
    const options = h.native(c);
    const frame_options = h.frame(c);
    const selector = h.selected(c, dict);
    const level = std.mem.startsWith(u8, c.api, "level_");
    const parallel_api = std.mem.startsWith(u8, c.api, "parallel_");
    const reuse = std.mem.startsWith(u8, c.api, "reuse_");
    const limits = h.parallel(init, c, &s.parallel_profile);
    s.encoded_bound = if (parallel_api)
        (if (c.use_dictionary_set) try Z.encodedNativeParallelFrameBoundWithDictionarySet(input.len, options, set, selector, limits) else try Z.encodedNativeParallelFrameBoundWithDictionary(input.len, options, dict, limits))
    else if (level)
        (if (c.use_dictionary_set) try Z.encodedFrameBoundWithLevelAndOptionsAndDictionarySet(input.len, c.level, frame_options, set, selector) else try Z.encodedFrameBoundWithLevelAndOptionsAndDictionary(input.len, c.level, frame_options, dict))
    else
        (if (c.use_dictionary_set) try Z.encodedNativeFrameBoundWithDictionarySet(input.len, options, set, selector) else try Z.encodedNativeFrameBoundWithDictionary(input.len, options, dict));
    var encoder = Z.NativeFrameEncoder.init(init.gpa);
    defer encoder.deinit();
    if (reuse) {
        const warm = try encoder.encodeWithDictionaryAlloc("warm dictionary lifecycle", options, dict);
        init.gpa.free(warm.frame);
    }
    if (std.mem.endsWith(u8, c.api, "alloc")) {
        if (parallel_api) return if (c.use_dictionary_set) Z.encodeNativeParallelFrameWithDictionarySetAlloc(init.gpa, input, options, set, selector, limits) else Z.encodeNativeParallelFrameWithDictionaryAlloc(init.gpa, input, options, dict, limits);
        if (level) return if (c.use_dictionary_set) Z.encodeFrameWithLevelAndOptionsAndDictionarySetAlloc(init.gpa, input, c.level, frame_options, set, selector) else Z.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(init.gpa, input, c.level, frame_options, dict);
        const result = if (reuse)
            (if (c.use_dictionary_set) try encoder.encodeWithDictionarySetAlloc(input, options, set, selector) else try encoder.encodeWithDictionaryAlloc(input, options, dict))
        else
            (if (c.use_dictionary_set) try Z.encodeNativeFrameWithDictionarySetAlloc(init.gpa, input, options, set, selector) else try Z.encodeNativeFrameWithDictionaryAlloc(init.gpa, input, options, dict));
        s.mode = result.mode;
        return result.frame;
    }
    if (std.mem.eql(u8, c.api, "reuse_scratch")) {
        const result = if (c.use_dictionary_set) try encoder.encodeScratchWithDictionarySet(input, options, set, selector) else try encoder.encodeScratchWithDictionary(input, options, dict);
        s.mode = result.mode;
        return init.gpa.dupe(u8, result.frame);
    }
    if (std.mem.endsWith(u8, c.api, "append")) {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(init.gpa);
        try output.appendSlice(init.gpa, "prefix");
        if (parallel_api) {
            _ = if (c.use_dictionary_set) try Z.encodeNativeParallelFrameAppendWithDictionarySet(init.gpa, &output, input, options, set, selector, limits) else try Z.encodeNativeParallelFrameAppendWithDictionary(init.gpa, &output, input, options, dict, limits);
        } else if (level) {
            _ = if (c.use_dictionary_set) try Z.encodeFrameAppendWithLevelAndOptionsAndDictionarySet(init.gpa, &output, input, c.level, frame_options, set, selector) else try Z.encodeFrameAppendWithLevelAndOptionsAndDictionary(init.gpa, &output, input, c.level, frame_options, dict);
        } else if (reuse) {
            s.mode = if (c.use_dictionary_set) try encoder.encodeAppendWithDictionarySet(&output, input, options, set, selector) else try encoder.encodeAppendWithDictionary(&output, input, options, dict);
        } else {
            s.mode = if (c.use_dictionary_set) try Z.encodeNativeFrameAppendWithDictionarySet(init.gpa, &output, input, options, set, selector) else try Z.encodeNativeFrameAppendWithDictionary(init.gpa, &output, input, options, dict);
        }
        try h.require(std.mem.eql(u8, output.items[0..6], "prefix"));
        s.caller_guards_verified = true;
        return init.gpa.dupe(u8, output.items[6..]);
    }
    if (std.mem.endsWith(u8, c.api, "into")) {
        const capacity = if (c.short_output) 0 else s.encoded_bound.?;
        const output = try init.gpa.alloc(u8, capacity + 19);
        defer init.gpa.free(output);
        @memset(output, 0xa5);
        const count = into(init, input, c, dict, set, s, &encoder, output[0..capacity]) catch |err| {
            try h.guard(output);
            s.caller_guards_verified = true;
            return err;
        };
        try h.guard(output[count..]);
        s.caller_guards_verified = true;
        return init.gpa.dupe(u8, output[0..count]);
    }
    return error.UnknownProbeApi;
}
fn into(init: std.process.Init, input: []const u8, c: h.Config, dict: Z.NativeDictionary, set: Z.NativeDictionarySet, s: *h.State, encoder: *Z.NativeFrameEncoder, output: []u8) !usize {
    const options = h.native(c);
    const selector = h.selected(c, dict);
    if (std.mem.startsWith(u8, c.api, "parallel_")) {
        const limits = h.parallel(init, c, &s.parallel_profile);
        return if (c.use_dictionary_set) Z.encodeNativeParallelFrameIntoSliceWithDictionarySet(init.gpa, input, options, set, selector, output, limits) else Z.encodeNativeParallelFrameIntoSliceWithDictionary(init.gpa, input, options, dict, output, limits);
    }
    if (std.mem.startsWith(u8, c.api, "level_")) return if (c.use_dictionary_set) Z.encodeFrameIntoSliceWithLevelAndOptionsAndDictionarySet(init.gpa, input, c.level, h.frame(c), set, selector, output) else Z.encodeFrameIntoSliceWithLevelAndOptionsAndDictionary(init.gpa, input, c.level, h.frame(c), dict, output);
    const result = if (std.mem.startsWith(u8, c.api, "reuse_"))
        (if (c.use_dictionary_set) try encoder.encodeIntoSliceWithDictionarySet(input, options, set, selector, output) else try encoder.encodeIntoSliceWithDictionary(input, options, dict, output))
    else
        (if (c.use_dictionary_set) try Z.encodeNativeFrameIntoSliceWithDictionarySet(init.gpa, input, options, set, selector, output) else try Z.encodeNativeFrameIntoSliceWithDictionary(init.gpa, input, options, dict, output));
    s.mode = result.mode;
    return result.written;
}
