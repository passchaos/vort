//! Non-timed native q8 resource comparison, compatible with profile v1 and v2.
//! All codec calls use public APIs; independent backing requests are the oracle.
const std = @import("std");
const builtin = @import("builtin");
const br = @import("vort_br");
const tracker = @import("candidate_memory_tracker.zig");

const Options = struct {
    output: ?[]const u8 = null,
    paths: std.ArrayList([]const u8) = .empty,
    fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        for (self.paths.items) |path| allocator.free(path);
        self.paths.deinit(allocator);
    }
};
const Kind = enum { ordinary, profile };
const Summary = struct {
    kind: Kind,
    limit: ?usize,
    error_name: ?[]const u8,
    peak_requested_bytes: usize,
    live_after_return: usize,
    live_after_caller_free: usize,
    allocated_bytes: usize,
    freed_bytes: usize,
    alloc_attempts: usize,
    resize_attempts: usize,
    remap_attempts: usize,
    free_calls: usize,
    successful_resizes: usize,
    successful_remaps: usize,
    peak_operation: tracker.Operation,
    peak_before: usize,
    peak_request: usize,
    wire_bytes: ?usize,
    wire_sha256: ?[64]u8,
    wire_equal: ?bool,
    memory_profile: br.EncodeMemoryProfile,
};
const Result = struct {
    summary: Summary,
    ledger: []tracker.Request,
    wire_copy: ?[]u8,

    fn deinit(self: Result, allocator: std.mem.Allocator) void {
        allocator.free(self.ledger);
        if (self.wire_copy) |wire| allocator.free(wire);
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var options: Options = .{};
    defer options.deinit(init.gpa);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            options.output = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--path")) {
            try options.paths.append(init.gpa, try init.gpa.dupe(u8, args.next() orelse return error.MissingArgument));
        } else return error.UnknownArgument;
    }
    if (options.paths.items.len == 0) return error.InvalidArguments;
    if (options.output) |output| for (options.paths.items) |path| {
        // Resolve parents so a missing report file cannot alias an input path.
        const output_absolute = try std.fs.path.resolve(init.gpa, &.{output});
        defer init.gpa.free(output_absolute);
        const input_absolute = try std.fs.path.resolve(init.gpa, &.{path});
        defer init.gpa.free(input_absolute);
        if (std.mem.eql(u8, output_absolute, input_absolute)) return error.OutputAliasesInput;
    };
    var json = std.Io.Writer.Allocating.init(init.gpa);
    defer json.deinit();
    try json.writer.writeAll("{\"schema\":\"vort.brotli.q8-candidate-memory.v1\",\"measurement\":\"non_timed_independent_requested_heap\",\"quality\":8,\"mode\":\"generic\",\"window_bits\":16,\"force_moving_growth\":true,");
    try json.writer.print("\"zig_version\":\"{s}\",\"optimize\":\"{s}\",\"profile_state_bytes\":{d},\"evaluation_fields_available\":{s},\"rows\":[", .{ builtin.zig_version_string, @tagName(builtin.mode), @sizeOf(br.QualityQ8Profile), if (@hasField(br.QualityQ8Profile, "evaluation_attempts")) "true" else "false" });
    const trace = try init.gpa.create(br.QualityQ8Profile);
    defer init.gpa.destroy(trace);
    for (options.paths.items, 0..) |path, index| {
        if (index != 0) try json.writer.writeByte(',');
        const input = try readInput(init.io, init.gpa, path);
        defer init.gpa.free(input);
        try json.writer.writeAll("{\"path\":");
        try std.json.Stringify.value(path, .{}, &json.writer);
        try json.writer.print(",\"input_bytes\":{d},\"input_sha256\":\"{s}\",\"passes\":[", .{ input.len, sha256Hex(input) });
        const normal = try runPass(init.io, init.gpa, input, .ordinary, null, null, trace);
        defer normal.deinit(init.gpa);
        const expected = normal.wire_copy orelse return error.MissingWire;
        const decoded = try br.decodeStreamAlloc(init.gpa, expected);
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, input, decoded)) return error.RoundTripMismatch;
        try writePass(&json.writer, normal, trace);
        const observed = try runPass(init.io, init.gpa, input, .profile, null, expected, trace);
        defer observed.deinit(init.gpa);
        try sameResources(normal, observed);
        try json.writer.writeByte(',');
        try writePass(&json.writer, observed, trace);
        const peak = normal.summary.peak_requested_bytes;
        if (peak == 0) return error.MissingPeak;
        const exact_normal = try runPass(init.io, init.gpa, input, .ordinary, peak, expected, trace);
        defer exact_normal.deinit(init.gpa);
        try sameResources(normal, exact_normal);
        try json.writer.writeByte(',');
        try writePass(&json.writer, exact_normal, trace);
        const exact_profile = try runPass(init.io, init.gpa, input, .profile, peak, expected, trace);
        defer exact_profile.deinit(init.gpa);
        try sameResources(exact_normal, exact_profile);
        try json.writer.writeByte(',');
        try writePass(&json.writer, exact_profile, trace);
        const below_normal = try runPass(init.io, init.gpa, input, .ordinary, peak - 1, expected, trace);
        defer below_normal.deinit(init.gpa);
        if (!std.mem.eql(u8, below_normal.summary.error_name orelse "", "WorkingMemoryLimitExceeded")) return error.ExpectedBudgetFailure;
        try json.writer.writeByte(',');
        try writePass(&json.writer, below_normal, trace);
        const below_profile = try runPass(init.io, init.gpa, input, .profile, peak - 1, expected, trace);
        defer below_profile.deinit(init.gpa);
        try sameResources(below_normal, below_profile);
        try json.writer.writeByte(',');
        try writePass(&json.writer, below_profile, trace);
        try json.writer.writeAll("],\"roundtrip_verified\":true,\"ordinary_profile_ledgers_equal\":true,\"uncapped_exact_ledgers_equal\":true,\"exact_peak_succeeded\":true,\"peak_minus_one_failed\":true,\"profile_live_after_budget_end_zero\":true,\"caller_free_live_zero\":true}");
    }
    try json.writer.writeAll("]}\n");
    if (options.output) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = json.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(json.written());
        try stdout.interface.flush();
    }
}

