//! Deterministic fixtures from the public incremental Deflate64 and ZIP APIs.
//! Build this tool with the full `vort` module, then pass one output directory.
//! The independent Python gate checks actual 65538/65536 encoded match tokens.
const std = @import("std");
const builtin = @import("builtin");
const vort = @import("vort");

const block_len = 128 * 1024;
const Pattern = enum { one, mixed };
const case_names = [_][]const u8{ "empty", "tiny", "pattern", "binary", "runs", "long_length", "long_distance" };
const input_chunks = [_]usize{ 0, 1, 2, 0, 3, 5, 7, 31 };
const output_chunks = [_]usize{ 0, 1, 0, 2, 3, 7, 16 };

const Progress = struct {
    steps: usize = 0,
    input_read: usize = 0,
    output_written: usize = 0,
    zero_input_offers: usize = 0,
    zero_output_offers: usize = 0,
    need_input: usize = 0,
    need_output: usize = 0,
    first_output_input_offset: ?usize = null,
    caller_guards_verified: bool = true,
};
const Artifact = struct {
    file: []const u8,
    kind: enum { incremental_raw, incremental_zip },
    pattern: Pattern,
    bytes: usize,
    sha256: []const u8,
    progress: Progress,
    self_decode_verified: bool,
};
const Case = struct {
    name: []const u8,
    input_file: []const u8,
    input_bytes: usize,
    input_sha256: []const u8,
    crc32: u32,
    artifacts: [4]Artifact,
};
const Encoded = struct { bytes: []u8, progress: Progress };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputDirectory;
    if (args.next() != null) return error.UnexpectedArgument;
    try std.Io.Dir.cwd().createDirPath(init.io, output_path);
    var directory = try std.Io.Dir.cwd().openDir(init.io, output_path, .{});
    defer directory.close(init.io);

    var cases: std.ArrayList(Case) = .empty;
    defer {
        for (cases.items) |case| {
            init.gpa.free(case.input_file);
            init.gpa.free(case.input_sha256);
            for (case.artifacts) |artifact| {
                init.gpa.free(artifact.file);
                init.gpa.free(artifact.sha256);
            }
        }
        cases.deinit(init.gpa);
    }
    for (case_names) |name| {
        const input = try makeInput(init.gpa, name);
        defer init.gpa.free(input);
        const input_file = try std.fmt.allocPrint(init.gpa, "{s}.input", .{name});
        errdefer init.gpa.free(input_file);
        const input_sha = try digestAlloc(init.gpa, input);
        errdefer init.gpa.free(input_sha);
        try directory.writeFile(init.io, .{ .sub_path = input_file, .data = input });

        var artifacts: [4]Artifact = undefined;
        var completed: usize = 0;
        errdefer for (artifacts[0..completed]) |artifact| {
            init.gpa.free(artifact.file);
            init.gpa.free(artifact.sha256);
        };
        inline for (.{ Pattern.one, Pattern.mixed }) |pattern| {
            const raw = try encodeRaw(init.gpa, input, pattern);
            defer init.gpa.free(raw.bytes);
            const decoded = try vort.decodeDeflate64AllocLimited(init.gpa, raw.bytes, input.len);
            defer init.gpa.free(decoded);
            if (!std.mem.eql(u8, decoded, input)) return error.RawRoundTripMismatch;
            artifacts[completed] = try saveArtifact(init, directory, name, pattern, .incremental_raw, raw, true);
            completed += 1;

            const zip = try encodeZip(init.gpa, input, pattern);
            defer init.gpa.free(zip.bytes);
            artifacts[completed] = try saveArtifact(init, directory, name, pattern, .incremental_zip, zip, false);
            completed += 1;
        }
        const after_sha = try digestAlloc(init.gpa, input);
        defer init.gpa.free(after_sha);
        if (!std.mem.eql(u8, input_sha, after_sha)) return error.InputModified;
        try cases.append(init.gpa, .{
            .name = name,
            .input_file = input_file,
            .input_bytes = input.len,
            .input_sha256 = input_sha,
            .crc32 = crc32(input),
            .artifacts = artifacts,
        });
    }
    const manifest = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.deflate64.stream-fixtures.v1",
        .generator = "public Deflate64IncrementalEncoder and ZipIncrementalWriter",
        .zig_version = builtin.zig_version_string,
        .optimize = @tagName(builtin.mode),
        .compression = "fixed",
        .block_len = block_len,
        .known_unknown_zip_entries = .{ "known.bin", "unknown.bin" },
        .boundary_contract = "actual encoder output must contain length65538 and distance65536; Python token gate verifies presence",
        .cases = cases.items,
    }, .{ .whitespace = .indent_2 });
    defer init.gpa.free(manifest);
    try directory.writeFile(init.io, .{ .sub_path = "manifest.json", .data = manifest });
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.print("{{\"schema\":\"vort.deflate64.stream-probe.v1\",\"cases\":{d},\"artifacts\":{d}}}\n", .{ cases.items.len, cases.items.len * 4 });
    try stdout.interface.flush();
}

