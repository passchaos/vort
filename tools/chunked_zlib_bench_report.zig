const std = @import("std");
const vort = @import("vort");

const Encoder = enum { best, stored, dynamic_literal };

const CaseSpec = struct {
    name: []const u8,
    width: usize,
    height: usize,
    bytes_per_pixel: usize,
    encoder: Encoder,
    chunk_bytes: usize,
    include_empty_chunks: bool = false,
};

const Row = struct {
    name: []const u8,
    encoder: []const u8,
    input_bytes: usize,
    zlib_bytes: usize,
    chunk_bytes: usize,
    chunk_count: usize,
    include_empty_chunks: bool,
    iterations: usize,
    repeat: usize,
    contiguous_mib_s: f64,
    chunk_join_mib_s: f64,
    chunk_direct_mib_s: f64,
    direct_over_contiguous: f64,
    direct_over_join: f64,
    join_over_contiguous: f64,
    mix: u64,
};

const specs = [_]CaseSpec{
    .{ .name = "png-rgb8-dynamic-64b", .width = 96, .height = 64, .bytes_per_pixel = 3, .encoder = .best, .chunk_bytes = 64 },
    .{ .name = "png-rgb8-dynamic-1b-empty", .width = 48, .height = 48, .bytes_per_pixel = 3, .encoder = .best, .chunk_bytes = 1, .include_empty_chunks = true },
    .{ .name = "png-rgba8-stored-256b", .width = 128, .height = 96, .bytes_per_pixel = 4, .encoder = .stored, .chunk_bytes = 256 },
    .{ .name = "png-indexed-stored-1b-empty", .width = 96, .height = 64, .bytes_per_pixel = 1, .encoder = .stored, .chunk_bytes = 1, .include_empty_chunks = true },
    .{ .name = "png-indexed-stored-7b-empty", .width = 257, .height = 48, .bytes_per_pixel = 1, .encoder = .stored, .chunk_bytes = 7, .include_empty_chunks = true },
    .{ .name = "png-literal-16b", .width = 80, .height = 80, .bytes_per_pixel = 3, .encoder = .dynamic_literal, .chunk_bytes = 16 },
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var markdown_path: ?[]const u8 = null;
    var iterations_override: ?usize = null;
    var repeat: usize = 1;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--iterations")) {
            iterations_override = try std.fmt.parseInt(usize, args.next() orelse return error.MissingReportPath, 10);
            if (iterations_override.? == 0) return error.InvalidBlockPlan;
            continue;
        }
        if (std.mem.eql(u8, arg, "--repeat")) {
            repeat = try std.fmt.parseInt(usize, args.next() orelse return error.MissingReportPath, 10);
            if (repeat == 0) return error.InvalidBlockPlan;
            continue;
        }
        return error.UnknownArgument;
    }

    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(init.gpa);
    for (&specs) |spec| try rows.append(init.gpa, try measureSpecRepeated(init, spec, iterations_override, repeat));

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, rows.items);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(csv.written());
    try stdout.flush();

    if (csv_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    if (markdown_path) |path| {
        var markdown = std.Io.Writer.Allocating.init(init.gpa);
        defer markdown.deinit();
        try writeMarkdown(&markdown.writer, rows.items);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = markdown.written() });
    }
}

fn measureSpecRepeated(init: std.process.Init, spec: CaseSpec, iterations_override: ?usize, repeat: usize) !Row {
    var best: ?Row = null;
    var best_score: f64 = std.math.inf(f64);
    var i: usize = 0;
    while (i < repeat) : (i += 1) {
        const row = try measureSpec(init, spec, iterations_override, repeat);
        const score = inverseThroughput(row.contiguous_mib_s) + inverseThroughput(row.chunk_join_mib_s) + inverseThroughput(row.chunk_direct_mib_s);
        if (score < best_score) {
            best_score = score;
            best = row;
        }
    }
    return best.?;
}

