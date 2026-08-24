const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

const json_payload = "{\"kind\":\"event\",\"active\":true,\"values\":[1,2,3,5,8,13]}\n" ** 48;
const source_payload = "pub fn update(state: *State, value: u32) void { state.total += value; state.count += 1; }\n" ** 40;
const log_payload = "2026-08-21T02:00:00Z level=info service=vort request=compress status=ok bytes=4096\n" ** 40;
const Case = struct {
    name: []const u8,
    payload: []const u8,
    owned: bool = false,

    fn deinit(case: Case, allocator: std.mem.Allocator) void {
        if (case.owned) {
            allocator.free(case.name);
            allocator.free(case.payload);
        }
    }
};
const Options = struct {
    iterations: usize = 1000,
    csv_path: ?[]const u8 = null,
    quality: c_int = 3,
    path_limit: usize = 128 * 1024,
    paths: std.ArrayList([]const u8) = .empty,

    fn deinit(options: *Options, allocator: std.mem.Allocator) void {
        for (options.paths.items) |path| allocator.free(path);
        options.paths.deinit(allocator);
    }
};
const Sample = struct { ns: u64, mix: usize };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var options = try parseOptions(init.gpa, &args);
    defer options.deinit(init.gpa);
    var reference = try libbrotli.Runtime.open();
    defer reference.deinit();
    var cases: std.ArrayList(Case) = .empty;
    defer {
        for (cases.items) |case| case.deinit(init.gpa);
        cases.deinit(init.gpa);
    }
    if (options.paths.items.len == 0) {
        try cases.append(init.gpa, .{ .name = "json", .payload = json_payload });
        try cases.append(init.gpa, .{ .name = "source", .payload = source_payload });
        try cases.append(init.gpa, .{ .name = "log", .payload = log_payload });
    } else {
        for (options.paths.items, 0..) |path, index| {
            const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
            defer file.close(init.io);
            const stat = try file.stat(init.io);
            const read_len: usize = @intCast(@min(stat.size, options.path_limit));
            if (read_len == 0) continue;
            const payload = try init.gpa.alloc(u8, read_len);
            errdefer init.gpa.free(payload);
            var reader_buffer: [4096]u8 = undefined;
            var reader = file.reader(init.io, &reader_buffer);
            if (try reader.interface.readSliceShort(payload) != read_len) return error.InputTooSmall;
            const name = try caseNameForPath(init.gpa, path, index);
            errdefer init.gpa.free(name);
            try cases.append(init.gpa, .{ .name = name, .payload = payload, .owned = true });
        }
    }
    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,reference_version,quality,input_bytes,vort_bytes,lazy_bytes,ratio_bytes,reference_bytes,iterations,vort_ns,lazy_ns,ratio_ns,reference_ns,vort_mib_s,lazy_mib_s,ratio_mib_s,reference_mib_s,vort_over_reference,lazy_over_reference,ratio_over_reference,vort_size_over_reference,lazy_size_over_reference,ratio_size_over_reference,checksum\n");
    for (cases.items) |case| {
        const vort_encoded = try vort.brEncodePlannedStreamAlloc(init.gpa, case.payload);
        defer init.gpa.free(vort_encoded);
        const reference_encoded = try reference.encodeAlloc(init.gpa, case.payload, options.quality);
        defer init.gpa.free(reference_encoded);
        const lazy_encoded = try vort.brEncodePlannedStreamLazyAlloc(init.gpa, case.payload);
        defer init.gpa.free(lazy_encoded);
        const ratio_encoded = try vort.brEncodePlannedStreamRatioAlloc(init.gpa, case.payload);
        defer init.gpa.free(ratio_encoded);
        const decoded = try init.gpa.alloc(u8, case.payload.len);
        defer init.gpa.free(decoded);
        for ([_][]const u8{ vort_encoded, lazy_encoded, ratio_encoded }) |encoded| {
            try reference.decode(encoded, decoded);
            if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;
        }
        const samples = try measureInterleaved(init.io, init.gpa, reference, case.payload, options);
        const lazy_sample = try measurePlanned(init.io, init.gpa, case.payload, options.iterations, .balanced);
        const ratio_sample = try measurePlanned(init.io, init.gpa, case.payload, options.iterations, .ratio);
        const total_bytes = case.payload.len * options.iterations;
        const vort_rate = mibPerSecond(total_bytes, samples.vort.ns);
        const reference_rate = mibPerSecond(total_bytes, samples.reference.ns);
        const lazy_rate = mibPerSecond(total_bytes, lazy_sample.ns);
        const ratio_rate = mibPerSecond(total_bytes, ratio_sample.ns);
        try csv.writer.print("{s},{x},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.2},{d:.2},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d}\n", .{
            case.name,          reference.version(),        options.quality,            case.payload.len,            vort_encoded.len,                                                                           lazy_encoded.len,                                                                           ratio_encoded.len,                                                                           reference_encoded.len,
            options.iterations, samples.vort.ns,            lazy_sample.ns,             ratio_sample.ns,             samples.reference.ns,                                                                       vort_rate,                                                                                  lazy_rate,                                                                                   ratio_rate,
            reference_rate,     vort_rate / reference_rate, lazy_rate / reference_rate, ratio_rate / reference_rate, @as(f64, @floatFromInt(vort_encoded.len)) / @as(f64, @floatFromInt(reference_encoded.len)), @as(f64, @floatFromInt(lazy_encoded.len)) / @as(f64, @floatFromInt(reference_encoded.len)), @as(f64, @floatFromInt(ratio_encoded.len)) / @as(f64, @floatFromInt(reference_encoded.len)), samples.vort.mix +% lazy_sample.mix +% ratio_sample.mix +% samples.reference.mix,
        });
    }
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn measurePlanned(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, iterations: usize, level: vort.BrotliPlannedCompressionLevel) !Sample {
    var best = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
    for (0..5) |_| {
        var mix: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(allocator, payload, .{ .level = level });
            mix +%= encoded.len;
            allocator.free(encoded);
        }
        const sample = Sample{ .ns = elapsed(start, io), .mix = mix };
        if (sample.ns < best.ns) best = sample;
    }
    return best;
}