fn saveArtifact(init: std.process.Init, directory: std.Io.Dir, name: []const u8, pattern: Pattern, kind: @FieldType(Artifact, "kind"), encoded: Encoded, verified: bool) !Artifact {
    const file = try std.fmt.allocPrint(init.gpa, "{s}-{s}.{s}", .{ name, @tagName(pattern), if (kind == .incremental_raw) "raw" else "zip" });
    errdefer init.gpa.free(file);
    const sha = try digestAlloc(init.gpa, encoded.bytes);
    errdefer init.gpa.free(sha);
    try directory.writeFile(init.io, .{ .sub_path = file, .data = encoded.bytes });
    return .{ .file = file, .kind = kind, .pattern = pattern, .bytes = encoded.bytes.len, .sha256 = sha, .progress = encoded.progress, .self_decode_verified = verified };
}

fn makeInput(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    if (std.mem.eql(u8, name, "empty")) return allocator.dupe(u8, "");
    if (std.mem.eql(u8, name, "tiny")) return allocator.dupe(u8, "Deflate64\x00tiny\xff\n");
    if (std.mem.eql(u8, name, "pattern")) return allocator.dupe(u8, "Deflate64 streaming ZIP method 9 backpressure.\n" ** 257);
    if (std.mem.eql(u8, name, "binary")) {
        const input = try allocator.alloc(u8, 16_387);
        randomBytes(input, 0xd640_2026);
        return input;
    }
    if (std.mem.eql(u8, name, "runs") or std.mem.eql(u8, name, "long_length")) {
        const long = std.mem.eql(u8, name, "long_length");
        const input = try allocator.alloc(u8, if (long) 65_539 else 70_003);
        @memset(input, if (long) 'Q' else 'R');
        return input;
    }
    if (std.mem.eql(u8, name, "long_distance")) {
        const input = try allocator.alloc(u8, 128 * 1024);
        randomBytes(input[0..65_536], 0x6536_2026);
        @memcpy(input[65_536..], input[0..65_536]);
        return input;
    }
    return error.UnknownCase;
}

fn randomBytes(output: []u8, seed: u32) void {
    var state = seed;
    for (output) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
}

fn digestAlloc(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    return allocator.dupe(u8, &hex);
}

fn crc32(bytes: []const u8) u32 {
    var value: u32 = 0xffff_ffff;
    for (bytes) |byte| {
        value ^= byte;
        for (0..8) |_| value = (value >> 1) ^ (if (value & 1 != 0) @as(u32, 0xedb8_8320) else 0);
    }
    return ~value;
}

fn inputEnd(input: []const u8, offset: usize, pattern: Pattern, step: usize) usize {
    const offered = if (pattern == .one) 1 else input_chunks[step % input_chunks.len];
    return offset + @min(input.len - offset, offered);
}

fn outputSlice(guard: *[48]u8, pattern: Pattern, step: usize) []u8 {
    @memset(guard, 0xa5);
    const offered = if (pattern == .one) 1 else output_chunks[step % output_chunks.len];
    return guard[8..][0..offered];
}

fn record(progress: *Progress, input_offer: usize, output: []u8, input_read: usize, output_written: usize, status: anytype, guard: *const [48]u8) !void {
    if (input_read > input_offer or output_written > output.len) return error.InvalidProgress;
    for (guard[0..8]) |byte| if (byte != 0xa5) return error.OutputPrefixModified;
    for (guard[8 + output_written ..]) |byte| if (byte != 0xa5) return error.OutputSuffixModified;
    progress.steps += 1;
    progress.zero_input_offers += @intFromBool(input_offer == 0);
    progress.zero_output_offers += @intFromBool(output.len == 0);
    progress.input_read += input_read;
    progress.output_written += output_written;
    progress.need_input += @intFromBool(status == .need_input);
    progress.need_output += @intFromBool(status == .need_output);
    if (output_written != 0 and progress.first_output_input_offset == null) progress.first_output_input_offset = progress.input_read;
}

