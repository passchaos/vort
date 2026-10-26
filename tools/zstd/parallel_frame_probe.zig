//! Public one-frame parallel Zstd APIs. File input/wire/config; JSON evidence.
const std = @import("std");
const builtin = @import("builtin");
const zstd = @import("zstd");

const Config = struct {
    operation: enum { encode, decode } = .encode,
    api: enum { alloc, append, into } = .alloc,
    format: zstd.FrameFormat = .standard,
    selection: zstd.NativeFrameSelection = .auto,
    strategy: zstd.Strategy = .auto,
    checksum: bool = true,
    content_size: bool = true,
    block_size: usize = 4096,
    window_log: ?u6 = null,
    max_match_history_len: ?usize = null,
    dictionary_kind: enum { none, raw, full } = .none,
    dictionary_path: ?[]const u8 = null,
    use_dictionary_set: bool = false,
    dictionary_id: ?u32 = null,
    expected_output_len: ?usize = null,
    worker_count: usize = 3,
    job_size: usize = 8192,
    max_inflight_jobs: usize = 4,
    max_inflight_bytes: usize = 131072,
    max_working_memory: usize = 256 * 1024 * 1024,
    alias: bool = false,
    exact_output: bool = true,
    short_output: bool = false,
};
const State = struct {
    parallel_profile: zstd.ParallelProfile = .{},
    control: zstd.EncoderControlProfile = .{},
    encoded_bound: ?usize = null,
    worker1_wire_equal: bool = false,
    worker1_wire_bytes: ?usize = null,
    worker1_wire_sha256: ?[64]u8 = null,
    self_decode_verified: bool = false,
    original_serial_contents_verified: bool = false,
    caller_guards_verified: bool = true,
    caller_preserved_on_error: ?bool = null,
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
    const json = try read(init, config_path);
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, json, .{});
    defer parsed.deinit();
    const c = parsed.value;
    const dictionary_bytes = if (c.dictionary_path) |path| try read(init, path) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(dictionary_bytes);
    const dictionary: ?zstd.NativeDictionary = switch (c.dictionary_kind) {
        .none => null,
        .raw => zstd.NativeDictionary.init(c.dictionary_id orelse 0, dictionary_bytes),
        .full => (try zstd.NativeDictionary.initFromStandardDictionary(dictionary_bytes)).dictionary,
    };
    const dictionaries = [_]zstd.NativeDictionary{dictionary orelse zstd.NativeDictionary.initRawContent("")};
    const set = try zstd.NativeDictionarySet.initChecked(if (c.use_dictionary_set and dictionary != null) &dictionaries else &.{});
    const input_sha = digest(input);
    const dict_sha = digest(dictionary_bytes);
    var state: State = .{};
    var failure: ?[]const u8 = null;
    const output: ?[]u8 = operation(init, input, output_path, c, dictionary, set, &state) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (output) |bytes| init.gpa.free(bytes);
    const after = digest(input);
    const dict_after = digest(dictionary_bytes);
    if (!std.mem.eql(u8, &input_sha, &after) or !std.mem.eql(u8, &dict_sha, &dict_after)) return error.BorrowedInputChanged;
    const output_sha: ?[64]u8 = if (output) |bytes| digest(bytes) else null;
    if (output) |bytes| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.zstd.parallel-frame-probe.v1",
        .config = c,
        .@"error" = failure,
        .input_bytes = input.len,
        .input_sha256 = input_sha[0..],
        .dictionary_bytes = dictionary_bytes.len,
        .dictionary_sha256 = dict_sha[0..],
        .dictionary_id = if (dictionary) |dict| dict.id else 0,
        .output_bytes = if (output) |bytes| bytes.len else 0,
        .output_sha256 = if (output_sha) |*hash| hash[0..] else null,
        .encoded_bound = state.encoded_bound,
        .parallel_profile = state.parallel_profile,
        .control_emitted = state.control.emitted(),
        .worker1_wire_equal = state.worker1_wire_equal,
        .worker1_wire_bytes = state.worker1_wire_bytes,
        .worker1_wire_sha256 = if (state.worker1_wire_sha256) |*hash| hash[0..] else null,
        .self_decode_verified = state.self_decode_verified,
        .original_serial_contents_verified = state.original_serial_contents_verified,
        .caller_guards_verified = state.caller_guards_verified,
        .caller_preserved_on_error = state.caller_preserved_on_error,
        .borrowed_input_verified = true,
        .target = @tagName(builtin.cpu.arch),
        .cpu_model = builtin.cpu.model.name,
        .build_mode = @tagName(builtin.mode),
        .zig_version = builtin.zig_version_string,
        .scope = "single Frame with bounded parallel Jobs; worker1 parity uses same geometry, original serial parity is contents only",
    }, .{});
    defer init.gpa.free(report);
    try std.Io.File.stdout().writeStreamingAll(init.io, report);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
