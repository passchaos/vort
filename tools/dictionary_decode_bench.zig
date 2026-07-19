const std = @import("std");
const vort = @import("vort");

const dictionary = "prefix:";
const payload = dictionary ** 128;

const Format = enum {
    raw,
    zlib,

    fn label(self: Format) []const u8 {
        return switch (self) {
            .raw => "raw",
            .zlib => "zlib",
        };
    }
};

const Encoder = enum {
    dynamic,
    best,
    fixed,

    fn label(self: Encoder) []const u8 {
        return switch (self) {
            .dynamic => "dynamic",
            .best => "best",
            .fixed => "fixed",
        };
    }
};

const Case = struct {
    name: []const u8,
    format: Format,
    encoder: Encoder,
    compressed: []u8,

    fn deinit(self: Case, allocator: std.mem.Allocator) void {
        allocator.free(self.compressed);
    }
};

const Result = struct {
    output_bytes: usize,
    elapsed_ns: i128,
    checksum: u64,
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

    var raw_dynamic = try makeCase(init.gpa, "history-replay-raw-dynamic", .raw, .dynamic);
    defer raw_dynamic.deinit(init.gpa);
    var raw_best = try makeCase(init.gpa, "history-replay-raw-best", .raw, .best);
    defer raw_best.deinit(init.gpa);
    var zlib_fixed = try makeCase(init.gpa, "history-replay-zlib-fixed", .zlib, .fixed);
    defer zlib_fixed.deinit(init.gpa);
    var zlib_dynamic = try makeCase(init.gpa, "history-replay-zlib-dynamic", .zlib, .dynamic);
    defer zlib_dynamic.deinit(init.gpa);

    const cases = [_]Case{ raw_dynamic, raw_best, zlib_fixed, zlib_dynamic };
    const iterations = iterations_override orelse iterationsFor(payload.len);

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,format,encoder,input_bytes,dict_bytes,compressed_bytes,iterations,repeat,output_bytes,elapsed_ns,decode_mib_s,checksum\n");

    for (cases) |case| {
        const result = try measureRepeated(init, case, iterations, repeat);
        try csv.writer.print("{s},{s},{s},{d},{d},{d},{d},{d},{d},{d},{d:.2},{d}\n", .{
            case.name,
            case.format.label(),
            case.encoder.label(),
            payload.len,
            dictionary.len,
            case.compressed.len,
            iterations,
            repeat,
            result.output_bytes,
            result.elapsed_ns,
            mibPerSecond(result.output_bytes, result.elapsed_ns),
            result.checksum,
        });
        std.debug.print("dictionary decode bench: case={s} format={s} encoder={s} compressed_bytes={d} iterations={d} repeat={d} output_bytes={d} elapsed_ns={d} decode_mib_s={d:.2} checksum={d}\n", .{
            case.name,
            case.format.label(),
            case.encoder.label(),
            case.compressed.len,
            iterations,
            repeat,
            result.output_bytes,
            result.elapsed_ns,
            mibPerSecond(result.output_bytes, result.elapsed_ns),
            result.checksum,
        });
    }

    if (csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
        try stdout_writer.interface.writeAll(csv.written());
        try stdout_writer.interface.flush();
    }
}

fn makeCase(allocator: std.mem.Allocator, name: []const u8, format: Format, encoder: Encoder) !Case {
    const options = vort.optionsForCompressionLevel(.default);
    const compressed = switch (format) {
        .raw => switch (encoder) {
            .dynamic => try vort.encodeRawDynamicWithDictionaryAlloc(allocator, payload, dictionary, options),
            .best => try vort.encodeRawBestWithDictionaryAlloc(allocator, payload, dictionary, options),
            .fixed => unreachable,
        },
        .zlib => switch (encoder) {
            .fixed => try vort.encodeZlibFixedWithDictionaryAlloc(allocator, payload, dictionary, options),
            .dynamic => try vort.encodeZlibDynamicWithDictionaryAlloc(allocator, payload, dictionary, options),
            .best => try vort.encodeZlibBestWithDictionaryAlloc(allocator, payload, dictionary, options),
        },
    };
    errdefer allocator.free(compressed);
    try verifyDecode(allocator, format, compressed);
    return .{ .name = name, .format = format, .encoder = encoder, .compressed = compressed };
}

fn measureRepeated(init: std.process.Init, case: Case, iterations: usize, repeat: usize) !Result {
    var best: ?Result = null;
    var best_score: f64 = std.math.inf(f64);
    var i: usize = 0;
    while (i < repeat) : (i += 1) {
        const result = try measure(init, case, iterations);
        const score = inverseThroughput(mibPerSecond(result.output_bytes, result.elapsed_ns));
        if (score < best_score) {
            best_score = score;
            best = result;
        }
    }
    return best.?;
}

fn measure(init: std.process.Init, case: Case, iterations: usize) !Result {
    const start = std.Io.Clock.awake.now(init.io);
    var checksum: u64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const decoded = switch (case.format) {
            .raw => try vort.decodeRawDeflateAllocWithDictionary(init.gpa, case.compressed, dictionary),
            .zlib => try vort.decodeZlibAllocWithDictionary(init.gpa, case.compressed, dictionary),
        };
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, payload, decoded)) return error.RoundTripMismatch;
        checksum +%= sparseChecksum(decoded) +% i;
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    return .{
        .output_bytes = payload.len * iterations,
        .elapsed_ns = elapsed_ns,
        .checksum = checksum,
    };
}

fn verifyDecode(allocator: std.mem.Allocator, format: Format, compressed: []const u8) !void {
    const decoded = switch (format) {
        .raw => try vort.decodeRawDeflateAllocWithDictionary(allocator, compressed, dictionary),
        .zlib => try vort.decodeZlibAllocWithDictionary(allocator, compressed, dictionary),
    };
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.RoundTripMismatch;
}

fn iterationsFor(size: usize) usize {
    const target_bytes: usize = 64 * 1024 * 1024;
    return @max(@as(usize, 64), @min(@as(usize, 20000), target_bytes / @max(size, 1)));
}

fn sparseChecksum(bytes: []const u8) u64 {
    var sum: u64 = 0xcbf29ce484222325;
    const step = @max(@as(usize, 1), bytes.len / 32);
    var i: usize = 0;
    while (i < bytes.len) : (i += step) {
        sum = (sum ^ bytes[i]) *% 0x100000001b3;
    }
    return sum ^ bytes.len;
}

fn mibPerSecond(bytes: usize, elapsed_ns: i128) f64 {
    if (elapsed_ns <= 0) return 0;
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    return (@as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0)) / seconds;
}

fn inverseThroughput(value: f64) f64 {
    return if (value <= 0) std.math.inf(f64) else 1.0 / value;
}
