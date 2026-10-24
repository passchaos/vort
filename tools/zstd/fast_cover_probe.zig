const std = @import("std");
const vort = @import("vort");
const codec = vort.zstd;
const selector = vort.dictionary;
const Profile = selector.FastCoverTrainProfile;
const OptimizeOptions = selector.FastCoverOptimizeOptions;
const OptimizeProfile = selector.FastCoverOptimizeProfile;
const Score = selector.FastCoverOptimizeScore;

const Config = struct {
    mode: []const u8 = "raw",
    training_paths: []const []const u8 = &.{},
    selector_paths: []const []const u8 = &.{},
    heldout_paths: []const []const u8 = &.{},
    target_size: usize = 512,
    segment_size: ?usize = 64,
    dmer_size: u8 = 6,
    hash_log: u8 = 12,
    acceleration: u8 = 1,
    max_corpus_size: usize = 256 * 1024 * 1024,
    max_working_memory: usize = 128 * 1024 * 1024,
    max_dictionary_size: usize = 64 * 1024 * 1024,
    dictionary_id: u32 = 0xfa570001,
    levels: []const c_int = &.{ 1, 3 },
    profile_enabled: bool = true,
    encode_selector: bool = false,
    candidate_repcodes: bool = false,
    segment_sizes: []const usize = &.{ 32, 64 },
    dmer_sizes: []const u8 = &.{ 6, 8 },
    hash_logs: []const u8 = &.{12},
    accelerations: []const u8 = &.{1},
    steps: usize = 2,
    max_samples: usize = 1024 * 1024,
    max_candidates: usize = 64,
    max_scoring_calls: usize = 8192,
    threads: usize = 1,
    max_threads: usize = 16,
    shrink_dictionary: bool = false,
    shrink_min_size: usize = 128,
    regression_tolerance_bps: u16 = 0,
    split_numerator: usize = 3,
    split_denominator: usize = 4,
    fail_index: ?usize = null,
    dictionary_path: ?[]const u8 = null,
    full_dictionary: bool = false,
    frame_path: ?[]const u8 = null,
    expected_path: ?[]const u8 = null,
    expect_failure: bool = false,
};

const Tracking = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    highest_peak: usize = 0,
    allocations: usize = 0,
    frees: usize = 0,
    fn allocator(self: *Tracking) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn changed(self: *Tracking, old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
        self.highest_peak = @max(self.highest_peak, self.live);
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *Tracking = @ptrCast(@alignCast(raw));
        const memory = self.backing.rawAlloc(len, alignment, address) orelse return null;
        self.changed(0, len);
        self.allocations += 1;
        return memory;
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *Tracking = @ptrCast(@alignCast(raw));
        if (!self.backing.rawResize(memory, alignment, len, address)) return false;
        self.changed(memory.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *Tracking = @ptrCast(@alignCast(raw));
        const result = self.backing.rawRemap(memory, alignment, len, address) orelse return null;
        self.changed(memory.len, len);
        return result;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *Tracking = @ptrCast(@alignCast(raw));
        self.backing.rawFree(memory, alignment, address);
        self.changed(memory.len, 0);
        self.frees += 1;
    }
};

