//! CLI ownership and explicit encoder/reference settings.
const std = @import("std");
const zstd = @import("vort_zstd");
const libzstd = @import("libzstd_runtime.zig");

pub const Options = struct {
    iterations: usize = 1,
    rounds: usize = 3,
    csv_path: ?[]const u8 = null,
    samples_json_path: ?[]const u8 = null,
    only_case: ?[]const u8 = null,
    only_level: ?c_int = null,
    native_selection: ?zstd.NativeFrameSelection = null,
    strategy: ?zstd.Strategy = null,
    fast_acceleration: ?u32 = null,
    show_help: bool = false,
    reference_library_path: ?[]const u8 = null,
    match_hq: bool = false,
    window_log: ?u6 = null,
    block_size: ?usize = null,
    content_checksum: ?bool = null,
    content_size: ?bool = null,
    hq_search_depth: ?u32 = null,
    hq_nice_len: ?u32 = null,
    hq_min_match: ?u8 = null,
    dictionary_path: ?[]const u8 = null,
    path_limit: usize = std.compress.zstd.block_size_max,
    paths: std.ArrayList([]const u8) = .empty,

    pub fn deinit(options: *Options, allocator: std.mem.Allocator) void {
        for (options.paths.items) |path| allocator.free(path);
        options.paths.deinit(allocator);
    }
};
pub fn resolvedNativeOptions(options: Options, level: c_int) !?zstd.NativeFrameOptions {
    var resolved = try zstd.resolveFrameOptionsForLevel(level, .{
        .strategy = options.strategy orelse .auto,
        .fast_acceleration = options.fast_acceleration,
    });
    if (options.match_hq) {
        if (options.strategy != .btopt and options.strategy != .btultra and options.strategy != .btultra2)
            return error.InvalidMatchedStrategy;
        if (options.fast_acceleration != null or options.native_selection != null)
            return error.InvalidMatchedOptions;
        const window_log = options.window_log orelse 17;
        if (window_log < 10 or window_log > 30) return error.InvalidBlockPlan;
        const ceiling = @min(@as(usize, 1) << @intCast(window_log), std.compress.zstd.block_size_max);
        if (options.block_size) |size| if (size != ceiling) return error.InvalidMatchedBlockSize;
        const hq: zstd.HqOptions = .{
            .search_depth = options.hq_search_depth orelse 64,
            .nice_len = options.hq_nice_len orelse 64,
            .min_match = options.hq_min_match orelse 3,
        };
        try hq.validate();
        // Optimal libzstd parsers accept 3 or 4-byte minima even when their
        // hash matcher parameter requests a larger value.
        if (hq.min_match > 4) return error.InvalidMatchedMinMatch;
        if (hq.search_depth < 2 or !std.math.isPowerOfTwo(hq.search_depth)) return error.InvalidMatchedSearchDepth;
        resolved.window_log = window_log;
        resolved.selection = .fast_compressed;
        resolved.max_match_history_len = @as(usize, 1) << @intCast(window_log);
        resolved.block_size_max = ceiling;
        resolved.content_checksum = options.content_checksum orelse true;
        resolved.include_content_size = options.content_size orelse true;
        resolved.hq = hq;
        try resolved.validate();
        return resolved;
    }
    // Retain the existing positive-level selection gate. New engine controls
    // and negative magnitudes always use the shared library level resolver.
    if (level > 0 and (options.strategy orelse .auto) == .auto and options.fast_acceleration == null) {
        if (options.native_selection) |selection| return .{ .selection = selection, .content_checksum = false };
        return null;
    }
    if (options.native_selection) |selection| {
        if (resolved.selection != .auto and resolved.selection != selection) return error.InvalidBlockPlan;
        resolved.selection = selection;
    }
    try resolved.validate();
    return resolved;
}

pub fn referenceOptions(options: Options, native: ?zstd.NativeFrameOptions, level: c_int) !?libzstd.Runtime.AdvancedOptions {
    if (!options.match_hq) return null;
    const primary = native.?;
    const hq = (try primary.effectiveHq()).?;
    return .{
        .level = level,
        .strategy = switch (primary.strategy) {
            .btopt => 7,
            .btultra => 8,
            .btultra2 => 9,
            else => return error.InvalidMatchedStrategy,
        },
        .window_log = primary.window_log.?,
        .search_log = @intCast(std.math.log2_int(u32, hq.search_depth)),
        .min_match = hq.min_match,
        .target_length = @intCast(hq.nice_len),
        .content_size = primary.include_content_size,
        .checksum = primary.content_checksum,
        .workers = 0,
    };
}

