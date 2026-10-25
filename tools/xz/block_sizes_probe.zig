//! Exact XZ declared Block size QA; public file-driven encoding and decoding.
const std = @import("std");
const builtin = @import("builtin");
const xz = @import("xz");

const Config = struct {
    operation: enum { encode, decode } = .encode,
    api: enum { alloc, append, into } = .alloc,
    payload: enum { compressed, stored } = .compressed,
    parallel: bool = true,
    lazy_entry: bool = false,
    parser: xz.Parser = .greedy,
    include_block_sizes: bool = true,
    omit_block_sizes_option: bool = false,
    preset: ?u32 = null,
    extreme: bool = false,
    check: xz.Check = .crc64,
    block_size: usize = 4096,
    dictionary_size: usize = 4096,
    chunk_size: usize = 4096,
    properties: xz.Properties = .{},
    filters: []const xz.Filter = &.{},
    match_options: ?xz.MatchOptions = null,
    worker_count: usize = 3,
    max_inflight_blocks: usize = 4,
    max_inflight_bytes: usize = 4 * 1024 * 1024,
    max_working_memory: usize = 256 * 1024 * 1024,
    alias: bool = false,
    short_output: bool = false,
    compare_serial_incremental: bool = false,
    max_output_len: usize = 2 * 1024 * 1024,
};
const State = struct {
    profile: xz.ParallelProfile = .{},
    serial_bytes: ?usize = null,
    serial_sha256: ?[64]u8 = null,
    serial_wire_equal: bool = false,
    unsized_bytes: ?usize = null,
    unsized_sha256: ?[64]u8 = null,
    default_false_wire_equal: ?bool = null,
    serial_incremental_equal: ?bool = null,
    self_decode_verified: bool = false,
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
    const configuration = try read(init, config_path);
    defer init.gpa.free(configuration);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, configuration, .{});
    defer parsed.deinit();
    const c = parsed.value;
    var state: State = .{};
    var failure: ?[]const u8 = null;
    const input_sha = digest(input);
    const output: ?[]u8 = operation(init, input, output_path, c, &state) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (output) |bytes| init.gpa.free(bytes);
    const input_after = digest(input);
    if (!std.mem.eql(u8, &input_sha, &input_after)) return error.BorrowedInputChanged;
    const output_sha: ?[64]u8 = if (output) |bytes| digest(bytes) else null;
    if (output) |bytes| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.xz.block-sizes-probe.v1",
        .config = c,
        .@"error" = failure,
        .input_bytes = input.len,
        .input_sha256 = input_sha[0..],
        .output_bytes = if (output) |bytes| bytes.len else 0,
        .output_sha256 = if (output_sha) |*hash| hash[0..] else null,
        .serial_bytes = state.serial_bytes,
        .serial_sha256 = if (state.serial_sha256) |*hash| hash[0..] else null,
        .serial_wire_equal = state.serial_wire_equal,
        .unsized_bytes = state.unsized_bytes,
        .unsized_sha256 = if (state.unsized_sha256) |*hash| hash[0..] else null,
        .default_false_wire_equal = state.default_false_wire_equal,
        .serial_incremental_equal = state.serial_incremental_equal,
        .parallel_profile = state.profile,
        .self_decode_verified = state.self_decode_verified,
        .caller_guards_verified = state.caller_guards_verified,
        .caller_preserved_on_error = state.caller_preserved_on_error,
        .borrowed_input_verified = true,
        .target = @tagName(builtin.cpu.arch),
        .cpu_model = builtin.cpu.model.name,
        .build_mode = @tagName(builtin.mode),
        .zig_version = builtin.zig_version_string,
        .scope = "exact optional compressed/uncompressed Block Header sizes; nullable parallel encoding and serial incremental",
    }, .{});
    defer init.gpa.free(json);
    try std.Io.File.stdout().writeStreamingAll(init.io, json);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}