const Trained = struct {
    bytes: []u8,
    full: bool = false,
    profile: Profile,
    preparation_profile: Profile = .{},
    training_ns: usize,
    preparation_ns: usize = 0,
    prepared_working_bytes: usize = 0,
    prepared_reuse_verified: bool = false,
    training_peak: usize = 0,
    standard_profile: ?codec.FastCoverStandardDictionaryTrainingProfile = null,
    optimization_profile: ?OptimizeProfile = null,
    standard_search_profile: ?codec.FastCoverCodecSearchProfile = null,
    selected_options: ?selector.FastCoverTrainOptions = null,
    validation_score: ?Score = null,
    candidates_evaluated: usize = 0,
    original_dictionary_size: usize = 0,
};
const Frame = struct {
    path: []const u8,
    input_path: []const u8,
    partition: []const u8,
    level: c_int,
    input_bytes: usize,
    encoded_bytes: usize,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const config_path = args.next() orelse return error.MissingConfig;
    const prefix = args.next() orelse return error.MissingOutput;
    if (args.next() != null) return error.TooManyArguments;
    const configuration = try read(init, config_path);
    defer init.gpa.free(configuration);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, configuration, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (std.mem.eql(u8, config.mode, "decode_reference")) return decodeReference(init, config, prefix);
    const training = try readSamples(init, config.training_paths);
    defer freeSamples(init.gpa, training);
    const validation = try readSamples(init, config.selector_paths);
    defer freeSamples(init.gpa, validation);
    var failing = std.testing.FailingAllocator.init(init.gpa, .{ .fail_index = config.fail_index orelse std.math.maxInt(usize) });
    var tracked: Tracking = .{ .backing = failing.allocator() };
    var profile: Profile = .{};
    const options: selector.FastCoverTrainOptions = .{
        .target_size = config.target_size,
        .segment_size = config.segment_size,
        .dmer_size = config.dmer_size,
        .hash_log = config.hash_log,
        .acceleration = config.acceleration,
        .max_corpus_size = config.max_corpus_size,
        .max_working_memory = config.max_working_memory,
        .max_dictionary_size = config.max_dictionary_size,
        .profile = if (config.profile_enabled) &profile else null,
    };
    var failure: ?[]const u8 = null;
    const attempted = train(init, &tracked, training, validation, options, config);
    const trained: ?Trained = attempted catch |err| blk: {
        if (!config.expect_failure) return err;
        failure = @errorName(err);
        break :blk null;
    };
    defer if (trained) |value| init.gpa.free(value.bytes);
    if (tracked.live != 0) return error.TrainingAllocationLeak;
    if ((failure != null) != config.expect_failure) return error.UnexpectedTrainingResult;
    var training_ns_samples: [3]usize = @splat(0);
    var preparation_ns_samples: [3]usize = @splat(0);
    if (trained) |value| {
        training_ns_samples[0] = value.training_ns;
        preparation_ns_samples[0] = value.preparation_ns;
        var repeated_profile: Profile = .{};
        var repeated_options = options;
        repeated_options.profile = if (config.profile_enabled) &repeated_profile else null;
        const repeated = try train(init, &tracked, training, validation, repeated_options, config);
        defer init.gpa.free(repeated.bytes);
        training_ns_samples[1] = repeated.training_ns;
        preparation_ns_samples[1] = repeated.preparation_ns;
        if (tracked.live != 0 or !std.mem.eql(u8, value.bytes, repeated.bytes)) return error.NonDeterministicTraining;
        var unprofiled_options = options;
        unprofiled_options.profile = null;
        var unprofiled_config = config;
        unprofiled_config.profile_enabled = false;
        const unprofiled = try train(init, &tracked, training, validation, unprofiled_options, unprofiled_config);
        defer init.gpa.free(unprofiled.bytes);
        training_ns_samples[2] = unprofiled.training_ns;
        preparation_ns_samples[2] = unprofiled.preparation_ns;
        if (tracked.live != 0 or !std.mem.eql(u8, value.bytes, unprofiled.bytes)) return error.ProfileChangedDictionary;
    }
    const dictionary_path = try std.fmt.allocPrint(init.gpa, "{s}.dict", .{prefix});
    defer init.gpa.free(dictionary_path);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = dictionary_path, .data = if (trained) |value| value.bytes else &.{} });
    var frames: std.ArrayList(Frame) = .empty;
    defer {
        for (frames.items) |frame| init.gpa.free(frame.path);
        frames.deinit(init.gpa);
    }
    var content_bytes: usize = 0;
    var content_reference_verified = false;
    var dictionary_id: u32 = 0;
    if (trained) |value| {
        const dictionary = if (value.full) (try codec.NativeDictionary.initFromStandardDictionary(value.bytes)).dictionary else codec.NativeDictionary.init(0, value.bytes);
        content_bytes = dictionary.content.len;
        dictionary_id = dictionary.id;
        try encodeFrames(init, dictionary, config.heldout_paths, config.levels, prefix, "heldout", &frames);
        if (config.encode_selector or std.mem.eql(u8, config.mode, "codec_optimized_full"))
            try encodeFrames(init, dictionary, config.selector_paths, config.levels, prefix, "selector", &frames);
        if (dictionary.content.len >= 4) {
            const suffix = dictionary.content[dictionary.content.len - @min(dictionary.content.len, 512) ..];
            const input = try init.gpa.alloc(u8, suffix.len * 2 + 1);
            defer init.gpa.free(input);
            @memcpy(input[0..suffix.len], suffix);
            @memcpy(input[suffix.len .. suffix.len * 2], suffix);
            input[suffix.len * 2] = suffix[suffix.len - 1] +% 1;
            var controls: codec.EncoderControlProfile = .{};
            const frame = try codec.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(init.gpa, input, 3, .{ .strategy = .fast, .control_profile = &controls, .include_content_size = false, .window_log = 16 }, dictionary);
            defer init.gpa.free(frame);
            if (controls.dictionary_sequences == 0) return error.NoTrainedDictionaryReference;
            const restored = try codec.decodeFrameAllocWithDictionary(init.gpa, frame, dictionary);
            defer init.gpa.free(restored);
            if (!std.mem.eql(u8, input, restored)) return error.TrainedDictionaryReferenceMismatch;
            if (codec.decodeFrameAlloc(init.gpa, frame)) |unexpected| {
                init.gpa.free(unexpected);
                return error.TrainedDictionaryNotRequired;
            } else |_| {}
            const proof_frame = try std.fmt.allocPrint(init.gpa, "{s}-content-reference.zst", .{prefix});
            defer init.gpa.free(proof_frame);
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = proof_frame, .data = frame });
            content_reference_verified = true;
        }
    }
    try printJson(init, .{
        .@"error" = failure,
        .dictionary_path = dictionary_path,
        .dictionary_bytes = if (trained) |value| value.bytes.len else 0,
        .content_bytes = content_bytes,
        .dictionary_id = dictionary_id,
        .full_dictionary = if (trained) |value| value.full else false,
        .deterministic = trained != null,
        .profile_dictionary_verified = trained != null,
        .content_reference_verified = content_reference_verified,
        .training_ns = if (trained) |value| value.training_ns else 0,
        .training_ns_samples = training_ns_samples,
        .preparation_ns_samples = preparation_ns_samples,
        .preparation_ns = if (trained) |value| value.preparation_ns else 0,
        .prepared_working_bytes = if (trained) |value| value.prepared_working_bytes else 0,
        .prepared_reuse_verified = if (trained) |value| value.prepared_reuse_verified else false,
        .profile = if (trained) |value| value.profile else profile,
        .preparation_profile = if (trained) |value| value.preparation_profile else Profile{},
        .standard_profile = if (trained) |value| value.standard_profile else null,
        .optimization_profile = if (trained) |value| value.optimization_profile else null,
        .standard_search_profile = if (trained) |value| value.standard_search_profile else null,
        .selected_options = if (trained) |value| value.selected_options else null,
        .validation_score = if (trained) |value| value.validation_score else null,
        .candidates_evaluated = if (trained) |value| value.candidates_evaluated else 0,
        .original_dictionary_size = if (trained) |value| value.original_dictionary_size else 0,
        .peak_requested_training_bytes = if (trained) |value| value.training_peak else tracked.peak,
        .peak_requested_training_and_validation_bytes = tracked.highest_peak,
        .live_training_bytes_after_free = tracked.live,
        .allocations = tracked.allocations,
        .frees = tracked.frees,
        .frames = frames.items,
    });
}

