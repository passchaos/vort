//! File-driven public Zstd format QA; no reference process or compiler calls.
const std = @import("std");
const builtin = @import("builtin");
const zstd = @import("zstd");

const Api = enum { one_shot, into, append, reuse, size, incremental };
const DictionaryKind = enum { none, raw, full };
const Config = struct {
    operation: enum { encode, decode } = .encode,
    api: Api = .one_shot,
    format: zstd.FrameFormat = .standard,
    selection: zstd.NativeFrameSelection = .auto,
    strategy: zstd.Strategy = .auto,
    hq: bool = false,
    checksum: bool = true,
    content_size: bool = true,
    block_size: usize = 131072,
    dictionary_path: ?[]const u8 = null,
    dictionary_kind: DictionaryKind = .none,
    use_dictionary_set: bool = false,
    resume_dictionary: bool = false,
    max_output_len: usize = 2 * 1024 * 1024,
    expected_output_len: ?usize = null,
    input_policy: enum { block_stream, prevalidated_frame } = .block_stream,
};

const Progress = struct {
    steps: usize = 0,
    input_read: usize = 0,
    output_written: usize = 0,
    zero_input_offers: usize = 0,
    zero_output_offers: usize = 0,
    need_input: usize = 0,
    need_output: usize = 0,
};
const State = struct {
    progress: Progress = .{},
    decoder_snapshot: ?zstd.NativeIncrementalFrameDecoder.Snapshot = null,
    encoded_bound: ?usize = null,
    dictionary_resumes: usize = 0,
    measured_size: ?usize = null,
    reusable_repeated: bool = false,
    self_decode_verified: bool = false,
    caller_guards_verified: bool = true,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try read(init, input_path);
    defer init.gpa.free(input);
    const config_json = try read(init, config_path);
    defer init.gpa.free(config_json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, config_json, .{});
    defer parsed.deinit();
    const c = parsed.value;
    const dictionary_bytes = if (c.dictionary_path) |path| try read(init, path) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(dictionary_bytes);
    const dictionary: ?zstd.NativeDictionary = switch (c.dictionary_kind) {
        .none => null,
        .raw => zstd.NativeDictionary.initRawContent(dictionary_bytes),
        .full => (try zstd.NativeDictionary.initFromStandardDictionary(dictionary_bytes)).dictionary,
    };
    const entries = if (dictionary) |dict| [_]zstd.NativeDictionary{dict} else [_]zstd.NativeDictionary{zstd.NativeDictionary.initRawContent("")};
    const dictionary_set = try zstd.NativeDictionarySet.initChecked(if (dictionary != null and c.use_dictionary_set) &entries else &.{});
    var state: State = .{};
    var failure: ?[]const u8 = null;
    const input_sha = digest(input);
    const dictionary_sha = digest(dictionary_bytes);
    const output: ?[]u8 = operation(init.gpa, input, c, dictionary, dictionary_set, &state) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (output) |bytes| init.gpa.free(bytes);
    const input_after = digest(input);
    const dictionary_after = digest(dictionary_bytes);
    if (!std.mem.eql(u8, &input_sha, &input_after) or !std.mem.eql(u8, &dictionary_sha, &dictionary_after)) return error.BorrowedInputChanged;
    const output_sha: ?[64]u8 = if (output) |bytes| digest(bytes) else null;
    if (output) |bytes| if (c.api != .size) try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.zstd.magicless-probe.v1",
        .config = c,
        .@"error" = failure,
        .input_bytes = input.len,
        .input_sha256 = input_sha[0..],
        .dictionary_bytes = dictionary_bytes.len,
        .dictionary_sha256 = dictionary_sha[0..],
        .dictionary_id = if (dictionary) |dict| dict.id else 0,
        .output_bytes = if (output) |bytes| bytes.len else 0,
        .output_sha256 = if (output_sha) |*hash| hash[0..] else null,
        .encoded_bound = state.encoded_bound,
        .measured_size = state.measured_size,
        .progress = state.progress,
        .decoder_snapshot = state.decoder_snapshot,
        .dictionary_resumes = state.dictionary_resumes,
        .reusable_repeated = state.reusable_repeated,
        .self_decode_verified = state.self_decode_verified,
        .caller_guards_verified = state.caller_guards_verified,
        .borrowed_input_verified = true,
        .target = @tagName(builtin.cpu.arch),
        .cpu_model = builtin.cpu.model.name,
        .build_mode = @tagName(builtin.mode),
        .zig_version = builtin.zig_version_string,
    }, .{});
    defer init.gpa.free(json);
    try std.Io.File.stdout().writeStreamingAll(init.io, json);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}

