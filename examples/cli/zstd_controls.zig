const std = @import("std");
const vort = @import("vort");
const stream_files = @import("stream_files.zig");

pub const Controls = struct {
    selection: vort.ZstdNativeFrameSelection = .auto,
    checksum: bool = true,
    content_size: bool = true,
    level: ?c_int = null,
    strategy: ?vort.zstd.Strategy = null,
    fast_acceleration: ?u32 = null,
    hq_depth: ?u32 = null,
    hq_nice_len: ?u32 = null,
    hq_min_match: ?u8 = null,
    hq_memory: ?usize = null,
    profile: bool = false,
    window_log: ?u6 = null,
    max_match_history_len: ?usize = null,
    max_total_memory: ?usize = null,
    memory_profile: bool = false,
    max_input_len: ?vort.StreamCount = null,
    max_output_len: ?vort.StreamCount = null,

    pub fn hasStreamLimits(self: Controls) bool {
        return self.max_input_len != null or self.max_output_len != null;
    }

    pub fn hasHqOverrides(self: Controls) bool {
        return self.hq_depth != null or self.hq_nice_len != null or self.hq_min_match != null or self.hq_memory != null;
    }

    pub fn resolved(self: Controls) !vort.ZstdNativeFrameOptions {
        return self.resolvedWithProfile(null);
    }

    pub fn resolvedWithProfile(self: Controls, profile: ?*vort.ZstdEncoderControlProfile) !vort.ZstdNativeFrameOptions {
        return self.resolvedWithProfiles(profile, null);
    }

    pub fn resolvedWithProfiles(self: Controls, profile: ?*vort.ZstdEncoderControlProfile, memory_profile: ?*vort.zstd.EncodeMemoryProfile) !vort.ZstdNativeFrameOptions {
        if (self.level == null and self.strategy == null and self.fast_acceleration == null and !self.hasHqOverrides()) {
            var native: vort.ZstdNativeFrameOptions = .{
                .selection = self.selection,
                .content_checksum = self.checksum,
                .include_content_size = self.content_size,
                .control_profile = profile,
                .window_log = self.window_log,
                .max_match_history_len = self.max_match_history_len,
                .max_total_working_memory = self.max_total_memory,
                .memory_profile = if (self.memory_profile) memory_profile else null,
            };
            try native.validate();
            return native;
        }
        // Resolve the library's strategy/level defaults first. A partial HQ
        // override must preserve the remaining defaults, including tuned levels.
        var options = try vort.zstd.resolveFrameOptionsForLevel(self.level orelse vort.zstdDefaultCompressionLevel, .{
            .strategy = self.strategy orelse .auto,
            .fast_acceleration = self.fast_acceleration,
            .content_checksum = self.checksum,
            .include_content_size = self.content_size,
            .control_profile = profile,
            .window_log = self.window_log,
            .max_match_history_len = self.max_match_history_len,
            .max_total_working_memory = self.max_total_memory,
            .memory_profile = if (self.memory_profile) memory_profile else null,
        });
        if (self.hasHqOverrides()) {
            if (@hasField(@TypeOf(options), "hq")) {
                const Hq = @typeInfo(@FieldType(@TypeOf(options), "hq")).optional.child;
                var hq = options.hq orelse Hq{};
                if (self.hq_depth) |value| hq.search_depth = value;
                if (self.hq_nice_len) |value| hq.nice_len = value;
                if (self.hq_min_match) |value| hq.min_match = value;
                if (self.hq_memory) |value| hq.max_working_memory = value;
                options.hq = hq;
            } else return error.UnsupportedZstdHqOptions;
        }
        if (self.selection != .auto) {
            if (options.selection != .auto and options.selection != self.selection) return error.InvalidBlockPlan;
            options.selection = self.selection;
        }
        try options.validate();
        return options;
    }

    pub fn frameOptionsWithProfile(self: Controls, profile: ?*vort.ZstdEncoderControlProfile) !vort.zstd.FrameOptions {
        return self.frameOptionsWithProfiles(profile, null);
    }

    pub fn frameOptionsWithProfiles(self: Controls, profile: ?*vort.ZstdEncoderControlProfile, memory_profile: ?*vort.zstd.EncodeMemoryProfile) !vort.zstd.FrameOptions {
        if (self.selection != .auto) return error.InvalidBlockPlan;
        const native = try self.resolvedWithProfiles(profile, memory_profile);
        var frame: vort.zstd.FrameOptions = .{
            .strategy = self.strategy orelse .auto,
            .fast_acceleration = self.fast_acceleration,
            .content_checksum = self.checksum,
            .include_content_size = self.content_size,
            .control_profile = profile,
            .window_log = self.window_log,
            .max_match_history_len = self.max_match_history_len,
            .max_total_working_memory = self.max_total_memory,
            .memory_profile = if (self.memory_profile) memory_profile else null,
        };
        if (@hasField(@TypeOf(frame), "hq") and @hasField(@TypeOf(native), "hq")) frame.hq = native.hq;
        return frame;
    }
};