fn train(init: std.process.Init, tracked: *Tracking, samples: []const []const u8, validation: []const []const u8, options: selector.FastCoverTrainOptions, config: Config) !Trained {
    if (tracked.live != 0) return error.TrainingStateLeak;
    tracked.peak = 0;
    const allocator = tracked.allocator();
    if (std.mem.eql(u8, config.mode, "full")) {
        var standard_profile: codec.FastCoverStandardDictionaryTrainingProfile = .{};
        const start = std.Io.Clock.awake.now(init.io);
        const owned = if (config.profile_enabled)
            try codec.profileFastCoverStandardDictionaryAlloc(allocator, init.io, samples, options, config.dictionary_id, &standard_profile)
        else
            try codec.trainFastCoverStandardDictionaryAlloc(allocator, samples, options, config.dictionary_id);
        const training_ns = elapsed(init, start);
        defer owned.deinit(allocator);
        return .{ .bytes = try init.gpa.dupe(u8, owned.bytes), .full = true, .profile = if (config.profile_enabled) standard_profile.training else .{}, .standard_profile = if (config.profile_enabled) standard_profile else null, .training_ns = training_ns, .training_peak = tracked.peak };
    }
    if (std.mem.eql(u8, config.mode, "prepared")) {
        const prepare_start = std.Io.Clock.awake.now(init.io);
        var prepared = try selector.PreparedFastCover.init(allocator, samples, options);
        defer prepared.deinit(allocator);
        const preparation_ns = elapsed(init, prepare_start);
        const preparation_profile = if (options.profile) |p| p.* else Profile{};
        if (options.profile) |p| p.reset();
        const start = std.Io.Clock.awake.now(init.io);
        const first = try prepared.trainAlloc(allocator, options);
        const training_ns = elapsed(init, start);
        defer allocator.free(first);
        const first_profile = if (options.profile) |p| p.* else Profile{};
        const training_peak = tracked.peak;
        const second = try prepared.trainAlloc(allocator, options);
        defer allocator.free(second);
        if (!std.mem.eql(u8, first, second)) return error.PreparedReuseChangedDictionary;
        var fork = try prepared.fork(allocator, options.max_working_memory);
        defer fork.deinit(allocator);
        const forked = try fork.trainAlloc(allocator, options);
        defer allocator.free(forked);
        if (!std.mem.eql(u8, first, forked)) return error.PreparedForkChangedDictionary;
        const retained = prepared.workingBytes();
        prepared.reset();
        if (prepared.workingBytes() != retained) return error.PreparedResetReleasedCapacity;
        if (prepared.trainAlloc(allocator, options)) |unexpected| {
            allocator.free(unexpected);
            return error.PreparedResetKeptReadyState;
        } else |err| if (err != error.InvalidDictionaryTraining) return err;
        try prepared.prepare(allocator, samples, options);
        const restored = try prepared.trainAlloc(allocator, options);
        defer allocator.free(restored);
        if (!std.mem.eql(u8, first, restored)) return error.PreparedResetChangedDictionary;
        return .{ .bytes = try init.gpa.dupe(u8, first), .profile = first_profile, .preparation_profile = preparation_profile, .training_ns = training_ns, .preparation_ns = preparation_ns, .prepared_working_bytes = prepared.workingBytes(), .prepared_reuse_verified = true, .training_peak = training_peak };
    }
    if (std.mem.eql(u8, config.mode, "optimized_raw") or std.mem.eql(u8, config.mode, "optimized_split_raw") or std.mem.eql(u8, config.mode, "optimized_full") or std.mem.eql(u8, config.mode, "codec_optimized_full"))
        return optimize(init, tracked, samples, validation, config);
    if (!std.mem.eql(u8, config.mode, "raw")) return error.InvalidMode;
    const start = std.Io.Clock.awake.now(init.io);
    const bytes = try selector.trainFastCoverAlloc(allocator, samples, options);
    const training_ns = elapsed(init, start);
    defer allocator.free(bytes);
    return .{ .bytes = try init.gpa.dupe(u8, bytes), .profile = if (options.profile) |p| p.* else .{}, .training_ns = training_ns, .training_peak = tracked.peak };
}