fn options(c: Config) !xz.EncodeOptions {
    var resolved = if (c.preset) |level| try xz.EncodeOptions.fromPreset(level, c.extreme) else xz.EncodeOptions{ .dictionary_size = c.dictionary_size, .parser = c.parser, .properties = c.properties, .match_options = c.match_options };
    resolved.check = c.check;
    resolved.block_size = c.block_size;
    resolved.chunk_size = c.chunk_size;
    resolved.filters = c.filters;
    if (!c.omit_block_sizes_option) resolved.include_block_sizes = c.include_block_sizes;
    return resolved;
}
fn serialAlloc(a: std.mem.Allocator, input: []const u8, c: Config, opts: xz.EncodeOptions) ![]u8 {
    if (c.payload == .stored) return xz.encodeStoredAlloc(a, input, opts);
    if (c.lazy_entry) return xz.encodeLazyAlloc(a, input, opts);
    return xz.encodeAlloc(a, input, opts);
}
fn operation(init: std.process.Init, input: []const u8, output_path: []const u8, c: Config, s: *State) ![]u8 {
    if (c.operation == .decode) return xz.decodeAllocLimited(init.gpa, input, c.max_output_len);
    const serial_options = try options(c);
    const serial = try serialAlloc(init.gpa, input, c, serial_options);
    defer init.gpa.free(serial);
    s.serial_bytes = serial.len;
    s.serial_sha256 = digest(serial);
    const serial_path = try std.fmt.allocPrint(init.gpa, "{s}.serial.xz", .{output_path});
    defer init.gpa.free(serial_path);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = serial_path, .data = serial });
    var unsized_options = serial_options;
    unsized_options.include_block_sizes = false;
    const unsized = try serialAlloc(init.gpa, input, c, unsized_options);
    defer init.gpa.free(unsized);
    s.unsized_bytes = unsized.len;
    s.unsized_sha256 = digest(unsized);
    const unsized_path = try std.fmt.allocPrint(init.gpa, "{s}.unsized.xz", .{output_path});
    defer init.gpa.free(unsized_path);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = unsized_path, .data = unsized });
    if (!c.include_block_sizes) s.default_false_wire_equal = std.mem.eql(u8, serial, unsized);
    var selected = serial_options;
    if (c.parallel) selected.parallel = .{ .io = init.io, .worker_count = c.worker_count, .max_inflight_blocks = c.max_inflight_blocks, .max_inflight_bytes = c.max_inflight_bytes, .max_working_memory = c.max_working_memory, .profile = &s.profile };
    const actual = try encode(init.gpa, input, serial.len, c, selected, s);
    errdefer init.gpa.free(actual);
    s.serial_wire_equal = std.mem.eql(u8, serial, actual);
    const restored = try xz.decodeAllocLimited(init.gpa, actual, input.len);
    defer init.gpa.free(restored);
    if (!std.mem.eql(u8, input, restored)) return error.RoundTripMismatch;
    s.self_decode_verified = true;
    if (c.compare_serial_incremental) {
        const streamed = try serialIncremental(init.gpa, input, c, serial_options);
        defer init.gpa.free(streamed);
        if (!std.mem.eql(u8, streamed, serial)) return error.SerialIncrementalWireMismatch;
        s.serial_incremental_equal = true;
    }
    return actual;
}
fn encode(a: std.mem.Allocator, input: []const u8, exact_len: usize, c: Config, opts: xz.EncodeOptions, s: *State) ![]u8 {
    if (c.api == .alloc) return serialAlloc(a, input, c, opts);
    if (c.api == .append) {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(a);
        try output.appendSlice(a, if (c.alias) input else "guard:");
        const prefix_len = output.items.len;
        const prefix = try a.dupe(u8, output.items);
        defer a.free(prefix);
        const source = if (c.alias) output.items else input;
        const result = if (c.payload == .stored) xz.encodeStoredAppend(a, &output, source, opts) else if (c.lazy_entry) xz.encodeLazyAppend(a, &output, source, opts) else xz.encodeAppend(a, &output, source, opts);
        const written = result catch |err| {
            s.caller_preserved_on_error = std.mem.eql(u8, prefix, output.items);
            if (!s.caller_preserved_on_error.?) return error.AppendChangedOnError;
            return err;
        };
        if (output.items.len != prefix_len + written or !std.mem.eql(u8, prefix, output.items[0..prefix_len])) return error.AppendPrefixChanged;
        return a.dupe(u8, output.items[prefix_len..]);
    }
    const capacity = exact_len - @intFromBool(c.short_output and exact_len != 0);
    const buffer = try a.alloc(u8, @max(capacity, if (c.alias) input.len else 0) + 16);
    defer a.free(buffer);
    @memset(buffer, 0xa5);
    if (c.alias) @memcpy(buffer[8..][0..input.len], input);
    const original = try a.dupe(u8, buffer);
    defer a.free(original);
    const source = if (c.alias) buffer[8..][0..input.len] else input;
    const destination = buffer[8..][0..capacity];
    const result = if (c.payload == .stored) xz.encodeStoredInto(a, source, destination, opts) else if (c.lazy_entry) xz.encodeLazyInto(a, source, destination, opts) else xz.encodeInto(a, source, destination, opts);
    const written = result catch |err| {
        s.caller_preserved_on_error = std.mem.eql(u8, original, buffer);
        if (!s.caller_preserved_on_error.?) return error.IntoChangedOnError;
        return err;
    };
    if (written > capacity) return error.InvalidOutputAccounting;
    for (buffer[0..8], original[0..8]) |byte, expected| if (byte != expected) return error.OutputGuardChanged;
    for (buffer[8 + written ..], original[8 + written ..]) |byte, expected| if (byte != expected) return error.OutputGuardChanged;
    return a.dupe(u8, destination[0..written]);
}
fn serialIncremental(a: std.mem.Allocator, input: []const u8, c: Config, opts: xz.EncodeOptions) ![]u8 {
    var encoder = try xz.IncrementalEncoder.initExactSize(a, .{ .check = opts.check, .block_size = opts.block_size, .include_block_sizes = opts.include_block_sizes, .dictionary_size = opts.dictionary_size, .chunk_size = opts.chunk_size, .parser = if (c.lazy_entry) .lazy else opts.parser, .properties = opts.properties, .match_options = opts.match_options, .filters = opts.filters, .payload_encoding = if (c.payload == .stored) .stored else .compressed }, input.len);
    defer encoder.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(a);
    var offset: usize = 0;
    var finishing = false;
    var buffer: [4112]u8 = undefined;
    var step: usize = 0;
    while (step < input.len * 8 + 8192) : (step += 1) {
        if (offset == input.len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        const end = offset + @min(input.len - offset, if (step % 3 == 0) @as(usize, 0) else 4096);
        const capacity: usize = if (step % 5 == 0) 0 else 4096;
        @memset(&buffer, 0xa5);
        const result = try encoder.step(input[offset..end], buffer[8..][0..capacity]);
        if (result.progress.input_read > end - offset or result.progress.output_written > capacity) return error.InvalidProgress;
        offset += result.progress.input_read;
        try output.appendSlice(a, buffer[8..][0..result.progress.output_written]);
        for (buffer[0..8]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
        for (buffer[8 + result.progress.output_written ..]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
        if (result.status == .done) {
            if (offset != input.len) return error.InvalidProgress;
            return output.toOwnedSlice(a);
        }
    }
    return error.SerialIncrementalDidNotFinish;
}
fn digest(input: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(input, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(4 * 1024 * 1024));
}