pub fn parse(args: anytype, first: ?[]const u8) !Controls {
    var result = Controls{};
    var positional: usize = 0;
    var pending = first;
    while (true) {
        const arg = pending orelse args.next() orelse break;
        pending = null;
        if (try optionValue("--level", arg, args)) |value| {
            if (result.level != null) return error.DuplicateZstdOption;
            result.level = try std.fmt.parseInt(c_int, value, 10);
        } else if (try optionValue("--strategy", arg, args)) |value| {
            if (result.strategy != null) return error.DuplicateZstdOption;
            result.strategy = try parseStrategy(value);
        } else if (try optionValue("--fast-acceleration", arg, args)) |value| {
            if (result.fast_acceleration != null) return error.DuplicateZstdOption;
            result.fast_acceleration = try std.fmt.parseInt(u32, value, 10);
        } else if (try optionValue("--hq-depth", arg, args)) |value| {
            if (result.hq_depth != null) return error.DuplicateZstdOption;
            result.hq_depth = try std.fmt.parseInt(u32, value, 10);
        } else if (try optionValue("--hq-nice-len", arg, args)) |value| {
            if (result.hq_nice_len != null) return error.DuplicateZstdOption;
            result.hq_nice_len = try std.fmt.parseInt(u32, value, 10);
        } else if (try optionValue("--hq-min-match", arg, args)) |value| {
            if (result.hq_min_match != null) return error.DuplicateZstdOption;
            result.hq_min_match = try std.fmt.parseInt(u8, value, 10);
        } else if (try optionValue("--hq-memory", arg, args)) |value| {
            if (result.hq_memory != null) return error.DuplicateZstdOption;
            result.hq_memory = try std.fmt.parseInt(usize, value, 10);
        } else if (try optionValue("--window-log", arg, args)) |value| {
            if (result.window_log != null) return error.DuplicateZstdOption;
            result.window_log = try std.fmt.parseInt(u6, value, 10);
        } else if (try optionValue("--max-match-history-len", arg, args)) |value| {
            if (result.max_match_history_len != null) return error.DuplicateZstdOption;
            result.max_match_history_len = try std.fmt.parseInt(usize, value, 10);
        } else if (try optionValue("--max-total-memory", arg, args)) |value| {
            if (result.max_total_memory != null) return error.DuplicateZstdOption;
            result.max_total_memory = try std.fmt.parseInt(usize, value, 10);
        } else if (try optionValue("--max-input-len", arg, args)) |value| {
            if (result.max_input_len != null) return error.DuplicateZstdOption;
            result.max_input_len = try std.fmt.parseInt(vort.StreamCount, value, 10);
        } else if (try optionValue("--max-output-len", arg, args)) |value| {
            if (result.max_output_len != null) return error.DuplicateZstdOption;
            result.max_output_len = try std.fmt.parseInt(vort.StreamCount, value, 10);
        } else if (std.mem.eql(u8, arg, "--memory-profile")) {
            if (result.memory_profile) return error.DuplicateZstdOption;
            result.memory_profile = true;
        } else if (std.mem.eql(u8, arg, "--profile")) {
            if (result.profile) return error.DuplicateZstdOption;
            result.profile = true;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownZstdOption;
        } else {
            switch (positional) {
                0 => result.selection = try parseSelection(arg),
                1 => result.checksum = try parseBool(arg),
                2 => result.content_size = try parseBool(arg),
                else => return error.UnexpectedZstdArgument,
            }
            positional += 1;
        }
    }
    return result;
}

