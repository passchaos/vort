const std = @import("std");
const h = @import("common.zig");
const Z = h.Z;

pub fn serial(init: std.process.Init, input: []const u8, c: h.Config, dict: Z.NativeDictionary, set: Z.NativeDictionarySet, s: *h.State) ![]u8 {
    var options = h.native(c);
    options.dictionary_id = dict.id;
    const selector = h.selected(c, dict);
    var encoder = if (c.use_dictionary_set)
        (if (c.known_size) try Z.NativeIncrementalFrameEncoder.initExactSizeWithDictionarySet(init.gpa, options, input.len, set, selector) else try Z.NativeIncrementalFrameEncoder.initWithDictionarySet(init.gpa, options, set, selector))
    else
        (if (c.known_size) try Z.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(init.gpa, options, input.len, dict) else try Z.NativeIncrementalFrameEncoder.initWithPresetDictionary(init.gpa, options, dict));
    defer encoder.deinit();
    s.encoded_bound = try Z.encodedNativeFrameBoundWithDictionary(input.len, options, dict);
    return drive(init, input, c, &encoder, s);
}
pub fn parallel(init: std.process.Init, input: []const u8, c: h.Config, dict: Z.NativeDictionary, set: Z.NativeDictionarySet, s: *h.State) ![]u8 {
    var frame = h.native(c);
    frame.dictionary_id = dict.id;
    const options: Z.NativeIncrementalParallelFrameEncoder.Options = .{ .frame = frame, .parallel = .{ .io = if (c.synchronous) std.Io.failing else init.io, .worker_count = c.worker_count, .job_size = c.block_size, .max_inflight_jobs = 4, .max_inflight_bytes = c.block_size * 4, .profile = &s.incremental_parallel_profile } };
    const selector = h.selected(c, dict);
    var encoder = if (c.use_dictionary_set)
        (if (c.known_size) try Z.NativeIncrementalParallelFrameEncoder.initExactSizeWithDictionarySet(init.gpa, options, input.len, set, selector) else try Z.NativeIncrementalParallelFrameEncoder.initWithDictionarySet(init.gpa, options, set, selector))
    else
        (if (c.known_size) try Z.NativeIncrementalParallelFrameEncoder.initExactSizeWithPresetDictionary(init.gpa, options, input.len, dict) else try Z.NativeIncrementalParallelFrameEncoder.initWithPresetDictionary(init.gpa, options, dict));
    defer encoder.deinit();
    s.encoded_bound = try Z.encodedNativeFrameBoundWithDictionary(input.len, frame, dict);
    return drive(init, input, c, &encoder, s);
}
fn drive(init: std.process.Init, input: []const u8, c: h.Config, encoder: anytype, s: *h.State) ![]u8 {
    const scratch = try init.gpa.alloc(u8, c.output_chunk);
    defer init.gpa.free(scratch);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(init.gpa);
    var offset: usize = 0;
    var finished = false;
    for (0..input.len * 8 + 65536) |_| {
        if (offset == input.len and !finished) {
            encoder.finish();
            finished = true;
        }
        const end = offset + @min(input.len - offset, c.input_chunk);
        const result = try encoder.step(input[offset..end], scratch);
        try h.require(result.progress.input_read <= end - offset and result.progress.output_written <= scratch.len);
        offset += result.progress.input_read;
        s.public_step_calls += 1;
        try output.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
        if (result.status == .done) {
            try h.require(offset == input.len);
            s.input_consumed = offset;
            return output.toOwnedSlice(init.gpa);
        }
    }
    return error.ProbeDidNotConverge;
}
