const std = @import("std");
const vort = @import("vort");

const HistoryDictionary = "prefix:";
const HistoryPayload = HistoryDictionary ** 128;
const JsonDictionary = "{\"service\":\"vort\",\"level\":\"";
const JsonPayload = "{\"service\":\"vort\",\"level\":\"default\",\"message\":\"dictionary decode bench\"}\n" ** 8;
const LogDictionary = "2026-07-14T00:00:00Z INFO vort request_id=";
const LogPayload = "2026-07-14T00:00:00Z INFO vort request_id=alpha path=/deflate status=200\n" ** 8;

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

const Mode = enum {
    alloc,
    exact_alloc,
    into,

    fn label(self: Mode) []const u8 {
        return switch (self) {
            .alloc => "alloc",
            .exact_alloc => "exact_alloc",
            .into => "into",
        };
    }
};

const Fixture = struct {
    name: []const u8,
    dictionary: []const u8,
    payload: []const u8,
};

const Case = struct {
    name: []const u8,
    owned_name: bool = false,
    fixture: Fixture,
    format: Format,
    encoder: Encoder,
    mode: Mode,
    compressed: []u8,

    fn deinit(self: Case, allocator: std.mem.Allocator) void {
        if (self.owned_name) allocator.free(self.name);
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

    const fixtures = [_]Fixture{
        .{ .name = "history-replay", .dictionary = HistoryDictionary, .payload = HistoryPayload },
        .{ .name = "json-prefix", .dictionary = JsonDictionary, .payload = JsonPayload },
        .{ .name = "log-prefix", .dictionary = LogDictionary, .payload = LogPayload },
    };
    const case_specs = [_]struct { fixture_index: usize, format: Format, encoder: Encoder, mode: Mode }{
        .{ .fixture_index = 0, .format = .raw, .encoder = .dynamic, .mode = .alloc },
        .{ .fixture_index = 0, .format = .raw, .encoder = .dynamic, .mode = .exact_alloc },
        .{ .fixture_index = 0, .format = .raw, .encoder = .dynamic, .mode = .into },
        .{ .fixture_index = 0, .format = .raw, .encoder = .best, .mode = .alloc },
        .{ .fixture_index = 0, .format = .zlib, .encoder = .fixed, .mode = .alloc },
        .{ .fixture_index = 0, .format = .zlib, .encoder = .fixed, .mode = .exact_alloc },
        .{ .fixture_index = 0, .format = .zlib, .encoder = .fixed, .mode = .into },
        .{ .fixture_index = 0, .format = .zlib, .encoder = .dynamic, .mode = .alloc },
        .{ .fixture_index = 0, .format = .zlib, .encoder = .dynamic, .mode = .exact_alloc },
        .{ .fixture_index = 0, .format = .zlib, .encoder = .dynamic, .mode = .into },
        .{ .fixture_index = 1, .format = .raw, .encoder = .dynamic, .mode = .alloc },
        .{ .fixture_index = 1, .format = .raw, .encoder = .dynamic, .mode = .into },
        .{ .fixture_index = 1, .format = .zlib, .encoder = .dynamic, .mode = .alloc },
        .{ .fixture_index = 1, .format = .zlib, .encoder = .dynamic, .mode = .into },
        .{ .fixture_index = 2, .format = .raw, .encoder = .dynamic, .mode = .alloc },
        .{ .fixture_index = 2, .format = .raw, .encoder = .dynamic, .mode = .into },
        .{ .fixture_index = 2, .format = .zlib, .encoder = .dynamic, .mode = .alloc },
        .{ .fixture_index = 2, .format = .zlib, .encoder = .dynamic, .mode = .into },
    };

    var cases: std.ArrayList(Case) = .empty;
    defer {
        for (cases.items) |case| case.deinit(init.gpa);
        cases.deinit(init.gpa);
    }
    for (case_specs) |spec| {
        const fixture = fixtures[spec.fixture_index];
        const name = try std.fmt.allocPrint(init.gpa, "{s}-{s}-{s}-{s}", .{ fixture.name, spec.format.label(), spec.encoder.label(), spec.mode.label() });
        var name_owned = true;
        defer if (name_owned) init.gpa.free(name);
        const case = try makeCase(init.gpa, name, fixture, spec.format, spec.encoder, spec.mode);
        try cases.append(init.gpa, case);
        name_owned = false;
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,format,encoder,mode,input_bytes,dict_bytes,compressed_bytes,iterations,repeat,output_bytes,elapsed_ns,decode_mib_s,checksum\n");

    for (cases.items) |case| {
        const iterations = iterations_override orelse iterationsFor(case.fixture.payload.len);
        const result = try measureRepeated(init, case, iterations, repeat);
        try csv.writer.print("{s},{s},{s},{s},{d},{d},{d},{d},{d},{d},{d},{d:.2},{d}\n", .{
            case.name,
            case.format.label(),
            case.encoder.label(),
            case.mode.label(),
            case.fixture.payload.len,
            case.fixture.dictionary.len,
            case.compressed.len,
            iterations,
            repeat,
            result.output_bytes,
            result.elapsed_ns,
            mibPerSecond(result.output_bytes, result.elapsed_ns),
            result.checksum,
        });
        std.debug.print("dictionary decode bench: case={s} format={s} encoder={s} mode={s} compressed_bytes={d} iterations={d} repeat={d} output_bytes={d} elapsed_ns={d} decode_mib_s={d:.2} checksum={d}\n", .{
            case.name,
            case.format.label(),
            case.encoder.label(),
            case.mode.label(),
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

fn makeCase(allocator: std.mem.Allocator, name: []const u8, fixture: Fixture, format: Format, encoder: Encoder, mode: Mode) !Case {
    const options = vort.optionsForCompressionLevel(.default);
    const compressed = switch (format) {
        .raw => switch (encoder) {
            .dynamic => try vort.encodeRawDynamicWithDictionaryAlloc(allocator, fixture.payload, fixture.dictionary, options),
            .best => try vort.encodeRawBestWithDictionaryAlloc(allocator, fixture.payload, fixture.dictionary, options),
            .fixed => unreachable,
        },
        .zlib => switch (encoder) {
            .fixed => try vort.encodeZlibFixedWithDictionaryAlloc(allocator, fixture.payload, fixture.dictionary, options),
            .dynamic => try vort.encodeZlibDynamicWithDictionaryAlloc(allocator, fixture.payload, fixture.dictionary, options),
            .best => try vort.encodeZlibBestWithDictionaryAlloc(allocator, fixture.payload, fixture.dictionary, options),
        },
    };
    errdefer allocator.free(compressed);
    try verifyDecode(allocator, format, compressed, fixture);
    return .{ .name = name, .owned_name = true, .fixture = fixture, .format = format, .encoder = encoder, .mode = mode, .compressed = compressed };
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
        switch (case.mode) {
            .alloc => {
                const decoded = switch (case.format) {
                    .raw => try vort.decodeRawDeflateAllocWithDictionary(init.gpa, case.compressed, case.fixture.dictionary),
                    .zlib => try vort.decodeZlibAllocWithDictionary(init.gpa, case.compressed, case.fixture.dictionary),
                };
                defer init.gpa.free(decoded);
                if (!std.mem.eql(u8, case.fixture.payload, decoded)) return error.RoundTripMismatch;
                checksum +%= sparseChecksum(decoded) +% i;
            },
            .exact_alloc => {
                const decoded = switch (case.format) {
                    .raw => try vort.decodeRawDeflateAllocWithDictionaryExactSize(init.gpa, case.compressed, case.fixture.dictionary, case.fixture.payload.len),
                    .zlib => try vort.decodeZlibAllocWithDictionaryExactSize(init.gpa, case.compressed, case.fixture.dictionary, case.fixture.payload.len),
                };
                defer init.gpa.free(decoded);
                if (!std.mem.eql(u8, case.fixture.payload, decoded)) return error.RoundTripMismatch;
                checksum +%= sparseChecksum(decoded) +% i;
            },
            .into => {
                const out = try init.gpa.alloc(u8, case.fixture.payload.len);
                defer init.gpa.free(out);
                const written = switch (case.format) {
                    .raw => (try vort.decodeRawDeflateWithDictionary(case.compressed, case.fixture.dictionary, out)).output_written,
                    .zlib => try vort.decodeZlibWithDictionary(case.compressed, out, case.fixture.dictionary),
                };
                if (written != case.fixture.payload.len) return error.RoundTripMismatch;
                if (!std.mem.eql(u8, case.fixture.payload, out)) return error.RoundTripMismatch;
                checksum +%= sparseChecksum(out) +% i;
            },
        }
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    return .{
        .output_bytes = case.fixture.payload.len * iterations,
        .elapsed_ns = elapsed_ns,
        .checksum = checksum,
    };
}

fn verifyDecode(allocator: std.mem.Allocator, format: Format, compressed: []const u8, fixture: Fixture) !void {
    const decoded = switch (format) {
        .raw => try vort.decodeRawDeflateAllocWithDictionary(allocator, compressed, fixture.dictionary),
        .zlib => try vort.decodeZlibAllocWithDictionary(allocator, compressed, fixture.dictionary),
    };
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, fixture.payload, decoded)) return error.RoundTripMismatch;
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
