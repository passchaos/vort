//! Whole-stream payload counts on existing producer wires. No timing or
//! compression is performed. Compile with named modules `br` and `sampling`.
const std = @import("std");
const builtin = @import("builtin");
const br = @import("br");
const sampling = @import("sampling");

const max_file_bytes = 256 * 1024 * 1024;
const usage =
    "payload-counts --input WIRE --plain PLAIN --output JSON\n" ++
    "Reports whole-stream Brotli command, distance, and copy counts without timing.\n" ++
    "Reuses the existing producer wire and validates its complete public decode.\n" ++
    "Files are limited to 256 MiB each; Linux /proc/self/exe identity is required.\n";

const Options = struct { input: []const u8, plain: []const u8, output: []const u8 };

pub fn main(init: std.process.Init) void {
    run(init) catch |err| {
        var buffer: [1024]u8 = undefined;
        var stderr = std.Io.File.stderr().writerStreaming(init.io, &buffer);
        stderr.interface.print("payload-counts: {s}\n{s}", .{ @errorName(err), usage }) catch {};
        stderr.interface.flush() catch {};
        std.process.exit(2);
    };
}

fn run(init: std.process.Init) !void {
    if (comptime builtin.os.tag != .linux) return error.LinuxExecutableIdentityRequired;
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var arguments: [6][]const u8 = undefined;
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
    // Reading the running executable is mandatory: report publication never
    // substitutes an empty or guessed identity when /proc capture fails.
    const executable = std.Io.Dir.cwd().readFileAlloc(init.io, "/proc/self/exe", init.gpa, .limited(max_file_bytes)) catch return error.ExecutableIdentityUnavailable;
    defer init.gpa.free(executable);
    if (executable.len == 0) return error.ExecutableIdentityUnavailable;
    const executable_sha256 = sha256(executable);
    const wire_sha256 = sha256(wire);
    const plain_sha256 = sha256(plain);

    const guarded_wire = try sampling.GuardedBuffer.init(init.gpa, wire.len);
    defer guarded_wire.deinit(init.gpa);
    @memcpy(guarded_wire.data, wire);
    const output = try sampling.GuardedBuffer.init(init.gpa, plain.len);
    defer output.deinit(init.gpa);

    var diagnostics: br.StreamSummaryDiagnostics = .{};
    const summary = try br.summarizeStreamAllocLimitedWithOptionsAndDiagnostics(init.gpa, guarded_wire.data, @intCast(plain.len), .{}, &diagnostics);
    try requireSummarySize(summary.decoded_bytes, plain.len);
    if (summary.input_bytes != wire.len) return error.SummaryInputSizeMismatch;
    try guarded_wire.validate();
    if (!std.mem.eql(u8, guarded_wire.data, wire)) return error.InputChanged;

    const written = try br.decodeStreamInto(guarded_wire.data, output.data);
    if (written != plain.len) return error.OutputSizeMismatch;
    try guarded_wire.validate();
    try output.validate();
    if (!std.mem.eql(u8, guarded_wire.data, wire)) return error.InputChanged;
    if (!std.mem.eql(u8, output.data, plain)) return error.OutputMismatch;

    const report = .{
        .schema = "vort.brotli.mozilla-payload-counts.v1",
        .diagnostic = true,
        .input_path = options.input,
        .plain_path = options.plain,
        .wire_bytes = wire.len,
        .plain_bytes = plain.len,
        .wire_sha256 = wire_sha256[0..],
        .plain_sha256 = plain_sha256[0..],
        .executable_sha256 = executable_sha256[0..],
        .executable_bytes = executable.len,
        .executable_identity_origin = "SHA-256 of the complete Linux /proc/self/exe bytes; capture failure is fatal",
        .producer_wire_reused_without_recompression = true,
        .source = .{
            .runtime_source_sha256 = @as(?[]const u8, null),
            .scope = "An external runner must bind its source digest and build command to executable_sha256; this tool does not assert a runtime Zig source SHA",
        },
        .summary = summary,
        .summary_diagnostics = diagnostics,
        .summary_scope = .{
            .api = "br.summarizeStreamAllocLimitedWithOptionsAndDiagnostics",
            .aggregation = "One complete stream, accumulating logical payload quantities over every compressed meta-block; the full public StreamSummary is preserved",
            .max_output_len = plain.len,
            .command_shape = "Command counts and copy_length_log2_histogram include the final decoded command even when its insert reaches the meta-block end before its copy is applied",
            .distance_copy_shape = "Implicit/short/direct/regular copy counters classify applied copies by wire distance coding path; they are distinct from implicit-distance command counts",
            .copy_length_histogram_ranges = [_][]const u8{ "1", "2-3", "4-7", "8-15", "16-31", "32-63", "64-127", "128-255", ">=256" },
            .allocating_history_discovery = true,
            .may_allocate_full_declared_window = true,
            .allocation_bytes_measured = false,
            .allocation_scope = "The allocating summary may reserve history or retry with a full declared window bounded by max_output_len to recover literal context; this is diagnostic replay and does not describe production decoder heap",
        },
        .validation = .{
            .api = "br.decodeStreamInto",
            .output_written = written,
            .output_matches_complete_plain = true,
            .wire_unchanged_after_summary_and_decode = true,
            .wire_guards = true,
            .output_guards = true,
            .guard_bytes_per_side = sampling.GuardedBuffer.guard_bytes,
            .scope = "Guarded caller wire and output buffers used by the public validation decode; private summary/history buffers are not guarded by this tool",
        },
        .measurement_scope = .{
            .timing_measured = false,
            .throughput_measured = false,
            .heap_measured = false,
            .per_meta_block_actual_public_route_identified = false,
            .scope = "Whole-stream summary counts and stream-wide maxima cannot replace actual per-meta-block public decoder route attribution or establish a whole-codec performance or memory result",
        },
        .build = .{
            .mode = @tagName(builtin.mode),
            .zig_version = builtin.zig_version_string,
            .target_arch = @tagName(builtin.target.cpu.arch),
            .target_os = @tagName(builtin.target.os.tag),
            .target_abi = @tagName(builtin.target.abi),
            .target_cpu_model = builtin.target.cpu.model.name,
            .pointer_bits = @bitSizeOf(usize),
            .single_threaded = builtin.single_threaded,
        },
        .limits = .{ .max_file_bytes = max_file_bytes },
    };
    const json = try std.json.Stringify.valueAlloc(init.gpa, report, .{ .whitespace = .indent_2 });
    defer init.gpa.free(json);
    // No report is opened until parameters, bounded summary, complete public
    // decode, guards and identities have succeeded. Recheck filesystem aliases
    // immediately before publication, including symlinks and hardlinks.
    try sampling.rejectOutputAliases(init.io, init.gpa, options.output, &protected_paths);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = options.output, .data = json });
}

