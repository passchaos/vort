const std = @import("std");
const vort = @import("vort");
const br = vort.br;

const Config = struct {
    operation: []const u8 = "encode",
    codec: []const u8 = "planned",
    api: []const u8 = "one_shot",
    level: br.PlannedCompressionLevel = .fast,
    quality: ?u4 = null,
    mode: br.PlannedMode = .generic,
    window_bits: ?u5 = null,
    large_window: bool = false,
    block_len: usize = 0,
    metadata: []const u8 = "",
    stream_metadata: ?[]const u8 = null,
    flush_at: ?usize = null,
    dictionary_paths: []const []const u8 = &.{},
    serialized_dictionary_path: ?[]const u8 = null,
    max_total_working_memory: ?usize = null,
    total_profile_enabled: bool = true,
    input_chunk: usize = 127,
    output_chunk: usize = 31,
    max_output_size: usize = 64 * 1024,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try read(init, input_path, 64 * 1024);
    defer init.gpa.free(input);
    const json = try read(init, config_path, 65536);
    defer init.gpa.free(json);
    var profile: br.EncodeMemoryProfile = .{};
    var summary: ?br.StreamSummary = null;
    const parsed = std.json.parseFromSlice(Config, init.gpa, json, .{}) catch |err| {
        try print(init, .{ .@"error" = @errorName(err), .input_bytes = input.len, .output_bytes = 0, .summary = summary, .total_profile = profile, .output_preserved_on_error = true });
        return;
    };
    defer parsed.deinit();
    var failure: ?[]const u8 = null;
    const output: ?[]u8 = operation(init, input, parsed.value, &profile, &summary) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (output) |bytes| init.gpa.free(bytes);
    if (output) |bytes| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    try print(init, .{
        .@"error" = failure,
        .input_bytes = input.len,
        .output_bytes = if (output) |bytes| bytes.len else 0,
        .requested = .{ .codec = parsed.value.codec, .api = parsed.value.api, .level = parsed.value.level, .quality = parsed.value.quality, .mode = parsed.value.mode, .window_bits = parsed.value.window_bits, .large_window = parsed.value.large_window, .max_total_working_memory = parsed.value.max_total_working_memory },
        .summary = summary,
        .total_profile = profile,
        .output_preserved_on_error = failure != null,
        .build_mode = @tagName(@import("builtin").mode),
    });
}

