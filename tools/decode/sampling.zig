//! Run shape, order, and raw sample helpers shared by the decoder probe/tests.
const std = @import("std");
const perf = @import("perf_group.zig");

pub const Codec = enum { deflate, zstd, brotli };
pub const Lifecycle = enum { cold, prepared };
pub const Implementation = enum { vort, reference };
pub const Pair = struct {
    pair_id: usize,
    first: Implementation,
    vort_ns: u64,
    reference_ns: u64,
    vort_mix: u64,
    reference_mix: u64,
    vort_counters: ?perf.Counts = null,
};
pub const Sample = struct { ns: u64, mix: u64, counters: ?perf.Counts = null };

pub const GuardedBuffer = struct {
    pub const guard_bytes = 64;
    const sentinel = 0xc7;
    storage: []align(64) u8,
    data: []u8,

    pub fn init(allocator: std.mem.Allocator, len: usize) !GuardedBuffer {
        const total = try std.math.add(usize, len, 2 * guard_bytes);
        const storage = try allocator.alignedAlloc(u8, .@"64", total);
        @memset(storage, sentinel);
        return .{ .storage = storage, .data = storage[guard_bytes .. guard_bytes + len] };
    }

    pub fn deinit(self: GuardedBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.storage);
    }

    pub fn validate(self: GuardedBuffer) !void {
        for (self.storage[0..guard_bytes]) |byte| if (byte != sentinel) return error.GuardCorrupted;
        for (self.storage[guard_bytes + self.data.len ..]) |byte| if (byte != sentinel) return error.GuardCorrupted;
    }
};

pub fn firstForPair(pair_id: usize) Implementation {
    return if (pair_id % 2 == 0) .vort else .reference;
}

pub fn makePair(pair_id: usize, vort: Sample, reference: Sample) Pair {
    return .{
        .pair_id = pair_id,
        .first = firstForPair(pair_id),
        .vort_ns = vort.ns,
        .reference_ns = reference.ns,
        .vort_mix = vort.mix,
        .reference_mix = reference.mix,
        .vort_counters = vort.counters,
    };
}

/// Includes every observation; even-sized medians average the middle two.
pub fn median(allocator: std.mem.Allocator, pairs: []const Pair, implementation: Implementation) !f64 {
    if (pairs.len == 0) return error.EmptySamples;
    const values = try allocator.alloc(u64, pairs.len);
    defer allocator.free(values);
    for (pairs, values) |pair, *value|
        value.* = if (implementation == .vort) pair.vort_ns else pair.reference_ns;
    std.mem.sort(u64, values, {}, std.sort.asc(u64));
    const middle = values.len / 2;
    const right: f64 = @floatFromInt(values[middle]);
    if (values.len % 2 == 1) return right;
    const left: f64 = @floatFromInt(values[middle - 1]);
    return left / 2 + right / 2;
}

pub const Options = struct {
    codec: Codec,
    input_path: []const u8,
    encoded_path: []const u8,
    iterations: usize,
    rounds: usize,
    warmup: usize,
    lifecycle: Lifecycle,
    reference: ?[]const u8,
    reference_version: ?[]const u8,
    brotli_encoder: ?[]const u8,
    brotli_decoder: ?[]const u8,
    brotli_common: ?[]const u8,
    output_path: ?[]const u8,
    perf_group: ?perf.Kind = null,
};