fn measureInterleaved(io: std.Io, allocator: std.mem.Allocator, reference: libbrotli.Runtime, payload: []const u8, options: Options) !struct { vort: Sample, reference: Sample } {
    var best_vort = Sample{ .ns = std.math.maxInt(u64), .mix = 0 };
    var best_reference = best_vort;
    for (0..5) |round| {
        const vort_first = round & 1 == 0;
        const first = if (vort_first) try measureVort(io, allocator, payload, options.iterations) else try measureReference(io, allocator, reference, payload, options);
        const second = if (vort_first) try measureReference(io, allocator, reference, payload, options) else try measureVort(io, allocator, payload, options.iterations);
        const vort_sample = if (vort_first) first else second;
        const reference_sample = if (vort_first) second else first;
        if (vort_sample.ns < best_vort.ns) best_vort = vort_sample;
        if (reference_sample.ns < best_reference.ns) best_reference = reference_sample;
    }
    return .{ .vort = best_vort, .reference = best_reference };
}

fn measureVort(io: std.Io, allocator: std.mem.Allocator, payload: []const u8, iterations: usize) !Sample {
    var mix: usize = 0;
    var encoder = vort.BrotliPlannedStreamEncoder.init(allocator);
    defer encoder.deinit();
    const warmup = try encoder.encodeAlloc(allocator, payload);
    allocator.free(warmup);
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try encoder.encodeAlloc(allocator, payload);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn measureReference(io: std.Io, allocator: std.mem.Allocator, reference: libbrotli.Runtime, payload: []const u8, options: Options) !Sample {
    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..options.iterations) |_| {
        const encoded = try reference.encodeAlloc(allocator, payload, options.quality);
        mix +%= encoded.len;
        allocator.free(encoded);
    }
    return .{ .ns = elapsed(start, io), .mix = mix };
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) / (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}

fn caseNameForPath(allocator: std.mem.Allocator, path: []const u8, index: usize) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    try out.writer.print("file{d}_", .{index});
    for (std.fs.path.basename(path)) |byte|
        try out.writer.writeByte(if (std.ascii.isAlphanumeric(byte)) byte else '_');
    return try out.toOwnedSlice();
}

fn parseOptions(allocator: std.mem.Allocator, args: *std.process.Args.Iterator) !Options {
    var options = Options{};
    errdefer options.deinit(allocator);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--quality")) options.quality = try std.fmt.parseInt(c_int, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--csv")) options.csv_path = args.next() orelse return error.MissingCorpusPath else if (std.mem.eql(u8, arg, "--limit")) options.path_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--path")) try options.paths.append(allocator, try allocator.dupe(u8, args.next() orelse return error.MissingCorpusPath)) else return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.path_limit == 0 or options.quality < 0 or options.quality > 11) return error.InvalidBlockPlan;
    return options;
}