fn optimize(init: std.process.Init, tracked: *Tracking, training: []const []const u8, validation: []const []const u8, config: Config) !Trained {
    var profile: OptimizeProfile = .{};
    const options: OptimizeOptions = .{
        .target_size = config.target_size,
        .segment_sizes = config.segment_sizes,
        .dmer_sizes = config.dmer_sizes,
        .hash_logs = config.hash_logs,
        .accelerations = config.accelerations,
        .steps = config.steps,
        .max_corpus_size = config.max_corpus_size,
        .max_samples = config.max_samples,
        .max_working_memory = config.max_working_memory,
        .max_dictionary_size = config.max_dictionary_size,
        .max_candidates = config.max_candidates,
        .max_scoring_calls = config.max_scoring_calls,
        .threads = config.threads,
        .max_threads = config.max_threads,
        .shrink_dictionary = config.shrink_dictionary,
        .shrink_min_size = config.shrink_min_size,
        .regression_tolerance_bps = config.regression_tolerance_bps,
        .profile = if (config.profile_enabled) &profile else null,
    };
    const allocator = tracked.allocator();
    const start = std.Io.Clock.awake.now(init.io);
    if (std.mem.eql(u8, config.mode, "optimized_raw") or std.mem.eql(u8, config.mode, "optimized_split_raw")) {
        const owned = if (std.mem.eql(u8, config.mode, "optimized_split_raw"))
            try selector.trainOptimizedFastCoverSplitAlloc(allocator, training, .{ .numerator = config.split_numerator, .denominator = config.split_denominator }, options)
        else
            try selector.trainOptimizedFastCoverAlloc(allocator, training, validation, options);
        const training_ns = elapsed(init, start);
        defer owned.deinit(allocator);
        var selected = owned.selected_options;
        selected.profile = null;
        return .{ .bytes = try init.gpa.dupe(u8, owned.bytes), .profile = owned.profile.training, .optimization_profile = owned.profile, .selected_options = selected, .validation_score = owned.validation_score, .candidates_evaluated = owned.candidates_evaluated, .original_dictionary_size = owned.original_dictionary_size, .training_ns = training_ns, .training_peak = tracked.peak };
    }
    var search_profile: codec.FastCoverCodecSearchProfile = .{};
    const codec_options: codec.FastCoverDictionaryCodecOptimizeOptions = .{ .fast_cover = options, .levels = config.levels, .candidate_repcodes = config.candidate_repcodes };
    const owned = if (std.mem.eql(u8, config.mode, "codec_optimized_full"))
        if (config.profile_enabled) try codec.profileCodecOptimizedFastCoverStandardDictionaryAlloc(allocator, init.io, training, validation, codec_options, config.dictionary_id, &search_profile) else try codec.trainCodecOptimizedFastCoverStandardDictionaryAlloc(allocator, training, validation, codec_options, config.dictionary_id)
    else if (config.profile_enabled)
        try codec.profileOptimizedFastCoverStandardDictionaryAlloc(allocator, init.io, training, validation, options, config.dictionary_id, &search_profile)
    else
        try codec.trainOptimizedFastCoverStandardDictionaryAlloc(allocator, training, validation, options, config.dictionary_id);
    const training_ns = elapsed(init, start);
    defer owned.deinit(allocator);
    var selected = owned.selected_options;
    selected.profile = null;
    return .{ .bytes = try init.gpa.dupe(u8, owned.bytes), .full = true, .profile = search_profile.search.training, .optimization_profile = if (config.profile_enabled) search_profile.search else null, .standard_search_profile = if (config.profile_enabled) search_profile else null, .selected_options = selected, .validation_score = owned.validation_score, .candidates_evaluated = owned.candidates_evaluated, .original_dictionary_size = owned.original_dictionary_size, .training_ns = training_ns, .training_peak = tracked.peak };
}

