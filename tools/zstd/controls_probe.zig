const std = @import("std");
const codec = @import("codec");
const Profile = codec.EncoderControlProfile;
const default_native = codec.NativeFrameOptions{};
const Strategy = @TypeOf(default_native.strategy);
const Config = struct {
    mode: []const u8 = "level",
    api: []const u8 = "one_shot",
    level: c_int = 3,
    selection: []const u8 = "auto",
    strategy: []const u8 = "auto",
    fast_acceleration: ?u32 = null,
    match_search_budget: ?usize = null,
    rep_beam_search: bool = false,
    dictionary_path: ?[]const u8 = null,
    dictionary_id: u32 = 0,
    full_dictionary: bool = false,
    use_set: bool = false,
    window_log: ?u6 = null,
    max_match_history_len: ?usize = null,
    checksum: bool = false,
    content_size: bool = true,
    block_size: usize = 131072,
    frame_size: usize = 8192,
    expect_failure: bool = false,
    expected_path: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try read(init, input_path);
    defer init.gpa.free(input);
    const configuration = try read(init, config_path);
    defer init.gpa.free(configuration);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, configuration, .{});
    defer parsed.deinit();
    const config = parsed.value;
    const bytes = if (config.dictionary_path) |path| try read(init, path) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(bytes);
    const dictionary: ?codec.NativeDictionary = if (config.dictionary_path != null)
        if (config.full_dictionary) (try codec.NativeDictionary.initFromStandardDictionary(bytes)).dictionary else codec.NativeDictionary.init(config.dictionary_id, bytes)
    else
        null;
    if (std.mem.eql(u8, config.mode, "decode")) return decodeReference(init, input, output_path, config, dictionary);
    var profile = Profile{};
    var failure: ?[]const u8 = null;
    const encoded = encode(init.gpa, input, config, dictionary, &profile) catch |err| blk: {
        if (!config.expect_failure) return err;
        failure = @errorName(err);
        break :blk try init.gpa.alloc(u8, 0);
    };
    defer init.gpa.free(encoded);
    var deterministic = false;
    var round_trip_verified = false;
    var profile_wire_verified = false;
    var raw_dictionary_required = false;
    if (failure == null) {
        if (config.expect_failure) return error.UnexpectedSuccess;
        var repeated_profile = Profile{};
        const repeated = try encode(init.gpa, input, config, dictionary, &repeated_profile);
        defer init.gpa.free(repeated);
        deterministic = std.mem.eql(u8, encoded, repeated);
        if (!deterministic or !std.meta.eql(profile, repeated_profile)) return error.NonDeterministic;
        const unprofiled = try encode(init.gpa, input, config, dictionary, null);
        defer init.gpa.free(unprofiled);
        profile_wire_verified = std.mem.eql(u8, encoded, unprofiled);
        if (!profile_wire_verified) return error.ProfileChangedWire;
        const restored = if (std.mem.eql(u8, config.api, "seekable")) blk: {
            if (dictionary) |dict| break :blk try codec.decodeNativeConcatenatedFrameAllocWithDictionary(init.gpa, encoded, dict);
            break :blk try codec.decodeNativeConcatenatedFrameAlloc(init.gpa, encoded);
        } else blk: {
            if (dictionary) |dict| break :blk try codec.decodeFrameAllocWithDictionary(init.gpa, encoded, dict);
            break :blk try codec.decodeFrameAlloc(init.gpa, encoded);
        };
        defer init.gpa.free(restored);
        round_trip_verified = std.mem.eql(u8, restored, input);
        if (!round_trip_verified) return error.RoundTripMismatch;
        if (dictionary) |dict| {
            if (dict.id == 0 and profile.dictionary_sequences != 0) {
                const without = if (std.mem.eql(u8, config.api, "seekable")) codec.decodeNativeConcatenatedFrameAlloc(init.gpa, encoded) else codec.decodeFrameAlloc(init.gpa, encoded);
                if (without) |unexpected| {
                    init.gpa.free(unexpected);
                    return error.RawDictionaryNotRequired;
                } else |_| raw_dictionary_required = true;
            }
        }
    } else {
        if (!config.expect_failure) return error.UnexpectedEncodeFailure;
        if (encode(init.gpa, input, config, dictionary, null)) |unexpected| {
            init.gpa.free(unexpected);
            return error.ProfileChangedError;
        } else |unprofiled_error| {
            if (!std.mem.eql(u8, failure.?, @errorName(unprofiled_error))) return error.ProfileChangedError;
        }
        profile_wire_verified = true;
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{ .input = input.len, .encoded = encoded.len, .@"error" = failure, .deterministic = deterministic, .round_trip_verified = round_trip_verified, .profile_wire_verified = profile_wire_verified, .raw_dictionary_required = raw_dictionary_required, .reusable_verified = failure == null and std.mem.eql(u8, config.api, "reusable"), .control_stats = profile }, .{});
    defer init.gpa.free(json);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(16 * 1024 * 1024));
}
fn decodeReference(init: std.process.Init, frame: []const u8, output_path: []const u8, config: Config, dictionary: ?codec.NativeDictionary) !void {
    const expected = try read(init, config.expected_path orelse return error.MissingExpected);
    defer init.gpa.free(expected);
    const guard = try init.gpa.alloc(u8, expected.len + 16);
    defer init.gpa.free(guard);
    @memset(guard, 0xa5);
    const output = guard[8 .. 8 + expected.len];
    const attempted = if (dictionary) |dict| codec.decodeFrameIntoWithDictionary(frame, output, dict) else codec.decodeFrameInto(frame, output);
    var failure: ?[]const u8 = null;
    const count = attempted catch |err| blk: {
        failure = @errorName(err);
        break :blk 0;
    };
    if (failure == null) {
        if (config.expect_failure or count != expected.len or !std.mem.eql(u8, expected, output[0..count])) return error.ReferenceDecodeMismatch;
    } else if (!config.expect_failure) return error.ReferenceDecodeMismatch;
    for (guard[0..8]) |byte| if (byte != 0xa5) return error.ReferencePrefixModified;
    for (guard[8 + expected.len ..]) |byte| if (byte != 0xa5) return error.ReferenceSuffixModified;
    var unchanged = true;
    for (guard) |byte| if (byte != 0xa5) {
        unchanged = false;
        break;
    };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = if (failure == null) output[0..count] else &.{} });
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{ .@"error" = failure, .decoded = count, .round_trip_verified = failure == null, .caller_unchanged = unchanged, .outside_output_unchanged = true }, .{});
    defer init.gpa.free(json);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