pub fn parseStrategy(value: []const u8) !vort.zstd.Strategy {
    if (std.mem.eql(u8, value, "double-fast")) return .double_fast;
    return std.meta.stringToEnum(vort.zstd.Strategy, value) orelse error.InvalidZstdStrategy;
}

pub fn isControlArgument(arg: []const u8) bool {
    inline for (.{ "--level", "--strategy", "--fast-acceleration", "--hq-depth", "--hq-nice-len", "--hq-min-match", "--hq-memory", "--profile", "--window-log", "--max-match-history-len", "--max-total-memory", "--memory-profile", "--max-input-len", "--max-output-len" }) |name| {
        if (std.mem.eql(u8, arg, name) or std.mem.startsWith(u8, arg, name ++ "=")) return true;
    }
    return false;
}

fn optionValue(comptime name: []const u8, arg: []const u8, args: anytype) !?[]const u8 {
    if (std.mem.eql(u8, arg, name)) return args.next() orelse error.MissingZstdOptionValue;
    if (std.mem.startsWith(u8, arg, name ++ "=")) return arg[name.len + 1 ..];
    return null;
}

fn parseSelection(value: []const u8) !vort.ZstdNativeFrameSelection {
    if (std.mem.eql(u8, value, "auto")) return .auto;
    if (std.mem.eql(u8, value, "raw_or_rle") or std.mem.eql(u8, value, "raw-rle")) return .raw_or_rle;
    if (std.mem.eql(u8, value, "literal_only") or std.mem.eql(u8, value, "literal-only")) return .literal_only;
    if (std.mem.eql(u8, value, "fast_compressed") or std.mem.eql(u8, value, "fast-compressed")) return .fast_compressed;
    return error.InvalidZstdNativeSelection;
}

fn parseBool(value: []const u8) !bool {
    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "yes")) return true;
    if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0") or std.mem.eql(u8, value, "no")) return false;
    return error.InvalidBoolean;
}

pub fn encodeTextHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const first = args.next();
    const option_first = if (first) |arg| isControlArgument(arg) else false;
    const payload = if (option_first) "" else first orelse "";
    const parsed = try parse(args, if (option_first) first else null);
    if (parsed.hasStreamLimits()) return error.UnsupportedZstdStreamLimit;
    var profile: vort.ZstdEncoderControlProfile = .{};
    var memory_profile: vort.zstd.EncodeMemoryProfile = .{};
    const options = try parsed.resolvedWithProfiles(if (parsed.profile) &profile else null, if (parsed.memory_profile) &memory_profile else null);
    const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, options);
    defer init.gpa.free(result.frame);
    try printHex(stdout, result.frame);
    if (parsed.profile) try printProfile(stdout, profile);
    if (parsed.memory_profile) try printMemoryProfile(stdout, memory_profile);
}

pub fn encodeBytesHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const hex = args.next() orelse return error.MissingHexInput;
    if (hex.len & 1 != 0) return error.InvalidHexInput;
    const payload = try init.gpa.alloc(u8, hex.len / 2);
    defer init.gpa.free(payload);
    for (payload, 0..) |*byte, index| byte.* = try std.fmt.parseInt(u8, hex[index * 2 ..][0..2], 16);
    const parsed = try parse(args, null);
    if (parsed.hasStreamLimits()) return error.UnsupportedZstdStreamLimit;
    var profile: vort.ZstdEncoderControlProfile = .{};
    var memory_profile: vort.zstd.EncodeMemoryProfile = .{};
    const options = try parsed.resolvedWithProfiles(if (parsed.profile) &profile else null, if (parsed.memory_profile) &memory_profile else null);
    const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, options);
    defer init.gpa.free(result.frame);
    try printHex(stdout, result.frame);
    if (parsed.profile) try printProfile(stdout, profile);
    if (parsed.memory_profile) try printMemoryProfile(stdout, memory_profile);
}