fn measureSpec(init: std.process.Init, spec: CaseSpec, iterations_override: ?usize, repeat: usize) !Row {
    const payload = try makePngLikePayload(init.gpa, spec.width, spec.height, spec.bytes_per_pixel);
    defer init.gpa.free(payload);
    const frame = try encodeFrame(init.gpa, payload, spec.encoder);
    defer init.gpa.free(frame);
    const chunks = try makeChunks(init.gpa, frame, spec.chunk_bytes, spec.include_empty_chunks);
    defer init.gpa.free(chunks);

    const iterations = iterations_override orelse iterationsFor(payload.len);
    const out = try init.gpa.alloc(u8, payload.len);
    defer init.gpa.free(out);
    const compressed_scratch = try init.gpa.alloc(u8, frame.len);
    defer init.gpa.free(compressed_scratch);

    try verifyContiguous(frame, payload, out);
    try verifyChunkJoin(chunks, compressed_scratch, payload, out);
    try verifyChunkDirect(chunks, payload, out);

    const contiguous = try benchContiguous(init, frame, payload, out, iterations);
    const chunk_join = try benchChunkJoin(init, chunks, compressed_scratch, payload, out, iterations);
    const chunk_direct = try benchChunkDirect(init, chunks, payload, out, iterations);
    const mix = contiguous.mix +% chunk_join.mix +% chunk_direct.mix;

    const contiguous_mib_s = throughput(payload.len, iterations, contiguous.elapsed_ns);
    const chunk_join_mib_s = throughput(payload.len, iterations, chunk_join.elapsed_ns);
    const chunk_direct_mib_s = throughput(payload.len, iterations, chunk_direct.elapsed_ns);
    return .{
        .name = spec.name,
        .encoder = encoderName(spec.encoder),
        .input_bytes = payload.len,
        .zlib_bytes = frame.len,
        .chunk_bytes = spec.chunk_bytes,
        .chunk_count = chunks.len,
        .include_empty_chunks = spec.include_empty_chunks,
        .iterations = iterations,
        .repeat = repeat,
        .contiguous_mib_s = contiguous_mib_s,
        .chunk_join_mib_s = chunk_join_mib_s,
        .chunk_direct_mib_s = chunk_direct_mib_s,
        .direct_over_contiguous = ratio(chunk_direct_mib_s, contiguous_mib_s),
        .direct_over_join = ratio(chunk_direct_mib_s, chunk_join_mib_s),
        .join_over_contiguous = ratio(chunk_join_mib_s, contiguous_mib_s),
        .mix = mix,
    };
}

const BenchResult = struct { elapsed_ns: i128, mix: u64 };

fn benchContiguous(init: std.process.Init, frame: []const u8, payload: []const u8, out: []u8, iterations: usize) !BenchResult {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const written = try vort.decodeZlib(frame, out);
        if (written != payload.len or !std.mem.eql(u8, out[0..written], payload)) return error.DecodeLengthMismatch;
        mix +%= written;
        if (written != 0) mix +%= out[0];
    }
    return .{ .elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), .mix = mix };
}

fn benchChunkJoin(init: std.process.Init, chunks: []const []const u8, compressed_scratch: []u8, payload: []const u8, out: []u8, iterations: usize) !BenchResult {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const written = try vort.decodeZlibChunks(chunks, compressed_scratch, out);
        if (written != payload.len or !std.mem.eql(u8, out[0..written], payload)) return error.DecodeLengthMismatch;
        mix +%= written;
        if (written != 0) mix +%= out[0];
    }
    return .{ .elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), .mix = mix };
}

fn benchChunkDirect(init: std.process.Init, chunks: []const []const u8, payload: []const u8, out: []u8, iterations: usize) !BenchResult {
    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const written = try vort.decodeZlibChunksInto(chunks, out);
        if (written != payload.len or !std.mem.eql(u8, out[0..written], payload)) return error.DecodeLengthMismatch;
        mix +%= written;
        if (written != 0) mix +%= out[0];
    }
    return .{ .elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), .mix = mix };
}

fn verifyContiguous(frame: []const u8, payload: []const u8, out: []u8) !void {
    const written = try vort.decodeZlib(frame, out);
    if (written != payload.len or !std.mem.eql(u8, out[0..written], payload)) return error.DecodeLengthMismatch;
}

fn verifyChunkJoin(chunks: []const []const u8, compressed_scratch: []u8, payload: []const u8, out: []u8) !void {
    const written = try vort.decodeZlibChunks(chunks, compressed_scratch, out);
    if (written != payload.len or !std.mem.eql(u8, out[0..written], payload)) return error.DecodeLengthMismatch;
}

fn verifyChunkDirect(chunks: []const []const u8, payload: []const u8, out: []u8) !void {
    const written = try vort.decodeZlibChunksInto(chunks, out);
    if (written != payload.len or !std.mem.eql(u8, out[0..written], payload)) return error.DecodeLengthMismatch;
}

fn makePngLikePayload(allocator: std.mem.Allocator, width: usize, height: usize, bytes_per_pixel: usize) ![]u8 {
    const row_len = std.math.mul(usize, width, bytes_per_pixel) catch return error.IntegerOverflow;
    const stride = std.math.add(usize, row_len, 1) catch return error.IntegerOverflow;
    const total = std.math.mul(usize, stride, height) catch return error.IntegerOverflow;
    const out = try allocator.alloc(u8, total);
    errdefer allocator.free(out);
    var offset: usize = 0;
    for (0..height) |y| {
        out[offset] = @intCast(y % 5);
        offset += 1;
        for (0..row_len) |x| {
            // Deterministic image-like bytes: nearby rows are correlated, but
            // not all equal. This keeps dynamic Huffman and stored-block chunked
            // paths visible without depending on external PNG files.
            out[offset + x] = @intCast((x * 17 + y * 31 + (x / @max(bytes_per_pixel, 1)) * 3) & 0xff);
        }
        offset += row_len;
    }
    return out;
}

