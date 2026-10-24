//! Public API adapters shared by the independent encoder-control probes.
const std = @import("std");
const vort = @import("vort");

pub const Format = enum { alone, xz, raw2, micro, zip_payload };
pub const Controls = struct {
    preset: ?u32 = null,
    extreme: bool = false,
    dictionary_size: ?usize = null,
    mode: ?vort.LzmaEncodeMode = null,
    finder: ?vort.LzmaMatchFinder = null,
    nice_len: ?u16 = null,
    depth: ?u32 = null,
    max_working_memory: ?usize = null,
    lc: ?u8 = null,
    lp: ?u8 = null,
    pb: ?u8 = null,
    check: u8 = 4,
    block_size: ?usize = null,
    size_mode: ?vort.LzmaSizeMode = null,
};

fn configure(comptime Options: type, comptime mode_field: []const u8, controls: Controls, profile: ?*vort.LzmaEncodeWorkProfile) !Options {
    if (controls.extreme and controls.preset == null) return error.InvalidLzmaOptions;
    var options = if (controls.preset) |level| try Options.fromPreset(level, controls.extreme) else Options{};
    if (controls.dictionary_size) |value| options.dictionary_size = std.math.cast(@TypeOf(options.dictionary_size), value) orelse return error.InvalidLzmaOptions;
    if (controls.mode) |value| @field(options, mode_field) = value;
    if (controls.lc) |value| options.properties.lc = std.math.cast(@TypeOf(options.properties.lc), value) orelse return error.InvalidLzmaOptions;
    if (controls.lp) |value| options.properties.lp = std.math.cast(@TypeOf(options.properties.lp), value) orelse return error.InvalidLzmaOptions;
    if (controls.pb) |value| options.properties.pb = std.math.cast(@TypeOf(options.properties.pb), value) orelse return error.InvalidLzmaOptions;
    const selected_mode = @field(options, mode_field);
    const modern = selected_mode == .fast or selected_mode == .normal;
    const explicit_match = controls.finder != null or controls.nice_len != null or controls.depth != null or controls.max_working_memory != null;
    if (options.match_options != null or explicit_match or (modern and profile != null)) {
        var match = options.match_options orelse vort.LzmaMatchOptions{ .finder = if (selected_mode == .normal) .bt4 else .hc4 };
        if (controls.finder) |value| match.finder = value;
        if (controls.nice_len) |value| match.nice_len = value;
        if (controls.depth) |value| match.depth = value;
        if (controls.max_working_memory) |value| match.max_working_memory = value;
        match.profile = profile;
        options.match_options = match;
    }
    return options;
}

pub fn aloneOptions(controls: Controls, profile: ?*vort.LzmaEncodeWorkProfile) !vort.LzmaEncodeOptions {
    var options = try configure(vort.LzmaEncodeOptions, "mode", controls, profile);
    if (controls.size_mode) |value| options.size_mode = value;
    try options.validate();
    return options;
}

pub fn microOptions(controls: Controls, profile: ?*vort.LzmaEncodeWorkProfile) !vort.MicroLzmaEncodeOptions {
    const options = try configure(vort.MicroLzmaEncodeOptions, "mode", controls, profile);
    try options.validate();
    return options;
}

pub fn zipOptions(controls: Controls, profile: ?*vort.LzmaEncodeWorkProfile) !vort.LzmaZipEncodeOptions {
    const options = try configure(vort.LzmaZipEncodeOptions, "mode", controls, profile);
    try options.validate();
    return options;
}

pub fn rawOptions(controls: Controls, profile: ?*vort.LzmaEncodeWorkProfile) !vort.RawLzma2EncodeOptions {
    const options = try configure(vort.RawLzma2EncodeOptions, "parser", controls, profile);
    try options.validate();
    return options;
}

pub fn xzOptions(controls: Controls, profile: ?*vort.LzmaEncodeWorkProfile, filters: []const vort.XzFilter) !vort.XzEncodeOptions {
    var options = try configure(vort.XzEncodeOptions, "parser", controls, profile);
    options.check = switch (controls.check) {
        0 => .none,
        1 => .crc32,
        4 => .crc64,
        10 => .sha256,
        else => return error.InvalidChecksumMode,
    };
    if (controls.block_size) |value| options.block_size = value;
    options.filters = filters;
    try options.validate();
    return options;
}

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8, format: Format, controls: Controls, profile: ?*vort.LzmaEncodeWorkProfile, filters: []const vort.XzFilter) ![]u8 {
    return switch (format) {
        .alone => vort.encodeLzmaAlloc(allocator, input, try aloneOptions(controls, profile)),
        .xz => vort.encodeXzAlloc(allocator, input, try xzOptions(controls, profile, filters)),
        .micro => vort.encodeMicroLzmaAlloc(allocator, input, try microOptions(controls, profile)),
        .zip_payload => vort.encodeLzmaZipPayloadAlloc(allocator, input, try zipOptions(controls, profile)),
        .raw2 => blk: {
            var bytes: std.ArrayList(u8) = .empty;
            errdefer bytes.deinit(allocator);
            _ = try vort.encodeRawLzma2AppendWithOptions(allocator, &bytes, input, try rawOptions(controls, profile));
            break :blk bytes.toOwnedSlice(allocator);
        },
    };
}
