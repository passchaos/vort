const std = @import("std");
const vort = @import("vort");

const Encoder = enum { dynamic, fixed };
const Pattern = enum { zero, abcd, vertical_delta, repeated_row };

const CaseSpec = struct {
    name: []const u8,
    width: usize,
    height: usize,
    bytes_per_pixel: usize,
    encoder: Encoder,
    pattern: Pattern,
    chunk_bytes: usize,
};

const Row = struct {
    name: []const u8,
    encoder: []const u8,
    pattern: []const u8,
    width: usize,
    height: usize,
    row_bytes: usize,
    image_bytes: usize,
    zlib_bytes: usize,
    chunk_bytes: usize,
    chunk_count: usize,
    iterations: usize,
    repeat: usize,
    contiguous_mib_s: f64,
    chunked_mib_s: f64,
    chunked_over_contiguous: f64,
    mix: u64,
};

const specs = [_]CaseSpec{
    .{ .name = "png-stream-rle-dynamic", .width = 2048, .height = 64, .bytes_per_pixel = 1, .encoder = .dynamic, .pattern = .zero, .chunk_bytes = 64 },
    .{ .name = "png-stream-up-filter-dynamic", .width = 2048, .height = 64, .bytes_per_pixel = 1, .encoder = .dynamic, .pattern = .vertical_delta, .chunk_bytes = 64 },
    .{ .name = "png-stream-small-distance-dynamic", .width = 1024, .height = 64, .bytes_per_pixel = 4, .encoder = .dynamic, .pattern = .abcd, .chunk_bytes = 64 },
    .{ .name = "png-stream-row-repeat-dynamic", .width = 1024, .height = 96, .bytes_per_pixel = 3, .encoder = .dynamic, .pattern = .repeated_row, .chunk_bytes = 32 },
    .{ .name = "png-stream-row-repeat-fixed", .width = 1024, .height = 64, .bytes_per_pixel = 3, .encoder = .fixed, .pattern = .repeated_row, .chunk_bytes = 32 },
    .{ .name = "png-stream-wide-rle-dynamic", .width = 65536, .height = 16, .bytes_per_pixel = 1, .encoder = .dynamic, .pattern = .zero, .chunk_bytes = 64 },
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var iterations_override: ?usize = null;
    var repeat: usize = 1;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingReportPath;
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
}

fn measureSpecRepeated(init: std.process.Init, spec: CaseSpec, iterations_override: ?usize, repeat: usize) !Row {
    var best: ?Row = null;
    var best_score: f64 = std.math.inf(f64);
    var i: usize = 0;
    while (i < repeat) : (i += 1) {
        const row = try measureSpec(init, spec, iterations_override, repeat);
        const score = inverseThroughput(row.contiguous_mib_s) + inverseThroughput(row.chunked_mib_s);
        if (score < best_score) {
            best_score = score;
            best = row;
        }
    }
    return best.?;
}

fn measureSpec(init: std.process.Init, spec: CaseSpec, iterations_override: ?usize, repeat: usize) !Row {
    const row_len = spec.width * spec.bytes_per_pixel;
    const image_len = row_len * spec.height;
    const filtered_len = (row_len + 1) * spec.height;
    const image = try init.gpa.alloc(u8, image_len);
    defer init.gpa.free(image);
    const filtered = try init.gpa.alloc(u8, filtered_len);
    defer init.gpa.free(filtered);
    fillPngPayload(spec, image, filtered);

    const frame = try encodeFrame(init.gpa, filtered, spec.encoder);
    defer init.gpa.free(frame);
    const chunks = try makeChunks(init.gpa, frame, spec.chunk_bytes);
    defer init.gpa.free(chunks);

    const info = try vort.pngImageInfo(spec.width, spec.height, 8, colorTypeForBpp(spec.bytes_per_pixel));
    if (info.row_len != row_len) return error.DecodeLengthMismatch;

    const iterations = iterations_override orelse iterationsFor(image_len);
    const contiguous = try benchContiguous(init, frame, info, image, row_len, iterations);
    const chunked = try benchChunked(init, chunks, info, image, row_len, iterations);
    const contiguous_mib_s = throughput(image_len, iterations, contiguous.elapsed_ns);
    const chunked_mib_s = throughput(image_len, iterations, chunked.elapsed_ns);
    return .{
        .name = spec.name,
        .encoder = encoderName(spec.encoder),
        .pattern = patternName(spec.pattern),
        .width = spec.width,
        .height = spec.height,
        .row_bytes = row_len,
        .image_bytes = image_len,
        .zlib_bytes = frame.len,
        .chunk_bytes = spec.chunk_bytes,
        .chunk_count = chunks.len,
        .iterations = iterations,
        .repeat = repeat,
        .contiguous_mib_s = contiguous_mib_s,
        .chunked_mib_s = chunked_mib_s,
        .chunked_over_contiguous = ratio(chunked_mib_s, contiguous_mib_s),
        .mix = contiguous.mix +% chunked.mix,
    };
}

const BenchResult = struct { elapsed_ns: i128, mix: u64 };

