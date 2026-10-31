//! Allocation-inclusive BWT and one-shot encode measurements on caller files.
const std = @import("std");
const encoder = @import("bzip2_bench").encoder;
const reference = @import("bzip2_bench").reference;
const provenance = @import("benchmark_provenance");
const libbz2 = @import("libbz2_runtime.zig");

const Options = struct {
    input: ?[]const u8 = null,
    output: ?[]const u8 = null,
    scope: enum { bwt, encode, reference_encode } = .bwt,
    algorithm: enum { current, full } = .current,
    iterations: usize = 3,
    samples: usize = 5,
    block_size: u4 = 9,
    reference_library: ?[]const u8 = null,
    strategy: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var options: Options = .{};
    while (args.next()) |arg| {
        const value = args.next() orelse return error.MissingArgument;
        if (std.mem.eql(u8, arg, "--input")) {
            options.input = value;
        } else if (std.mem.eql(u8, arg, "--output")) {
            options.output = value;
        } else if (std.mem.eql(u8, arg, "--scope")) {
            options.scope = std.meta.stringToEnum(@TypeOf(options.scope), value) orelse return error.InvalidArgument;
        } else if (std.mem.eql(u8, arg, "--algorithm")) {
            options.algorithm = std.meta.stringToEnum(@TypeOf(options.algorithm), value) orelse return error.InvalidArgument;
        } else if (std.mem.eql(u8, arg, "--iterations")) {
            options.iterations = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.eql(u8, arg, "--samples")) {
            options.samples = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.eql(u8, arg, "--block-size")) {
            options.block_size = try std.fmt.parseInt(u4, value, 10);
        } else if (std.mem.eql(u8, arg, "--reference-library")) {
            options.reference_library = value;
        } else if (std.mem.eql(u8, arg, "--strategy")) {
            options.strategy = value;
        } else return error.InvalidArgument;
    }
    if (options.iterations == 0 or options.samples == 0 or
        options.block_size < 1 or options.block_size > 9 or
        (options.scope != .bwt and options.algorithm != .current)) return error.InvalidArgument;
    // Whole-encode comparisons may cover multi-block files. Raw BWT remains
    // bounded to one format block, with one extra byte needed to observe EOF.
    const input_limit: usize = if (options.scope == .bwt) 900_000 else 64 * 1024 * 1024;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, options.input orelse return error.MissingArgument, init.gpa, .limited(input_limit + 1));
    defer init.gpa.free(input);
    if ((input.len == 0 and options.scope == .bwt) or input.len > input_limit) return error.InvalidArgument;
    var encode_options: encoder.EncodeOptions = .{ .block_size_100k = options.block_size };
    if (comptime @hasField(encoder.EncodeOptions, "strategy")) {
        if (options.strategy) |name|
            encode_options.strategy = std.meta.stringToEnum(@TypeOf(encode_options.strategy), name) orelse return error.InvalidArgument;
    } else if (options.strategy) |name| {
        if (!std.mem.eql(u8, name, "legacy")) return error.InvalidArgument;
    }
    const strategy_name = if (options.scope == .reference_encode) "libbz2" else if (comptime @hasField(encoder.EncodeOptions, "strategy")) @tagName(encode_options.strategy) else "legacy";
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);

    // Exact comparison and hashes are outside the timed allocation/transform loop.
    const current = if (input.len != 0 and input.len <= 900_000) try encoder.bwtTransformAlloc(init.gpa, input) else null;
    defer if (current) |block| block.deinit(init.gpa);
    const full = if (input.len != 0 and input.len <= 900_000) try reference.transformAlloc(init.gpa, input) else null;
    defer if (full) |block| block.deinit(init.gpa);
    if (current) |block| {
        if (block.original_pointer != full.?.original_pointer or !std.mem.eql(u8, block.bytes, full.?.bytes))
            return error.ReferenceMismatch;
    }
    const library_path = if (options.reference_library) |path| try init.gpa.dupeZ(u8, path) else null;
    defer if (library_path) |path| init.gpa.free(path);
    var runtime: ?libbz2.Runtime = if (options.scope == .reference_encode)
        try libbz2.Runtime.open(library_path orelse return error.MissingArgument)
    else
        null;
    defer if (runtime) |*library| library.deinit();
    const encoded = switch (options.scope) {
        .bwt => null,
        .encode => try encoder.encodeAlloc(init.gpa, input, encode_options),
        .reference_encode => try runtime.?.encodeAlloc(init.gpa, input, options.block_size),
    };
    defer if (encoded) |bytes| init.gpa.free(bytes);
    const checked_output = encoded orelse current.?.bytes;
    var origin_buffer: [16]u8 = undefined;
    const origin_text = if (current) |block| try std.fmt.bufPrint(&origin_buffer, "{d}", .{block.original_pointer}) else "";
    if (options.output) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = checked_output });

    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const writer = &stdout.interface;
    try writer.print("scope,algorithm,block_size,strategy,reference_version,input_bytes,input_sha256,output_bytes,output_sha256,raw_bwt_original_pointer,sample,iterations,elapsed_ns,mib_s,checksum,{s}\n", .{provenance.csv_columns});
    for (0..options.samples) |sample| {
        const result = switch (options.scope) {
            .bwt => switch (options.algorithm) {
                .current => try measureBwt(encoder.bwtTransformAlloc, init, input, options.iterations),
                .full => try measureBwt(reference.transformAlloc, init, input, options.iterations),
            },
            .encode => try measureEncode(init, input, options.iterations, encode_options),
            .reference_encode => try measureReference(runtime.?, init, input, options.iterations, options.block_size),
        };
        try writer.print("{s},{s},{d},{s},\"{s}\",{d},{s},{d},{s},{s},{d},{d},{d},{d:.3},{d}", .{
            @tagName(options.scope),                                            @tagName(options.algorithm),                            options.block_size,          strategy_name,
            if (runtime) |library| std.mem.span(library.version()) else "none", input.len,                                              provenance.sha256Hex(input), checked_output.len,
            provenance.sha256Hex(checked_output),                               origin_text,                                            sample,                      options.iterations,
            result.ns,                                                          mibPerSecond(input.len, options.iterations, result.ns), result.checksum,
        });
        try info.writeCsvFields(writer);
        try writer.writeByte('\n');
    }
    try writer.flush();
}