pub fn parseOptions(allocator: std.mem.Allocator, args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    errdefer options.deinit(allocator);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help")) {
            options.show_help = true;
            return options;
        } else if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--rounds"))
            options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--case"))
            options.only_case = args.next() orelse return error.MissingCorpusPath
        else if (try optionValue("--level", arg, args)) |value| {
            if (options.only_level != null) return error.DuplicateZstdOption;
            options.only_level = try std.fmt.parseInt(c_int, value, 10);
        } else if (try optionValue("--strategy", arg, args)) |value| {
            if (options.strategy != null) return error.DuplicateZstdOption;
            options.strategy = if (std.mem.eql(u8, value, "double-fast")) .double_fast else std.meta.stringToEnum(zstd.Strategy, value) orelse return error.InvalidZstdStrategy;
        } else if (try optionValue("--fast-acceleration", arg, args)) |value| {
            if (options.fast_acceleration != null) return error.DuplicateZstdOption;
            options.fast_acceleration = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.eql(u8, arg, "--native-selection")) {
            const selection = args.next() orelse return error.MissingLimit;
            options.native_selection = if (std.mem.eql(u8, selection, "fast_compressed") or std.mem.eql(u8, selection, "fast-compressed"))
                .fast_compressed
            else
                return error.UnknownArgument;
        } else if (std.mem.eql(u8, arg, "--libzstd"))
            options.reference_library_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--match-hq")) {
            if (options.match_hq) return error.DuplicateZstdOption;
            options.match_hq = true;
        } else if (try optionValue("--window-log", arg, args)) |value| {
            if (options.window_log != null) return error.DuplicateZstdOption;
            options.window_log = try std.fmt.parseInt(u6, value, 10);
        } else if (try optionValue("--block-size", arg, args)) |value| {
            if (options.block_size != null) return error.DuplicateZstdOption;
            options.block_size = try std.fmt.parseInt(usize, value, 10);
        } else if (try optionValue("--content-checksum", arg, args)) |value| {
            if (options.content_checksum != null) return error.DuplicateZstdOption;
            options.content_checksum = try parseBool(value);
        } else if (try optionValue("--content-size", arg, args)) |value| {
            if (options.content_size != null) return error.DuplicateZstdOption;
            options.content_size = try parseBool(value);
        } else if (try optionValue("--hq-search-depth", arg, args)) |value| {
            if (options.hq_search_depth != null) return error.DuplicateZstdOption;
            options.hq_search_depth = try std.fmt.parseInt(u32, value, 10);
        } else if (try optionValue("--hq-nice-len", arg, args)) |value| {
            if (options.hq_nice_len != null) return error.DuplicateZstdOption;
            options.hq_nice_len = try std.fmt.parseInt(u32, value, 10);
        } else if (try optionValue("--hq-min-match", arg, args)) |value| {
            if (options.hq_min_match != null) return error.DuplicateZstdOption;
            options.hq_min_match = try std.fmt.parseInt(u8, value, 10);
        } else if (try optionValue("--dictionary", arg, args)) |value| {
            if (options.dictionary_path != null) return error.DuplicateZstdOption;
            options.dictionary_path = value;
        } else if (try optionValue("--samples-json", arg, args)) |value| {
            if (options.samples_json_path != null) return error.DuplicateZstdOption;
            options.samples_json_path = value;
        } else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--limit"))
            options.path_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--path"))
            try options.paths.append(allocator, try allocator.dupe(u8, args.next() orelse return error.MissingCorpusPath))
        else
            return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.rounds == 0 or options.path_limit == 0) return error.InvalidBlockPlan;
    if (options.match_hq) {
        // Matched comparisons carry an explicit library identity and raw
        // settings/rounds; level remains the reference's unspecified preset.
        if (options.reference_library_path == null or options.samples_json_path == null)
            return error.MissingMatchedEvidence;
        if (options.only_level == null) options.only_level = 3;
    } else if (options.window_log != null or options.block_size != null or
        options.content_checksum != null or options.content_size != null or
        options.hq_search_depth != null or options.hq_nice_len != null or
        options.hq_min_match != null or options.dictionary_path != null)
        return error.MissingMatchedMode;
    if (options.only_level) |level| {
        _ = try resolvedNativeOptions(options, level);
    } else {
        for ([_]c_int{ 1, 3, 9, 22 }) |level| _ = try resolvedNativeOptions(options, level);
    }
    return options;
}

fn optionValue(comptime name: []const u8, arg: []const u8, args: *std.process.Args.Iterator) !?[]const u8 {
    if (std.mem.eql(u8, arg, name)) return args.next() orelse error.MissingLimit;
    if (std.mem.startsWith(u8, arg, name ++ "=")) return arg[name.len + 1 ..];
    return null;
}

fn parseBool(value: []const u8) !bool {
    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1")) return true;
    if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0")) return false;
    return error.InvalidBoolean;
}