fn benchContiguous(init: std.process.Init, frame: []const u8, info: vort.PngImageInfo, expected: []const u8, row_len: usize, iterations: usize) !BenchResult {
    var history: [vort.PngStreamingZlibScanlineDecoder.history_scratch_len]u8 = undefined;
    const filtered_row = try init.gpa.alloc(u8, row_len);
    defer init.gpa.free(filtered_row);
    const previous_row = try init.gpa.alloc(u8, row_len);
    defer init.gpa.free(previous_row);
    const out_row = try init.gpa.alloc(u8, row_len);
    defer init.gpa.free(out_row);

    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        var decoder = try vort.PngStreamingZlibScanlineDecoder.initWithInfo(frame, &history, filtered_row, previous_row, info);
        mix +%= try drainRows(&decoder, expected, out_row, row_len);
    }
    return .{ .elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), .mix = mix };
}

fn benchChunked(init: std.process.Init, chunks: []const []const u8, info: vort.PngImageInfo, expected: []const u8, row_len: usize, iterations: usize) !BenchResult {
    var history: [vort.PngStreamingZlibChunkedScanlineDecoder.history_scratch_len]u8 = undefined;
    const filtered_row = try init.gpa.alloc(u8, row_len);
    defer init.gpa.free(filtered_row);
    const previous_row = try init.gpa.alloc(u8, row_len);
    defer init.gpa.free(previous_row);
    const out_row = try init.gpa.alloc(u8, row_len);
    defer init.gpa.free(out_row);

    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        var decoder = try vort.PngStreamingZlibChunkedScanlineDecoder.initWithInfo(chunks, &history, filtered_row, previous_row, info);
        mix +%= try drainRows(&decoder, expected, out_row, row_len);
    }
    return .{ .elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(), .mix = mix };
}

fn drainRows(decoder: anytype, expected: []const u8, out_row: []u8, row_len: usize) !u64 {
    var mix: u64 = 0;
    var offset: usize = 0;
    while (offset < expected.len) : (offset += row_len) {
        const step = try decoder.step(out_row);
        if (step.row_bytes != row_len) return error.DecodeLengthMismatch;
        if (!std.mem.eql(u8, out_row, expected[offset..][0..row_len])) return error.DecodeLengthMismatch;
        mix +%= step.progress.output_written;
        if (row_len != 0) mix +%= out_row[0];
    }
    if (!decoder.snapshot().done) return error.DecodeLengthMismatch;
    return mix;
}

fn fillPngPayload(spec: CaseSpec, image: []u8, filtered: []u8) void {
    const row_len = spec.width * spec.bytes_per_pixel;
    var image_offset: usize = 0;
    var filtered_offset: usize = 0;
    for (0..spec.height) |y| {
        const filter: u8 = if (spec.pattern == .vertical_delta and y != 0) 2 else 0;
        filtered[filtered_offset] = filter;
        filtered_offset += 1;
        for (0..row_len) |x| {
            const reconstructed: u8 = switch (spec.pattern) {
                .zero => 0,
                .abcd => "ABCD"[x % 4],
                .vertical_delta => @intCast((x * 17 + y * 29 + spec.bytes_per_pixel * 13) & 0xff),
                .repeated_row => @intCast((x * 31 + (x / @max(spec.bytes_per_pixel, 1)) * 7 + 13) & 0xff),
            };
            image[image_offset + x] = reconstructed;
            filtered[filtered_offset + x] = if (filter == 2)
                reconstructed -% image[image_offset + x - row_len]
            else
                reconstructed;
        }
        image_offset += row_len;
        filtered_offset += row_len;
    }
}

fn encodeFrame(allocator: std.mem.Allocator, filtered: []const u8, encoder: Encoder) ![]u8 {
    const options = vort.optionsForCompressionLevel(.default);
    return switch (encoder) {
        .dynamic => vort.encodeZlibDynamicWithOptionsAlloc(allocator, filtered, options),
        .fixed => vort.encodeZlibFixedWithOptionsAlloc(allocator, filtered, options),
    };
}

fn makeChunks(allocator: std.mem.Allocator, frame: []const u8, chunk_bytes: usize) ![][]const u8 {
    if (chunk_bytes == 0) return error.InvalidBlockPlan;
    var chunks: std.ArrayList([]const u8) = .empty;
    errdefer chunks.deinit(allocator);
    var offset: usize = 0;
    while (offset < frame.len) {
        const n = @min(chunk_bytes, frame.len - offset);
        try chunks.append(allocator, frame[offset..][0..n]);
        offset += n;
    }
    return chunks.toOwnedSlice(allocator);
}

fn colorTypeForBpp(bytes_per_pixel: usize) vort.PngColorType {
    return switch (bytes_per_pixel) {
        1 => .grayscale,
        3 => .truecolor,
        4 => .truecolor_alpha,
        else => .grayscale,
    };
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
        .dynamic => "dynamic",
        .fixed => "fixed",
    };
}

fn patternName(pattern: Pattern) []const u8 {
    return switch (pattern) {
        .zero => "zero",
        .abcd => "abcd",
        .vertical_delta => "vertical_delta",
        .repeated_row => "repeated_row",
    };
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("case,encoder,pattern,width,height,row_bytes,image_bytes,zlib_bytes,chunk_bytes,chunk_count,iterations,repeat,contiguous_mib_s,chunked_mib_s,chunked_over_contiguous,mix\n");
    for (rows) |row| {
        try writer.print("{s},{s},{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.4},{d}\n", .{
            row.name,
            row.encoder,
            row.pattern,
            row.width,
            row.height,
            row.row_bytes,
            row.image_bytes,
            row.zlib_bytes,
            row.chunk_bytes,
            row.chunk_count,
            row.iterations,
            row.repeat,
            row.contiguous_mib_s,
            row.chunked_mib_s,
            row.chunked_over_contiguous,
            row.mix,
        });
    }
}
