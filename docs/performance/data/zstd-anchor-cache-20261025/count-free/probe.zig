const std = @import("std");
const zstd = @import("vort_zstd");
const provenance = @import("benchmark_provenance");

const rounds = 5;
const Case = struct { name: []const u8, path: []const u8 };
const cases = [_]Case{
    .{ .name = "XML64K", .path = "/tmp/vort-wide-bit-final-20261025/next-performance-audit/corpus-preparation/silesia-xml-65536.bin" },
    .{ .name = "MR64K", .path = "/tmp/vort-wide-bit-final-20261025/next-performance-audit/corpus-preparation/silesia-mr-65536.bin" },
    .{ .name = "source64K", .path = "/tmp/vort-wide-bit-final-20261025/next-performance-audit/corpus-preparation/brotli-source-65536.bin" },
};
const Round = struct { index: usize, baseline_first: bool, baseline_ns: u64, cached_ns: u64 };
const Row = struct {
    case: []const u8,
    path: []const u8,
    input_bytes: usize,
    input_sha256: [64]u8,
    candidate_available: bool,
    baseline_wire_bytes: usize,
    cached_wire_bytes: usize,
    baseline_wire_sha256: [64]u8,
    cached_wire_sha256: [64]u8,
    wire_equal_before_timing: bool,
    every_timed_wire_equal: bool,
    rounds: [rounds]Round,
    baseline_min_ns: u64,
    cached_min_ns: u64,
    baseline_median_ns: u64,
    cached_median_ns: u64,
};

fn hash(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn median(values: *[rounds]u64) u64 {
    std.mem.sort(u64, values, {}, std.sort.asc(u64));
    return values[rounds / 2];
}

fn readCase(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const stat = try file.stat(io);
    if (stat.size != 65536) return error.InvalidInputLength;
    const input = try allocator.alloc(u8, 65536);
    errdefer allocator.free(input);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &buffer);
    if (try reader.interface.readSliceShort(input) != input.len) return error.InputTooSmall;
    return input;
}

fn timed(comptime enabled: bool, io: std.Io, allocator: std.mem.Allocator, input: []const u8, expected_wire: []const u8, expected_available: bool) !u64 {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    const start = std.Io.Clock.awake.now(io);
    const available = try zstd.benchmarkUnprofiledAnchorCandidate(enabled, allocator, &out, input);
    const elapsed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    // Validation and output cleanup are outside this single candidate timer.
    if (available != expected_available or !std.mem.eql(u8, out.items, expected_wire)) return error.WireMismatch;
    return if (elapsed <= 0) 0 else @intCast(elapsed);
}

fn runCase(io: std.Io, allocator: std.mem.Allocator, case: Case) !Row {
    const input = try readCase(io, allocator, case.path);
    defer allocator.free(input);
    var baseline: std.ArrayList(u8) = .empty;
    defer baseline.deinit(allocator);
    var cached: std.ArrayList(u8) = .empty;
    defer cached.deinit(allocator);
    const available = try zstd.benchmarkUnprofiledAnchorCandidate(false, allocator, &baseline, input);
    const cached_available = try zstd.benchmarkUnprofiledAnchorCandidate(true, allocator, &cached, input);
    if (available != cached_available or !std.mem.eql(u8, baseline.items, cached.items)) return error.WireMismatch;
    // Both candidate wires and hashes are recorded before the first timer.
    const input_sha = hash(input);
    const baseline_sha = hash(baseline.items);
    const cached_sha = hash(cached.items);
    var raw: [rounds]Round = undefined;
    var baseline_ns: [rounds]u64 = undefined;
    var cached_ns: [rounds]u64 = undefined;
    for (&raw, 0..) |*round, index| {
        const baseline_first = index & 1 == 0;
        const first = if (baseline_first)
            try timed(false, io, allocator, input, baseline.items, available)
        else
            try timed(true, io, allocator, input, baseline.items, available);
        const second = if (baseline_first)
            try timed(true, io, allocator, input, baseline.items, available)
        else
            try timed(false, io, allocator, input, baseline.items, available);
        baseline_ns[index] = if (baseline_first) first else second;
        cached_ns[index] = if (baseline_first) second else first;
        round.* = .{ .index = index, .baseline_first = baseline_first, .baseline_ns = baseline_ns[index], .cached_ns = cached_ns[index] };
    }
    return .{
        .case = case.name,
        .path = case.path,
        .input_bytes = input.len,
        .input_sha256 = input_sha,
        .candidate_available = available,
        .baseline_wire_bytes = baseline.items.len,
        .cached_wire_bytes = cached.items.len,
        .baseline_wire_sha256 = baseline_sha,
        .cached_wire_sha256 = cached_sha,
        .wire_equal_before_timing = true,
        .every_timed_wire_equal = true,
        .rounds = raw,
        .baseline_min_ns = std.mem.min(u64, &baseline_ns),
        .cached_min_ns = std.mem.min(u64, &cached_ns),
        .baseline_median_ns = median(&baseline_ns),
        .cached_median_ns = median(&cached_ns),
    };
}

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    // The build stage must not accidentally enter a timer. The parent decides
    // when compiler activity has ended and authorizes a later explicit run.
    const requested = args.next() orelse return error.TimingAuthorizationRequired;
    if (!std.mem.eql(u8, requested, "--run") or args.next() != null) return error.TimingAuthorizationRequired;
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    var rows: [cases.len]Row = undefined;
    for (cases, 0..) |case, index| rows[index] = try runCase(init.io, init.gpa, case);
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.zstd.anchor-cache-unprofiled.v1",
        .provenance = info,
        .profile_work = false,
        .profile_argument = "null",
        .anchor_work_observed = false,
        .purpose = "isolate unprofiled candidate-stage cache overhead and benefit",
        .round_count = rounds,
        .timer_includes = "candidate allocation and emission; cached hash/length allocation, preparation and deallocation",
        .timer_excludes = "input reads, hashing, validation, JSON, output-buffer deallocation",
        .premeasurement = "one untimed baseline and cached candidate with exact wire equality",
        .rows = rows,
    }, .{ .whitespace = .indent_2 });
    defer init.gpa.free(json);
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