fn readInput(io: std.Io, allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const stat = try file.stat(io);
    if (stat.size > 65536) return error.InputTooLarge;
    const input = try allocator.alloc(u8, @intCast(stat.size));
    errdefer allocator.free(input);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &buffer);
    if (try reader.interface.readSliceShort(input) != input.len) return error.InputTooSmall;
    return input;
}

fn runPass(io: std.Io, allocator: std.mem.Allocator, input: []const u8, kind: Kind, limit: ?usize, expected: ?[]const u8, trace: *br.QualityQ8Profile) !Result {
    const tracked = try allocator.create(tracker.TrackingAllocator);
    defer allocator.destroy(tracked);
    tracked.* = tracker.TrackingAllocator.init(allocator);
    var memory: br.EncodeMemoryProfile = .{};
    trace.* = .{ .request = .{ .max_total_working_memory = limit, .memory_profile = &memory } };
    var failure: ?[]const u8 = null;
    const wire: ?[]u8 = (switch (kind) {
        .ordinary => br.encodePlannedStreamWithOptionsAlloc(tracked.allocator(), input, .{ .quality = 8, .mode = .generic, .window_bits = 16, .max_total_working_memory = limit, .memory_profile = &memory }),
        .profile => br.benchmarkQualityQ8ProfileAlloc(tracked.allocator(), input, io, trace),
    }) catch |err| block: {
        failure = @errorName(err);
        break :block null;
    };
    const live_after_return = tracked.live;
    if (!memory.available or memory.live_requested_bytes != 0) return error.BudgetCleanupMismatch;
    if (memory.peak_requested_bytes != tracked.peak) return error.RealPeakProfileMismatch;
    var copy: ?[]u8 = null;
    errdefer if (copy) |bytes| allocator.free(bytes);
    var wire_hash: ?[64]u8 = null;
    var equal: ?bool = null;
    if (wire) |bytes| {
        if (live_after_return != bytes.len) return error.ReturnedWireLiveMismatch;
        wire_hash = sha256Hex(bytes);
        equal = if (expected) |reference| std.mem.eql(u8, bytes, reference) else true;
        if (!equal.?) return error.WireMismatch;
        if (expected == null) copy = try allocator.dupe(u8, bytes);
        tracked.allocator().free(bytes);
    }
    if (tracked.live != 0 or tracked.allocated_bytes != tracked.freed_bytes) return error.RealHeapCleanupMismatch;
    return .{
        .summary = .{
            .kind = kind,
            .limit = limit,
            .error_name = failure,
            .peak_requested_bytes = tracked.peak,
            .live_after_return = live_after_return,
            .live_after_caller_free = tracked.live,
            .allocated_bytes = tracked.allocated_bytes,
            .freed_bytes = tracked.freed_bytes,
            .alloc_attempts = tracked.alloc_attempts,
            .resize_attempts = tracked.resize_attempts,
            .remap_attempts = tracked.remap_attempts,
            .free_calls = tracked.free_calls,
            .successful_resizes = tracked.successful_resizes,
            .successful_remaps = tracked.successful_remaps,
            .peak_operation = tracked.peak_operation,
            .peak_before = tracked.peak_before,
            .peak_request = tracked.peak_request,
            .wire_bytes = if (wire) |bytes| bytes.len else null,
            .wire_sha256 = wire_hash,
            .wire_equal = equal,
            .memory_profile = memory,
        },
        .ledger = try allocator.dupe(tracker.Request, tracked.ledger()),
        .wire_copy = copy,
    };
}