fn native(c: Config, control: ?*zstd.EncoderControlProfile) zstd.NativeFrameOptions {
    const hq = c.strategy == .lazy2 or c.strategy == .btlazy2 or c.strategy == .btopt or c.strategy == .btultra or c.strategy == .btultra2;
    return .{ .format = c.format, .selection = c.selection, .strategy = c.strategy, .block_size_max = c.block_size, .window_log = c.window_log, .max_match_history_len = c.max_match_history_len, .content_checksum = c.checksum, .include_content_size = c.content_size, .control_profile = control, .hq = if (hq) .{ .search_depth = 8, .nice_len = 32, .min_match = 3 } else null };
}
fn parallel(init: std.process.Init, c: Config, profile: ?*zstd.ParallelProfile) zstd.ParallelOptions {
    return .{ .io = init.io, .worker_count = c.worker_count, .job_size = c.job_size, .max_inflight_jobs = c.max_inflight_jobs, .max_inflight_bytes = c.max_inflight_bytes, .max_working_memory = c.max_working_memory, .profile = profile };
}
fn decoded(a: std.mem.Allocator, input: []const u8, c: Config, dictionary: ?zstd.NativeDictionary, set: zstd.NativeDictionarySet) ![]u8 {
    return zstd.decodeFrameAllocWithOptions(a, input, .{ .format = c.format, .dictionary = if (c.use_dictionary_set) null else dictionary, .dictionary_set = if (c.use_dictionary_set) set else null, .max_output_len = 8 * 1024 * 1024, .expected_output_len = c.expected_output_len });
}
fn alloc(a: std.mem.Allocator, input: []const u8, opts: zstd.NativeFrameOptions, limits: zstd.ParallelOptions, dictionary: ?zstd.NativeDictionary, set: zstd.NativeDictionarySet, use_set: bool) ![]u8 {
    if (use_set) return zstd.encodeNativeParallelFrameWithDictionarySetAlloc(a, input, opts, set, dictionary.?.id, limits);
    if (dictionary) |dict| return zstd.encodeNativeParallelFrameWithDictionaryAlloc(a, input, opts, dict, limits);
    return zstd.encodeNativeParallelFrameAlloc(a, input, opts, limits);
}
fn operation(init: std.process.Init, input: []const u8, path: []const u8, c: Config, dictionary: ?zstd.NativeDictionary, set: zstd.NativeDictionarySet, s: *State) ![]u8 {
    if (c.operation == .decode) return decoded(init.gpa, input, c, dictionary, set);
    const opts = native(c, &s.control);
    const limits = parallel(init, c, &s.parallel_profile);
    s.encoded_bound = if (c.use_dictionary_set) try zstd.encodedNativeParallelFrameBoundWithDictionarySet(input.len, opts, set, dictionary.?.id, limits) else if (dictionary) |dict| try zstd.encodedNativeParallelFrameBoundWithDictionary(input.len, opts, dict, limits) else try zstd.encodedNativeParallelFrameBound(input.len, opts, limits);
    // Caller buffers exist before the measured parallel operation. Failure
    // must preserve them; worker1 comparison is performed after publication.
    const wire = try encode(init.gpa, input, c, opts, limits, dictionary, set, s);
    errdefer init.gpa.free(wire);
    const restored = try decoded(init.gpa, wire, c, dictionary, set);
    defer init.gpa.free(restored);
    if (!std.mem.eql(u8, restored, input)) return error.RoundTripMismatch;
    s.self_decode_verified = true;
    if (wire.len > s.encoded_bound.?) return error.EncodedBoundExceeded;
    var worker1 = limits;
    worker1.worker_count = 1;
    worker1.profile = null;
    const baseline = try alloc(init.gpa, input, native(c, null), worker1, dictionary, set, c.use_dictionary_set);
    defer init.gpa.free(baseline);
    s.worker1_wire_equal = std.mem.eql(u8, baseline, wire);
    s.worker1_wire_bytes = baseline.len;
    s.worker1_wire_sha256 = digest(baseline);
    const baseline_path = try std.fmt.allocPrint(init.gpa, "{s}.worker1.zst", .{path});
    defer init.gpa.free(baseline_path);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = baseline_path, .data = baseline });
    const serial = if (dictionary) |dict| try zstd.encodeNativeFrameWithDictionaryAlloc(init.gpa, input, native(c, null), dict) else try zstd.encodeNativeFrameWithOptionsAlloc(init.gpa, input, native(c, null));
    defer init.gpa.free(serial.frame);
    const serial_restored = try decoded(init.gpa, serial.frame, c, dictionary, set);
    defer init.gpa.free(serial_restored);
    if (!std.mem.eql(u8, serial_restored, input)) return error.OriginalSerialContentsMismatch;
    s.original_serial_contents_verified = true;
    return wire;
}
fn encode(a: std.mem.Allocator, input: []const u8, c: Config, opts: zstd.NativeFrameOptions, limits: zstd.ParallelOptions, dictionary: ?zstd.NativeDictionary, set: zstd.NativeDictionarySet, s: *State) ![]u8 {
    if (c.api == .alloc) return alloc(a, input, opts, limits, dictionary, set, c.use_dictionary_set);
    if (c.api == .append) {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(a);
        try output.appendSlice(a, if (c.alias) input else "guard:");
        const prefix = try a.dupe(u8, output.items);
        defer a.free(prefix);
        const source = if (c.alias) output.items else input;
        const result = if (c.use_dictionary_set) zstd.encodeNativeParallelFrameAppendWithDictionarySet(a, &output, source, opts, set, dictionary.?.id, limits) else if (dictionary) |dict| zstd.encodeNativeParallelFrameAppendWithDictionary(a, &output, source, opts, dict, limits) else zstd.encodeNativeParallelFrameAppend(a, &output, source, opts, limits);
        const written = result catch |err| {
            s.caller_preserved_on_error = std.mem.eql(u8, prefix, output.items);
            if (!s.caller_preserved_on_error.?) return error.AppendChangedOnError;
            return err;
        };
        if (output.items.len != prefix.len + written or !std.mem.eql(u8, prefix, output.items[0..prefix.len])) return error.AppendPrefixChanged;
        return a.dupe(u8, output.items[prefix.len..]);
    }
    var capacity = s.encoded_bound.?;
    if (c.short_output or (c.exact_output and c.max_working_memory != 0)) {
        var reference = limits;
        reference.worker_count = 1;
        reference.profile = null;
        const exact = try alloc(a, input, native(c, null), reference, dictionary, set, c.use_dictionary_set);
        defer a.free(exact);
        capacity = exact.len - @intFromBool(c.short_output and exact.len != 0);
    }
    const buffer = try a.alloc(u8, @max(capacity, if (c.alias) input.len else 0) + 16);
    defer a.free(buffer);
    @memset(buffer, 0xa5);
    if (c.alias) @memcpy(buffer[8..][0..input.len], input);
    const original = try a.dupe(u8, buffer);
    defer a.free(original);
    const source = if (c.alias) buffer[8..][0..input.len] else input;
    const output = buffer[8..][0..capacity];
    const result = if (c.use_dictionary_set) zstd.encodeNativeParallelFrameIntoSliceWithDictionarySet(a, source, opts, set, dictionary.?.id, output, limits) else if (dictionary) |dict| zstd.encodeNativeParallelFrameIntoSliceWithDictionary(a, source, opts, dict, output, limits) else zstd.encodeNativeParallelFrameIntoSlice(a, source, opts, output, limits);
    const written = result catch |err| {
        s.caller_preserved_on_error = std.mem.eql(u8, original, buffer);
        if (!s.caller_preserved_on_error.?) return error.IntoChangedOnError;
        return err;
    };
    if (written > capacity) return error.InvalidOutputAccounting;
    for (buffer[0..8], original[0..8]) |actual, expected| if (actual != expected) return error.OutputGuardChanged;
    for (buffer[8 + written ..], original[8 + written ..]) |actual, expected| if (actual != expected) return error.OutputGuardChanged;
    return a.dupe(u8, output[0..written]);
}
fn digest(data: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(8 * 1024 * 1024));
}
