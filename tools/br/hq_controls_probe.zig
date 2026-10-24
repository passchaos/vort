const std = @import("std");
const vort = @import("vort");
const br = vort.br;
const Profile = if (@hasDecl(br, "HqProfile")) br.HqProfile else struct {};
const MemoryProfile = if (@hasDecl(br, "EncodeMemoryProfile")) br.EncodeMemoryProfile else struct {};

const Config = struct {
    operation: []const u8 = "encode",
    api: []const u8 = "one_shot",
    hq: bool = false,
    parse_mode: ?[]const u8 = null,
    quality: ?u8 = null,
    level: []const u8 = "fast",
    mode: []const u8 = "generic",
    window_bits: ?u8 = null,
    large_window: bool = false,
    search_depth: ?u32 = null,
    nice_len: ?u32 = null,
    beam_width: ?u8 = null,
    iterations: ?u8 = null,
    block_len: ?usize = null,
    max_working_memory: ?usize = null,
    max_total_working_memory: ?usize = null,
    npostfix: ?u8 = null,
    ndirect_high: ?u8 = null,
    profile_enabled: bool = true,
    total_profile_enabled: bool = true,
    raw_dictionary_paths: []const []const u8 = &.{},
    serialized_dictionary_path: ?[]const u8 = null,
    input_chunk: usize = 4096,
    output_chunk: usize = 4096,
    max_output_size: usize = 32 * 1024 * 1024,
};
const Resolved = struct {
    hq: bool,
    parse_mode: ?[]const u8 = null,
    quality: ?u8,
    level: []const u8,
    mode: []const u8,
    window_bits: ?u8 = null,
    large_window: bool = false,
    format: []const u8 = "standard",
    wire_alphabet_size: ?usize = null,
    active_alphabet_size: ?usize = null,
    shape_max_distance: ?usize = null,
    search_depth: ?u32 = null,
    nice_len: ?u32 = null,
    beam_width: ?u8 = null,
    iterations: ?u8 = null,
    block_len: ?usize = null,
    max_working_memory: ?usize = null,
    max_total_working_memory: ?usize = null,
    npostfix: ?u8 = null,
    ndirect_high: ?u8 = null,
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
    var total_profile: MemoryProfile = .{};
    var resolved: ?Resolved = null;
    var failure: ?[]const u8 = null;
    const output: ?[]u8 = operation(init, input, parsed.value, &profile, if (parsed.value.total_profile_enabled) &total_profile else null, &resolved) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (output) |bytes| init.gpa.free(bytes);
    if (output) |bytes| {
        if (resolved != null) {
            if (wireWindow(bytes)) |header| {
                resolved.?.window_bits = header.bits;
                resolved.?.large_window = header.large;
                resolved.?.format = if (header.large) "large_window" else "standard";
            } else |err| failure = @errorName(err);
        }
        if (failure == null) try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    }
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{
        .@"error" = failure,
        .input_bytes = input.len,
        .output_bytes = if (failure == null) if (output) |bytes| bytes.len else 0 else 0,
        .resolved = resolved,
        .profile = profile,
        .total_profile = total_profile,
        .work_memory = .{ .hq_requested_peak = if (@hasField(Profile, "peak_working_memory")) profile.peak_working_memory else @as(?usize, null) },
        .output_preserved_on_error = failure != null,
        .build_mode = @tagName(@import("builtin").mode),
    }, .{});
    defer init.gpa.free(report);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(report);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn configure(options: anytype, config: Config, profile: ?*Profile, total_profile: ?*MemoryProfile, resolved: *?Resolved) !void {
    options.level = std.meta.stringToEnum(br.PlannedCompressionLevel, config.level) orelse return error.InvalidBlockPlan;
    options.mode = std.meta.stringToEnum(br.PlannedMode, config.mode) orelse return error.InvalidBlockPlan;
    if (config.quality) |quality| options.quality = std.math.cast(u4, quality) orelse return error.InvalidBlockPlan;
    if (config.window_bits) |bits| options.window_bits = std.math.cast(u5, bits) orelse return error.InvalidBlockPlan;
    if (@hasField(@TypeOf(options.*), "large_window")) {
        options.large_window = config.large_window;
    } else if (config.large_window) return error.UnsupportedLargeWindowControls;
    if (@hasField(@TypeOf(options.*), "max_total_working_memory")) {
        options.max_total_working_memory = config.max_total_working_memory;
        options.memory_profile = total_profile;
    } else if (config.max_total_working_memory != null or total_profile != null) return error.UnsupportedTotalMemoryControls;
    resolved.* = .{ .hq = config.hq, .quality = config.quality, .level = config.level, .mode = config.mode, .window_bits = config.window_bits, .large_window = config.large_window, .format = if (config.large_window) "large_window" else "standard", .max_total_working_memory = config.max_total_working_memory };
    if (!config.hq) {
        if (config.search_depth != null or config.nice_len != null or config.beam_width != null or config.iterations != null or
            config.max_working_memory != null or config.npostfix != null or config.ndirect_high != null or config.parse_mode != null) return error.InvalidBlockPlan;
        return;
    }
    if (@hasField(@TypeOf(options.*), "hq")) {
        var hq = br.HqOptions{};
        if (@hasField(br.HqOptions, "parse_mode")) {
            if (config.parse_mode) |value| hq.parse_mode = std.meta.stringToEnum(@FieldType(br.HqOptions, "parse_mode"), value) orelse return error.InvalidBlockPlan;
        } else if (config.parse_mode) |value| {
            if (!std.mem.eql(u8, value, "bounded")) return error.UnsupportedParseMode;
        }
        if (config.search_depth) |value| hq.search_depth = value;
        if (config.nice_len) |value| hq.nice_len = value;
        if (config.beam_width) |value| hq.beam_width = value;
        if (config.iterations) |value| hq.iterations = value;
        if (config.block_len) |value| hq.block_len = value;
        if (config.max_working_memory) |value| hq.max_working_memory = value;
        if (config.npostfix != null or config.ndirect_high != null) {
            hq.distance_parameters = br.HqDistanceParameters.init(
                std.math.cast(u2, config.npostfix orelse 0) orelse return error.InvalidBlockPlan,
                std.math.cast(u4, config.ndirect_high orelse 0) orelse return error.InvalidBlockPlan,
            );
        }
        hq.profile = profile;
        const effective = if (@hasDecl(br.HqOptions, "resolveForFormat"))
            try hq.resolveForFormat(config.quality orelse return error.InvalidBlockPlan, options.mode, if (config.large_window) .large_window else .standard)
        else
            try hq.resolve(config.quality orelse return error.InvalidBlockPlan, options.mode);
        const selected = &resolved.*.?;
        selected.parse_mode = if (@hasField(@TypeOf(effective), "parse_mode")) @tagName(effective.parse_mode) else "bounded";
        selected.search_depth = effective.search_depth;
        selected.nice_len = effective.nice_len;
        selected.beam_width = effective.beam_width;
        selected.iterations = effective.iterations;
        selected.block_len = effective.block_len;
        selected.max_working_memory = effective.max_working_memory;
        selected.npostfix = effective.distance_parameters.npostfix;
        selected.ndirect_high = effective.distance_parameters.ndirect_high;
        if (@hasDecl(br.HqDistanceParameters, "wireAlphabetSize")) {
            selected.wire_alphabet_size = effective.distance_parameters.wireAlphabetSize(effective.format);
            selected.active_alphabet_size = effective.distance_parameters.activeAlphabetSize(effective.format);
            selected.shape_max_distance = effective.distance_parameters.maximumDistanceForFormat(effective.format);
        }
        options.hq = hq;
    } else return error.UnsupportedHqControls;
}
fn operation(init: std.process.Init, input: []const u8, config: Config, profile: *Profile, total_profile: ?*MemoryProfile, resolved: *?Resolved) ![]u8 {
    var prefixes: std.ArrayList([]const u8) = .empty;
    defer {
        for (prefixes.items) |bytes| init.gpa.free(bytes);
        prefixes.deinit(init.gpa);
    }
    for (config.raw_dictionary_paths) |path| {
        const bytes = try read(init, path, 16 * 1024 * 1024);
        errdefer init.gpa.free(bytes);
        try prefixes.append(init.gpa, bytes);
    }
    const serialized_bytes = if (config.serialized_dictionary_path) |path| try read(init, path, 16 * 1024 * 1024) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(serialized_bytes);
    var serialized: ?br.SerializedSharedDictionary = if (config.serialized_dictionary_path != null) try br.parseSerializedSharedDictionary(serialized_bytes) else null;
    const dictionary: br.SharedDictionary = .{ .raw_prefixes = prefixes.items, .serialized = if (serialized) |*value| value else null };
    if (std.mem.eql(u8, config.operation, "decode")) return br.decodeStreamAllocLimitedWithOptions(init.gpa, input, config.max_output_size, .{ .shared_dictionary = dictionary, .allow_large_window = config.large_window });
    if (!std.mem.eql(u8, config.operation, "encode")) return error.UnsupportedOperation;
    if (std.mem.eql(u8, config.api, "one_shot")) {
        var options = br.PlannedEncodeOptions{ .shared_dictionary = dictionary };
        try configure(&options, config, if (config.profile_enabled) profile else null, total_profile, resolved);
        return br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, options);
    }
    var options = br.PlannedStreamChunksOptions{ .shared_dictionary = dictionary, .block_len = config.block_len orelse 0 };
    try configure(&options, config, if (config.profile_enabled) profile else null, total_profile, resolved);
    if (std.mem.eql(u8, config.api, "incremental")) {
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(init.gpa, .{ .stream = options, .block_len = options.block_len, .max_input_len = input.len });
        defer encoder.deinit();
        return pump(init, input, config, &encoder);
    }
    if (std.mem.eql(u8, config.api, "chunks")) {
        if (config.input_chunk == 0) return error.InvalidChunkSize;
        var chunks: std.ArrayList([]const u8) = .empty;
        defer chunks.deinit(init.gpa);
        var offset: usize = 0;
        while (offset < input.len) {
            const end = offset + @min(input.len - offset, config.input_chunk);
            try chunks.append(init.gpa, input[offset..end]);
            offset = end;
        }
        return br.encodePlannedStreamChunksWithOptionsAlloc(init.gpa, chunks.items, options);
    }
    return error.UnsupportedOperation;
}
fn pump(init: std.process.Init, input: []const u8, config: Config, encoder: anytype) ![]u8 {
    if (config.input_chunk == 0 or config.output_chunk == 0 or config.output_chunk > 1024 * 1024) return error.InvalidChunkSize;
    const buffer = try init.gpa.alloc(u8, config.output_chunk);
    defer init.gpa.free(buffer);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(init.gpa);
    var offset: usize = 0;
    var finished = false;
    var steps: usize = 0;
    while (steps < input.len * 4 + config.max_output_size + 1024) : (steps += 1) {
        if (offset == input.len and !finished) {
            try encoder.finish();
            finished = true;
        }
        const end = offset + @min(input.len - offset, config.input_chunk);
        const result = try encoder.step(input[offset..end], buffer);
        offset += result.progress.input_read;
        if (result.progress.output_written > config.max_output_size - output.items.len) return error.OutputLimitExceeded;
        try output.appendSlice(init.gpa, buffer[0..result.progress.output_written]);
        if (result.status == .done) {
            if (offset != input.len) return error.InputAccountingMismatch;
            return output.toOwnedSlice(init.gpa);
        }
    }
    return error.IncrementalDidNotFinish;
}
fn wireWindow(input: []const u8) !struct { bits: u8, large: bool = false } {
    if (input.len == 0) return error.TruncatedInput;
    const first = input[0];
    if (first & 1 == 0) return .{ .bits = 16 };
    const high = (first >> 1) & 7;
    if (high != 0) return .{ .bits = 17 + high };
    const low = (first >> 4) & 7;
    if (low == 1) {
        if (input.len < 2) return error.TruncatedInput;
        const bits = input[1] & 63;
        if (first & 128 != 0 or bits < 10 or bits > 30) return error.CorruptFrame;
        return .{ .bits = bits, .large = true };
    }
    return .{ .bits = if (low == 0) 17 else 8 + low };
}
fn read(init: std.process.Init, path: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(limit));
}
