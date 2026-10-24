const std = @import("std");
const vort = @import("vort");

pub const Mode = enum { train, optimize };

pub const Options = struct {
    output_path: []const u8,
    target_size: usize,
    dictionary_id: u32,
    dmer_size: u8 = 8,
    segment_size: ?usize = null,
    hash_log: u8 = 20,
    acceleration: u8 = 1,
    max_corpus_size: usize = 256 * 1024 * 1024,
    max_working_memory: usize = 128 * 1024 * 1024,
    max_dictionary_size: usize = 64 * 1024 * 1024,
    steps: ?usize = null,
    threads: ?usize = null,
    shrink: ?bool = null,
    split_numerator: ?usize = null,
    split_denominator: ?usize = null,
    json: bool = false,
    profile: bool = false,
    seen: u16 = 0,
    paths: std.ArrayList([]const u8) = .empty,

    pub fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        self.paths.deinit(allocator);
    }
};

/// Sample path strings remain borrowed from the process argument iterator.
pub fn parse(allocator: std.mem.Allocator, args: *std.process.Args.Iterator, mode: Mode) !Options {
    const output_path = args.next() orelse return error.MissingDictionaryOutput;
    const target = args.next() orelse return error.MissingDictionaryTargetSize;
    const dictionary_id = args.next() orelse return error.MissingDictionaryId;
    var options = Options{
        .output_path = output_path,
        .target_size = try std.fmt.parseInt(usize, target, 10),
        .dictionary_id = try std.fmt.parseInt(u32, dictionary_id, 10),
    };
    errdefer options.deinit(allocator);
    if (options.dictionary_id == 0) return error.InvalidDictionaryMetadata;
    var end_options = false;
    var seen: u16 = 0;
    while (args.next()) |arg| {
        if (end_options) {
            try options.paths.append(allocator, arg);
        } else if (std.mem.eql(u8, arg, "--")) {
            end_options = true;
        } else if (std.mem.eql(u8, arg, "--json")) {
            try unique(&seen, 0);
            options.json = true;
        } else if (std.mem.eql(u8, arg, "--profile")) {
            try unique(&seen, 1);
            options.profile = true;
        } else if (try optionValue("--dmer", arg, args)) |value| {
            try unique(&seen, 2);
            options.dmer_size = try std.fmt.parseInt(u8, value, 10);
        } else if (try optionValue("--segment", arg, args)) |value| {
            try unique(&seen, 3);
            options.segment_size = try std.fmt.parseInt(usize, value, 10);
        } else if (try optionValue("--hash-log", arg, args)) |value| {
            try unique(&seen, 4);
            options.hash_log = try std.fmt.parseInt(u8, value, 10);
        } else if (try optionValue("--accel", arg, args)) |value| {
            try unique(&seen, 5);
            options.acceleration = try std.fmt.parseInt(u8, value, 10);
        } else if (try optionValue("--max-corpus", arg, args)) |value| {
            try unique(&seen, 6);
            options.max_corpus_size = try std.fmt.parseInt(usize, value, 10);
        } else if (try optionValue("--max-working", arg, args)) |value| {
            try unique(&seen, 7);
            options.max_working_memory = try std.fmt.parseInt(usize, value, 10);
        } else if (try optionValue("--max-dictionary", arg, args)) |value| {
            try unique(&seen, 8);
            options.max_dictionary_size = try std.fmt.parseInt(usize, value, 10);
        } else if (try optionValue("--steps", arg, args)) |value| {
            if (mode != .optimize) return error.InvalidFastCoverOption;
            try unique(&seen, 9);
            options.steps = try std.fmt.parseInt(usize, value, 10);
        } else if (try optionValue("--threads", arg, args)) |value| {
            if (mode != .optimize) return error.InvalidFastCoverOption;
            try unique(&seen, 10);
            options.threads = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.eql(u8, arg, "--shrink")) {
            if (mode != .optimize) return error.InvalidFastCoverOption;
            try unique(&seen, 11);
            options.shrink = true;
        } else if (try optionValue("--shrink", arg, args)) |value| {
            if (mode != .optimize) return error.InvalidFastCoverOption;
            try unique(&seen, 11);
            options.shrink = try parseBool(value);
        } else if (try optionValue("--split-num", arg, args)) |value| {
            if (mode != .optimize) return error.InvalidFastCoverOption;
            try unique(&seen, 12);
            options.split_numerator = try std.fmt.parseInt(usize, value, 10);
        } else if (try optionValue("--split-den", arg, args)) |value| {
            if (mode != .optimize) return error.InvalidFastCoverOption;
            try unique(&seen, 13);
            options.split_denominator = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownFastCoverOption;
        } else {
            try options.paths.append(allocator, arg);
        }
    }
    if (options.paths.items.len == 0) return error.MissingDictionarySamples;
    if ((options.dmer_size != 6 and options.dmer_size != 8) or options.hash_log < 1 or options.hash_log > 31 or
        options.acceleration < 1 or options.acceleration > 10 or options.max_corpus_size == 0 or
        options.max_working_memory == 0 or options.max_dictionary_size == 0 or
        options.target_size > options.max_dictionary_size or
        (options.steps != null and options.steps.? == 0) or (options.threads != null and options.threads.? == 0))
        return error.InvalidFastCoverOption;
    if (options.segment_size) |segment| {
        if (segment > options.target_size) return error.InvalidFastCoverOption;
        // Optimization may still select d=6 when d was not pinned by a flag.
        // Its public grid validator owns compatibility among those candidates.
        if ((mode == .train or seen & (@as(u16, 1) << 2) != 0) and segment < options.dmer_size)
            return error.InvalidFastCoverOption;
    }
    if ((options.split_numerator == null) != (options.split_denominator == null)) return error.InvalidFastCoverOption;
    if (options.split_denominator) |denominator|
        if (denominator == 0 or options.split_numerator.? == 0 or options.split_numerator.? > denominator) return error.InvalidFastCoverOption;
    options.seen = seen;
    return options;
}