fn encodeFrame(allocator: std.mem.Allocator, payload: []const u8, encoder: Encoder) ![]u8 {
    return switch (encoder) {
        .best => vort.encodeZlibBestAlloc(allocator, payload, .{}),
        .stored => vort.encodeZlibStoredAlloc(allocator, payload),
        .dynamic_literal => vort.encodeZlibDynamicLiteralAlloc(allocator, payload),
    };
}

fn makeChunks(allocator: std.mem.Allocator, frame: []const u8, chunk_bytes: usize, include_empty_chunks: bool) ![][]const u8 {
    if (chunk_bytes == 0) return error.InvalidBlockPlan;
    var chunks: std.ArrayList([]const u8) = .empty;
    errdefer chunks.deinit(allocator);
    var offset: usize = 0;
    while (offset < frame.len) {
        if (include_empty_chunks) try chunks.append(allocator, frame[offset..offset]);
        const n = @min(chunk_bytes, frame.len - offset);
        try chunks.append(allocator, frame[offset..][0..n]);
        offset += n;
    }
    if (include_empty_chunks) try chunks.append(allocator, frame[frame.len..frame.len]);
    return chunks.toOwnedSlice(allocator);
}

fn iterationsFor(size: usize) usize {
    const target_bytes: usize = 96 * 1024 * 1024;
    return @max(@as(usize, 16), @min(@as(usize, 4000), target_bytes / @max(size, 1)));
}

fn throughput(size: usize, iterations: usize, elapsed_ns: i128) f64 {
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    if (seconds == 0) return 0;
    const mib = (@as(f64, @floatFromInt(size)) * @as(f64, @floatFromInt(iterations))) / (1024.0 * 1024.0);
    return mib / seconds;
}

fn ratio(num: f64, denom: f64) f64 {
    return if (denom == 0) 0 else num / denom;
}

fn inverseThroughput(value: f64) f64 {
    return if (value <= 0) std.math.inf(f64) else 1.0 / value;
}

fn encoderName(encoder: Encoder) []const u8 {
    return switch (encoder) {
        .best => "best",
        .stored => "stored",
        .dynamic_literal => "dynamic_literal",
    };
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("case,encoder,input_bytes,zlib_bytes,chunk_bytes,chunk_count,include_empty_chunks,iterations,repeat,contiguous_mib_s,chunk_join_mib_s,chunk_direct_mib_s,direct_over_contiguous,direct_over_join,join_over_contiguous,mix\n");
    for (rows) |row| {
        try writer.print("{s},{s},{d},{d},{d},{d},{},{d},{d},{d:.2},{d:.2},{d:.2},{d:.4},{d:.4},{d:.4},{d}\n", .{
            row.name,
            row.encoder,
            row.input_bytes,
            row.zlib_bytes,
            row.chunk_bytes,
            row.chunk_count,
            row.include_empty_chunks,
            row.iterations,
            row.repeat,
            row.contiguous_mib_s,
            row.chunk_join_mib_s,
            row.chunk_direct_mib_s,
            row.direct_over_contiguous,
            row.direct_over_join,
            row.join_over_contiguous,
            row.mix,
        });
    }
}

fn writeMarkdown(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll(
        \\# Chunked zlib decode benchmark
        \\
        \\PNG IDAT commonly arrives as multiple zlib byte chunks. These rows compare contiguous zlib decode, legacy join-then-decode chunks, and direct chunked decode into caller output scratch. Throughput ratios above 1.0 are better.
        \\
        \\| case | encoder | input bytes | zlib bytes | chunk bytes | chunks | empty chunks | iterations | repeat | contiguous MiB/s | join MiB/s | direct MiB/s | direct/contiguous | direct/join | join/contiguous |
        \\| --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
        \\
    );
    for (rows) |row| {
        try writer.print("| {s} | {s} | {d} | {d} | {d} | {d} | {} | {d} | {d} | {d:.2} | {d:.2} | {d:.2} | {d:.3} | {d:.3} | {d:.3} |\n", .{
            row.name,
            row.encoder,
            row.input_bytes,
            row.zlib_bytes,
            row.chunk_bytes,
            row.chunk_count,
            row.include_empty_chunks,
            row.iterations,
            row.repeat,
            row.contiguous_mib_s,
            row.chunk_join_mib_s,
            row.chunk_direct_mib_s,
            row.direct_over_contiguous,
            row.direct_over_join,
            row.join_over_contiguous,
        });
    }
}