pub fn encodeFileHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const path = args.next() orelse return error.MissingCorpusPath;
    const parsed = try parse(args, null);
    if (parsed.hasStreamLimits()) return error.UnsupportedZstdStreamLimit;
    var profile: vort.ZstdEncoderControlProfile = .{};
    var memory_profile: vort.zstd.EncodeMemoryProfile = .{};
    const options = try parsed.resolvedWithProfiles(if (parsed.profile) &profile else null, if (parsed.memory_profile) &memory_profile else null);
    const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(payload);
    const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, options);
    defer init.gpa.free(result.frame);
    try printHex(stdout, result.frame);
    if (parsed.profile) try printProfile(stdout, profile);
    if (parsed.memory_profile) try printMemoryProfile(stdout, memory_profile);
}

pub fn encodeFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    if (isControlArgument(output_path)) return error.MissingCorpusPath;
    const parsed = try parse(args, null);
    if (parsed.hasStreamLimits()) return error.UnsupportedZstdStreamLimit;
    var profile: vort.ZstdEncoderControlProfile = .{};
    var memory_profile: vort.zstd.EncodeMemoryProfile = .{};
    const options = try parsed.resolvedWithProfiles(if (parsed.profile) &profile else null, if (parsed.memory_profile) &memory_profile else null);
    const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(payload);
    const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, options);
    defer init.gpa.free(result.frame);
    try writeAtomic(init, output_path, result.frame);
    try stdout.print("zstd_native_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ result.frame.len, payload.len, output_path });
    if (parsed.profile) try printProfile(stdout, profile);
    if (parsed.memory_profile) try printMemoryProfile(stdout, memory_profile);
}

fn printHex(stdout: *std.Io.Writer, bytes: []const u8) !void {
    for (bytes) |byte| try stdout.print("{x:0>2}", .{byte});
    try stdout.writeByte('\n');
}

/// Thin verification helper for the public level-based one-shot API.
pub fn encodeLevelFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    if (isControlArgument(output_path)) return error.MissingCorpusPath;
    const parsed = try parse(args, null);
    if (parsed.hasStreamLimits()) return error.UnsupportedZstdStreamLimit;
    var profile: vort.ZstdEncoderControlProfile = .{};
    var memory_profile: vort.zstd.EncodeMemoryProfile = .{};
    const options = try parsed.frameOptionsWithProfiles(if (parsed.profile) &profile else null, if (parsed.memory_profile) &memory_profile else null);
    const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(payload);
    const encoded = try vort.zstd.encodeFrameWithLevelAndOptionsAlloc(init.gpa, payload, parsed.level orelse vort.zstdDefaultCompressionLevel, options);
    defer init.gpa.free(encoded);
    try writeAtomic(init, output_path, encoded);
    try stdout.print("zstd_level_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ encoded.len, payload.len, output_path });
    if (parsed.profile) try printProfile(stdout, profile);
    if (parsed.memory_profile) try printMemoryProfile(stdout, memory_profile);
}

pub fn printProfile(stdout: *std.Io.Writer, profile: vort.ZstdEncoderControlProfile) !void {
    try stdout.print("zstd_profile strategy={s} available={any} controls_used={any} hq_used={any} hq_depth={d} hq_nice_len={d} hq_min_match={d} hq_memory={d} positions={d} tree_nodes={d} price_evaluations={d} hq_passes={d} refinement_passes={d} peak_working_memory={d} raw_blocks={d} rle_blocks={d} compressed_blocks={d}\n", .{
        @tagName(profile.resolved_strategy), profile.available,             profile.controls_used,          profile.hq_used,
        profile.effective_hq_search_depth,   profile.effective_hq_nice_len, profile.effective_hq_min_match, profile.effective_hq_max_working_memory,
        profile.positions_tested,            profile.tree_nodes,            profile.price_evaluations,      profile.hq_passes,
        profile.refinement_passes,           profile.peak_working_memory,   profile.raw_blocks,             profile.rle_blocks,
        profile.compressed_blocks,
    });
}

