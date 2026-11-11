//! Header attribution on existing producer wires. This tool never compresses.
//! Compile with named modules `br` (src/br.zig) and `sampling`
//! (tools/decode/sampling.zig). Run separately from whole-codec timing.
const std = @import("std");
const builtin = @import("builtin");
const br = @import("br");
const sampling = @import("sampling");

const max_file_bytes = 256 * 1024 * 1024;
const max_iterations = 1_000_000;
const usage =
    "header-profile --input WIRE --plain PLAIN --iterations N --output JSON\n" ++
    "Reads existing Brotli producer frames; validates public decode outside timing.\n" ++
    "Reports aggregate compressed-header diagnostics across all compressed meta-blocks.\n" ++
    "Files are limited to 256 MiB each; iterations must be 1..1000000.\n";

const Options = struct {
    input: []const u8,
    plain: []const u8,
    iterations: usize,
    output: []const u8,
};

pub fn main(init: std.process.Init) void {
    run(init) catch |err| {
        var buffer: [1024]u8 = undefined;
        var stderr = std.Io.File.stderr().writerStreaming(init.io, &buffer);
        stderr.interface.print("header-profile: {s}\n{s}", .{ @errorName(err), usage }) catch {};
        stderr.interface.flush() catch {};
        std.process.exit(2);
    };
}

fn run(init: std.process.Init) !void {
    if (comptime builtin.os.tag != .linux) return error.LinuxFileIdentityRequired;
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var arguments: [8][]const u8 = undefined;
    var count: usize = 0;
    while (args.next()) |argument| {
        if (count == arguments.len) return error.ExtraArguments;
        arguments[count] = argument;
        count += 1;
    }
    if (count == 1 and std.mem.eql(u8, arguments[0], "--help")) {
        var buffer: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(usage);
        try stdout.interface.flush();
        return;
    }
    const options = try parseOptions(arguments[0..count]);
    const protected_paths = [_][]const u8{ options.input, options.plain, "/proc/self/exe" };
    try sampling.rejectOutputAliases(init.io, init.gpa, options.output, &protected_paths);

    const wire = try std.Io.Dir.cwd().readFileAlloc(init.io, options.input, init.gpa, .limited(max_file_bytes));
    defer init.gpa.free(wire);
    const plain = try std.Io.Dir.cwd().readFileAlloc(init.io, options.plain, init.gpa, .limited(max_file_bytes));
    defer init.gpa.free(plain);
    const guarded_wire = try sampling.GuardedBuffer.init(init.gpa, wire.len);
    defer guarded_wire.deinit(init.gpa);
    @memcpy(guarded_wire.data, wire);
    const output = try sampling.GuardedBuffer.init(init.gpa, plain.len);
    defer output.deinit(init.gpa);

    // Public behavior and guard checks are outside every reported timer.
    const written = try br.decodeStreamInto(guarded_wire.data, output.data);
    if (written != plain.len) return error.OutputSizeMismatch;
    try validate(guarded_wire, wire, output, plain);

    // Both APIs perform their own full-decode discovery before their timers.
    // Their internal output/list allocations are diagnostic preparation work.
    const profile = try br.profileCompressedHeaders(init.io, init.gpa, guarded_wire.data, options.iterations);
    try validate(guarded_wire, wire, output, plain);
    const sample = try br.benchmarkCompressedHeaders(init.io, init.gpa, guarded_wire.data, options.iterations);
    try validate(guarded_wire, wire, output, plain);
    if (profile.compressed_meta_block_count == 0 or
        profile.compressed_meta_block_count % options.iterations != 0 or
        profile.input_bits % options.iterations != 0) return error.InvalidProfileAggregate;

    const wire_sha256 = sha256(wire);
    const plain_sha256 = sha256(plain);
    const report = .{
        .schema = "vort.brotli.mozilla-header-profile.v1",
        .diagnostic = true,
        .input_path = options.input,
        .plain_path = options.plain,
        .wire_bytes = wire.len,
        .plain_bytes = plain.len,
        .wire_sha256 = wire_sha256[0..],
        .plain_sha256 = plain_sha256[0..],
        .producer_wire_reused_without_recompression = true,
        .iterations = options.iterations,
        .compressed_headers_per_stream = profile.compressed_meta_block_count / options.iterations,
        .compressed_header_bits_per_stream = profile.input_bits / options.iterations,
        .aggregation = "Every compressed meta-block header, accumulated over all iterations; stored, metadata, and end blocks are excluded",
        .validation = .{
            .api = "br.decodeStreamInto",
            .output_written = written,
            .output_matches_plain = true,
            .wire_guards = true,
            .output_guards = true,
            .wire_unchanged = true,
            .guard_bytes_per_side = sampling.GuardedBuffer.guard_bytes,
            .outside_timing = true,
            .scope = "Caller buffers of the public validation decode; private discovery buffers are not guarded by this tool",
        },
        .profile = .{
            .api = "br.profileCompressedHeaders",
            .aggregate = profile,
            .family_order = [_][]const u8{ "literal", "command", "distance" },
            .outer_stage_sum_ns = profile.elapsedNs(),
            .checksum = profile.checksum(),
            .nested_stage_clock_overhead_included = true,
            .scope = "Instrumented header attribution; nested prefix-stage times overlap the outer tree stages and must not be added to outer_stage_sum_ns",
        },
        .cold_header_only = .{
            .api = "br.benchmarkCompressedHeaders",
            .total_elapsed_ns = sample.elapsed_ns,
            .checksum = sample.checksum,
            .nested_stage_clocks = false,
            .scope = "One outer timer around repeated isolated header reconstruction at discovered bit offsets; includes loop, checksum, and outer clock overhead",
            .cold_meaning = "Each header reconstructs fresh parser/table state; CPU caches are not flushed and this follows the attribution run",
        },
        .discovery_and_allocation = .{
            .diagnostic_only = true,
            .full_decode_discovery_passes = 2,
            .discovery_output_and_header_start_list_allocations = true,
            .discovery_inside_reported_timing = false,
            .caller_validation_buffers_and_json_allocation_inside_timing = false,
            .allocation_bytes_measured = false,
            .scope = "Each header API locates offsets by full payload decoding into allocated output before timing; tool input reads, guards, validation, hashes, and JSON publication are also outside timing",
        },
        .interpretation = .{
            .whole_codec_total_time_measured = false,
            .whole_codec_heap_measured = false,
            .public_payload_route_identified = false,
            .scope = "Header totals describe diagnostic parser/table reconstruction; they do not identify the public decoder's actual payload route or establish whole-codec performance",
        },
        .build = .{
            .mode = @tagName(builtin.mode),
            .target_arch = @tagName(builtin.cpu.arch),
            .target_cpu_model = builtin.cpu.model.name,
            .pointer_bits = @bitSizeOf(usize),
            .single_threaded = builtin.single_threaded,
        },
        .limits = .{ .max_file_bytes = max_file_bytes, .max_iterations = max_iterations },
    };
    const json = try std.json.Stringify.valueAlloc(init.gpa, report, .{ .whitespace = .indent_2 });
    defer init.gpa.free(json);
    // Recheck immediately before publication, including symlinks and hardlinks.
    try sampling.rejectOutputAliases(init.io, init.gpa, options.output, &protected_paths);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = options.output, .data = json });
}

