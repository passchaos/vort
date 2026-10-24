const std = @import("std");
const vort = @import("vort");
const codec = vort.zstd;
const Profile = codec.EncoderControlProfile;

const Config = struct {
    operation: []const u8 = "encode",
    api: []const u8 = "one_shot",
    mode: []const u8 = "level",
    level: c_int = 3,
    strategy: []const u8 = "auto",
    parse_mode: ?[]const u8 = null,
    match_lengths: ?[]const u8 = null,
    max_price_evaluations: ?u64 = null,
    search_depth: ?usize = null,
    nice_len: ?usize = null,
    min_match: ?usize = null,
    max_working_memory: ?usize = null,
    max_total_working_memory: ?usize = null,
    total_profile_enabled: bool = true,
    output_capacity: ?usize = null,
    verify_reusable_cycle: bool = false,
    profile_enabled: bool = true,
    checksum: bool = false,
    content_size: bool = true,
    block_size: usize = 131072,
    frame_size: usize = 65536,
    window_log: ?u6 = null,
    max_match_history_len: ?usize = null,
    dictionary_path: ?[]const u8 = null,
    dictionary_id: u32 = 0,
    full_dictionary: bool = false,
    input_chunk: usize = 4096,
    output_chunk: usize = 4096,
    max_output_size: usize = 16 * 1024 * 1024,
};
const Resolved = struct {
    strategy: codec.Strategy,
    level: c_int,
    mode: []const u8,
    block_size: usize,
    search_depth: ?usize = null,
    nice_len: ?usize = null,
    min_match: ?usize = null,
    max_working_memory: ?usize = null,
    parse_mode: ?[]const u8 = null,
    match_lengths: ?[]const u8 = null,
    max_price_evaluations: ?u64 = null,
    max_total_working_memory: ?usize = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try read(init, input_path, 16 * 1024 * 1024);
    defer init.gpa.free(input);
    const json = try read(init, config_path, 65536);
    defer init.gpa.free(json);
    const parsed = std.json.parseFromSlice(Config, init.gpa, json, .{}) catch |err| {
        try printJson(init, .{ .@"error" = @errorName(err), .input_bytes = input.len, .output_bytes = 0, .resolved = @as(?Resolved, null), .profile = Profile{}, .memory_profile = codec.EncodeMemoryProfile{}, .reusable_cycle_verified = false, .output_preserved_on_error = true });
        return;
    };
    defer parsed.deinit();
    var profile: Profile = .{};
    var memory: codec.EncodeMemoryProfile = .{};
    var resolved: ?Resolved = null;
    var reusable_cycle_verified = false;
    var failure: ?[]const u8 = null;
    const output: ?[]u8 = operation(init, input, parsed.value, &profile, if (parsed.value.total_profile_enabled) &memory else null, &resolved, &reusable_cycle_verified) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (output) |bytes| init.gpa.free(bytes);
    if (output) |bytes| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    const peak: ?usize = if (@hasField(Profile, "peak_working_memory")) profile.peak_working_memory else null;
    try printJson(init, .{
        .@"error" = failure,
        .input_bytes = input.len,
        .output_bytes = if (output) |bytes| bytes.len else 0,
        .resolved = resolved,
        .profile = profile,
        .memory_profile = memory,
        .reusable_cycle_verified = reusable_cycle_verified,
        .guard_scope = if (std.mem.eql(u8, parsed.value.api, "incremental")) "expanded controls use same-state per-block safeguards" else "expanded controls use complete-frame safeguards; budget-only controls do not add safeguards",
        .work_memory = .{ .hq_requested_peak = peak, .limit = parsed.value.max_working_memory },
        .output_preserved_on_error = failure != null,
        .build_mode = @tagName(@import("builtin").mode),
    });
}
fn printJson(init: std.process.Init, value: anytype) !void {
    const report = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(report);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(report);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn configureHq(options: anytype, config: Config) !void {
    const explicit = config.search_depth != null or config.nice_len != null or config.min_match != null or config.max_working_memory != null or
        config.parse_mode != null or config.match_lengths != null or config.max_price_evaluations != null;
    if (!explicit) return;
    if (@hasField(@TypeOf(options.*), "hq")) {
        const Hq = std.meta.Child(@FieldType(@TypeOf(options.*), "hq"));
        var hq: Hq = .{};
        if (config.search_depth) |value| hq.search_depth = std.math.cast(@TypeOf(hq.search_depth), value) orelse return error.InvalidBlockPlan;
        if (config.nice_len) |value| hq.nice_len = std.math.cast(@TypeOf(hq.nice_len), value) orelse return error.InvalidBlockPlan;
        if (config.min_match) |value| hq.min_match = std.math.cast(@TypeOf(hq.min_match), value) orelse return error.InvalidBlockPlan;
        if (config.max_working_memory) |value| hq.max_working_memory = value;
        if (@hasField(Hq, "parse_mode")) {
            if (config.parse_mode) |value| hq.parse_mode = std.meta.stringToEnum(@FieldType(Hq, "parse_mode"), value) orelse return error.InvalidBlockPlan;
            if (config.match_lengths) |value| hq.match_lengths = std.meta.stringToEnum(@FieldType(Hq, "match_lengths"), value) orelse return error.InvalidBlockPlan;
            hq.max_price_evaluations = config.max_price_evaluations;
        } else {
            if (config.parse_mode) |value| if (!std.mem.eql(u8, value, "bounded")) return error.UnsupportedSearchControls;
            if (config.match_lengths) |value| if (!std.mem.eql(u8, value, "sampled")) return error.UnsupportedSearchControls;
            if (config.max_price_evaluations != null) return error.UnsupportedSearchControls;
        }
        options.hq = hq;
    } else return error.UnsupportedHqControls;
}
fn nativeOptions(config: Config, profile: ?*Profile, memory: ?*codec.EncodeMemoryProfile) !codec.NativeFrameOptions {
    const strategy = std.meta.stringToEnum(codec.Strategy, config.strategy) orelse return error.InvalidBlockPlan;
    var options: codec.NativeFrameOptions = undefined;
    if (std.mem.eql(u8, config.mode, "level")) {
        var frame: codec.FrameOptions = .{
            .strategy = strategy,
            .content_checksum = config.checksum,
            .include_content_size = config.content_size,
            .window_log = config.window_log,
            .max_match_history_len = config.max_match_history_len,
            .control_profile = profile,
            .max_total_working_memory = config.max_total_working_memory,
            .memory_profile = memory,
        };
        try configureHq(&frame, config);
        options = try codec.resolveFrameOptionsForLevel(config.level, frame);
    } else {
        options = .{
            .strategy = strategy,
            .content_checksum = config.checksum,
            .include_content_size = config.content_size,
            .window_log = config.window_log,
            .max_match_history_len = config.max_match_history_len,
            .control_profile = profile,
            .max_total_working_memory = config.max_total_working_memory,
            .memory_profile = memory,
        };
        try configureHq(&options, config);
    }
    options.block_size_max = config.block_size;
    try options.validate();
    return options;
}
fn describe(options: codec.NativeFrameOptions, config: Config) !Resolved {
    var resolved: Resolved = .{ .strategy = options.strategy, .level = config.level, .mode = config.mode, .block_size = options.block_size_max, .max_total_working_memory = options.max_total_working_memory };
    if (@hasDecl(codec.NativeFrameOptions, "effectiveHq")) {
        if (try options.effectiveHq()) |hq| {
            resolved.search_depth = hq.search_depth;
            resolved.nice_len = hq.nice_len;
            resolved.min_match = hq.min_match;
            resolved.max_working_memory = hq.max_working_memory;
            if (@hasField(@TypeOf(hq), "parse_mode")) {
                resolved.parse_mode = @tagName(hq.parse_mode);
                resolved.match_lengths = @tagName(hq.match_lengths);
                resolved.max_price_evaluations = hq.max_price_evaluations;
            } else {
                resolved.parse_mode = "bounded";
                resolved.match_lengths = "sampled";
            }
        }
    }
    return resolved;
}
fn operation(init: std.process.Init, input: []const u8, config: Config, profile: *Profile, memory: ?*codec.EncodeMemoryProfile, resolved: *?Resolved, cycle_verified: *bool) ![]u8 {
    const dictionary_bytes = if (config.dictionary_path) |path| try read(init, path, 4 * 1024 * 1024) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(dictionary_bytes);
    const dictionary: ?codec.NativeDictionary = if (config.dictionary_path != null)
        if (config.full_dictionary) (try codec.NativeDictionary.initFromStandardDictionary(dictionary_bytes)).dictionary else codec.NativeDictionary.init(config.dictionary_id, dictionary_bytes)
    else
        null;
    if (std.mem.eql(u8, config.operation, "decode")) {
        const output = if (std.mem.eql(u8, config.api, "seekable") or std.mem.eql(u8, config.api, "concatenated")) blk: {
            if (dictionary) |dict| break :blk try codec.decodeNativeConcatenatedFrameAllocWithDictionary(init.gpa, input, dict);
            break :blk try codec.decodeNativeConcatenatedFrameAlloc(init.gpa, input);
        } else blk: {
            if (dictionary) |dict| break :blk try codec.decodeFrameAllocWithDictionaryLimited(init.gpa, input, dict, config.max_output_size);
            break :blk try codec.decodeFrameAllocLimited(init.gpa, input, config.max_output_size);
        };
        errdefer init.gpa.free(output);
        if (output.len > config.max_output_size) return error.OutputLimitExceeded;
        return output;
    }
    if (!std.mem.eql(u8, config.operation, "encode")) return error.UnsupportedOperation;
    if (config.verify_reusable_cycle and !std.mem.eql(u8, config.api, "reusable")) return error.InvalidBlockPlan;
    if ((std.mem.eql(u8, config.mode, "default") or std.mem.eql(u8, config.mode, "native-default")) and
        !std.mem.eql(u8, config.strategy, "auto")) return error.InvalidBlockPlan;
    const options = try nativeOptions(config, if (config.profile_enabled) profile else null, memory);
    resolved.* = try describe(options, config);
    if (std.mem.eql(u8, config.api, "incremental")) return incremental(init, input, config, options, dictionary);
    if (std.mem.eql(u8, config.api, "seekable")) {
        const seek: codec.NativeSeekableOptions = .{ .frame_size = config.frame_size, .frame_options = options, .seek_checksums = true };
        if (dictionary) |dict| return codec.encodeNativeSeekableStreamWithDictionaryAlloc(init.gpa, input, seek, dict);
        return codec.encodeNativeSeekableStreamAlloc(init.gpa, input, seek);
    }
    if (std.mem.eql(u8, config.api, "reusable")) {
        var encoder = codec.NativeFrameEncoder.init(init.gpa);
        defer encoder.deinit();
        if (config.verify_reusable_cycle) {
            const first = try reusableEncode(&encoder, input, options, dictionary);
            defer init.gpa.free(first);
            const first_profile = profile.*;
            const second = try reusableEncode(&encoder, input, options, dictionary);
            defer init.gpa.free(second);
            var accumulated = first_profile;
            accumulated.merge(first_profile);
            if (!std.mem.eql(u8, first, second) or !std.meta.eql(accumulated, profile.*)) return error.ReusableProfileAccumulationMismatch;
            profile.reset();
            const third = try reusableEncode(&encoder, input, options, dictionary);
            errdefer init.gpa.free(third);
            if (!std.mem.eql(u8, first, third) or !std.meta.eql(first_profile, profile.*)) return error.ReusableProfileResetMismatch;
            cycle_verified.* = true;
            return third;
        }
        if (dictionary) |dict| return (try encoder.encodeWithDictionaryAlloc(input, options, dict)).frame;
        return (try encoder.encodeWithOptionsAlloc(input, options)).frame;
    }
    if (std.mem.eql(u8, config.api, "into")) {
        const capacity = config.output_capacity orelse try codec.encodedNativeFrameBoundWithOptions(input.len, options);
        const storage = try init.gpa.alloc(u8, try std.math.add(usize, capacity, 16));
        defer init.gpa.free(storage);
        @memset(storage, 0xa5);
        const buffer = storage[8 .. 8 + capacity];
        const result = (if (dictionary) |dict| codec.encodeNativeFrameIntoSliceWithDictionary(init.gpa, input, options, dict, buffer) else codec.encodeNativeFrameIntoSlice(init.gpa, input, options, buffer)) catch |err| {
            for (storage) |byte| if (byte != 0xa5) return error.CallerBufferModifiedOnError;
            return err;
        };
        for (storage[0..8]) |byte| if (byte != 0xa5) return error.OutputGuardModified;
        for (storage[8 + capacity ..]) |byte| if (byte != 0xa5) return error.OutputGuardModified;
        return init.gpa.dupe(u8, buffer[0..result.written]);
    }
    if (!std.mem.eql(u8, config.api, "one_shot")) return error.UnsupportedOperation;
    if (std.mem.eql(u8, config.mode, "default")) return codec.encodeFrameAlloc(init.gpa, input);
    if (std.mem.eql(u8, config.mode, "native-default")) return codec.encodeNativeFrameAlloc(init.gpa, input);
    if (std.mem.eql(u8, config.mode, "native")) {
        if (dictionary) |dict| return (try codec.encodeNativeFrameWithDictionaryAlloc(init.gpa, input, options, dict)).frame;
        return (try codec.encodeNativeFrameWithOptionsAlloc(init.gpa, input, options)).frame;
    }
    if (!std.mem.eql(u8, config.mode, "level")) return error.UnsupportedMode;
    var frame: codec.FrameOptions = .{ .strategy = options.strategy, .content_checksum = config.checksum, .include_content_size = config.content_size, .window_log = config.window_log, .max_match_history_len = config.max_match_history_len, .control_profile = if (config.profile_enabled) profile else null, .max_total_working_memory = config.max_total_working_memory, .memory_profile = memory };
    try configureHq(&frame, config);
    if (dictionary) |dict| return codec.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(init.gpa, input, config.level, frame, dict);
    return codec.encodeFrameWithLevelAndOptionsAlloc(init.gpa, input, config.level, frame);
}
fn reusableEncode(encoder: *codec.NativeFrameEncoder, input: []const u8, options: codec.NativeFrameOptions, dictionary: ?codec.NativeDictionary) ![]u8 {
    if (dictionary) |dict| return (try encoder.encodeWithDictionaryAlloc(input, options, dict)).frame;
    return (try encoder.encodeWithOptionsAlloc(input, options)).frame;
}
fn incremental(init: std.process.Init, input: []const u8, config: Config, options: codec.NativeFrameOptions, dictionary: ?codec.NativeDictionary) ![]u8 {
    if (config.input_chunk == 0 or config.output_chunk == 0 or config.output_chunk > 1024 * 1024) return error.InvalidChunkSize;
    var selected = options;
    if (dictionary) |dict| selected.dictionary_id = dict.id;
    var encoder = if (dictionary) |dict| blk: {
        if (selected.include_content_size) break :blk try codec.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(init.gpa, selected, input.len, dict);
        break :blk try codec.NativeIncrementalFrameEncoder.initWithPresetDictionary(init.gpa, selected, dict);
    } else if (selected.include_content_size) try codec.NativeIncrementalFrameEncoder.initExactSize(init.gpa, selected, input.len) else try codec.NativeIncrementalFrameEncoder.init(init.gpa, selected);
    defer encoder.deinit();
    const buffer = try init.gpa.alloc(u8, config.output_chunk);
    defer init.gpa.free(buffer);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(init.gpa);
    var offset: usize = 0;
    var finished = false;
    var steps: usize = 0;
    while (steps < input.len * 4 + config.max_output_size + 1024) : (steps += 1) {
        if (offset == input.len and !finished) {
            encoder.finish();
            finished = true;
        }
        const end = offset + @min(input.len - offset, config.input_chunk);
        const progress = try encoder.step(input[offset..end], buffer);
        offset += progress.progress.input_read;
        if (progress.progress.output_written > config.max_output_size - output.items.len) return error.OutputLimitExceeded;
        try output.appendSlice(init.gpa, buffer[0..progress.progress.output_written]);
        if (progress.status == .done) {
            if (offset != input.len) return error.InputAccountingMismatch;
            return output.toOwnedSlice(init.gpa);
        }
    }
    return error.IncrementalDidNotFinish;
}
fn read(init: std.process.Init, path: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(limit));
}
