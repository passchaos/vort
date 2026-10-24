const std = @import("std");
const vort = @import("vort");
pub const codec = vort.zstd;
pub const MemoryProfile = if (@hasDecl(codec, "EncodeMemoryProfile")) codec.EncodeMemoryProfile else struct {};

pub const Config = struct {
    operation: []const u8 = "encode",
    api: []const u8 = "incremental",
    strategy: []const u8 = "auto",
    selection: []const u8 = "auto",
    window_log: ?u6 = null,
    max_match_history_len: ?usize = null,
    max_total_working_memory: ?usize = null,
    memory_profile_enabled: bool = true,
    control_profile_enabled: bool = true,
    checksum: bool = false,
    content_size: bool = false,
    block_size: usize = 128 * 1024,
    input_chunk: usize = 128 * 1024,
    output_chunk: usize = 128 * 1024,
    flush_at: ?usize = null,
    max_input_size: usize = 128 * 1024 * 1024,
    max_output_size: usize = 128 * 1024 * 1024,
    dictionary_path: ?[]const u8 = null,
    dictionary_id: u32 = 0,
};

pub const Observation = struct {
    history_before_flush_tail: usize = 0,
    history_capacity_before_flush_tail: usize = 0,
    history_absolute_start_before_flush_tail: usize = 0,
    history_final_len: usize = 0,
    history_final_capacity: usize = 0,
    long_index_enabled: bool = false,
    input_read: usize = 0,
    output_written: usize = 0,
};

fn readInclusive(init: std.process.Init, path: []const u8, maximum: usize) ![]u8 {
    // Zig's readFileAlloc treats a reached limit as StreamTooLong. Leave one
    // byte for EOF discrimination, then enforce this probe's inclusive bound.
    const exclusive = std.math.add(usize, maximum, 1) catch return error.InvalidProbeConfig;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(exclusive));
    if (bytes.len > maximum) {
        init.gpa.free(bytes);
        return error.InputLimitExceeded;
    }
    return bytes;
}

pub fn options(config: Config, profile: ?*codec.EncoderControlProfile, memory: ?*MemoryProfile) !codec.NativeFrameOptions {
    var result: codec.NativeFrameOptions = .{
        .strategy = std.meta.stringToEnum(codec.Strategy, config.strategy) orelse return error.InvalidBlockPlan,
        .selection = std.meta.stringToEnum(codec.NativeFrameSelection, config.selection) orelse return error.InvalidBlockPlan,
        .window_log = config.window_log,
        .max_match_history_len = config.max_match_history_len,
        .include_content_size = config.content_size,
        .content_checksum = config.checksum,
        .block_size_max = config.block_size,
        .dictionary_id = config.dictionary_id,
        .control_profile = profile,
    };
    if (@hasField(codec.NativeFrameOptions, "max_total_working_memory")) {
        result.max_total_working_memory = config.max_total_working_memory;
        result.memory_profile = memory;
    } else if (config.max_total_working_memory != null or memory != null) return error.TotalBudgetNotAvailable;
    try result.validate();
    return result;
}