fn planned(config: Config, dictionary: br.SharedDictionary, profile: ?*br.EncodeMemoryProfile) br.PlannedEncodeOptions {
    return .{ .level = config.level, .quality = config.quality, .mode = config.mode, .window_bits = config.window_bits, .large_window = config.large_window, .metadata = config.metadata, .shared_dictionary = dictionary, .max_total_working_memory = config.max_total_working_memory, .memory_profile = profile };
}
fn chunked(config: Config, dictionary: br.SharedDictionary, profile: ?*br.EncodeMemoryProfile) br.PlannedStreamChunksOptions {
    return .{ .level = config.level, .quality = config.quality, .mode = config.mode, .window_bits = config.window_bits orelse 16, .large_window = config.large_window, .block_len = config.block_len, .metadata = config.metadata, .shared_dictionary = dictionary, .max_total_working_memory = config.max_total_working_memory, .memory_profile = profile };
}
fn stored(config: Config) !br.StoredStreamOptions {
    var options: br.StoredStreamOptions = .{ .window_bits = config.window_bits orelse 16, .metadata = config.metadata };
    if (@hasField(br.StoredStreamOptions, "large_window")) {
        options.large_window = config.large_window;
    } else if (config.large_window) return error.UnsupportedStoredLargeWindow;
    if (config.max_total_working_memory != null) return error.UnsupportedStoredTotalBudget;
    return options;
}
fn operation(init: std.process.Init, input: []const u8, config: Config, profile: *br.EncodeMemoryProfile, summary: *?br.StreamSummary) ![]u8 {
    if (std.mem.eql(u8, config.operation, "make_serialized_dictionary")) {
        var bits: [32]u8 = @splat(0);
        bits[4] = 1;
        const words = [_]br.SerializedSharedDictionaryWordListSpec{.{ .size_bits_by_length = bits, .data = "wordtest" }};
        const transforms = [_]br.SerializedSharedDictionaryTransformListSpec{.{ .prefix_suffix = &.{0}, .transforms = &.{ 0, 0, 0 } }};
        const choices = [_]br.SerializedSharedDictionaryChoice{.{ .word_list_index = 0, .transform_list_index = 0 }};
        return br.serializeSharedDictionaryAlloc(init.gpa, .{ .raw_prefix = input, .word_lists = &words, .transform_lists = &transforms, .dictionaries = &choices });
    }
    var prefixes: std.ArrayList([]const u8) = .empty;
    defer {
        for (prefixes.items) |bytes| init.gpa.free(bytes);
        prefixes.deinit(init.gpa);
    }
    for (config.dictionary_paths) |path| {
        const bytes = try read(init, path, 64 * 1024);
        errdefer init.gpa.free(bytes);
        try prefixes.append(init.gpa, bytes);
    }
    const serialized_bytes = if (config.serialized_dictionary_path) |path| try read(init, path, 64 * 1024) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(serialized_bytes);
    var serialized: ?br.SerializedSharedDictionary = if (config.serialized_dictionary_path != null) try br.parseSerializedSharedDictionary(serialized_bytes) else null;
    const dictionary: br.SharedDictionary = .{ .raw_prefixes = prefixes.items, .serialized = if (serialized) |*value| value else null };
    const decode: br.DecodeOptions = .{ .allow_large_window = config.large_window, .shared_dictionary = dictionary };
    if (std.mem.eql(u8, config.operation, "decode")) return br.decodeStreamAllocLimitedWithOptions(init.gpa, input, config.max_output_size, decode);
    if (!std.mem.eql(u8, config.operation, "encode")) return error.UnsupportedOperation;
    const output = try encode(init, input, config, dictionary, if (config.total_profile_enabled) profile else null);
    errdefer init.gpa.free(output);
    summary.* = try br.summarizeStreamAllocLimitedWithOptions(init.gpa, output, config.max_output_size, decode);
    return output;
}
fn encode(init: std.process.Init, input: []const u8, config: Config, dictionary: br.SharedDictionary, profile: ?*br.EncodeMemoryProfile) ![]u8 {
    if ((config.flush_at != null or config.stream_metadata != null) and !std.mem.eql(u8, config.api, "incremental")) return error.InvalidBlockPlan;
    if (config.stream_metadata != null and config.flush_at == null) return error.InvalidBlockPlan;
    if (std.mem.eql(u8, config.codec, "stored")) {
        if (dictionary.raw_prefixes.len != 0 or dictionary.serialized != null) return error.InvalidBlockPlan;
        const options = try stored(config);
        if (std.mem.eql(u8, config.api, "one_shot")) return br.encodeStoredStreamWithOptionsAlloc(init.gpa, input, options);
        if (std.mem.eql(u8, config.api, "reusable")) {
            var encoder = br.StoredStreamEncoder.init(init.gpa);
            defer encoder.deinit();
            return encoder.encodeWithOptionsAlloc(input, options);
        }
        if (std.mem.eql(u8, config.api, "incremental")) {
            var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(init.gpa, .{ .stream = options, .block_len = if (config.block_len == 0) 256 else config.block_len, .max_input_len = input.len });
            defer encoder.deinit();
            return pump(init, input, config, &encoder);
        }
        if (!std.mem.eql(u8, config.api, "chunks")) return error.UnsupportedOperation;
        var pieces = try split(init.gpa, input, config.input_chunk);
        defer pieces.deinit(init.gpa);
        return br.encodeStoredStreamChunksWithOptionsAlloc(init.gpa, pieces.items, options);
    }
    if (!std.mem.eql(u8, config.codec, "planned")) return error.UnsupportedCodec;
    if (std.mem.eql(u8, config.api, "one_shot")) return br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, planned(config, dictionary, profile));
    if (std.mem.eql(u8, config.api, "reusable")) {
        var encoder = br.PlannedStreamEncoder.init(init.gpa);
        defer encoder.deinit();
        return encoder.encodeWithOptionsAlloc(init.gpa, input, planned(config, dictionary, profile));
    }
    const options = chunked(config, dictionary, profile);
    if (std.mem.eql(u8, config.api, "incremental")) {
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(init.gpa, .{ .stream = options, .block_len = options.block_len, .max_input_len = input.len });
        defer encoder.deinit();
        return pump(init, input, config, &encoder);
    }
    if (!std.mem.eql(u8, config.api, "chunks")) return error.UnsupportedOperation;
    var pieces = try split(init.gpa, input, config.input_chunk);
    defer pieces.deinit(init.gpa);
    return br.encodePlannedStreamChunksWithOptionsAlloc(init.gpa, pieces.items, options);
}
fn split(allocator: std.mem.Allocator, input: []const u8, chunk_size: usize) !std.ArrayList([]const u8) {
    if (chunk_size == 0) return error.InvalidChunkSize;
    var pieces: std.ArrayList([]const u8) = .empty;
    errdefer pieces.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const end = offset + @min(input.len - offset, chunk_size);
        try pieces.append(allocator, input[offset..end]);
        offset = end;
    }
    return pieces;
}
fn pump(init: std.process.Init, input: []const u8, config: Config, encoder: anytype) ![]u8 {
    if (config.input_chunk == 0 or config.output_chunk == 0 or config.output_chunk > 65536) return error.InvalidChunkSize;
    if (config.flush_at) |at| if (at > input.len) return error.InvalidBlockPlan;
    const buffer = try init.gpa.alloc(u8, config.output_chunk);
    defer init.gpa.free(buffer);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(init.gpa);
    var offset: usize = 0;
    var finishing = false;
    var flushed = config.flush_at == null;
    var flushing = false;
    var steps: usize = 0;
    while (steps < input.len * 4 + config.max_output_size + 1024) : (steps += 1) {
        if (!flushed and !flushing and offset == config.flush_at.?) {
            if (config.stream_metadata) |metadata| try encoder.writeMetadata(metadata) else encoder.flush();
            flushing = true;
        }
        if (offset == input.len and !finishing and !flushing) {
            try encoder.finish();
            finishing = true;
        }
        var end = offset + @min(input.len - offset, config.input_chunk);
        if (!flushed) end = @min(end, config.flush_at.?);
        const progress = try encoder.step(if (flushing) &.{} else input[offset..end], buffer);
        offset += progress.progress.input_read;
        if (progress.progress.output_written > config.max_output_size - output.items.len) return error.OutputLimitExceeded;
        try output.appendSlice(init.gpa, buffer[0..progress.progress.output_written]);
        if (flushing and progress.status == .need_input) {
            flushing = false;
            flushed = true;
        }
        if (progress.status == .done) {
            if (offset != input.len) return error.InputAccountingMismatch;
            return output.toOwnedSlice(init.gpa);
        }
    }
    return error.IncrementalDidNotFinish;
}
fn read(init: std.process.Init, path: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(limit));
}
fn print(init: std.process.Init, value: anytype) !void {
    const json = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(json);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