fn sameResources(a: Result, b: Result) !void {
    if (a.summary.peak_requested_bytes != b.summary.peak_requested_bytes or
        a.summary.live_after_return != b.summary.live_after_return or
        a.ledger.len != b.ledger.len) return error.ResourceMismatch;
    for (a.ledger, b.ledger) |left, right| if (!std.meta.eql(left, right)) return error.RequestLedgerMismatch;
    const a_error = a.summary.error_name orelse "";
    const b_error = b.summary.error_name orelse "";
    if (!std.mem.eql(u8, a_error, b_error)) return error.ErrorMismatch;
}

fn writePass(writer: *std.Io.Writer, result: Result, trace: *const br.QualityQ8Profile) !void {
    try writer.writeAll("{\"summary\":");
    try std.json.Stringify.value(result.summary, .{}, writer);
    try writer.writeAll(",\"ledger\":");
    try std.json.Stringify.value(result.ledger, .{}, writer);
    if (result.summary.kind == .profile) {
        try writer.writeAll(",\"candidate_profile\":");
        try std.json.Stringify.value(.{
            .wire_attempts = trace.wire_attempts,
            .evaluation_attempts = if (@hasField(br.QualityQ8Profile, "evaluation_attempts")) trace.evaluation_attempts else @as(?usize, null),
            .event_count = trace.event_count,
            .events_total = trace.events_total,
            .events_truncated = trace.events_truncated,
            .wire_attempt_coverage_complete = trace.wire_attempt_coverage_complete,
            .returned_wire_event_id = trace.returned_wire_event_id,
            .returned_wire_bytes = trace.returned_wire_bytes,
            .error_name = trace.error_name,
        }, .{}, writer);
        try writer.writeAll(",\"linked_emissions\":[");
        var linked: usize = 0;
        for (trace.recordedEvents()) |event| {
            if (@hasField(@TypeOf(event), "evaluation_event_id")) {
                if (event.evaluation_event_id) |evaluation_id| {
                    if (linked != 0) try writer.writeByte(',');
                    try std.json.Stringify.value(.{ .event_id = event.id, .evaluation_event_id = evaluation_id, .wire_bytes = event.wire_bytes, .evaluated_wire_bytes = event.evaluated_wire_bytes }, .{}, writer);
                    linked += 1;
                }
            }
        }
        try writer.print("],\"linked_emission_count\":{d}", .{linked});
    }
    try writer.writeByte('}');
}

fn sha256Hex(bytes: []const u8) [64]u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}
