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
    search_depth: ?usize = null,
    nice_len: ?usize = null,
    min_match: ?usize = null,
    max_working_memory: ?usize = null,
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
    const parsed = try std.json.parseFromSlice(Config, init.gpa, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    var profile: Profile = .{};
    var resolved: ?Resolved = null;
    var failure: ?[]const u8 = null;
    const output: ?[]u8 = operation(init, input, parsed.value, &profile, &resolved) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (output) |bytes| init.gpa.free(bytes);
    if (output) |bytes| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    const peak: ?usize = if (@hasField(Profile, "peak_working_memory")) profile.peak_working_memory else null;
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{
        .@"error" = failure,
        .input_bytes = input.len,
        .output_bytes = if (output) |bytes| bytes.len else 0,
        .resolved = resolved,
        .profile = profile,
        .work_memory = .{ .hq_requested_peak = peak, .limit = parsed.value.max_working_memory },
        .output_preserved_on_error = failure != null,
        .build_mode = @tagName(@import("builtin").mode),
    }, .{});
    defer init.gpa.free(report);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(report);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn configureHq(options: anytype, config: Config) !void {
    const explicit = config.search_depth != null or config.nice_len != null or config.min_match != null or config.max_working_memory != null;
    if (!explicit) return;
    if (@hasField(@TypeOf(options.*), "hq")) {
        const Hq = std.meta.Child(@FieldType(@TypeOf(options.*), "hq"));
        var hq: Hq = .{};
        if (config.search_depth) |value| hq.search_depth = std.math.cast(@TypeOf(hq.search_depth), value) orelse return error.InvalidBlockPlan;
        if (config.nice_len) |value| hq.nice_len = std.math.cast(@TypeOf(hq.nice_len), value) orelse return error.InvalidBlockPlan;
        if (config.min_match) |value| hq.min_match = std.math.cast(@TypeOf(hq.min_match), value) orelse return error.InvalidBlockPlan;
        if (config.max_working_memory) |value| hq.max_working_memory = value;
        options.hq = hq;
    } else return error.UnsupportedHqControls;
}
fn nativeOptions(config: Config, profile: ?*Profile) !codec.NativeFrameOptions {
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
        };
        try configureHq(&options, config);
    }
    options.block_size_max = config.block_size;
    try options.validate();
    return options;
}
fn describe(options: codec.NativeFrameOptions, config: Config) !Resolved {
    var resolved: Resolved = .{ .strategy = options.strategy, .level = config.level, .mode = config.mode, .block_size = options.block_size_max };
    if (@hasDecl(codec.NativeFrameOptions, "effectiveHq")) {
        if (try options.effectiveHq()) |hq| {
            resolved.search_depth = hq.search_depth;
            resolved.nice_len = hq.nice_len;
            resolved.min_match = hq.min_match;
            resolved.max_working_memory = hq.max_working_memory;
        }
    }
    return resolved;
}
fn operation(init: std.process.Init, input: []const u8, config: Config, profile: *Profile, resolved: *?Resolved) ![]u8 {
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
    if ((std.mem.eql(u8, config.mode, "default") or std.mem.eql(u8, config.mode, "native-default")) and
        !std.mem.eql(u8, config.strategy, "auto")) return error.InvalidBlockPlan;
    const options = try nativeOptions(config, if (config.profile_enabled) profile else null);
    resolved.* = try describe(options, config);
    if (std.mem.eql(u8, config.api, "incremental")) return incremental(init, input, config, options, dictionary);
    if (std.mem.eql(u8, config.api, "seekable")) {
        const seek: codec.NativeSeekableOptions = .{ .frame_size = config.frame_size, .frame_options = options, .seek_checksums = true };
        if (dictionary) |dict| return codec.encodeNativeSeekableStreamWithDictionaryAlloc(init.gpa, input, seek, dict);
        return codec.encodeNativeSeekableStreamAlloc(init.gpa, input, seek);
    }
    if (!std.mem.eql(u8, config.api, "one_shot")) return error.UnsupportedOperation;
    if (std.mem.eql(u8, config.mode, "default")) return codec.encodeFrameAlloc(init.gpa, input);
    if (std.mem.eql(u8, config.mode, "native-default")) return codec.encodeNativeFrameAlloc(init.gpa, input);
    if (std.mem.eql(u8, config.mode, "native")) {
        if (dictionary) |dict| return (try codec.encodeNativeFrameWithDictionaryAlloc(init.gpa, input, options, dict)).frame;
        return (try codec.encodeNativeFrameWithOptionsAlloc(init.gpa, input, options)).frame;
    }
    if (!std.mem.eql(u8, config.mode, "level")) return error.UnsupportedMode;
    var frame: codec.FrameOptions = .{ .strategy = options.strategy, .content_checksum = config.checksum, .include_content_size = config.content_size, .window_log = config.window_log, .max_match_history_len = config.max_match_history_len, .control_profile = if (config.profile_enabled) profile else null };
    try configureHq(&frame, config);
    if (dictionary) |dict| return codec.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(init.gpa, input, config.level, frame, dict);
    return codec.encodeFrameWithLevelAndOptionsAlloc(init.gpa, input, config.level, frame);
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