fn sha256(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn requireSummarySize(decoded_bytes: br.Counter, plain_len: usize) !void {
    if (decoded_bytes > plain_len) return error.SummaryExceedsPlain;
    if (decoded_bytes != plain_len) return error.SummaryOutputSizeMismatch;
}

fn parseOptions(arguments: []const []const u8) !Options {
    if (arguments.len > 6) return error.ExtraArguments;
    const Field = enum { input, plain, output };
    var seen = std.EnumSet(Field).initEmpty();
    var input: ?[]const u8 = null;
    var plain: ?[]const u8 = null;
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
        }
    }
    return .{ .input = input orelse return error.MissingInput, .plain = plain orelse return error.MissingPlain, .output = output orelse return error.MissingOutput };
}

test "Mozilla payload counts accepts explicit paths in any order" {
    const options = try parseOptions(&.{ "--output", "report.json", "--plain", "plain", "--input", "wire" });
    try std.testing.expectEqualStrings("wire", options.input);
    try std.testing.expectEqualStrings("plain", options.plain);
    try std.testing.expectEqualStrings("report.json", options.output);
}

test "Mozilla payload counts rejects malformed missing duplicate and extra options" {
    try std.testing.expectError(error.UnknownOption, parseOptions(&.{ "--iterations", "1" }));
    try std.testing.expectError(error.UnknownOption, parseOptions(&.{ "input", "wire" }));
    try std.testing.expectError(error.MissingOptionValue, parseOptions(&.{"--input"}));
    try std.testing.expectError(error.MissingOptionValue, parseOptions(&.{ "--plain", "--output" }));
    try std.testing.expectError(error.InvalidOptionValue, parseOptions(&.{ "--input", "" }));
    try std.testing.expectError(error.InvalidOptionValue, parseOptions(&.{ "--input", "wire\x00suffix" }));
    try std.testing.expectError(error.DuplicateOption, parseOptions(&.{ "--output", "first", "--output", "second" }));
    try std.testing.expectError(error.MissingInput, parseOptions(&.{}));
    try std.testing.expectError(error.MissingPlain, parseOptions(&.{ "--input", "wire" }));
    try std.testing.expectError(error.MissingOutput, parseOptions(&.{ "--input", "wire", "--plain", "plain" }));
    try std.testing.expectError(error.ExtraArguments, parseOptions(&.{ "--input", "wire", "--plain", "plain", "--output", "report.json", "extra" }));
}

test "Mozilla payload counts rejects summary size disagreement" {
    try requireSummarySize(5, 5);
    try std.testing.expectError(error.SummaryExceedsPlain, requireSummarySize(6, 5));
    try std.testing.expectError(error.SummaryOutputSizeMismatch, requireSummarySize(4, 5));
}
