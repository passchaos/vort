//! Optional raw-round evidence. Hashing, medians and serialization run outside
//! the benchmark's timed encode calls; the CSV keeps its independent minima.
const std = @import("std");
const builtin = @import("builtin");
const vort = @import("vort");

pub const schema = "vort.codec_encode_samples";
pub const version: u8 = 1;

pub const Round = struct {
    index: usize,
    vort_first: bool,
    vort_ns: u64,
    reference_ns: u64,
    vort_mix: usize,
    reference_mix: usize,
};
pub const Summary = struct {
    vort_min_ns: u64,
    reference_min_ns: u64,
    vort_median_ns: u64,
    reference_median_ns: u64,
};
pub const ResolvedOptions = struct {
    content_checksum: bool,
    include_content_size: bool,
    window_log: ?u6,
    max_match_history_len: ?usize,
    max_total_working_memory: ?usize,
    selection: vort.ZstdNativeFrameSelection,
    block_size_max: usize,
    dictionary_id: u32,
    match_search_budget: usize,
    rep_beam_search: bool,
    strategy: vort.zstd.Strategy,
    fast_acceleration: ?u32,
    hq: ?vort.zstd.HqOptions,
    control_profile_enabled: bool,
    memory_profile_enabled: bool,

    pub fn capture(options: vort.ZstdNativeFrameOptions) !ResolvedOptions {
        return .{
            .content_checksum = options.content_checksum,
            .include_content_size = options.include_content_size,
            .window_log = options.window_log,
            .max_match_history_len = options.max_match_history_len,
            .max_total_working_memory = options.max_total_working_memory,
            .selection = options.selection,
            .block_size_max = options.block_size_max,
            .dictionary_id = options.dictionary_id,
            .match_search_budget = options.match_search_budget,
            .rep_beam_search = options.rep_beam_search,
            .strategy = options.strategy,
            .fast_acceleration = options.fast_acceleration,
            .hq = try options.effectiveHq(),
            .control_profile_enabled = options.control_profile != null,
            .memory_profile_enabled = options.memory_profile != null,
        };
    }
};
pub const WireHeader = struct {
    window_size: u64,
    content_size: ?u64,
    content_checksum: bool,
    dictionary_id: u32,
};

pub const Settings = struct {
    level: c_int,
    /// level_policy can arbitrate multiple block plans. Its public resolver
    /// describes the primary preset, not every internal candidate it may try.
    api: []const u8,
    requested_strategy: ?vort.zstd.Strategy,
    requested_fast_acceleration: ?u32,
    requested_native_selection: ?vort.ZstdNativeFrameSelection,
    resolved_primary: ResolvedOptions,
    internal_candidate_settings: []const u8,
    wire_header: WireHeader,
    reference: struct {
        api: []const u8 = "ZSTD_compress",
        level: c_int,
        internal_parameters: []const u8 = "library_default_level_preset",
        wire_header: WireHeader,
    },
};
pub const Wires = struct {
    vort_bytes: usize,
    reference_bytes: usize,
    vort_sha256: [64]u8,
    reference_sha256: [64]u8,
};
pub const Row = struct {
    case: []const u8,
    input_bytes: usize,
    input_sha256: [64]u8,
    iterations: usize,
    rounds: []Round,
    summary: Summary,
    settings: Settings,
    wires: Wires,
};
pub const Reference = struct {
    role: []const u8 = "zstd",
    requested_path: ?[]const u8,
    canonical_file_path: ?[:0]u8,
    file_sha256: ?[64]u8,
    version: []const u8,
    successful_open_argument: ?[]const u8,
    loaded_identity: ?[]const u8 = null,
    dependencies_verified: bool = false,

    /// Runtime.open() does not report which default search argument succeeded.
    /// Explicit arguments identify the requested file, without asserting the
    /// platform loader's resolved object or transitive dependency identities.
    pub fn capture(io: std.Io, allocator: std.mem.Allocator, requested_path: ?[]const u8, reference_version: []const u8) !Reference {
        const canonical = if (requested_path) |path|
            std.Io.Dir.cwd().realPathFileAlloc(io, path, allocator) catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                else => null,
            }
        else
            null;
        errdefer if (canonical) |path| allocator.free(path);
        return .{
            .requested_path = requested_path,
            .canonical_file_path = canonical,
            .file_sha256 = if (canonical) |path| try fileSha256(io, path) else null,
            .version = reference_version,
            .successful_open_argument = requested_path,
        };
    }

    pub fn deinit(self: Reference, allocator: std.mem.Allocator) void {
        if (self.canonical_file_path) |path| allocator.free(path);
    }
};

const FileIdentity = struct { device_major: u32, device_minor: u32, inode: u64 };

