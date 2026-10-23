const std = @import("std");
const xz = @import("xz");
const Workspace = xz.DecodeWorkspace;
const Config = struct {
    concatenated: bool = false,
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = 65536,
    max_working_memory: usize = std.math.maxInt(usize),
    short_output: bool = false,
    alias: bool = false,
    borrowed_alias: bool = false,
    check_limits: bool = false,
    oom: bool = false,
    expect_failure: bool = false,
    expected_error: ?[]const u8 = null,
};
const Report = struct {
    input_bytes: usize,
    output_written: usize = 0,
    prepared_output_len: usize = 0,
    @"error": ?[]const u8 = null,
    caller_unchanged: bool = false,
    legacy_into_verified: bool = false,
    size_verified: bool = false,
    inspect_verified: bool = false,
    limited_size_error: ?[]const u8 = null,
    prepass_replay_no_alloc_verified: bool = false,
    warm_no_alloc_verified: bool = false,
    peak_working_bytes: usize = 0,
    cold_peak_working_bytes: usize = 0,
    working_bytes: usize = 0,
    resource_checks: usize = 0,
    oom_failures: usize = 0,
    snapshot: ?std.json.Value = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const expected_path = args.next() orelse return error.MissingExpected;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try read(init, input_path);
    defer init.gpa.free(input);
    const expected = try read(init, expected_path);
    defer init.gpa.free(expected);
    const configuration = try read(init, config_path);
    defer init.gpa.free(configuration);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, configuration, .{});
    defer parsed.deinit();
    const config = parsed.value;
    const caller = try init.gpa.alloc(u8, @max(input.len, expected.len) + 16);
    defer init.gpa.free(caller);
    @memset(caller, 0xa5);
    const output_len = expected.len - @intFromBool(config.short_output and expected.len != 0);
    const output = caller[8 .. 8 + output_len];
    const source = if (config.alias or config.borrowed_alias) blk: {
        @memcpy(caller[8..][0..input.len], input);
        break :blk caller[8..][0..input.len];
    } else input;
    const original = try init.gpa.dupe(u8, caller);
    defer init.gpa.free(original);
    var allocator = std.testing.FailingAllocator.init(init.gpa, .{});
    var workspace = try Workspace.initWithOptions(allocator.allocator(), options(config));
    defer workspace.deinit();
    var report = Report{ .input_bytes = input.len };
    const written = if (config.borrowed_alias) blk: {
        report.prepared_output_len = try workspace.prepare(source, if (config.concatenated) .concatenated else .single);
        break :blk workspace.replayInto(output);
    } else workspaceInto(&workspace, source, output, config.concatenated);
    if (written) |count| {
        report.output_written = count;
        if (config.expected_error != null or config.expect_failure or count != expected.len or !std.mem.eql(u8, output[0..count], expected))
            return error.DecodeMismatch;
        if (!std.mem.eql(u8, caller[0..8], original[0..8]) or !std.mem.eql(u8, caller[8 + output_len ..], original[8 + output_len ..]))
            return error.WorkspaceGuardModified;
        report.prepared_output_len = count;
        report.cold_peak_working_bytes = workspace.snapshot().peak_working_bytes;
        try verifyLegacy(init.gpa, input, expected, config, &report);
        // Warm once before locking allocations; aliases can need an owned
        // compressed input, so warm the same publication contract separately.
        @memset(caller, 0xa5);
        report.prepared_output_len = try workspace.prepare(input, if (config.concatenated) .concatenated else .single);
        allocator.fail_index = allocator.alloc_index;
        if (try workspace.replayInto(output) != expected.len or !std.mem.eql(u8, output[0..expected.len], expected)) return error.ReplayMismatch;
        if (allocator.has_induced_failure) return error.ReplayAllocated;
        report.prepass_replay_no_alloc_verified = true;
        allocator.fail_index = std.math.maxInt(usize);
        _ = try workspaceInto(&workspace, input, output, config.concatenated);
        allocator.fail_index = allocator.alloc_index;
        const size = try workspaceSize(&workspace, input, config.concatenated);
        if (size != expected.len or try workspaceInto(&workspace, input, output, config.concatenated) != expected.len)
            return error.WarmMismatch;
        if (!config.concatenated) {
            _ = try workspace.inspect(input);
            report.inspect_verified = true;
        }
        if (allocator.has_induced_failure or !std.mem.eql(u8, output[0..expected.len], expected)) return error.WarmAllocated;
        allocator.fail_index = std.math.maxInt(usize);
        report.warm_no_alloc_verified = true;
        if (config.check_limits) report.resource_checks = try checkLimits(init.gpa, input, expected, config, report.cold_peak_working_bytes);
        if (config.oom) report.oom_failures = try checkOom(init.gpa, input, expected, config);
    } else |err| {
        report.@"error" = @errorName(err);
        report.caller_unchanged = std.mem.eql(u8, original, caller);
        if (!report.caller_unchanged) return error.WorkspaceErrorModifiedCaller;
        if (config.expected_error) |name| {
            if (!std.mem.eql(u8, report.@"error".?, name)) return error.UnexpectedError;
        } else if (!config.expect_failure) return err;
        try verifyLegacyError(init.gpa, input, expected.len, config, &report);
    }
    report.working_bytes = workspace.snapshot().working_bytes;
    report.peak_working_bytes = @max(report.cold_peak_working_bytes, workspace.snapshot().peak_working_bytes);
    var size_config = config;
    size_config.max_output_len = @min(config.max_output_len, output_len);
    var size_workspace = try Workspace.initWithOptions(init.gpa, options(size_config));
    defer size_workspace.deinit();
    _ = workspaceSize(&size_workspace, input, config.concatenated) catch |err| blk: {
        report.limited_size_error = @errorName(err);
        break :blk 0;
    };
    const snapshot_text = try std.json.Stringify.valueAlloc(init.gpa, workspace.snapshot(), .{});
    defer init.gpa.free(snapshot_text);
    const snapshot = try std.json.parseFromSlice(std.json.Value, init.gpa, snapshot_text, .{});
    defer snapshot.deinit();
    report.snapshot = snapshot.value;
    const json = try std.json.Stringify.valueAlloc(init.gpa, report, .{});
    defer init.gpa.free(json);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = if (report.@"error" == null) output[0..report.output_written] else &.{} });
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
}
fn options(config: Config) xz.DecodeOptions {
    return .{ .max_output_len = config.max_output_len, .max_dictionary_size = config.max_dictionary_size, .max_working_memory = config.max_working_memory };
}
fn workspaceInto(workspace: *Workspace, input: []const u8, output: []u8, concatenated: bool) !usize {
    return if (concatenated) workspace.decodeConcatenatedInto(input, output) else workspace.decodeInto(input, output);
}
fn workspaceSize(workspace: *Workspace, input: []const u8, concatenated: bool) !usize {
    return if (concatenated) workspace.decodedSizeConcatenated(input) else workspace.decodedSize(input);
}
fn legacyInto(allocator: std.mem.Allocator, input: []const u8, output: []u8, concatenated: bool) !usize {
    return if (concatenated) xz.decodeConcatenatedInto(allocator, input, output) else xz.decodeInto(allocator, input, output);
}
fn verifyLegacy(allocator: std.mem.Allocator, input: []const u8, expected: []const u8, config: Config, report: *Report) !void {
    const output = try allocator.alloc(u8, @max(input.len, expected.len) + 16);
    defer allocator.free(output);
    @memset(output, 0xa5);
    const source = if (config.alias) blk: {
        @memcpy(output[8..][0..input.len], input);
        break :blk output[8..][0..input.len];
    } else input;
    const original = try allocator.dupe(u8, output);
    defer allocator.free(original);
    const written = try legacyInto(allocator, source, output[8 .. 8 + expected.len], config.concatenated);
    if (written != expected.len or !std.mem.eql(u8, expected, output[8 .. 8 + expected.len])) return error.LegacyMismatch;
    if (!std.mem.eql(u8, output[0..8], original[0..8])) return error.LegacyPrefixModified;
    if (!std.mem.eql(u8, output[8 + expected.len ..], original[8 + expected.len ..])) return error.LegacySuffixModified;
    report.legacy_into_verified = true;
    const size = if (config.concatenated) try xz.decodedSizeConcatenated(allocator, input) else try xz.decodedSize(allocator, input);
    if (size != expected.len) return error.SizeMismatch;
    report.size_verified = true;
    if (!config.concatenated) {
        const info = try xz.inspect(allocator, input);
        if (info.uncompressed_size != expected.len) return error.InspectMismatch;
        report.inspect_verified = true;
    }
}
fn verifyLegacyError(allocator: std.mem.Allocator, input: []const u8, output_len: usize, config: Config, report: *Report) !void {
    // Workspace-only safety limits have no equivalent legacy Into argument.
    if (config.max_working_memory != std.math.maxInt(usize) or config.max_output_len != std.math.maxInt(usize) or
        config.max_dictionary_size != 65536 or config.borrowed_alias) return;
    const length = output_len - @intFromBool(config.short_output and output_len != 0);
    const guard = try allocator.alloc(u8, @max(input.len, length) + 16);
    defer allocator.free(guard);
    @memset(guard, 0xa5);
    const source = if (config.alias) blk: {
        @memcpy(guard[8..][0..input.len], input);
        break :blk guard[8..][0..input.len];
    } else input;
    const original = try allocator.dupe(u8, guard);
    defer allocator.free(original);
    if (legacyInto(allocator, source, guard[8 .. 8 + length], config.concatenated)) |_| return error.LegacyUnexpectedSuccess else |err| {
        if (config.expected_error != null and !std.mem.eql(u8, @errorName(err), report.@"error".?)) return error.LegacyErrorMismatch;
    }
    if (!std.mem.eql(u8, original, guard)) return error.LegacyErrorModifiedCaller;
    report.legacy_into_verified = true;
}
fn checkLimits(backing: std.mem.Allocator, input: []const u8, expected: []const u8, config: Config, peak: usize) !usize {
    if (peak == 0) return error.MissingMemoryAccounting;
    for ([_]usize{ peak, peak - 1 }, 0..) |limit, index| {
        var constrained = config;
        constrained.max_working_memory = limit;
        var workspace = try Workspace.initWithOptions(backing, options(constrained));
        defer workspace.deinit();
        const guard = try backing.alloc(u8, expected.len + 16);
        defer backing.free(guard);
        @memset(guard, 0xa5);
        if (workspaceInto(&workspace, input, guard[8 .. 8 + expected.len], config.concatenated)) |count| {
            if (index != 0 or count != expected.len or !std.mem.eql(u8, expected, guard[8 .. 8 + expected.len])) return error.ExactMemoryMismatch;
        } else |err| {
            if (index == 0 or err != error.WorkingMemoryLimitExceeded) return error.MemoryLimitMismatch;
            for (guard) |byte| if (byte != 0xa5) return error.MemoryErrorModifiedCaller;
        }
    }
    return 2;
}
fn checkOom(backing: std.mem.Allocator, input: []const u8, expected: []const u8, config: Config) !usize {
    const guard = try backing.alloc(u8, expected.len + 16);
    defer backing.free(guard);
    for (0..1024) |failure_index| {
        var tracker = std.testing.FailingAllocator.init(backing, .{ .fail_index = failure_index });
        var workspace = try Workspace.initWithOptions(tracker.allocator(), options(config));
        @memset(guard, 0xa5);
        if (workspaceInto(&workspace, input, guard[8 .. 8 + expected.len], config.concatenated)) |count| {
            if (count != expected.len or !std.mem.eql(u8, expected, guard[8 .. 8 + expected.len])) return error.OomMismatch;
        } else |err| {
            if (err != error.OutOfMemory) return error.UnexpectedOomError;
            for (guard) |byte| if (byte != 0xa5) return error.OomModifiedCaller;
        }
        workspace.deinit();
        if (tracker.allocated_bytes != tracker.freed_bytes) return error.OomAllocationLeak;
        if (!tracker.has_induced_failure) return failure_index;
    }
    return error.OomWalkLimit;
}