fn frameOptions(config: Config, profile: ?*Profile) !codec.FrameOptions {
    return .{ .content_checksum = config.checksum, .include_content_size = config.content_size, .window_log = config.window_log, .max_match_history_len = config.max_match_history_len, .strategy = std.meta.stringToEnum(Strategy, config.strategy) orelse return error.InvalidBlockPlan, .fast_acceleration = config.fast_acceleration, .control_profile = profile };
}
fn nativeOptions(config: Config, profile: ?*Profile) !codec.NativeFrameOptions {
    if (std.mem.eql(u8, config.mode, "level")) {
        var resolved = try codec.resolveFrameOptionsForLevel(config.level, try frameOptions(config, profile));
        resolved.block_size_max = config.block_size;
        return resolved;
    }
    return .{ .content_checksum = config.checksum, .include_content_size = config.content_size, .window_log = config.window_log, .max_match_history_len = config.max_match_history_len, .block_size_max = config.block_size, .selection = if (std.mem.eql(u8, config.selection, "raw_or_rle")) .raw_or_rle else if (std.mem.eql(u8, config.selection, "literal_only")) .literal_only else if (std.mem.eql(u8, config.selection, "fast_compressed")) .fast_compressed else .auto, .strategy = std.meta.stringToEnum(Strategy, config.strategy) orelse return error.InvalidBlockPlan, .fast_acceleration = config.fast_acceleration, .match_search_budget = config.match_search_budget orelse default_native.match_search_budget, .rep_beam_search = config.rep_beam_search, .control_profile = profile };
}
fn encode(allocator: std.mem.Allocator, input: []const u8, config: Config, dictionary: ?codec.NativeDictionary, profile: ?*Profile) ![]u8 {
    if (std.mem.eql(u8, config.api, "incremental")) return incremental(allocator, input, try nativeOptions(config, profile), dictionary, config.use_set);
    if (std.mem.eql(u8, config.api, "seekable")) {
        const options: codec.NativeSeekableOptions = .{ .frame_size = config.frame_size, .frame_options = try nativeOptions(config, profile), .seek_checksums = true };
        if (dictionary) |dict| {
            if (config.use_set) return codec.encodeNativeSeekableStreamWithDictionarySetAlloc(allocator, input, options, codec.NativeDictionarySet.init(&.{dict}), dict.id);
            return codec.encodeNativeSeekableStreamWithDictionaryAlloc(allocator, input, options, dict);
        }
        return codec.encodeNativeSeekableStreamAlloc(allocator, input, options);
    }
    if (std.mem.eql(u8, config.mode, "default")) return codec.encodeFrameAlloc(allocator, input);
    if (std.mem.eql(u8, config.mode, "native-default")) return codec.encodeNativeFrameAlloc(allocator, input);
    if (std.mem.eql(u8, config.mode, "native") or (std.mem.eql(u8, config.api, "reusable") and dictionary != null)) {
        const options = try nativeOptions(config, profile);
        if (std.mem.eql(u8, config.api, "reusable")) {
            var encoder = codec.NativeFrameEncoder.init(allocator);
            defer encoder.deinit();
            const first = try reusableNative(&encoder, input, options, dictionary, config.use_set);
            defer allocator.free(first);
            const first_profile = if (profile) |p| p.* else Profile{};
            const second = try reusableNative(&encoder, input, options, dictionary, config.use_set);
            if (!std.mem.eql(u8, first, second)) {
                allocator.free(second);
                return error.ReusableChangedWire;
            }
            if (profile) |p| {
                defer allocator.free(second);
                try verifyAccumulation(p, first_profile);
                const reset = try reusableNative(&encoder, input, options, dictionary, config.use_set);
                errdefer allocator.free(reset);
                if (!std.mem.eql(u8, first, reset) or !std.meta.eql(first_profile, p.*)) return error.ProfileResetMismatch;
                return reset;
            }
            return second;
        }
        if (dictionary) |dict| {
            if (config.use_set) return (try codec.encodeNativeFrameWithDictionarySetAlloc(allocator, input, options, codec.NativeDictionarySet.init(&.{dict}), dict.id)).frame;
            return (try codec.encodeNativeFrameWithDictionaryAlloc(allocator, input, options, dict)).frame;
        }
        return (try codec.encodeNativeFrameWithOptionsAlloc(allocator, input, options)).frame;
    }
    const options = try frameOptions(config, profile);
    if (std.mem.eql(u8, config.api, "reusable")) {
        var encoder = codec.LevelFrameEncoder.init(allocator);
        defer encoder.deinit();
        const first = try encoder.encodeWithOptionsAlloc(input, config.level, options);
        defer allocator.free(first);
        const first_profile = if (profile) |p| p.* else Profile{};
        const second = try encoder.encodeWithOptionsAlloc(input, config.level, options);
        if (!std.mem.eql(u8, first, second)) {
            allocator.free(second);
            return error.ReusableChangedWire;
        }
        if (profile) |p| {
            defer allocator.free(second);
            try verifyAccumulation(p, first_profile);
            const reset = try encoder.encodeWithOptionsAlloc(input, config.level, options);
            errdefer allocator.free(reset);
            if (!std.mem.eql(u8, first, reset) or !std.meta.eql(first_profile, p.*)) return error.ProfileResetMismatch;
            return reset;
        }
        return second;
    }
    if (dictionary) |dict| {
        if (config.use_set) return codec.encodeFrameWithLevelAndOptionsAndDictionarySetAlloc(allocator, input, config.level, options, codec.NativeDictionarySet.init(&.{dict}), dict.id);
        return codec.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(allocator, input, config.level, options, dict);
    }
    return codec.encodeFrameWithLevelAndOptionsAlloc(allocator, input, config.level, options);
}
fn reusableNative(encoder: *codec.NativeFrameEncoder, input: []const u8, options: codec.NativeFrameOptions, dictionary: ?codec.NativeDictionary, use_set: bool) ![]u8 {
    if (dictionary) |dict| {
        if (use_set) return (try encoder.encodeWithDictionarySetAlloc(input, options, codec.NativeDictionarySet.init(&.{dict}), dict.id)).frame;
        return (try encoder.encodeWithDictionaryAlloc(input, options, dict)).frame;
    }
    return (try encoder.encodeWithOptionsAlloc(input, options)).frame;
}
fn verifyAccumulation(profile: *Profile, first: Profile) !void {
    var expected = first;
    expected.merge(first);
    if (!std.meta.eql(expected, profile.*)) return error.ProfileAccumulationMismatch;
    profile.reset();
    if (!std.meta.eql(Profile{}, profile.*)) return error.ProfileResetMismatch;
}
fn incremental(allocator: std.mem.Allocator, input: []const u8, supplied_options: codec.NativeFrameOptions, dictionary: ?codec.NativeDictionary, use_set: bool) ![]u8 {
    var options = supplied_options;
    if (dictionary) |dict| options.dictionary_id = dict.id;
    var encoder = if (dictionary) |dict| blk: {
        if (options.include_content_size) {
            if (use_set) break :blk try codec.NativeIncrementalFrameEncoder.initExactSizeWithDictionarySet(allocator, options, input.len, codec.NativeDictionarySet.init(&.{dict}), dict.id);
            break :blk try codec.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(allocator, options, input.len, dict);
        }
        if (use_set) break :blk try codec.NativeIncrementalFrameEncoder.initWithDictionarySet(allocator, options, codec.NativeDictionarySet.init(&.{dict}), dict.id);
        break :blk try codec.NativeIncrementalFrameEncoder.initWithPresetDictionary(allocator, options, dict);
    } else if (options.include_content_size) try codec.NativeIncrementalFrameEncoder.initExactSize(allocator, options, input.len) else try codec.NativeIncrementalFrameEncoder.init(allocator, options);
    defer encoder.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var offset: usize = 0;
    var finishing = false;
    var step_index: usize = 0;
    var buffer: [31]u8 = undefined;
    while (step_index < input.len * 4 + 100000) : (step_index += 1) {
        const end = @min(input.len, offset + 4096);
        const target = buffer[0..if (step_index % 4 == 0) @as(usize, 0) else buffer.len];
        const result = try encoder.step(input[offset..end], target);
        offset += result.progress.input_read;
        try output.appendSlice(allocator, target[0..result.progress.output_written]);
        if (result.status == .done) {
            if (offset != input.len) return error.InputAccounting;
            return output.toOwnedSlice(allocator);
        }
        if (!finishing and offset == input.len) {
            encoder.finish();
            finishing = true;
        }
    }
    return error.IncrementalDidNotFinish;
}