fn rejectSameTargets(left: []const u8, right: []const u8, left_file: ?FileIdentity, right_file: ?FileIdentity) error{ConflictingOutputPaths}!void {
    if (std.mem.eql(u8, left, right)) return error.ConflictingOutputPaths;
    if (left_file) |first| if (right_file) |second| {
        if (std.meta.eql(first, second)) return error.ConflictingOutputPaths;
    };
}

/// Run before provenance capture, reference loading or timed work. Resolve the
/// parent directory when a target does not yet exist, so `.`/`..` and symlinked
/// parents cannot name the same output through different argument strings.
pub fn validateOutputPaths(io: std.Io, allocator: std.mem.Allocator, csv_path: ?[]const u8, json_path: ?[]const u8) !void {
    const left = csv_path orelse return;
    const right = json_path orelse return;
    try rejectSameTargets(left, right, null, null);
    const left_target = try canonicalOutputPath(io, allocator, left);
    defer if (left_target) |path| allocator.free(path);
    const right_target = try canonicalOutputPath(io, allocator, right);
    defer if (right_target) |path| allocator.free(path);
    if (left_target) |first| if (right_target) |second| {
        try rejectSameTargets(first, second, existingFileIdentity(first), existingFileIdentity(second));
        return;
    };
    // If a directory cannot be resolved, still reject simple lexical aliases.
    // Distinct unresolvable paths retain their normal eventual write errors.
    const left_normalized = try std.fs.path.resolve(allocator, &.{left});
    defer allocator.free(left_normalized);
    const right_normalized = try std.fs.path.resolve(allocator, &.{right});
    defer allocator.free(right_normalized);
    try rejectSameTargets(left_normalized, right_normalized, null, null);
}

fn canonicalOutputPath(io: std.Io, allocator: std.mem.Allocator, path: []const u8) !?[:0]u8 {
    const directory = std.Io.Dir.cwd();
    if (directory.realPathFileAlloc(io, path, allocator)) |canonical| return canonical else |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => {},
    }
    const parent = std.fs.path.dirname(path) orelse ".";
    const canonical_parent = directory.realPathFileAlloc(io, parent, allocator) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return null,
    };
    defer allocator.free(canonical_parent);
    const joined = try std.fs.path.join(allocator, &.{ canonical_parent, std.fs.path.basename(path) });
    defer allocator.free(joined);
    return try allocator.dupeZ(u8, joined);
}

fn existingFileIdentity(path: [:0]const u8) ?FileIdentity {
    if (comptime builtin.os.tag != .linux) return null;
    const linux = std.os.linux;
    var stat = std.mem.zeroes(linux.Statx);
    if (linux.errno(linux.statx(linux.AT.FDCWD, path, 0, .{ .INO = true }, &stat)) != .SUCCESS or !stat.mask.INO) return null;
    return .{ .device_major = stat.dev_major, .device_minor = stat.dev_minor, .inode = stat.ino };
}

pub const Report = struct {
    rows: std.ArrayList(Row) = .empty,

    pub fn deinit(self: *Report, allocator: std.mem.Allocator) void {
        for (self.rows.items) |row| allocator.free(row.rounds);
        self.rows.deinit(allocator);
        self.* = .{};
    }

    pub fn append(self: *Report, allocator: std.mem.Allocator, row: Row) !void {
        const rounds = try allocator.dupe(Round, row.rounds);
        errdefer allocator.free(rounds);
        var owned = row;
        owned.rounds = rounds;
        owned.summary = try summarize(allocator, rounds);
        try self.rows.append(allocator, owned);
    }

    pub fn write(self: *const Report, writer: *std.Io.Writer, reference: Reference, provenance: anytype) !void {
        try writer.writeAll("{\"schema\":\"" ++ schema ++ "\",\"version\":1,\"codec\":\"zstd\",\"rows\":[");
        for (self.rows.items, 0..) |row, index| {
            if (index != 0) try writer.writeByte(',');
            try std.json.Stringify.value(.{
                .case = row.case,
                .input_bytes = row.input_bytes,
                .input_sha256 = row.input_sha256[0..],
                .iterations = row.iterations,
                .rounds = row.rounds,
                .summary = row.summary,
                .settings = row.settings,
                .wires = .{
                    .vort_bytes = row.wires.vort_bytes,
                    .reference_bytes = row.wires.reference_bytes,
                    .vort_sha256 = row.wires.vort_sha256[0..],
                    .reference_sha256 = row.wires.reference_sha256[0..],
                },
            }, .{}, writer);
        }
        try writer.writeAll("],\"references\":[");
        try std.json.Stringify.value(.{
            .role = reference.role,
            .requested_path = reference.requested_path,
            .canonical_file_path = reference.canonical_file_path,
            .file_sha256 = if (reference.file_sha256) |hash| hash[0..] else null,
            .version = reference.version,
            .successful_open_argument = reference.successful_open_argument,
            .loaded_identity = reference.loaded_identity,
            .dependencies_verified = reference.dependencies_verified,
        }, .{}, writer);
        try writer.writeAll("],\"provenance\":");
        try std.json.Stringify.value(provenance, .{}, writer);
        try writer.writeAll("}\n");
    }
};

