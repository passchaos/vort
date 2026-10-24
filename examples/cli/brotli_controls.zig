const std = @import("std");
const vort = @import("vort");
const br = vort.br;
const ParseMode = @FieldType(vort.BrotliHqOptions, "parse_mode");
const CopyLengths = @FieldType(vort.BrotliHqOptions, "copy_lengths");

pub const Controls = struct {
    quality: ?u4 = null,
    mode: ?br.PlannedMode = null,
    window_bits: ?u5 = null,
    large_window: bool = false,
    hq: bool = false,
    search_depth: ?u32 = null,
    nice_len: ?u32 = null,
    beam_width: ?u8 = null,
    iterations: ?u8 = null,
    parse_mode: ?ParseMode = null,
    copy_lengths: ?CopyLengths = null,
    max_price_evaluations: ?u64 = null,
    block_len: ?usize = null,
    memory: ?usize = null,
    npostfix: ?u2 = null,
    ndirect_high: ?u4 = null,
    profile: bool = false,
    max_total_memory: ?usize = null,
    memory_profile: bool = false,
    metadata: ?[]const u8 = null,

    pub fn hqSelected(self: Controls) bool {
        return self.hq or self.search_depth != null or self.nice_len != null or self.beam_width != null or
            self.iterations != null or self.parse_mode != null or self.copy_lengths != null or self.max_price_evaluations != null or self.block_len != null or self.memory != null or self.npostfix != null or self.ndirect_high != null;
    }

    pub fn storedOptions(self: Controls) !vort.br.StoredStreamOptions {
        if (self.quality != null or self.mode != null or self.hqSelected() or self.profile or
            self.max_total_memory != null or self.memory_profile) return error.UnsupportedBrotliStoredOption;
        const options: vort.br.StoredStreamOptions = .{
            .large_window = self.large_window,
            .window_bits = self.window_bits orelse vort.brotliDefaultWindowBits,
            .metadata = self.metadata orelse "",
        };
        _ = try vort.br.encodedStoredStreamBoundWithOptions(0, options);
        return options;
    }

    pub fn resolve(self: Controls, comptime Options: type, profile: ?*vort.BrotliHqProfile) !Options {
        return self.resolveWithMemoryProfile(Options, profile, null);
    }

    pub fn resolveWithMemoryProfile(self: Controls, comptime Options: type, hq_profile: ?*vort.BrotliHqProfile, memory_profile: ?*vort.BrotliEncodeMemoryProfile) !Options {
        var options: Options = .{};
        options.large_window = self.large_window;
        options.metadata = self.metadata orelse "";
        options.max_total_working_memory = self.max_total_memory;
        if (self.memory_profile) options.memory_profile = memory_profile;
        if (self.quality) |value| options.quality = value;
        if (self.mode) |value| options.mode = value;
        if (self.window_bits) |value| options.window_bits = value;
        if (!self.hqSelected()) {
            if (self.profile) return error.BrotliProfileRequiresHq;
            return options;
        }
        const quality = options.quality orelse return error.InvalidBlockPlan;
        var hq: vort.BrotliHqOptions = .{};
        if (self.search_depth) |value| hq.search_depth = value;
        if (self.nice_len) |value| hq.nice_len = value;
        if (self.beam_width) |value| hq.beam_width = value;
        if (self.iterations) |value| hq.iterations = value;
        if (self.parse_mode) |value| hq.parse_mode = value;
        if (self.copy_lengths) |value| hq.copy_lengths = value;
        if (self.max_price_evaluations) |value| hq.max_price_evaluations = value;
        if (self.block_len) |value| hq.block_len = value;
        if (self.memory) |value| hq.max_working_memory = value;
        // Preserve font's public default distance shape when only one field
        // is explicitly overridden. The library owns the mode policy.
        if (self.npostfix != null or self.ndirect_high != null) {
            var distance = (try hq.resolve(quality, options.mode)).distance_parameters;
            if (self.npostfix) |value| distance.npostfix = value;
            if (self.ndirect_high) |value| distance.ndirect_high = value;
            hq.distance_parameters = distance;
        }
        if (self.profile) hq.profile = hq_profile;
        try hq.validate(quality);
        options.hq = hq;
        return options;
    }
};

pub fn parse(args: anytype) !Controls {
    return parseWithFirst(args, null);
}