fn validate(wire: sampling.GuardedBuffer, original_wire: []const u8, output: sampling.GuardedBuffer, plain: []const u8) !void {
    try wire.validate();
    try output.validate();
    if (!std.mem.eql(u8, wire.data, original_wire)) return error.InputChanged;
    if (!std.mem.eql(u8, output.data, plain)) return error.OutputMismatch;
}

fn sha256(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn parseOptions(arguments: []const []const u8) !Options {
    const Field = enum { input, plain, iterations, output };
    var seen = std.EnumSet(Field).initEmpty();
    var input: ?[]const u8 = null;
    var plain: ?[]const u8 = null;
    var iterations: ?usize = null;
    var output: ?[]const u8 = null;
    var i: usize = 0;
    while (i < arguments.len) : (i += 2) {
        const flag = arguments[i];
        if (!std.mem.startsWith(u8, flag, "--")) return error.UnknownOption;
        const field = std.meta.stringToEnum(Field, flag[2..]) orelse return error.UnknownOption;
        if (seen.contains(field)) return error.DuplicateOption;
        seen.insert(field);
        if (i + 1 == arguments.len) return error.MissingOptionValue;
        const value = arguments[i + 1];
        if (value.len == 0 or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidOptionValue;
        if (std.mem.startsWith(u8, value, "--")) return error.MissingOptionValue;
        switch (field) {
            .input => input = value,
            .plain => plain = value,
            .output => output = value,
            .iterations => {
                const parsed = std.fmt.parseInt(usize, value, 10) catch return error.InvalidIterations;
                if (parsed == 0 or parsed > max_iterations) return error.InvalidIterations;
                iterations = parsed;
            },
        }
    }
    return .{
        .input = input orelse return error.MissingInput,
        .plain = plain orelse return error.MissingPlain,
        .iterations = iterations orelse return error.MissingIterations,
        .output = output orelse return error.MissingOutput,
    };
}

test "Mozilla header diagnostic accepts explicit options in any order" {
    const options = try parseOptions(&.{ "--output", "report.json", "--iterations", "3", "--plain", "plain", "--input", "wire" });
    try std.testing.expectEqualStrings("wire", options.input);
    try std.testing.expectEqualStrings("plain", options.plain);
    try std.testing.expectEqualStrings("report.json", options.output);
    try std.testing.expectEqual(@as(usize, 3), options.iterations);
}

test "Mozilla header diagnostic rejects malformed and missing options" {
    try std.testing.expectError(error.UnknownOption, parseOptions(&.{ "--unknown", "x" }));
    try std.testing.expectError(error.UnknownOption, parseOptions(&.{ "input", "x" }));
    try std.testing.expectError(error.MissingOptionValue, parseOptions(&.{"--input"}));
    try std.testing.expectError(error.MissingOptionValue, parseOptions(&.{ "--input", "--plain" }));
    try std.testing.expectError(error.InvalidOptionValue, parseOptions(&.{ "--input", "" }));
    try std.testing.expectError(error.InvalidOptionValue, parseOptions(&.{ "--input", "wire\x00suffix" }));
    try std.testing.expectError(error.DuplicateOption, parseOptions(&.{ "--input", "one", "--input", "two" }));
    try std.testing.expectError(error.MissingInput, parseOptions(&.{}));
    try std.testing.expectError(error.MissingPlain, parseOptions(&.{ "--input", "wire" }));
    try std.testing.expectError(error.MissingIterations, parseOptions(&.{ "--input", "wire", "--plain", "plain" }));
    try std.testing.expectError(error.MissingOutput, parseOptions(&.{ "--input", "wire", "--plain", "plain", "--iterations", "1" }));
}

test "Mozilla header diagnostic bounds iteration work" {
    for ([_][]const u8{ "0", "-1", "word", "1000001", "999999999999999999999999999999" }) |value|
        try std.testing.expectError(error.InvalidIterations, parseOptions(&.{ "--iterations", value }));
}
