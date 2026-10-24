const std = @import("std");
const vort = @import("vort");
const adapter = @import("encode_controls_api.zig");

const Config = struct {
    format: adapter.Format = .alone,
    operation: []const u8 = "encode",
    profile_enabled: bool = true,
    expected_size: ?usize = null,
    expected_path: ?[]const u8 = null,
    dictionary_property: ?u8 = null,
    input_chunk: usize = 4096,
    output_chunk: usize = 4096,
    max_output_size: usize = 64 * 1024 * 1024,
    filter_id: u32 = 0,
    filter_argument: u32 = 0,
};
const Effective = struct {
    dictionary_size: usize,
    chunk_size: ?usize,
    lc: u4,
    lp: u3,
    pb: u3,
    mode: vort.LzmaEncodeMode,
    finder: ?vort.LzmaMatchFinder,
    nice_len: ?u16,
    depth: ?u32,
    effective_nice_len: ?u16,
    effective_depth: ?u32,
    max_working_memory: ?usize,
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
    const json = try read(init, config_path, 64 * 1024);
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const controls_parsed = try std.json.parseFromSlice(adapter.Controls, init.gpa, json, .{ .ignore_unknown_fields = true });
    defer controls_parsed.deinit();
    const config = parsed.value;
    const controls = controls_parsed.value;
    var profile: vort.LzmaEncodeWorkProfile = .{};
    var failure: ?[]const u8 = null;
    var effective: ?Effective = null;
    const output: ?[]u8 = operation(init, input, config, controls, &profile, &effective) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (output) |bytes| init.gpa.free(bytes);
    if (output) |bytes| {
        if (config.expected_path) |path| {
            const expected = try read(init, path, config.max_output_size);
            defer init.gpa.free(expected);
            if (!std.mem.eql(u8, bytes, expected)) return error.ExpectedOutputMismatch;
        }
        // Library failure returns JSON and leaves any existing target intact.
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    }
    try printJson(init, .{
        .@"error" = failure,
        .input_bytes = input.len,
        .output_bytes = if (output) |bytes| bytes.len else 0,
        .profile = profile,
        .resolved = effective,
        .output_preserved_on_error = failure != null,
        .build_mode = @tagName(@import("builtin").mode),
    });
}