pub fn parseWithFirst(args: anytype, first: ?[]const u8) !Controls {
    var result: Controls = .{};
    var positional: usize = 0;
    var pending = first;
    while (true) {
        const arg = pending orelse args.next() orelse break;
        pending = null;
        if (try optionValue("--quality", arg, args)) |value| try set(&result, "quality", try std.fmt.parseInt(u4, value, 10)) else if (try optionValue("--mode", arg, args)) |value| try set(&result, "mode", try parseMode(value)) else if (try optionValue("--window-bits", arg, args)) |value| try set(&result, "window_bits", try std.fmt.parseInt(u5, value, 10)) else if (try optionValue("--hq-depth", arg, args)) |value| try set(&result, "search_depth", try std.fmt.parseInt(u32, value, 10)) else if (try optionValue("--hq-nice-len", arg, args)) |value| try set(&result, "nice_len", try std.fmt.parseInt(u32, value, 10)) else if (try optionValue("--hq-beam-width", arg, args)) |value| try set(&result, "beam_width", try std.fmt.parseInt(u8, value, 10)) else if (try optionValue("--hq-iterations", arg, args)) |value| try set(&result, "iterations", try std.fmt.parseInt(u8, value, 10)) else if (try optionValue("--hq-parse-mode", arg, args)) |value| try set(&result, "parse_mode", std.meta.stringToEnum(ParseMode, value) orelse return error.InvalidBrotliParseMode) else if (try optionValue("--hq-copy-lengths", arg, args)) |value| try set(&result, "copy_lengths", std.meta.stringToEnum(CopyLengths, value) orelse return error.InvalidBrotliCopyLengths) else if (try optionValue("--hq-max-price-evaluations", arg, args)) |value| try set(&result, "max_price_evaluations", try std.fmt.parseInt(u64, value, 10)) else if (try optionValue("--hq-block-len", arg, args)) |value| try set(&result, "block_len", try std.fmt.parseInt(usize, value, 10)) else if (try optionValue("--hq-memory", arg, args)) |value| try set(&result, "memory", try std.fmt.parseInt(usize, value, 10)) else if (try optionValue("--hq-npostfix", arg, args)) |value| try set(&result, "npostfix", try std.fmt.parseInt(u2, value, 10)) else if (try optionValue("--hq-ndirect-high", arg, args)) |value| try set(&result, "ndirect_high", try std.fmt.parseInt(u4, value, 10)) else if (try optionValue("--max-total-memory", arg, args)) |value| try set(&result, "max_total_memory", try std.fmt.parseInt(usize, value, 10)) else if (try optionValue("--metadata", arg, args)) |value| try set(&result, "metadata", value) else if (std.mem.eql(u8, arg, "--memory-profile")) {
            if (result.memory_profile) return error.DuplicateBrotliOption;
            result.memory_profile = true;
        } else if (std.mem.eql(u8, arg, "--large-window")) {
            if (result.large_window) return error.DuplicateBrotliOption;
            result.large_window = true;
        } else if (std.mem.eql(u8, arg, "--hq")) {
            if (result.hq) return error.DuplicateBrotliOption;
            result.hq = true;
        } else if (std.mem.eql(u8, arg, "--profile")) {
            if (result.profile) return error.DuplicateBrotliOption;
            result.profile = true;
        } else if (std.mem.startsWith(u8, arg, "--")) return error.UnknownBrotliOption else {
            switch (positional) {
                0 => try set(&result, "quality", try std.fmt.parseInt(u4, arg, 10)),
                1 => try set(&result, "mode", try parseMode(arg)),
                2 => try set(&result, "window_bits", try std.fmt.parseInt(u5, arg, 10)),
                else => return error.UnexpectedBrotliArgument,
            }
            positional += 1;
        }
    }
    return result;
}

/// Stored commands retain their established [window_bits] [metadata]
/// positionals. Only format/header controls apply to this standalone API.
pub fn parseStored(args: anytype) !Controls {
    return parseStoredWithFirst(args, null);
}

pub fn parseStoredWithFirst(args: anytype, first: ?[]const u8) !Controls {
    var window_bits: ?u5 = null;
    var metadata: ?[]const u8 = null;
    var positional: usize = 0;
    var first_option: ?[]const u8 = null;
    var pending = first;
    while (true) {
        const value = pending orelse args.next() orelse break;
        pending = null;
        if (std.mem.startsWith(u8, value, "--")) {
            first_option = value;
            break;
        }
        switch (positional) {
            0 => window_bits = try std.fmt.parseInt(u5, value, 10),
            1 => metadata = value,
            else => return error.UnexpectedBrotliArgument,
        }
        positional += 1;
    }
    var parsed = try parseWithFirst(args, first_option);
    if (parsed.quality != null or parsed.mode != null or parsed.hqSelected() or parsed.profile or
        parsed.max_total_memory != null or parsed.memory_profile)
        return error.UnsupportedBrotliStoredOption;
    if (window_bits != null) {
        if (parsed.window_bits != null) return error.DuplicateBrotliOption;
        parsed.window_bits = window_bits;
    }
    if (metadata != null) {
        if (parsed.metadata != null) return error.DuplicateBrotliOption;
        parsed.metadata = metadata;
    }
    return parsed;
}

