//! Probe JSON policy and exact public encoder construction.
const std = @import("std");
const zstd = @import("zstd");
const E = zstd.NativeIncrementalParallelFrameEncoder;
const ParallelProfile = @TypeOf(@as(E.Snapshot, undefined).parallel.profile);
pub const Count = u64;

pub const Config = struct {
    scenario: enum { normal, seal, pledge_lookahead, input_lookahead, credit, partial_credit, flush, pending_retry, input_retry, output_retry, jobs_retry, move, reset, concat, skippable, sticky } = .normal,
    format: zstd.FrameFormat = .standard,
    selection: zstd.NativeFrameSelection = .auto,
    strategy: zstd.Strategy = .auto,
    hq: ?zstd.HqOptions = null,
    rep_beam_search: bool = false,
    match_search_budget: usize = 512,
    checksum: bool = true,
    content_size: bool = false,
    pledge_delta: i64 = 0,
    block_size: usize = 4096,
    window_log: ?u6 = 15,
    max_match_history_len: ?usize = 32768,
    dictionary_kind: enum { none, raw, full, metadata } = .none,
    dictionary_path: ?[]const u8 = null,
    dictionary_id: u32 = 0,
    use_dictionary_set: bool = false,
    worker_count: usize = 3,
    job_size: usize = 8192,
    max_inflight_jobs: usize = 4,
    max_inflight_bytes: usize = 32768,
    max_working_memory: usize = 256 * 1024 * 1024,
    max_input_len: Count = std.math.maxInt(Count),
    max_output_len: Count = std.math.maxInt(Count),
    max_pending_output_len: usize = 16 * 1024 * 1024,
    max_job_count: Count = std.math.maxInt(Count),
    input_chunks: []const usize = &.{ 1, 7, 31, 257, 8192 },
    output_chunks: []const usize = &.{ 0, 1, 3, 257 },
    flush_offsets: []const usize = &.{},
    record_every: usize = 1,
    frames: usize = 1,
    expected_error: ?[]const u8 = null,
};

pub fn encoderOptions(init: std.process.Init, c: Config, dictionary: ?zstd.NativeDictionary, control: *zstd.EncoderControlProfile, profile: *ParallelProfile, fallback: bool) E.Options {
    return .{
        .frame = .{
            .format = c.format,
            .selection = c.selection,
            .strategy = c.strategy,
            .content_checksum = c.checksum,
            .include_content_size = c.content_size,
            .block_size_max = c.block_size,
            .window_log = c.window_log,
            .max_match_history_len = c.max_match_history_len,
            .dictionary_id = if (dictionary) |dict| dict.id else c.dictionary_id,
            .control_profile = control,
            .hq = c.hq,
            .rep_beam_search = c.rep_beam_search,
            .match_search_budget = c.match_search_budget,
        },
        .parallel = .{ .io = if (fallback) std.Io.failing else init.io, .worker_count = c.worker_count, .job_size = c.job_size, .max_inflight_jobs = c.max_inflight_jobs, .max_inflight_bytes = c.max_inflight_bytes, .max_working_memory = c.max_working_memory, .profile = profile },
        .max_input_len = c.max_input_len,
        .max_output_len = c.max_output_len,
        .max_pending_output_len = c.max_pending_output_len,
        .max_job_count = c.max_job_count,
    };
}

pub fn pledge(c: Config, input_len: usize) !?Count {
    if (!c.content_size) return null;
    const length: i128 = @as(i128, @intCast(input_len)) + c.pledge_delta;
    if (length < 0 or length > std.math.maxInt(Count)) return error.InvalidPledge;
    return @intCast(length);
}

pub fn create(allocator: std.mem.Allocator, c: Config, dictionary: ?zstd.NativeDictionary, set: zstd.NativeDictionarySet, options: E.Options, expected: ?Count) !E {
    if (c.use_dictionary_set) {
        const id = if (dictionary) |dict| dict.id else c.dictionary_id;
        if (expected) |length| return E.initExactSizeWithDictionarySet(allocator, options, length, set, id);
        return E.initWithDictionarySet(allocator, options, set, id);
    }
    if (c.dictionary_kind == .metadata) {
        if (expected) |length| return E.initExactSizeWithDictionary(allocator, options, length, c.dictionary_id);
        return E.initWithDictionary(allocator, options, c.dictionary_id);
    }
    if (dictionary) |dict| {
        if (expected) |length| return E.initExactSizeWithPresetDictionary(allocator, options, length, dict);
        return E.initWithPresetDictionary(allocator, options, dict);
    }
    if (expected) |length| return E.initExactSize(allocator, options, length);
    return E.init(allocator, options);
}

pub fn next(encoder: *E, c: Config, dictionary: ?zstd.NativeDictionary, set: zstd.NativeDictionarySet, options: E.Options, expected: ?Count) !void {
    if (c.use_dictionary_set) {
        const id = if (dictionary) |dict| dict.id else c.dictionary_id;
        if (expected) |length| return encoder.nextFrameExactSizeWithDictionarySet(options, length, set, id);
        return encoder.nextFrameWithDictionarySet(options, set, id);
    }
    if (c.dictionary_kind == .metadata) {
        if (expected) |length| return encoder.nextFrameExactSizeWithDictionary(options, length, c.dictionary_id);
        return encoder.nextFrameWithDictionary(options, c.dictionary_id);
    }
    if (dictionary) |dict| {
        if (expected) |length| return encoder.nextFrameExactSizeWithPresetDictionary(options, length, dict);
        return encoder.nextFrameWithPresetDictionary(options, dict);
    }
    if (expected) |length| return encoder.nextFrameExactSize(options, length);
    return encoder.nextFrame(options);
}

pub fn headerLen(c: Config, dictionary: ?zstd.NativeDictionary, expected: ?Count) usize {
    const magic: usize = if (c.format == .standard) 4 else 0;
    const id = if (dictionary) |dict| dict.id else c.dictionary_id;
    const id_bytes: usize = if (id == 0) 0 else if (id <= 255) 1 else if (id <= 65535) 2 else 4;
    const length = expected orelse return magic + 2 + id_bytes;
    const single = if (c.window_log) |log| length <= (@as(u64, 1) << log) else true;
    const field: usize = if (length <= 255) 1 else if (length <= 65791) 2 else if (length <= std.math.maxInt(u32)) 4 else 8;
    return magic + 1 + @as(usize, if (single) 0 else 1) + id_bytes + field;
}