pub fn run(init: std.process.Init, input: []const u8, config: Config, profile: *codec.EncoderControlProfile, memory: *MemoryProfile, observation: *Observation) ![]u8 {
    const dictionary_bytes = if (config.dictionary_path) |path|
        try readInclusive(init, path, config.max_input_size)
    else
        try init.gpa.alloc(u8, 0);
    defer init.gpa.free(dictionary_bytes);
    const dictionary: ?codec.NativeDictionary = if (config.dictionary_path != null) codec.NativeDictionary.init(config.dictionary_id, dictionary_bytes) else null;
    if (std.mem.eql(u8, config.operation, "decode")) {
        if (dictionary) |value| return codec.decodeFrameAllocWithDictionaryLimited(init.gpa, input, value, config.max_output_size);
        return codec.decodeFrameAllocLimited(init.gpa, input, config.max_output_size);
    }
    if (!std.mem.eql(u8, config.operation, "encode")) return error.UnsupportedOperation;
    const selected = try options(config, if (config.control_profile_enabled) profile else null, if (config.memory_profile_enabled) memory else null);
    if (std.mem.eql(u8, config.api, "one_shot")) {
        if (dictionary) |value| return (try codec.encodeNativeFrameWithDictionaryAlloc(init.gpa, input, selected, value)).frame;
        return (try codec.encodeNativeFrameWithOptionsAlloc(init.gpa, input, selected)).frame;
    }
    if (!std.mem.eql(u8, config.api, "incremental") or config.input_chunk == 0 or config.output_chunk == 0) return error.InvalidProbeConfig;
    var encoder = if (dictionary) |value| block: {
        if (selected.include_content_size) break :block try codec.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(init.gpa, selected, input.len, value);
        break :block try codec.NativeIncrementalFrameEncoder.initWithPresetDictionary(init.gpa, selected, value);
    } else if (selected.include_content_size)
        try codec.NativeIncrementalFrameEncoder.initExactSize(init.gpa, selected, input.len)
    else
        try codec.NativeIncrementalFrameEncoder.init(init.gpa, selected);
    defer encoder.deinit();
    const buffer = try init.gpa.alloc(u8, config.output_chunk);
    defer init.gpa.free(buffer);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(init.gpa);
    var offset: usize = 0;
    var finishing = false;
    var flushed = false;
    var flushing = false;
    for (0..input.len * 4 + 4096) |_| {
        if (config.flush_at) |at| {
            if (at > input.len) return error.InvalidProbeConfig;
            if (!flushed and offset == at and !flushing) {
                encoder.flush();
                flushing = true;
            }
        }
        if (offset == input.len and !flushing and !finishing) {
            encoder.finish();
            finishing = true;
        }
        var end = @min(input.len, offset + config.input_chunk);
        if (!flushed) {
            if (config.flush_at) |at| end = @min(end, at);
        }
        const result = try encoder.step(if (flushing) "" else input[offset..end], buffer);
        offset += result.progress.input_read;
        if (result.progress.output_written > config.max_output_size - output.items.len) return error.OutputLimitExceeded;
        try output.appendSlice(init.gpa, buffer[0..result.progress.output_written]);
        if (flushing and result.status == .need_input) {
            flushed = true;
            flushing = false;
            observation.history_before_flush_tail = encoder.history.bytes.items.len;
            observation.history_capacity_before_flush_tail = encoder.history.bytes.capacity;
            observation.history_absolute_start_before_flush_tail = encoder.history.absolute_start;
        }
        if (result.status == .done) {
            if (offset != input.len) return error.InputAccountingMismatch;
            observation.history_final_len = encoder.history.bytes.items.len;
            observation.history_final_capacity = encoder.history.bytes.capacity;
            observation.long_index_enabled = encoder.history.index.longEnabled();
            observation.input_read = encoder.snapshot().frame_input;
            observation.output_written = encoder.snapshot().frame_output;
            return output.toOwnedSlice(init.gpa);
        }
    }
    return error.IncrementalDidNotFinish;
}

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const json = try std.Io.Dir.cwd().readFileAlloc(init.io, config_path, init.gpa, .limited(65536));
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, json, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const input = try readInclusive(init, input_path, parsed.value.max_input_size);
    defer init.gpa.free(input);
    var profile: codec.EncoderControlProfile = .{};
    var memory: MemoryProfile = .{};
    var observation: Observation = .{};
    var failure: ?[]const u8 = null;
    const output: ?[]u8 = run(init, input, parsed.value, &profile, &memory, &observation) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (output) |bytes| init.gpa.free(bytes);
    if (output) |bytes| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    const header = if (output) |bytes| if (std.mem.eql(u8, parsed.value.operation, "encode")) try codec.inspectNativeFrameHeader(bytes) else null else null;
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{
        .@"error" = failure,
        .input_bytes = input.len,
        .output_bytes = if (output) |bytes| bytes.len else 0,
        .requested = parsed.value,
        .actual_header = header,
        .profile = profile,
        .memory_profile = memory,
        .observation = observation,
        .output_preserved_on_error = failure != null,
        .build_mode = @tagName(@import("builtin").mode),
    }, .{});
    defer init.gpa.free(report);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(report);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
