const std = @import("std");
const vort = @import("vort");

const Mode = @FieldType(vort.LzmaCompressionPreset, "mode");

pub const Controls = struct {
    preset: ?u32 = null,
    extreme: bool = false,
    finder: ?vort.LzmaMatchFinder = null,
    nice_len: ?u16 = null,
    depth: ?u32 = null,
    dictionary_size: ?u32 = null,
    chunk_size: ?usize = null,
    mode: ?Mode = null,
    lc: ?u4 = null,
    lp: ?u3 = null,
    pb: ?u3 = null,
    match_memory: ?usize = null,
    profile: bool = false,

    pub fn baseOptions(self: Controls, comptime Options: type) !Options {
        return if (self.preset) |level| try Options.fromPreset(level, self.extreme) else .{};
    }

    /// Apply explicit flags after the preset and legacy positional arguments.
    /// Profile storage is owned by the command and survives the encoder call.
    pub fn apply(self: Controls, options: anytype, comptime mode_field: []const u8, profile: ?*vort.LzmaEncodeWorkProfile) !void {
        if (self.chunk_size) |value| {
            if (@hasField(@TypeOf(options.*), "chunk_size")) {
                options.chunk_size = @intCast(value);
            } else return error.UnsupportedLzmaChunkSize;
        }
        if (self.dictionary_size) |value| options.dictionary_size = @intCast(value);
        if (self.mode) |value| @field(options.*, mode_field) = try convertMode(@TypeOf(@field(options.*, mode_field)), value);
        if (self.lc) |value| options.properties.lc = value;
        if (self.lp) |value| options.properties.lp = value;
        if (self.pb) |value| options.properties.pb = value;
        const selected_mode = try convertMode(Mode, @field(options.*, mode_field));
        const modern_mode = selected_mode == .fast or selected_mode == .normal;
        const explicit_match = self.finder != null or self.nice_len != null or
            self.depth != null or self.match_memory != null or modern_mode;
        if (self.profile and !explicit_match and options.match_options == null)
            return error.LzmaProfileRequiresAdvancedControls;
        if (explicit_match or (self.profile and options.match_options != null)) {
            var match = options.match_options orelse vort.LzmaMatchOptions{
                .finder = if (selected_mode == .normal) .bt4 else .hc4,
            };
            if (self.finder) |value| match.finder = value;
            if (self.nice_len) |value| match.nice_len = value;
            if (self.depth) |value| match.depth = value;
            if (self.match_memory) |value| match.max_working_memory = value;
            if (self.profile) match.profile = profile;
            options.match_options = match;
        }
    }

    fn parseFlag(self: *Controls, arg: []const u8) !void {
        if (std.mem.eql(u8, arg, "--extreme")) {
            if (self.extreme) return error.DuplicateLzmaOption;
            self.extreme = true;
            return;
        }
        if (std.mem.eql(u8, arg, "--profile")) {
            if (self.profile) return error.DuplicateLzmaOption;
            self.profile = true;
            return;
        }
        const separator = std.mem.indexOfScalar(u8, arg, '=') orelse return error.UnknownLzmaOption;
        const name = arg[0..separator];
        const value = arg[separator + 1 ..];
        if (value.len == 0) return error.MissingLzmaOptionValue;
        if (std.mem.eql(u8, name, "--preset")) {
            try assign(self, "preset", try std.fmt.parseInt(u32, value, 10));
        } else if (std.mem.eql(u8, name, "--match-finder")) {
            try assign(self, "finder", std.meta.stringToEnum(vort.LzmaMatchFinder, value) orelse return error.InvalidLzmaMatchFinder);
        } else if (std.mem.eql(u8, name, "--nice-len")) {
            try assign(self, "nice_len", try std.fmt.parseInt(u16, value, 10));
        } else if (std.mem.eql(u8, name, "--depth")) {
            try assign(self, "depth", try std.fmt.parseInt(u32, value, 10));
        } else if (std.mem.eql(u8, name, "--dict-size")) {
            try assign(self, "dictionary_size", try std.fmt.parseInt(u32, value, 10));
        } else if (std.mem.eql(u8, name, "--chunk-size")) {
            try assign(self, "chunk_size", try std.fmt.parseInt(usize, value, 10));
        } else if (std.mem.eql(u8, name, "--mode")) {
            try assign(self, "mode", try parseMode(value));
        } else if (std.mem.eql(u8, name, "--lc")) {
            try assign(self, "lc", try std.fmt.parseInt(u4, value, 10));
        } else if (std.mem.eql(u8, name, "--lp")) {
            try assign(self, "lp", try std.fmt.parseInt(u3, value, 10));
        } else if (std.mem.eql(u8, name, "--pb")) {
            try assign(self, "pb", try std.fmt.parseInt(u3, value, 10));
        } else if (std.mem.eql(u8, name, "--match-memory")) {
            try assign(self, "match_memory", try std.fmt.parseInt(usize, value, 10));
        } else return error.UnknownLzmaOption;
    }

    fn validate(self: Controls) !void {
        if (self.extreme and self.preset == null) return error.LzmaExtremeRequiresPreset;
        if (self.preset) |level| _ = try vort.lzmaResolvePreset(level, self.extreme);
        if (self.nice_len) |value| try (vort.LzmaMatchOptions{ .nice_len = value }).validate();
    }
};

pub const Parsed = struct {
    positionals: [5]?[]const u8 = @splat(null),
    count: usize = 0,
    controls: Controls = .{},
};

/// Existing positional arguments must precede the trailing named options.
/// A bounded result avoids allocating during command-line validation.
pub fn parse(args: anytype, maximum_positionals: usize) !Parsed {
    std.debug.assert(maximum_positionals <= 5);
    var result: Parsed = .{};
    var flags_started = false;
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--")) {
            flags_started = true;
            try result.controls.parseFlag(arg);
        } else {
            if (flags_started or result.count == maximum_positionals) return error.UnexpectedLzmaArgument;
            result.positionals[result.count] = arg;
            result.count += 1;
        }
    }
    try result.controls.validate();
    return result;
}

pub fn parseMode(text: []const u8) !Mode {
    if (std.mem.eql(u8, text, "literal-only")) return .literal_only;
    return std.meta.stringToEnum(Mode, text) orelse error.InvalidLzmaOptions;
}

pub fn convertMode(comptime Target: type, mode: anytype) !Target {
    return std.meta.stringToEnum(Target, @tagName(mode)) orelse error.InvalidLzmaOptions;
}

pub fn parseNumber(comptime T: type, text: ?[]const u8, default: T) !T {
    return if (text) |value| try std.fmt.parseInt(T, value, 10) else default;
}

pub fn printProfile(stdout: *std.Io.Writer, profile: vort.LzmaEncodeWorkProfile) !void {
    try stdout.print("lzma_profile finder={s} nice_len={d} depth={d} positions={d} candidate_probes={d} chain_steps={d} tree_steps={d} matched_bytes={d} parser_windows={d} peak_working_memory={d}\n", .{
        @tagName(profile.finder),    profile.effective_nice_len,  profile.effective_depth,
        profile.mf_positions,        profile.mf_candidate_probes, profile.mf_chain_steps,
        profile.mf_tree_steps,       profile.matched_bytes,       profile.parser_windows,
        profile.peak_working_memory,
    });
}

fn assign(controls: *Controls, comptime field: []const u8, value: anytype) !void {
    if (@field(controls.*, field) != null) return error.DuplicateLzmaOption;
    @field(controls.*, field) = value;
}

test {
    _ = @import("lzma_controls_tests.zig");
}
