//! Allocation-free normalization shared by initialization and consumer preflight.
const std = @import("std");
const types = @import("types.zig");

pub fn Prepared(comptime Codec: type) type {
    return struct { options: types.EncoderOptions(Codec.Options), config: types.Config(Codec) };
}

pub fn Limits(comptime Codec: type) type {
    _ = Codec;
    return struct {
        max_input_len: types.Count,
        max_output_len: types.Count,
        max_pending_output_len: usize,
        max_job_count: types.Count,
    };
}

pub fn limits(comptime Codec: type, options: types.EncoderOptions(Codec.Options)) Limits(Codec) {
    return .{ .max_input_len = options.max_input_len, .max_output_len = options.max_output_len, .max_pending_output_len = options.max_pending_output_len, .max_job_count = options.max_job_count };
}

pub fn applyLimits(comptime Codec: type, options: *types.EncoderOptions(Codec.Options), current: Limits(Codec)) void {
    options.max_input_len = current.max_input_len;
    options.max_output_len = current.max_output_len;
    options.max_pending_output_len = current.max_pending_output_len;
    if (current.max_job_count != 0) options.max_job_count = current.max_job_count;
}

pub fn prepare(comptime Codec: type, original: types.EncoderOptions(Codec.Options), expected: ?types.Count, dictionary: ?Codec.Dictionary, metadata_id: ?u32) Codec.Error!Prepared(Codec) {
    var options = original;
    var dictionary_id: ?u32 = null;
    if (metadata_id) |id| {
        if (id == 0) return error.NeedDictionary;
        if (dictionary != null or options.frame.selection != .raw_or_rle) return error.InvalidBlockPlan;
        dictionary_id = id;
    } else if (dictionary) |preset| {
        dictionary_id = preset.id;
    } else if (options.frame.dictionary_id != 0) return error.NeedDictionary;
    if (dictionary_id) |id| {
        if (options.frame.dictionary_id != 0 and options.frame.dictionary_id != id) return error.DictionaryMismatch;
        options.frame.dictionary_id = id;
    }
    try Codec.validateDictionaryMetadata(dictionary);
    const frame = Codec.stripProfiles(options.frame);
    try Codec.validateStream(frame, expected, dictionary_id);
    const window = try Codec.streamWindowLimit(frame, expected);
    const geometry = try types.Geometry.init(try Codec.streamBlockSize(frame, expected), options.parallel, options.max_job_count);
    return .{ .options = options, .config = .{
        .frame_options = frame,
        .parallel = options.parallel,
        .geometry = geometry,
        .history_window_len = @min(window, try Codec.historyLen(frame)),
        .expected_input_len = expected,
        .dictionary_id = dictionary_id,
        .dictionary = dictionary,
        .max_job_count = options.max_job_count,
    } };
}

pub fn heapLimit(comptime Codec: type, options: types.EncoderOptions(Codec.Options)) usize {
    return @min(options.parallel.max_working_memory, options.frame.max_total_working_memory orelse std.math.maxInt(usize));
}
