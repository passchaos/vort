const std = @import("std");
const vort = @import("vort");

const Mode = enum {
    raw_block,
    framed,
    raw_block_reusable,
    framed_reusable,
};

const incompressible_payload = incompressiblePayload();

const Case = struct {
    name: []const u8,
    payload: []const u8,
};

const Row = struct {
    mode: Mode,
    case_name: []const u8,
    input_bytes: usize,
    encoded_bytes: usize,
    ratio: f64,
    iterations: usize,
    encode_ns: u64,
    decode_ns: u64,
    encode_mib_s: f64,
    decode_mib_s: f64,
    checksum: u64,
};

const Options = struct {
    iterations: usize = 200,
    csv_path: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);

    const cases = [_]Case{
        .{ .name = "tiny", .payload = "hello snappy" },
        .{ .name = "text", .payload = "Snappy benchmark text payload. " ** 1024 },
        .{ .name = "structured", .payload = "{\"service\":\"vort\",\"codec\":\"snappy\",\"value\":12345}\n" ** 768 },
        .{ .name = "repetitive", .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256 },
        .{ .name = "incompressible", .payload = &incompressible_payload },
    };

    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(init.gpa);
    for (&cases) |case| {
        try rows.append(init.gpa, try row(init.io, init.gpa, .raw_block, case, options.iterations));
        try rows.append(init.gpa, try row(init.io, init.gpa, .framed, case, options.iterations));
        try rows.append(init.gpa, try row(init.io, init.gpa, .raw_block_reusable, case, options.iterations));
        try rows.append(init.gpa, try row(init.io, init.gpa, .framed_reusable, case, options.iterations));
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, rows.items);
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
        try stdout_writer.interface.writeAll(csv.written());
        try stdout_writer.interface.flush();
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            const value = args.next() orelse return error.MissingLimit;
            options.iterations = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path = args.next() orelse return error.MissingCorpusPath;
        } else {
            return error.UnknownArgument;
        }
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    return options;
}

fn row(io: std.Io, allocator: std.mem.Allocator, mode: Mode, case: Case, iterations: usize) !Row {
    var encoder = vort.SnappyEncoder.init(allocator);
    defer encoder.deinit();

    const encoded = switch (mode) {
        .raw_block => try vort.snappyEncodeBlockAlloc(allocator, case.payload),
        .framed => try vort.snappyEncodeFrameAlloc(allocator, case.payload),
        .raw_block_reusable => try encoder.encodeBlockAlloc(case.payload),
        .framed_reusable => try encoder.encodeFrameAlloc(case.payload),
    };
    defer allocator.free(encoded);

    const decoded = switch (mode) {
        .raw_block, .raw_block_reusable => try vort.snappyDecodeBlockAlloc(allocator, encoded),
        .framed, .framed_reusable => try vort.snappyDecodeFrameAlloc(allocator, encoded),
    };
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;

    var encode_checksum: u64 = 0;
    const encode_start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const iteration_encoded = switch (mode) {
            .raw_block => try vort.snappyEncodeBlockAlloc(allocator, case.payload),
            .framed => try vort.snappyEncodeFrameAlloc(allocator, case.payload),
            .raw_block_reusable => try encoder.encodeBlockAlloc(case.payload),
            .framed_reusable => try encoder.encodeFrameAlloc(case.payload),
        };
        encode_checksum +%= vort.crc32(iteration_encoded);
        allocator.free(iteration_encoded);
    }
    const encode_ns = elapsedNs(io, encode_start);

    var decode_checksum: u64 = 0;
    const decode_start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const iteration_decoded = switch (mode) {
            .raw_block, .raw_block_reusable => try vort.snappyDecodeBlockAlloc(allocator, encoded),
            .framed, .framed_reusable => try vort.snappyDecodeFrameAlloc(allocator, encoded),
        };
        decode_checksum +%= vort.crc32(iteration_decoded);
        allocator.free(iteration_decoded);
    }
    const decode_ns = elapsedNs(io, decode_start);

    return .{
        .mode = mode,
        .case_name = case.name,
        .input_bytes = case.payload.len,
        .encoded_bytes = encoded.len,
        .ratio = @as(f64, @floatFromInt(encoded.len)) / @as(f64, @floatFromInt(case.payload.len)),
        .iterations = iterations,
        .encode_ns = encode_ns,
        .decode_ns = decode_ns,
        .encode_mib_s = mibPerSecond(case.payload.len * iterations, encode_ns),
        .decode_mib_s = mibPerSecond(case.payload.len * iterations, decode_ns),
        .checksum = encode_checksum +% decode_checksum,
    };
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const elapsed = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (elapsed <= 0) 0 else @intCast(elapsed);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0.0;
    const mib = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0);
    const seconds = @as(f64, @floatFromInt(ns)) / 1_000_000_000.0;
    return mib / seconds;
}

fn modeName(mode: Mode) []const u8 {
    return switch (mode) {
        .raw_block => "raw_block",
        .framed => "framed",
        .raw_block_reusable => "raw_block_reusable",
        .framed_reusable => "framed_reusable",
    };
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("mode,case,input_bytes,encoded_bytes,ratio,iterations,encode_ns,decode_ns,encode_mib_s,decode_mib_s,checksum\n");
    for (rows) |entry| {
        try writer.print("{s},{s},{d},{d},{d:.6},{d},{d},{d},{d:.4},{d:.4},{d}\n", .{
            modeName(entry.mode),
            entry.case_name,
            entry.input_bytes,
            entry.encoded_bytes,
            entry.ratio,
            entry.iterations,
            entry.encode_ns,
            entry.decode_ns,
            entry.encode_mib_s,
            entry.decode_mib_s,
            entry.checksum,
        });
    }
}

fn incompressiblePayload() [1024]u8 {
    @setEvalBranchQuota(4096);
    var out: [1024]u8 = undefined;
    var state: u32 = 0x1234_5678;
    for (&out) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 16);
    }
    return out;
}