pub fn train(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    var options = try parse(init.gpa, args, .train);
    defer options.deinit(init.gpa);
    const training = trainOptions(options);
    try vort.zstd.validateFastCoverStandardDictionaryTrainOptions(training, options.dictionary_id);
    var samples = try readSamples(init, options);
    defer samples.deinit(init.gpa);
    var profile: vort.zstd.FastCoverStandardDictionaryTrainingProfile = .{};
    const dictionary = if (options.profile)
        try vort.zstd.profileFastCoverStandardDictionaryAlloc(init.gpa, init.io, samples.values.items, training, options.dictionary_id, &profile)
    else
        try vort.zstd.trainFastCoverStandardDictionaryAlloc(init.gpa, samples.values.items, training, options.dictionary_id);
    defer dictionary.deinit(init.gpa);
    try publish(init, stdout, options, dictionary.bytes, dictionary.view, training, if (options.profile) &profile else null);
}

pub fn optimize(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    var options = try parse(init.gpa, args, .optimize);
    defer options.deinit(init.gpa);
    // These immutable singleton slices live until the public optimizer returns.
    // Omitted flags preserve its own default parameter grid.
    const dmer = [_]u8{options.dmer_size};
    const hash = [_]u8{options.hash_log};
    const acceleration = [_]u8{options.acceleration};
    const segment = [_]usize{options.segment_size orelse 0};
    var search: vort.zstd.FastCoverDictionaryOptimizeOptions = .{
        .target_size = options.target_size,
        .max_corpus_size = options.max_corpus_size,
        .max_working_memory = options.max_working_memory,
        .max_dictionary_size = options.max_dictionary_size,
    };
    if (specified(options, 2)) search.dmer_sizes = &dmer;
    if (specified(options, 4)) search.hash_logs = &hash;
    if (specified(options, 5)) search.accelerations = &acceleration;
    if (options.segment_size != null) search.segment_sizes = &segment;
    if (options.steps) |steps| search.steps = steps;
    if (options.threads) |threads| search.threads = threads;
    if (options.shrink) |shrink| search.shrink_dictionary = shrink;
    try vort.zstd.validateFastCoverStandardDictionaryOptimizeOptions(search, options.dictionary_id);
    var samples = try readSamples(init, options);
    defer samples.deinit(init.gpa);
    var split: vort.dictionary.FastCoverSplitPoint = .{};
    if (options.split_numerator) |numerator| {
        split.numerator = numerator;
        split.denominator = options.split_denominator.?;
    }
    const partitions = try vort.dictionary.splitFastCoverSamples(samples.values.items, split);
    var profile: vort.zstd.FastCoverCodecSearchProfile = .{};
    const dictionary = if (options.profile)
        try vort.zstd.profileOptimizedFastCoverStandardDictionaryAlloc(init.gpa, init.io, partitions.training, partitions.validation, search, options.dictionary_id, &profile)
    else
        try vort.zstd.trainOptimizedFastCoverStandardDictionaryAlloc(init.gpa, partitions.training, partitions.validation, search, options.dictionary_id);
    defer dictionary.deinit(init.gpa);
    try publish(init, stdout, options, dictionary.bytes, dictionary.view, dictionary.selected_options, if (options.profile) &profile else null);
}