test {
    _ = @import("zstd_controls_tests.zig");
}

fn writeAtomic(init: std.process.Init, path: []const u8, bytes: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFileAtomic(init.io, path, .{ .replace = true });
    defer file.deinit(init.io);
    var buffer: [4096]u8 = undefined;
    var writer = file.file.writerStreaming(init.io, &buffer);
    try writer.interface.writeAll(bytes);
    try writer.interface.flush();
    try file.replace(init.io);
}

pub fn printMemoryProfile(stdout: *std.Io.Writer, profile: vort.zstd.EncodeMemoryProfile) !void {
    try stdout.print("zstd_memory_profile available={any} peak_requested_bytes={d} live_requested_bytes={d} limit=", .{
        profile.available, profile.peak_requested_bytes, profile.live_requested_bytes,
    });
    if (profile.limit) |limit| try stdout.print("{d}\n", .{limit}) else try stdout.writeAll("unlimited\n");
}

pub fn fileSizeCounter(size: u64) !vort.StreamCount {
    return stream_files.fileSizeCounter(size);
}

pub fn encodeStreamFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    if (isControlArgument(output_path)) return error.MissingCorpusPath;
    const parsed = try parse(args, null);
    var profile: vort.ZstdEncoderControlProfile = .{};
    var memory_profile: vort.zstd.EncodeMemoryProfile = .{};
    const options = try parsed.resolvedWithProfiles(if (parsed.profile) &profile else null, if (parsed.memory_profile) &memory_profile else null);
    const input_file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    var input_open = true;
    defer if (input_open) input_file.close(init.io);
    const input_size = try fileSizeCounter((try input_file.stat(init.io)).size);
    if (parsed.max_input_len) |limit| if (input_size > limit) return error.OutputLimitExceeded;
    var atomic = try std.Io.Dir.cwd().createFileAtomic(init.io, output_path, .{ .replace = true });
    defer atomic.deinit(init.io);
    var write_buffer: [32 * 1024]u8 = undefined;
    var writer = atomic.file.writerStreaming(init.io, &write_buffer);
    const totals = try pumpStreamFile(init, input_file, &writer.interface, options, input_size, parsed.max_input_len, parsed.max_output_len);
    input_file.close(init.io);
    input_open = false;
    try writer.interface.flush();
    try atomic.replace(init.io);
    try stdout.print("zstd_native_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ totals.output_written, totals.input_read, output_path });
    if (parsed.profile) try printProfile(stdout, profile);
    if (parsed.memory_profile) try printMemoryProfile(stdout, memory_profile);
}

fn pumpStreamFile(init: std.process.Init, input_file: std.Io.File, writer: *std.Io.Writer, options: vort.ZstdNativeFrameOptions, input_size: vort.StreamCount, max_input: ?vort.StreamCount, max_output: ?vort.StreamCount) !stream_files.Totals {
    var encoder = if (options.include_content_size)
        try vort.zstd.NativeIncrementalFrameEncoder.initExactSize(init.gpa, options, input_size)
    else
        try vort.zstd.NativeIncrementalFrameEncoder.init(init.gpa, options);
    defer encoder.deinit();
    return stream_files.pump(init, input_file, writer, &encoder, max_input, max_output);
}

/// Stream limits stay wide; allocating APIs must explicitly check narrowing.
pub fn parseLogicalLimit(value: ?[]const u8) !?vort.StreamCount {
    return if (value) |text| try std.fmt.parseInt(vort.StreamCount, text, 10) else null;
}

pub fn localLimit(value: ?vort.StreamCount) !?usize {
    return if (value) |limit| try vort.core.stream_count.toLocal(limit) else null;
}