/// Arguments exclude argv[0]. Every timing/lifecycle setting is explicit.
pub fn parseOptions(arguments: []const []const u8) !Options {
    const fields = enum { codec, input, encoded_input, iterations, rounds, warmup, lifecycle, reference, reference_version, brotli_encoder, brotli_decoder, brotli_common, output, perf_group };
    var seen = std.EnumSet(fields).initEmpty();
    var codec: ?Codec = null;
    var input: ?[]const u8 = null;
    var encoded: ?[]const u8 = null;
    var iterations: ?usize = null;
    var rounds: ?usize = null;
    var warmup: ?usize = null;
    var lifecycle: ?Lifecycle = null;
    var reference: ?[]const u8 = null;
    var version: ?[]const u8 = null;
    var encoder: ?[]const u8 = null;
    var decoder: ?[]const u8 = null;
    var common: ?[]const u8 = null;
    var output: ?[]const u8 = null;
    var perf_group: ?perf.Kind = null;
    var i: usize = 0;
    while (i < arguments.len) : (i += 2) {
        const flag = arguments[i];
        if (!std.mem.startsWith(u8, flag, "--")) return error.UnknownOption;
        var field_name_buffer: [32]u8 = undefined;
        const raw_name = flag[2..];
        if (raw_name.len > field_name_buffer.len) return error.UnknownOption;
        const name = field_name_buffer[0..raw_name.len];
        for (raw_name, name) |byte, *translated| translated.* = if (byte == '-') '_' else byte;
        const field = std.meta.stringToEnum(fields, name) orelse return error.UnknownOption;
        if (seen.contains(field)) return error.DuplicateOption;
        seen.insert(field);
        if (i + 1 >= arguments.len) return error.MissingOptionValue;
        const value = arguments[i + 1];
        if (value.len == 0 or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidOptionValue;
        switch (field) {
            .codec => codec = std.meta.stringToEnum(Codec, value) orelse return error.InvalidCodec,
            .input => input = value,
            .encoded_input => encoded = value,
            .iterations => iterations = std.fmt.parseInt(usize, value, 10) catch return error.InvalidIterations,
            .rounds => rounds = std.fmt.parseInt(usize, value, 10) catch return error.InvalidRounds,
            .warmup => warmup = std.fmt.parseInt(usize, value, 10) catch return error.InvalidWarmup,
            .lifecycle => lifecycle = std.meta.stringToEnum(Lifecycle, value) orelse return error.InvalidLifecycle,
            .reference => reference = value,
            .reference_version => version = value,
            .brotli_encoder => encoder = value,
            .brotli_decoder => decoder = value,
            .brotli_common => common = value,
            .output => output = value,
            .perf_group => perf_group = if (std.mem.eql(u8, value, "branches"))
                .branches
            else if (std.mem.eql(u8, value, "branch-misses"))
                .branch_misses
            else
                return error.InvalidPerfGroup,
        }
    }
    const selected_codec = codec orelse return error.MissingCodec;
    const selected_iterations = iterations orelse return error.MissingIterations;
    const selected_rounds = rounds orelse return error.MissingRounds;
    const selected_warmup = warmup orelse return error.MissingWarmup;
    const selected_lifecycle = lifecycle orelse return error.MissingLifecycle;
    if (selected_iterations == 0) return error.InvalidIterations;
    if (selected_rounds < 2 or selected_rounds % 2 != 0) return error.InvalidRounds;
    if (selected_warmup % 2 != 0) return error.InvalidWarmup;
    _ = std.math.add(usize, selected_warmup, selected_rounds) catch return error.InvalidRounds;
    switch (selected_codec) {
        .deflate, .zstd => {
            try validateLibraryPath(reference orelse return error.MissingReference);
            if (encoder != null or decoder != null or common != null) return error.UnexpectedReferenceOption;
            if (selected_codec == .deflate) {
                if (version == null) return error.MissingReferenceVersion;
            } else if (version != null) return error.UnexpectedReferenceVersion;
        },
        .brotli => {
            if (selected_lifecycle == .prepared) return error.UnsupportedPreparedLifecycle;
            if (reference != null or version != null) return error.UnexpectedReferenceOption;
            try validateLibraryPath(encoder orelse return error.MissingBrotliEncoder);
            try validateLibraryPath(decoder orelse return error.MissingBrotliDecoder);
            try validateLibraryPath(common orelse return error.MissingBrotliCommon);
        },
    }
    return .{
        .codec = selected_codec,
        .input_path = input orelse return error.MissingInput,
        .encoded_path = encoded orelse return error.MissingEncodedInput,
        .iterations = selected_iterations,
        .rounds = selected_rounds,
        .warmup = selected_warmup,
        .lifecycle = selected_lifecycle,
        .reference = reference,
        .reference_version = version,
        .brotli_encoder = encoder,
        .brotli_decoder = decoder,
        .brotli_common = common,
        .output_path = output,
        .perf_group = perf_group,
    };
}

fn validateLibraryPath(path: []const u8) !void {
    if (!std.fs.path.isAbsolute(path)) return error.ReferencePathMustBeAbsolute;
}

/// Protect frozen fixtures and binaries before decoding and again before
/// publication. Canonical paths catch symlinks; device/inode pairs catch
/// distinct hardlink names. An absent output is a permitted new artifact.
pub fn rejectOutputAliases(io: std.Io, allocator: std.mem.Allocator, output_path: ?[]const u8, protected_paths: []const []const u8) !void {
    const output = output_path orelse return;
    const canonical_output = std.Io.Dir.cwd().realPathFileAlloc(io, output, allocator) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer allocator.free(canonical_output);
    const output_identity = try fileIdentity(canonical_output);
    for (protected_paths) |path| {
        const canonical_protected = try std.Io.Dir.cwd().realPathFileAlloc(io, path, allocator);
        defer allocator.free(canonical_protected);
        if (std.mem.eql(u8, canonical_output, canonical_protected)) return error.OutputAliasesProtectedFile;
        const protected_identity = try fileIdentity(canonical_protected);
        if (std.meta.eql(output_identity, protected_identity)) return error.OutputAliasesProtectedFile;
    }
}

const FileIdentity = struct { inode: u64, device_major: u32, device_minor: u32 };

fn fileIdentity(canonical_path: [:0]const u8) !FileIdentity {
    const linux = std.os.linux;
    var stat: linux.Statx = undefined;
    switch (linux.errno(linux.statx(linux.AT.FDCWD, canonical_path.ptr, 0, .{ .INO = true }, &stat))) {
        .SUCCESS => {},
        else => return error.FileIdentityUnavailable,
    }
    if (!stat.mask.INO) return error.FileIdentityUnavailable;
    return .{ .inode = stat.ino, .device_major = stat.dev_major, .device_minor = stat.dev_minor };
}

/// Preserve actual Linux loader paths, including deleted suffixes and spaces.
/// Each ELF shared object has several mappings; return sorted unique paths.
pub fn mappedLibrariesAlloc(allocator: std.mem.Allocator, maps: []const u8) ![][]const u8 {
    var paths: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    var lines = std.mem.splitScalar(u8, maps, '\n');
    while (lines.next()) |line| {
        const path_start = std.mem.indexOfScalar(u8, line, '/') orelse continue;
        const path = std.mem.trim(u8, line[path_start..], " \t\r");
        if (std.mem.indexOf(u8, std.fs.path.basename(path), ".so") == null) continue;
        var duplicate = false;
        for (paths.items) |existing| {
            if (std.mem.eql(u8, existing, path)) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) {
            const copy = try allocator.dupe(u8, path);
            errdefer allocator.free(copy);
            try paths.append(allocator, copy);
        }
    }
    std.mem.sort([]const u8, paths.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);
    return paths.toOwnedSlice(allocator);
}