pub fn isStoredControlArgument(value: []const u8) bool {
    inline for (.{ "--large-window", "--window-bits", "--metadata" }) |name| {
        if (std.mem.eql(u8, value, name) or std.mem.startsWith(u8, value, name ++ "=")) return true;
    }
    return false;
}

fn set(controls: *Controls, comptime field: []const u8, value: anytype) !void {
    if (@field(controls.*, field) != null) return error.DuplicateBrotliOption;
    @field(controls.*, field) = value;
}
fn optionValue(comptime name: []const u8, arg: []const u8, args: anytype) !?[]const u8 {
    if (std.mem.eql(u8, arg, name)) return args.next() orelse error.MissingBrotliOptionValue;
    if (std.mem.startsWith(u8, arg, name ++ "=")) return arg[name.len + 1 ..];
    return null;
}
fn parseMode(value: []const u8) !br.PlannedMode {
    return std.meta.stringToEnum(br.PlannedMode, value) orelse error.InvalidBrotliMode;
}

pub fn printProfile(stdout: *std.Io.Writer, profile: vort.BrotliHqProfile) !void {
    const effective = profile.effective orelse {
        try stdout.print("br_hq_profile effective=false passes={d} peak_working_memory={d}\n", .{ profile.passes, profile.peak_working_memory });
        return;
    };
    try stdout.print("br_hq_profile effective=true quality={d} depth={d} nice_len={d} beam_width={d} iterations={d} block_len={d} npostfix={d} ndirect_high={d} memory={d} tree_nodes={d} states={d} transitions={d} price_evaluations={d} passes={d} refinement_passes={d} peak_working_memory={d} emitted_metablocks={d} emitted_commands={d} emitted_copy_bytes={d}\n", .{
        effective.quality,                      effective.search_depth,                     effective.nice_len,           effective.beam_width,        effective.iterations,       effective.block_len,
        effective.distance_parameters.npostfix, effective.distance_parameters.ndirect_high, effective.max_working_memory, profile.tree_nodes,          profile.states,             profile.transitions,
        profile.price_evaluations,              profile.passes,                             profile.refinement_passes,    profile.peak_working_memory, profile.emitted_metablocks, profile.emitted_commands,
        profile.emitted_copy_bytes,
    });
}

pub fn printParseProfile(stdout: *std.Io.Writer, requested: ?ParseMode, profile: vort.BrotliHqProfile) !void {
    if (requested != .whole_block) return;
    const mode = if (profile.effective) |resolved| resolved.parse_mode else .whole_block;
    try stdout.print("br_parse_profile parse_mode={s} bounded_passes={d} whole_block_passes={d} max_parse_positions={d}\n", .{
        @tagName(mode), profile.bounded_passes, profile.whole_block_passes, profile.max_parse_positions,
    });
}

pub fn printLengthProfile(stdout: *std.Io.Writer, requested: ?CopyLengths, profile: vort.BrotliHqProfile) !void {
    if (requested != .complete) return;
    const policy = if (profile.effective) |resolved| resolved.copy_lengths else .complete;
    try stdout.print("br_length_profile copy_lengths={s} sampled_length_passes={d} complete_length_passes={d} max_copy_length_considered={d} max_plan_price_evaluations={d}\n", .{
        @tagName(policy),                   profile.sampled_length_passes,      profile.complete_length_passes,
        profile.max_copy_length_considered, profile.max_plan_price_evaluations,
    });
}

pub fn printFormatProfile(stdout: *std.Io.Writer, profile: vort.BrotliHqProfile) !void {
    if (profile.effective) |resolved| {
        if (resolved.format == .large_window) try stdout.print("br_format_profile format={s}\n", .{@tagName(resolved.format)});
    }
}

pub fn printMemoryProfile(stdout: *std.Io.Writer, profile: vort.BrotliEncodeMemoryProfile) !void {
    try stdout.print("br_memory_profile available={any} peak_requested_bytes={d} live_requested_bytes={d} limit=", .{
        profile.available, profile.peak_requested_bytes, profile.live_requested_bytes,
    });
    if (profile.limit) |limit| try stdout.print("{d}\n", .{limit}) else try stdout.writeAll("unlimited\n");
}

test {
    _ = @import("brotli_controls_tests.zig");
}