pub fn summarize(allocator: std.mem.Allocator, rounds: []const Round) !Summary {
    if (rounds.len == 0) return error.InvalidBlockPlan;
    const value_count = std.math.mul(usize, rounds.len, 2) catch return error.IntegerOverflow;
    const values = try allocator.alloc(u64, value_count);
    defer allocator.free(values);
    const vort_values = values[0..rounds.len];
    const reference_values = values[rounds.len..];
    for (rounds, 0..) |round, index| {
        vort_values[index] = round.vort_ns;
        reference_values[index] = round.reference_ns;
    }
    std.mem.sort(u64, vort_values, {}, std.sort.asc(u64));
    std.mem.sort(u64, reference_values, {}, std.sort.asc(u64));
    return .{
        .vort_min_ns = vort_values[0],
        .reference_min_ns = reference_values[0],
        .vort_median_ns = median(vort_values),
        .reference_median_ns = median(reference_values),
    };
}

/// Even-sized samples use the floor of their two central values' mean.
fn median(sorted: []const u64) u64 {
    const middle = sorted.len / 2;
    if (sorted.len & 1 != 0) return sorted[middle];
    const low = sorted[middle - 1];
    return low + (sorted[middle] - low) / 2;
}

fn fileSha256(io: std.Io, path: []const u8) ![64]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var reader_buffer: [16 * 1024]u8 = undefined;
    var reader = file.readerStreaming(io, &reader_buffer);
    var hash_buffer: [16 * 1024]u8 = undefined;
    var hashing: std.Io.Writer.Hashing(std.crypto.hash.sha2.Sha256) = .init(&hash_buffer);
    _ = try reader.interface.streamRemaining(&hashing.writer);
    try hashing.writer.flush();
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    hashing.hasher.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

test "Zstd encode sample summaries preserve paired minima and overflow-safe medians" {
    const rounds = [_]Round{
        .{ .index = 0, .vort_first = true, .vort_ns = 8, .reference_ns = 1, .vort_mix = 11, .reference_mix = 17 },
        .{ .index = 1, .vort_first = false, .vort_ns = 2, .reference_ns = 9, .vort_mix = 11, .reference_mix = 17 },
        .{ .index = 2, .vort_first = true, .vort_ns = 4, .reference_ns = 3, .vort_mix = 11, .reference_mix = 17 },
        .{ .index = 3, .vort_first = false, .vort_ns = 6, .reference_ns = 7, .vort_mix = 11, .reference_mix = 17 },
    };
    const summary = try summarize(std.testing.allocator, &rounds);
    try std.testing.expectEqual(Summary{ .vort_min_ns = 2, .reference_min_ns = 1, .vort_median_ns = 5, .reference_median_ns = 5 }, summary);
    try std.testing.expectEqual(@as(u64, std.math.maxInt(u64) - 1), median(&.{ std.math.maxInt(u64) - 2, std.math.maxInt(u64) }));
    try std.testing.expectEqual(@as(u64, 9), median(&.{ 1, 9, 13 }));
    try std.testing.expectError(error.InvalidBlockPlan, summarize(std.testing.allocator, &.{}));
}

test "Zstd encode samples reject equal output targets and hard link identities" {
    try std.testing.expectError(error.ConflictingOutputPaths, rejectSameTargets("out", "out", null, null));
    const same: FileIdentity = .{ .device_major = 8, .device_minor = 1, .inode = 41 };
    try std.testing.expectError(error.ConflictingOutputPaths, rejectSameTargets("first", "second", same, same));
    try rejectSameTargets("first", "second", same, .{ .device_major = 8, .device_minor = 2, .inode = 41 });
    try rejectSameTargets("first", "second", same, .{ .device_major = 8, .device_minor = 1, .inode = 42 });
    try rejectSameTargets("first", "second", null, null);
}

test "Zstd encode samples lexical output aliases preserve distinct destinations" {
    const allocator = std.testing.allocator;
    const first = try std.fs.path.resolve(allocator, &.{"dir/./out"});
    defer allocator.free(first);
    const alias = try std.fs.path.resolve(allocator, &.{"dir/sub/../out"});
    defer allocator.free(alias);
    const distinct = try std.fs.path.resolve(allocator, &.{"dir/other"});
    defer allocator.free(distinct);
    try std.testing.expectError(error.ConflictingOutputPaths, rejectSameTargets(first, alias, null, null));
    try rejectSameTargets(first, distinct, null, null);
}