fn operation(init: std.process.Init, input: []const u8, config: Config, controls: adapter.Controls, profile: *vort.LzmaEncodeWorkProfile, effective: *?Effective) ![]u8 {
    if (std.mem.eql(u8, config.operation, "decode")) return decode(init, input, config, controls);
    const incremental = std.mem.eql(u8, config.operation, "incremental");
    if (!std.mem.eql(u8, config.operation, "encode") and !incremental) return error.UnsupportedOperation;
    if (incremental and config.format != .raw2 and config.format != .xz) return error.UnsupportedOperation;
    var filter: [1]vort.XzFilter = undefined;
    const filters: []const vort.XzFilter = switch (config.filter_id) {
        0 => &.{},
        3 => blk: {
            filter[0] = try vort.XzFilter.delta(config.filter_argument);
            break :blk &filter;
        },
        4 => blk: {
            filter[0] = vort.XzFilter.x86(config.filter_argument);
            break :blk &filter;
        },
        else => return error.UnsupportedFilter,
    };
    effective.* = switch (config.format) {
        .alone => describe(try adapter.aloneOptions(controls, null), "mode"),
        .micro => describe(try adapter.microOptions(controls, null), "mode"),
        .zip_payload => describe(try adapter.zipOptions(controls, null), "mode"),
        .raw2 => describe(try adapter.rawOptions(controls, null), "parser"),
        .xz => describe(try adapter.xzOptions(controls, null, filters), "parser"),
    };
    const selected_profile = if (config.profile_enabled) profile else null;
    if (incremental) return encodeIncremental(init, input, config, controls, selected_profile, filters);
    return adapter.encodeAlloc(init.gpa, input, config.format, controls, selected_profile, filters);
}
fn describe(options: anytype, comptime mode_field: []const u8) Effective {
    const mode = @field(options, mode_field);
    const match = options.match_options orelse if (mode == .fast or mode == .normal)
        vort.LzmaMatchOptions{ .finder = if (mode == .normal) .bt4 else .hc4 }
    else
        null;
    return .{
        .dictionary_size = options.dictionary_size,
        .chunk_size = if (@hasField(@TypeOf(options), "chunk_size")) options.chunk_size else null,
        .lc = options.properties.lc,
        .lp = options.properties.lp,
        .pb = options.properties.pb,
        .mode = mode,
        .finder = if (match) |m| m.finder else null,
        .nice_len = if (match) |m| m.nice_len else null,
        .depth = if (match) |m| m.depth else null,
        .effective_nice_len = if (match) |m| m.effectiveNiceLen() else null,
        .effective_depth = if (match) |m| m.effectiveDepth() else null,
        .max_working_memory = if (match) |m| m.max_working_memory else null,
    };
}
fn decode(init: std.process.Init, input: []const u8, config: Config, controls: adapter.Controls) ![]u8 {
    return switch (config.format) {
        .alone => vort.lzma.decodeAllocLimited(init.gpa, input, config.max_output_size),
        .xz => vort.xz.decodeAllocLimited(init.gpa, input, config.max_output_size),
        .micro => vort.lzma.decodeMicroAllocExactSize(init.gpa, input, config.expected_size orelse return error.ExpectedSizeRequired, std.math.cast(u32, controls.dictionary_size orelse 32768) orelse return error.InvalidLzmaOptions),
        .zip_payload => vort.lzma.decodeZipPayloadAllocLimited(init.gpa, input, config.expected_size orelse return error.ExpectedSizeRequired, vort.lzmaMaxEncodeDictionarySize, true),
        .raw2 => decodeRaw(init, input, config, controls),
    };
}
fn decodeRaw(init: std.process.Init, input: []const u8, config: Config, controls: adapter.Controls) ![]u8 {
    if (config.input_chunk == 0 or config.output_chunk == 0 or config.output_chunk > 1024 * 1024) return error.InvalidChunkSize;
    const size = controls.dictionary_size orelse 4096;
    const property = config.dictionary_property orelse try dictionaryProperty(size);
    var decoder = try vort.RawLzma2IncrementalDecoder.init(init.gpa, .{
        .dictionary_property = property,
        .max_dictionary_size = vort.xzMaxEncodeDictionarySize,
        .max_output_len = config.max_output_size,
        .expected_output_len = config.expected_size,
    });
    defer decoder.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(init.gpa);
    const buffer = try init.gpa.alloc(u8, config.output_chunk);
    defer init.gpa.free(buffer);
    var offset: usize = 0;
    var finished = false;
    var steps: usize = 0;
    while (steps < input.len * 4 + config.max_output_size + 1024) : (steps += 1) {
        if (offset == input.len and !finished) {
            decoder.finish();
            finished = true;
        }
        const end = offset + @min(input.len - offset, config.input_chunk);
        const result = try decoder.step(input[offset..end], buffer);
        offset += result.progress.input_read;
        try output.appendSlice(init.gpa, buffer[0..result.progress.output_written]);
        if (result.status == .done) {
            if (offset != input.len) return error.InputAccountingMismatch;
            return output.toOwnedSlice(init.gpa);
        }
    }
    return error.IncrementalDidNotFinish;
}
fn dictionaryProperty(size: usize) !u8 {
    if (size < 4096 or size > vort.xzMaxEncodeDictionarySize) return error.InvalidLzmaOptions;
    for (0..38) |p| {
        if (size <= @as(usize, 2 | (p & 1)) << @intCast(p / 2 + 11)) return @intCast(p);
    }
    return error.InvalidLzmaOptions;
}
fn encodeIncremental(init: std.process.Init, input: []const u8, config: Config, controls: adapter.Controls, profile: ?*vort.LzmaEncodeWorkProfile, filters: []const vort.XzFilter) ![]u8 {
    switch (config.format) {
        .raw2 => {
            const options = try adapter.rawOptions(controls, profile);
            var encoder = try vort.RawLzma2IncrementalEncoder.initExactSize(init.gpa, .{
                .dictionary_size = options.dictionary_size,
                .chunk_size = options.chunk_size,
                .parser = options.parser,
                .properties = options.properties,
                .match_options = options.match_options,
                .max_input_len = input.len,
                .max_pending_output_len = 16 * 1024 * 1024,
            }, input.len);
            defer encoder.deinit();
            return pumpEncoder(init, input, config, &encoder);
        },
        .xz => {
            const options = try adapter.xzOptions(controls, profile, filters);
            var encoder = try vort.XzIncrementalEncoder.initExactSize(init.gpa, .{
                .check = options.check,
                .block_size = options.block_size,
                .dictionary_size = options.dictionary_size,
                .chunk_size = options.chunk_size,
                .parser = options.parser,
                .properties = options.properties,
                .match_options = options.match_options,
                .filters = options.filters,
                .max_input_len = input.len,
            }, input.len);
            defer encoder.deinit();
            return pumpEncoder(init, input, config, &encoder);
        },
        else => return error.UnsupportedOperation,
    }
}
fn pumpEncoder(init: std.process.Init, input: []const u8, config: Config, encoder: anytype) ![]u8 {
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
            encoder.finish();
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
fn read(init: std.process.Init, path: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(limit));
}
fn printJson(init: std.process.Init, value: anytype) !void {
    const json = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(json);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