fn encodeRaw(allocator: std.mem.Allocator, input: []const u8, pattern: Pattern) !Encoded {
    const options: vort.Deflate64IncrementalEncoder.Options = .{
        .block_len = block_len,
        .compression = .fixed,
        .nice_length = 65_538,
    };
    var encoder = if (pattern == .one)
        vort.Deflate64IncrementalEncoder.initExactSize(allocator, options, input.len)
    else
        vort.Deflate64IncrementalEncoder.initWithOptions(allocator, options);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var progress: Progress = .{};
    var guard: [48]u8 = undefined;
    var finished = false;
    while (progress.steps < 64 * (input.len + 1024)) {
        if (!finished and progress.input_read == input.len) {
            encoder.finish();
            finished = true;
        }
        const end = inputEnd(input, progress.input_read, pattern, progress.steps);
        const output = outputSlice(&guard, pattern, progress.steps);
        const stepped = try encoder.step(input[progress.input_read..end], output);
        try record(&progress, end - progress.input_read, output, stepped.progress.input_read, stepped.progress.output_written, stepped.status, &guard);
        try encoded.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) {
            if (!finished or progress.input_read != input.len) return error.EarlyDone;
            return .{ .bytes = try encoded.toOwnedSlice(allocator), .progress = progress };
        }
    }
    return error.RawStepLimit;
}

fn encodeZip(allocator: std.mem.Allocator, input: []const u8, pattern: Pattern) !Encoded {
    var writer = try vort.ZipIncrementalWriter.initWithOptions(allocator, .{
        .zip64 = .never,
        .archive_comment = "vort Deflate64 streaming fixture",
        .deflate64_options = .{ .block_len = block_len, .compression = .fixed, .nice_length = 65_538 },
    });
    defer writer.deinit();
    var archive: std.ArrayList(u8) = .empty;
    errdefer archive.deinit(allocator);
    var progress: Progress = .{};
    var guard: [48]u8 = undefined;
    for ([_]bool{ true, false }) |known| {
        try writer.beginEntry(.{
            .name = if (known) "known.bin" else "unknown.bin",
            .method = .deflate64,
            .expected_size = if (known) @as(u64, @intCast(input.len)) else null,
        });
        const blocked = try writer.step(input[0..@min(input.len, 1)], &.{});
        if (blocked.status != .need_output or blocked.progress.input_read != 0 or blocked.progress.output_written != 0) return error.HeaderBackpressureMismatch;
        progress.steps += 1;
        progress.zero_output_offers += 1;
        progress.need_output += 1;
        var offset: usize = 0;
        var entry_steps: usize = 0;
        while (offset < input.len) {
            if (entry_steps >= 64 * (input.len + 1024)) return error.ZipInputStepLimit;
            const end = inputEnd(input, offset, pattern, progress.steps);
            const output = outputSlice(&guard, pattern, progress.steps);
            const stepped = try writer.step(input[offset..end], output);
            try record(&progress, end - offset, output, stepped.progress.input_read, stepped.progress.output_written, stepped.status, &guard);
            offset += stepped.progress.input_read;
            try archive.appendSlice(allocator, output[0..stepped.progress.output_written]);
            entry_steps += 1;
        }
        try writer.finishEntry();
        entry_steps = 0;
        while (writer.snapshot().phase != .ready) {
            if (entry_steps >= 64 * (input.len + 1024)) return error.ZipEntryStepLimit;
            const output = outputSlice(&guard, pattern, progress.steps);
            const stepped = try writer.step("", output);
            try record(&progress, 0, output, stepped.progress.input_read, stepped.progress.output_written, stepped.status, &guard);
            try archive.appendSlice(allocator, output[0..stepped.progress.output_written]);
            entry_steps += 1;
        }
    }
    try writer.finishArchive();
    var final_steps: usize = 0;
    while (final_steps < 100_000) : (final_steps += 1) {
        const output = outputSlice(&guard, pattern, progress.steps);
        const stepped = try writer.step("", output);
        try record(&progress, 0, output, stepped.progress.input_read, stepped.progress.output_written, stepped.status, &guard);
        try archive.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) return .{ .bytes = try archive.toOwnedSlice(allocator), .progress = progress };
    }
    return error.ZipArchiveStepLimit;
}