const Measurement = struct { ns: u64, checksum: u64 };

fn measureBwt(comptime transform: anytype, init: std.process.Init, input: []const u8, iterations: usize) !Measurement {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const block = try transform(init.gpa, input);
        checksum +%= block.original_pointer;
        checksum +%= sampleBytes(block.bytes);
        std.mem.doNotOptimizeAway(block.bytes.ptr);
        block.deinit(init.gpa);
    }
    return .{ .ns = @intCast(start.durationTo(std.Io.Clock.awake.now(init.io)).nanoseconds), .checksum = checksum };
}

fn measureEncode(init: std.process.Init, input: []const u8, iterations: usize, options: encoder.EncodeOptions) !Measurement {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const bytes = try encoder.encodeAlloc(init.gpa, input, options);
        checksum +%= sampleBytes(bytes);
        std.mem.doNotOptimizeAway(bytes.ptr);
        init.gpa.free(bytes);
    }
    return .{ .ns = @intCast(start.durationTo(std.Io.Clock.awake.now(init.io)).nanoseconds), .checksum = checksum };
}

fn measureReference(runtime: libbz2.Runtime, init: std.process.Init, input: []const u8, iterations: usize, block_size: u4) !Measurement {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const bytes = try runtime.encodeAlloc(init.gpa, input, block_size);
        checksum +%= sampleBytes(bytes);
        std.mem.doNotOptimizeAway(bytes.ptr);
        init.gpa.free(bytes);
    }
    return .{ .ns = @intCast(start.durationTo(std.Io.Clock.awake.now(init.io)).nanoseconds), .checksum = checksum };
}

fn sampleBytes(bytes: []const u8) u64 {
    return @as(u64, bytes.len) + bytes[0] + bytes[bytes.len / 2] + bytes[bytes.len - 1];
}

fn mibPerSecond(bytes: usize, iterations: usize, ns: u64) f64 {
    return (@as(f64, @floatFromInt(bytes)) * @as(f64, @floatFromInt(iterations)) / (1024 * 1024)) /
        (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}
