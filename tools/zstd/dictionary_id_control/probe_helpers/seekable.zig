const std = @import("std");
const h = @import("common.zig");
const Z = h.Z;

pub fn run(init: std.process.Init, input: []const u8, c: h.Config, dict: Z.NativeDictionary, set: Z.NativeDictionarySet, s: *h.State) ![]u8 {
    const options: Z.NativeSeekableOptions = .{ .frame_size = c.frame_size, .frame_options = h.native(c), .seek_checksums = c.checksum };
    const selector = h.selected(c, dict);
    s.encoded_bound = if (c.use_dictionary_set) try Z.encodedNativeSeekableStreamBoundWithDictionarySet(input.len, options, set, selector) else try Z.encodedNativeSeekableStreamBoundWithDictionary(input.len, options, dict);
    var encoder = Z.NativeSeekableStreamEncoder.init(init.gpa);
    defer encoder.deinit();
    const reuse = std.mem.startsWith(u8, c.api, "seekable_reuse_");
    if (reuse) {
        const warm = try encoder.encodeWithDictionaryAlloc("warm seekable lifecycle", options, dict);
        init.gpa.free(warm);
    }
    if (std.mem.eql(u8, c.api, "seekable_parallel")) return if (c.use_dictionary_set) Z.encodeNativeSeekableStreamParallelWithDictionarySetAlloc(init.gpa, input, options, set, selector, c.worker_count) else Z.encodeNativeSeekableStreamParallelWithDictionaryAlloc(init.gpa, input, options, dict, c.worker_count);
    if (std.mem.endsWith(u8, c.api, "alloc")) {
        if (reuse) return if (c.use_dictionary_set) encoder.encodeWithDictionarySetAlloc(input, options, set, selector) else encoder.encodeWithDictionaryAlloc(input, options, dict);
        return if (c.use_dictionary_set) Z.encodeNativeSeekableStreamWithDictionarySetAlloc(init.gpa, input, options, set, selector) else Z.encodeNativeSeekableStreamWithDictionaryAlloc(init.gpa, input, options, dict);
    }
    if (std.mem.endsWith(u8, c.api, "scratch")) {
        const bytes = if (c.use_dictionary_set) try encoder.encodeScratchWithDictionarySet(input, options, set, selector) else try encoder.encodeScratchWithDictionary(input, options, dict);
        return init.gpa.dupe(u8, bytes);
    }
    if (std.mem.endsWith(u8, c.api, "append")) {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(init.gpa);
        try output.appendSlice(init.gpa, "prefix");
        if (reuse) {
            if (c.use_dictionary_set) try encoder.encodeAppendWithDictionarySet(&output, input, options, set, selector) else try encoder.encodeAppendWithDictionary(&output, input, options, dict);
        } else {
            if (c.use_dictionary_set) try Z.encodeNativeSeekableStreamAppendWithDictionarySet(init.gpa, &output, input, options, set, selector) else try Z.encodeNativeSeekableStreamAppendWithDictionary(init.gpa, &output, input, options, dict);
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
        const result = into(init, input, c, dict, set, options, &encoder, output[0..capacity]) catch |err| {
            try h.guard(output);
            s.caller_guards_verified = true;
            return err;
        };
        try h.guard(output[result..]);
        s.caller_guards_verified = true;
        return init.gpa.dupe(u8, output[0..result]);
    }
    return error.UnknownProbeApi;
}
fn into(init: std.process.Init, input: []const u8, c: h.Config, dict: Z.NativeDictionary, set: Z.NativeDictionarySet, options: Z.NativeSeekableOptions, encoder: *Z.NativeSeekableStreamEncoder, output: []u8) !usize {
    const selector = h.selected(c, dict);
    if (std.mem.startsWith(u8, c.api, "seekable_reuse_")) return if (c.use_dictionary_set) encoder.encodeIntoSliceWithDictionarySet(input, options, set, selector, output) else encoder.encodeIntoSliceWithDictionary(input, options, dict, output);
    return if (c.use_dictionary_set) Z.encodeNativeSeekableStreamIntoSliceWithDictionarySet(init.gpa, input, options, set, selector, output) else Z.encodeNativeSeekableStreamIntoSliceWithDictionary(init.gpa, input, options, dict, output);
}