fn trainOptions(options: Options) vort.zstd.FastCoverDictionaryTrainOptions {
    return .{
        .target_size = options.target_size,
        .segment_size = options.segment_size,
        .dmer_size = options.dmer_size,
        .hash_log = options.hash_log,
        .acceleration = options.acceleration,
        .max_corpus_size = options.max_corpus_size,
        .max_working_memory = options.max_working_memory,
        .max_dictionary_size = options.max_dictionary_size,
    };
}

fn publish(init: std.process.Init, stdout: *std.Io.Writer, options: Options, bytes: []const u8, view: vort.zstd.StandardDictionaryView, parameters: vort.zstd.FastCoverDictionaryTrainOptions, profile: anytype) !void {
    const verified = try vort.zstd.inspectStandardDictionary(bytes);
    if (verified.id != options.dictionary_id or view.id != options.dictionary_id) return error.InvalidDictionaryMetadata;
    // Complete all allocating formatting before opening the caller's output.
    var summary = std.Io.Writer.Allocating.init(init.gpa);
    defer summary.deinit();
    if (options.json) {
        try std.json.Stringify.value(.{
            .dictionary_id = view.id,
            .dictionary_bytes = bytes.len,
            .history_bytes = view.content.len,
            .dmer_size = parameters.dmer_size,
            .segment_size = parameters.segment_size,
            .hash_log = parameters.hash_log,
            .acceleration = parameters.acceleration,
            .path = options.output_path,
            .profile = profile,
        }, .{}, &summary.writer);
        try summary.writer.writeByte('\n');
    } else {
        try summary.writer.print("dictionary_id={d} dictionary_bytes={d} history_bytes={d} d={d} k=", .{ view.id, bytes.len, view.content.len, parameters.dmer_size });
        if (parameters.segment_size) |segment| try summary.writer.print("{d}", .{segment}) else try summary.writer.writeAll("auto");
        try summary.writer.print(" f={d} accel={d} path={s}\n", .{ parameters.hash_log, parameters.acceleration, options.output_path });
        if (profile) |value| {
            try summary.writer.writeAll("profile=");
            try std.json.Stringify.value(value, .{}, &summary.writer);
            try summary.writer.writeByte('\n');
        }
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = options.output_path, .data = bytes });
    try stdout.writeAll(summary.written());
}

fn specified(options: Options, bit: u4) bool {
    return options.seen & (@as(u16, 1) << bit) != 0;
}

const Samples = struct {
    values: std.ArrayList([]const u8) = .empty,

    fn deinit(self: *Samples, allocator: std.mem.Allocator) void {
        for (self.values.items) |bytes| allocator.free(bytes);
        self.values.deinit(allocator);
    }
};

fn readSamples(init: std.process.Init, options: Options) !Samples {
    var result = Samples{};
    errdefer result.deinit(init.gpa);
    var total: usize = 0;
    for (options.paths.items) |path| {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(options.max_corpus_size - total));
        errdefer init.gpa.free(bytes);
        try result.values.append(init.gpa, bytes);
        total += bytes.len;
    }
    return result;
}

fn optionValue(comptime name: []const u8, arg: []const u8, args: *std.process.Args.Iterator) !?[]const u8 {
    if (std.mem.eql(u8, arg, name)) return args.next() orelse error.MissingFastCoverOptionValue;
    if (std.mem.startsWith(u8, arg, name ++ "=")) return arg[name.len + 1 ..];
    return null;
}

fn parseBool(value: []const u8) !bool {
    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1")) return true;
    if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0")) return false;
    return error.InvalidBoolean;
}

fn unique(seen: *u16, bit: u4) !void {
    const mask = @as(u16, 1) << bit;
    if (seen.* & mask != 0) return error.DuplicateFastCoverOption;
    seen.* |= mask;
}
