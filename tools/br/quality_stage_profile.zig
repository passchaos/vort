//! Fixed native q8 diagnostics. Ordinary public encoding is the byte oracle;
//! each instrumented round is compared after its timer and never ranked as a
//! normal encoder throughput sample.
const std = @import("std");
const br = @import("vort_br");
const provenance = @import("benchmark_provenance");
const output_identity = @import("encode_samples.zig");

const Options = struct {
    rounds: usize = 5,
    output: ?[]const u8 = null,
    paths: std.ArrayList([]const u8) = .empty,
    fn deinit(self: *Options, allocator: std.mem.Allocator) void {
        for (self.paths.items) |path| allocator.free(path);
        self.paths.deinit(allocator);
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var options: Options = .{};
    defer options.deinit(init.gpa);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--rounds")) {
            options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--json")) {
            options.output = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--path")) {
            try options.paths.append(init.gpa, try init.gpa.dupe(u8, args.next() orelse return error.MissingArgument));
        } else return error.UnknownArgument;
    }
    if (options.rounds == 0 or options.rounds > 31 or options.paths.items.len == 0) return error.InvalidArguments;
    if (options.output) |out| for (options.paths.items) |path| {
        try output_identity.requireDistinctOutputs(init.io, init.gpa, out, path);
    };
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    var json = std.Io.Writer.Allocating.init(init.gpa);
    defer json.deinit();
    try json.writer.writeAll("{\"schema\":\"vort.brotli.q8-candidate-profile.v1\",\"provenance\":");
    try std.json.Stringify.value(info, .{}, &json.writer);
    try json.writer.print(",\"quality\":8,\"mode\":\"generic\",\"window_bits\":16,\"profile_state_bytes\":{d},\"rows\":[", .{@sizeOf(br.QualityQ8Profile)});
    const profile = try init.gpa.create(br.QualityQ8Profile);
    defer init.gpa.destroy(profile);
    for (options.paths.items, 0..) |path, case_index| {
        if (case_index != 0) try json.writer.writeByte(',');
        const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
        defer file.close(init.io);
        const stat = try file.stat(init.io);
        if (stat.size > 65536) return error.InputTooLarge;
        const input = try init.gpa.alloc(u8, @intCast(stat.size));
        defer init.gpa.free(input);
        var read_buffer: [4096]u8 = undefined;
        var reader = file.reader(init.io, &read_buffer);
        if (try reader.interface.readSliceShort(input) != input.len) return error.InputTooSmall;
        const expected = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, .{ .quality = 8, .mode = .generic });
        defer init.gpa.free(expected);
        const decoded = try br.decodeStreamAlloc(init.gpa, expected);
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, input, decoded)) return error.RoundTripMismatch;
        try json.writer.writeAll("{\"path\":");
        try std.json.Stringify.value(path, .{}, &json.writer);
        const input_sha = provenance.sha256Hex(input);
        const wire_sha = provenance.sha256Hex(expected);
        try json.writer.print(",\"input_bytes\":{d},\"input_sha256\":\"{s}\",\"wire_bytes\":{d},\"wire_sha256\":\"{s}\",\"roundtrip_verified\":true,\"rounds\":[", .{ input.len, input_sha, expected.len, wire_sha });
        for (0..options.rounds) |round| {
            if (round != 0) try json.writer.writeByte(',');
            profile.* = .{};
            const first = if (round % 2 == 0)
                try normalPass(init.io, init.gpa, input, expected)
            else
                try profilePass(init.io, init.gpa, input, expected, profile);
            const second = if (round % 2 == 0)
                try profilePass(init.io, init.gpa, input, expected, profile)
            else
                try normalPass(init.io, init.gpa, input, expected);
            try json.writer.print("{{\"index\":{d},\"normal_first\":{s},\"normal_ns\":{d},\"profile_call_ns\":{d},\"wire_equal\":true,\"profile\":", .{ round, if (round % 2 == 0) "true" else "false", if (round % 2 == 0) first else second, if (round % 2 == 0) second else first });
            try std.json.Stringify.value(.{
                .event_count = profile.event_count,
                .events_total = profile.events_total,
                .events_truncated = profile.events_truncated,
                .wire_attempts = profile.wire_attempts,
                .wire_attempt_coverage_complete = profile.wire_attempt_coverage_complete,
                .timing_complete = profile.timing_complete,
                .outer_elapsed_ns = profile.outer_elapsed_ns,
                .exclusive_ns = profile.exclusive_ns,
                .unaccounted_ns = profile.unaccounted_ns,
                .error_name = profile.error_name,
                .returned_wire_bytes = profile.returned_wire_bytes,
                .returned_wire_event_id = profile.returned_wire_event_id,
                .context_details = profile.recordedContextDetails(),
                .context_details_truncated = profile.context_details_truncated,
                .events = profile.recordedEvents(),
            }, .{}, &json.writer);
            try json.writer.writeByte('}');
        }
        try json.writer.writeAll("]}");
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

fn normalPass(io: std.Io, allocator: std.mem.Allocator, input: []const u8, expected: []const u8) !u64 {
    const start = std.Io.Clock.awake.now(io);
    const wire = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, .{ .quality = 8, .mode = .generic });
    const elapsed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    defer allocator.free(wire);
    if (!std.mem.eql(u8, wire, expected)) return error.WireMismatch;
    return @intCast(elapsed);
}

fn profilePass(io: std.Io, allocator: std.mem.Allocator, input: []const u8, expected: []const u8, profile: *br.QualityQ8Profile) !u64 {
    const start = std.Io.Clock.awake.now(io);
    const wire = try br.benchmarkQualityQ8ProfileAlloc(allocator, input, io, profile);
    const elapsed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    defer allocator.free(wire);
    if (!std.mem.eql(u8, wire, expected)) return error.WireMismatch;
    return @intCast(elapsed);
}
