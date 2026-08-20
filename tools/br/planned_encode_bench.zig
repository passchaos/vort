const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

const json_payload = "{\"kind\":\"event\",\"active\":true,\"values\":[1,2,3,5,8,13]}\n" ** 48;
const source_payload = "pub fn update(state: *State, value: u32) void { state.total += value; state.count += 1; }\n" ** 40;
const log_payload = "2026-08-21T02:00:00Z level=info service=vort request=compress status=ok bytes=4096\n" ** 40;
const Case = struct { name: []const u8, payload: []const u8 };
const Options = struct { iterations: usize = 1000, csv_path: ?[]const u8 = null, quality: c_int = 3 };
const Sample = struct { ns: u64, mix: usize };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    var reference = try libbrotli.Runtime.open();
    defer reference.deinit();
    const cases = [_]Case{
        .{ .name = "json", .payload = json_payload },
        .{ .name = "source", .payload = source_payload },
        .{ .name = "log", .payload = log_payload },
    };
    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,reference_version,quality,input_bytes,vort_bytes,reference_bytes,iterations,vort_ns,reference_ns,vort_mib_s,reference_mib_s,vort_over_reference,vort_size_over_reference,checksum\n");
    for (cases) |case| {
        const vort_encoded = try vort.brEncodePlannedStreamAlloc(init.gpa, case.payload);
        defer init.gpa.free(vort_encoded);
        const reference_encoded = try reference.encodeAlloc(init.gpa, case.payload, options.quality);
        defer init.gpa.free(reference_encoded);
        const samples = try measureInterleaved(init.io, init.gpa, reference, case.payload, options);
        const total_bytes = case.payload.len * options.iterations;
        const vort_rate = mibPerSecond(total_bytes, samples.vort.ns);
        const reference_rate = mibPerSecond(total_bytes, samples.reference.ns);
        try csv.writer.print("{s},{x},{d},{d},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.4},{d:.4},{d}\n", .{
            case.name,                                                                                  reference.version(),                       options.quality,      case.payload.len, vort_encoded.len, reference_encoded.len,
            options.iterations,                                                                         samples.vort.ns,                           samples.reference.ns, vort_rate,        reference_rate,   vort_rate / reference_rate,
            @as(f64, @floatFromInt(vort_encoded.len)) / @as(f64, @floatFromInt(reference_encoded.len)), samples.vort.mix +% samples.reference.mix,
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

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options = Options{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--quality")) options.quality = try std.fmt.parseInt(c_int, args.next() orelse return error.MissingLimit, 10) else if (std.mem.eql(u8, arg, "--csv")) options.csv_path = args.next() orelse return error.MissingCorpusPath else return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.quality < 0 or options.quality > 11) return error.InvalidBlockPlan;
    return options;
}