fn encodeOptions(c: Config) zstd.NativeFrameOptions {
    return .{ .format = c.format, .selection = c.selection, .content_checksum = c.checksum, .include_content_size = c.content_size, .block_size_max = c.block_size, .strategy = c.strategy, .hq = if (c.hq) .{ .search_depth = 8, .nice_len = 32, .min_match = 3 } else null };
}
fn decodeOptions(c: Config, dictionary: ?zstd.NativeDictionary, set: zstd.NativeDictionarySet) zstd.FrameDecodeOptions {
    return .{ .format = c.format, .dictionary = if (c.use_dictionary_set) null else dictionary, .dictionary_set = if (c.use_dictionary_set) set else null, .max_output_len = c.max_output_len, .expected_output_len = c.expected_output_len };
}
fn operation(a: std.mem.Allocator, input: []const u8, c: Config, dictionary: ?zstd.NativeDictionary, set: zstd.NativeDictionarySet, state: *State) ![]u8 {
    if (c.operation == .decode) return decode(a, input, c, dictionary, set, state);
    const options = encodeOptions(c);
    state.encoded_bound = if (dictionary) |dict| try zstd.encodedNativeFrameBoundWithDictionary(input.len, options, dict) else try zstd.encodedNativeFrameBoundWithOptions(input.len, options);
    const wire = try encode(a, input, c, options, dictionary, set, state);
    errdefer a.free(wire);
    if (wire.len > state.encoded_bound.?) return error.EncodedBoundExceeded;
    const decoded = try zstd.decodeFrameAllocWithOptions(a, wire, decodeOptions(c, dictionary, set));
    defer a.free(decoded);
    if (!std.mem.eql(u8, decoded, input)) return error.RoundTripMismatch;
    state.self_decode_verified = true;
    return wire;
}
fn encode(a: std.mem.Allocator, input: []const u8, c: Config, options: zstd.NativeFrameOptions, dictionary: ?zstd.NativeDictionary, set: zstd.NativeDictionarySet, s: *State) ![]u8 {
    if (c.api == .incremental) return encodeIncremental(a, input, c, options, dictionary, s);
    if (c.api == .one_shot) {
        return if (c.use_dictionary_set) (try zstd.encodeNativeFrameWithDictionarySetAlloc(a, input, options, set, dictionary.?.id)).frame else if (dictionary) |dict| (try zstd.encodeNativeFrameWithDictionaryAlloc(a, input, options, dict)).frame else (try zstd.encodeNativeFrameWithOptionsAlloc(a, input, options)).frame;
    }
    if (c.api == .into) {
        const capacity = s.encoded_bound.?;
        const guarded = try a.alloc(u8, capacity + 16);
        defer a.free(guarded);
        @memset(guarded, 0xa5);
        const result = if (c.use_dictionary_set) try zstd.encodeNativeFrameIntoSliceWithDictionarySet(a, input, options, set, dictionary.?.id, guarded[8..][0..capacity]) else if (dictionary) |dict| try zstd.encodeNativeFrameIntoSliceWithDictionary(a, input, options, dict, guarded[8..][0..capacity]) else try zstd.encodeNativeFrameIntoSlice(a, input, options, guarded[8..][0..capacity]);
        try guards(guarded, result.written);
        return a.dupe(u8, guarded[8..][0..result.written]);
    }
    if (c.api == .append) {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(a);
        try output.appendSlice(a, "guard:");
        _ = if (c.use_dictionary_set) try zstd.encodeNativeFrameAppendWithDictionarySet(a, &output, input, options, set, dictionary.?.id) else if (dictionary) |dict| try zstd.encodeNativeFrameAppendWithDictionary(a, &output, input, options, dict) else try zstd.encodeNativeFrameAppend(a, &output, input, options);
        if (!std.mem.eql(u8, output.items[0..6], "guard:")) return error.AppendPrefixChanged;
        return a.dupe(u8, output.items[6..]);
    }
    if (c.api != .reuse) return error.InvalidEncodeApi;
    var encoder = zstd.NativeFrameEncoder.init(a);
    defer encoder.deinit();
    const first = if (c.use_dictionary_set) try encoder.encodeWithDictionarySetAlloc(input, options, set, dictionary.?.id) else if (dictionary) |dict| try encoder.encodeWithDictionaryAlloc(input, options, dict) else try encoder.encodeWithOptionsAlloc(input, options);
    errdefer a.free(first.frame);
    const second = if (c.use_dictionary_set) try encoder.encodeWithDictionarySetAlloc(input, options, set, dictionary.?.id) else if (dictionary) |dict| try encoder.encodeWithDictionaryAlloc(input, options, dict) else try encoder.encodeWithOptionsAlloc(input, options);
    defer a.free(second.frame);
    if (!std.mem.eql(u8, first.frame, second.frame)) return error.ReusableChangedWire;
    s.reusable_repeated = true;
    return first.frame;
}
fn decode(a: std.mem.Allocator, input: []const u8, c: Config, dictionary: ?zstd.NativeDictionary, set: zstd.NativeDictionarySet, s: *State) ![]u8 {
    if (c.api == .incremental) return decodeIncremental(a, input, c, dictionary, set, s);
    const options = decodeOptions(c, dictionary, set);
    if (c.api == .one_shot) return zstd.decodeFrameAllocWithOptions(a, input, options);
    if (c.api == .into) {
        const capacity = @min(c.max_output_len, 2 * 1024 * 1024);
        const buffer = try a.alloc(u8, capacity + 16);
        defer a.free(buffer);
        @memset(buffer, 0xa5);
        const written = zstd.decodeFrameIntoWithOptions(a, input, buffer[8..][0..capacity], options) catch |err| {
            try guards(buffer, 0);
            return err;
        };
        try guards(buffer, written);
        return a.dupe(u8, buffer[8..][0..written]);
    }
    if (c.api == .append) {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(a);
        try output.appendSlice(a, "guard:");
        const written = zstd.decodeFrameAppendWithOptions(a, &output, input, options) catch |err| {
            if (!std.mem.eql(u8, output.items, "guard:")) return error.AppendChangedOnError;
            return err;
        };
        if (!std.mem.eql(u8, output.items[0..6], "guard:") or output.items.len != written + 6) return error.AppendPrefixChanged;
        return a.dupe(u8, output.items[6..]);
    }
    if (c.api == .size) {
        s.measured_size = try zstd.decodedFrameSizeWithOptions(input, options);
        const decoded = try zstd.decodeFrameAllocWithOptions(a, input, options);
        if (decoded.len != s.measured_size.?) {
            a.free(decoded);
            return error.DecodedSizeMismatch;
        }
        return decoded;
    }
    if (c.api != .reuse) return error.InvalidDecodeApi;
    var decoder = zstd.NativeFrameDecoder.initWithOptions(a, options);
    defer decoder.deinit();
    const first = try decoder.decodeAlloc(input);
    errdefer a.free(first);
    const second = try decoder.decodeAllocWithOptions(input, options);
    defer a.free(second);
    if (!std.mem.eql(u8, first, second)) return error.ReusableChangedPlaintext;
    s.reusable_repeated = true;
    return first;
}
fn encodeIncremental(a: std.mem.Allocator, input: []const u8, _: Config, options: zstd.NativeFrameOptions, dictionary: ?zstd.NativeDictionary, s: *State) ![]u8 {
    var selected = options;
    if (dictionary) |dict| selected.dictionary_id = dict.id;
    var encoder = if (dictionary) |dict| blk: {
        if (selected.include_content_size) break :blk try zstd.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(a, selected, input.len, dict);
        break :blk try zstd.NativeIncrementalFrameEncoder.initWithPresetDictionary(a, selected, dict);
    } else if (selected.include_content_size) try zstd.NativeIncrementalFrameEncoder.initExactSize(a, selected, input.len) else try zstd.NativeIncrementalFrameEncoder.init(a, selected);
    defer encoder.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(a);
    var offset: usize = 0;
    var finishing = false;
    var buffer: [4112]u8 = undefined;
    const inputs = [_]usize{ 0, 1, 0, 127, 4096 };
    const outputs = [_]usize{ 0, 1, 0, 31, 4096 };
    while (s.progress.steps < input.len * 8 + 8192) : (s.progress.steps += 1) {
        if (offset == input.len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        const end = offset + @min(input.len - offset, inputs[s.progress.steps % inputs.len]);
        const offered = input[offset..end];
        const capacity = outputs[s.progress.steps % outputs.len];
        @memset(&buffer, 0xa5);
        const result = try encoder.step(offered, buffer[8..][0..capacity]);
        try update(a, &output, &s.progress, offered.len, capacity, result.progress.input_read, result.progress.output_written, &buffer);
        offset += result.progress.input_read;
        if (result.status == .need_input) s.progress.need_input += 1;
        if (result.status == .need_output) s.progress.need_output += 1;
        if (result.status == .done) {
            if (offset != input.len) return error.InputAccountingMismatch;
            s.progress.steps += 1;
            return output.toOwnedSlice(a);
        }
    }
    return error.IncrementalDidNotFinish;
}
fn decodeIncremental(a: std.mem.Allocator, input: []const u8, c: Config, dictionary: ?zstd.NativeDictionary, set: zstd.NativeDictionarySet, s: *State) ![]u8 {
    const options: zstd.NativeIncrementalFrameDecoder.Options = .{ .format = c.format, .max_output_len = c.max_output_len, .expected_output_len = if (c.expected_output_len) |len| @as(u64, len) else null, .input_policy = @enumFromInt(@intFromEnum(c.input_policy)) };
    var decoder = if (c.resume_dictionary) zstd.NativeIncrementalFrameDecoder.initWithOptions(a, options) else if (c.use_dictionary_set) zstd.NativeIncrementalFrameDecoder.initWithDictionarySetAndOptions(a, set, options) else if (dictionary) |dict| zstd.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(a, dict, options) else zstd.NativeIncrementalFrameDecoder.initWithOptions(a, options);
    defer decoder.deinit();
    defer s.decoder_snapshot = decoder.snapshot();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(a);
    var offset: usize = 0;
    var buffer: [4112]u8 = undefined;
    const inputs = [_]usize{ 0, 1, 0, 17, 4096 };
    const outputs = [_]usize{ 0, 1, 0, 31, 4096 };
    while (s.progress.steps < input.len * 16 + c.max_output_len * 2 + 8192) : (s.progress.steps += 1) {
        const end = offset + @min(input.len - offset, inputs[s.progress.steps % inputs.len]);
        const offered = input[offset..end];
        const capacity = outputs[s.progress.steps % outputs.len];
        @memset(&buffer, 0xa5);
        const result = decoder.step(offered, buffer[8..][0..capacity]) catch |err| {
            const progress = decoder.snapshot().last_step_progress;
            try update(a, &output, &s.progress, offered.len, capacity, progress.input_read, progress.output_written, &buffer);
            offset += progress.input_read;
            if (err == error.NeedDictionary and c.resume_dictionary and dictionary != null) {
                try decoder.provideDictionary(dictionary.?);
                s.dictionary_resumes += 1;
                continue;
            }
            return err;
        };
        try update(a, &output, &s.progress, offered.len, capacity, result.progress.input_read, result.progress.output_written, &buffer);
        offset += result.progress.input_read;
        if (result.status == .need_input) s.progress.need_input += 1;
        if (result.status == .need_output) s.progress.need_output += 1;
        if (result.status == .done or (offset == input.len and result.status == .need_input and offered.len == 0)) {
            try decoder.finish();
            if (offset != input.len or decoder.snapshot().input_received != input.len or decoder.snapshot().output_written != output.items.len) return error.DecoderProgressMismatch;
            s.progress.steps += 1;
            return output.toOwnedSlice(a);
        }
    }
    return error.IncrementalDidNotFinish;
}
fn update(a: std.mem.Allocator, output: *std.ArrayList(u8), progress: *Progress, input_len: usize, capacity: usize, read_count: usize, written: usize, buffer: []const u8) !void {
    if (read_count > input_len or written > capacity) return error.InvalidProgress;
    try guards(buffer, written);
    progress.input_read += read_count;
    progress.output_written += written;
    if (input_len == 0) progress.zero_input_offers += 1;
    if (capacity == 0) progress.zero_output_offers += 1;
    try output.appendSlice(a, buffer[8..][0..written]);
}
fn guards(buffer: []const u8, written: usize) !void {
    for (buffer[0..8]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
    for (buffer[8 + written ..]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
}
fn digest(data: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(4 * 1024 * 1024));
}