fn encodeFrames(init: std.process.Init, dictionary: codec.NativeDictionary, paths: []const []const u8, levels: []const c_int, prefix: []const u8, partition: []const u8, frames: *std.ArrayList(Frame)) !void {
    for (paths, 0..) |path, index| {
        const input = try read(init, path);
        defer init.gpa.free(input);
        for (levels) |level| {
            const frame = try codec.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(init.gpa, input, level, .{ .content_checksum = std.mem.eql(u8, partition, "heldout") }, dictionary);
            defer init.gpa.free(frame);
            const restored = try codec.decodeFrameAllocWithDictionary(init.gpa, frame, dictionary);
            defer init.gpa.free(restored);
            if (!std.mem.eql(u8, input, restored)) return error.TrainedDictionaryRoundTrip;
            const path_out = try std.fmt.allocPrint(init.gpa, "{s}-{s}-{d}-level{d}.zst", .{ prefix, partition, index, level });
            errdefer init.gpa.free(path_out);
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path_out, .data = frame });
            try frames.append(init.gpa, .{ .path = path_out, .input_path = path, .partition = partition, .level = level, .input_bytes = input.len, .encoded_bytes = frame.len });
        }
    }
}

fn decodeReference(init: std.process.Init, config: Config, prefix: []const u8) !void {
    const dictionary_bytes = try read(init, config.dictionary_path orelse return error.MissingDictionary);
    defer init.gpa.free(dictionary_bytes);
    const dictionary = if (config.full_dictionary) (try codec.NativeDictionary.initFromStandardDictionary(dictionary_bytes)).dictionary else codec.NativeDictionary.init(0, dictionary_bytes);
    const frame = try read(init, config.frame_path orelse return error.MissingFrame);
    defer init.gpa.free(frame);
    const expected = try read(init, config.expected_path orelse return error.MissingExpected);
    defer init.gpa.free(expected);
    const guarded = try init.gpa.alloc(u8, expected.len + 16);
    defer init.gpa.free(guarded);
    @memset(guarded, 0xa5);
    const output = guarded[8 .. 8 + expected.len];
    var failure: ?[]const u8 = null;
    const count = codec.decodeFrameIntoWithDictionary(frame, output, dictionary) catch |err| blk: {
        failure = @errorName(err);
        break :blk 0;
    };
    for (guarded[0..8]) |byte| if (byte != 0xa5) return error.ReferencePrefixModified;
    for (guarded[8 + expected.len ..]) |byte| if (byte != 0xa5) return error.ReferenceSuffixModified;
    if (failure == null) {
        if (config.expect_failure or count != expected.len or !std.mem.eql(u8, expected, output[0..count])) return error.ReferenceDecodeMismatch;
    } else if (!config.expect_failure) return error.UnexpectedReferenceDecodeFailure;
    const path = try std.fmt.allocPrint(init.gpa, "{s}.decoded", .{prefix});
    defer init.gpa.free(path);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = if (failure == null) output[0..count] else &.{} });
    try printJson(init, .{ .@"error" = failure, .decoded = count, .round_trip_verified = failure == null, .outside_output_unchanged = true });
}
fn elapsed(init: std.process.Init, start: std.Io.Timestamp) usize {
    return @intCast(@max(start.durationTo(std.Io.Clock.awake.now(init.io)).nanoseconds, 0));
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(64 * 1024 * 1024));
}
fn readSamples(init: std.process.Init, paths: []const []const u8) ![][]const u8 {
    const result = try init.gpa.alloc([]const u8, paths.len);
    errdefer init.gpa.free(result);
    var count: usize = 0;
    errdefer for (result[0..count]) |sample| init.gpa.free(sample);
    for (paths, 0..) |path, index| {
        result[index] = try read(init, path);
        count += 1;
    }
    return result;
}
fn freeSamples(allocator: std.mem.Allocator, samples: [][]const u8) void {
    for (samples) |sample| allocator.free(sample);
    allocator.free(samples);
}
fn printJson(init: std.process.Init, value: anytype) !void {
    const json = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(json);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
