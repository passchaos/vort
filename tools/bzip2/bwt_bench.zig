//! Allocation-inclusive BWT and one-shot encode measurements on caller files.
const std = @import("std");
const encoder = @import("bzip2_bench").encoder;
const reference = @import("bzip2_bench").reference;
const provenance = @import("benchmark_provenance");

const Options = struct {
    input: ?[]const u8 = null,
    output: ?[]const u8 = null,
    scope: enum { bwt, encode } = .bwt,
    algorithm: enum { current, full } = .current,
    iterations: usize = 3,
    samples: usize = 5,
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
        } else return error.InvalidArgument;
    }
    if (options.iterations == 0 or options.samples == 0 or
        (options.scope == .encode and options.algorithm != .current)) return error.InvalidArgument;
    // The reader needs room to observe EOF after an exactly maximum-size file.
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, options.input orelse return error.MissingArgument, init.gpa, .limited(900_001));
    defer init.gpa.free(input);
    if (input.len == 0 or input.len > 900_000) return error.InvalidArgument;
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);

    // Exact comparison and hashes are outside the timed allocation/transform loop.
    const current = try encoder.bwtTransformAlloc(init.gpa, input);
    defer current.deinit(init.gpa);
    const full = try reference.transformAlloc(init.gpa, input);
    defer full.deinit(init.gpa);
    if (current.original_pointer != full.original_pointer or !std.mem.eql(u8, current.bytes, full.bytes))
        return error.ReferenceMismatch;
    const encoded = if (options.scope == .encode) try encoder.encodeAlloc(init.gpa, input, .{ .block_size_100k = 9 }) else null;
    defer if (encoded) |bytes| init.gpa.free(bytes);
    const checked_output = encoded orelse current.bytes;
    if (options.output) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = checked_output });

    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const writer = &stdout.interface;
    try writer.print("scope,algorithm,input_bytes,input_sha256,output_bytes,output_sha256,raw_bwt_original_pointer,sample,iterations,elapsed_ns,mib_s,checksum,{s}\n", .{provenance.csv_columns});
    for (0..options.samples) |sample| {
        const result = switch (options.scope) {
            .bwt => switch (options.algorithm) {
                .current => try measureBwt(encoder.bwtTransformAlloc, init, input, options.iterations),
                .full => try measureBwt(reference.transformAlloc, init, input, options.iterations),
            },
            .encode => try measureEncode(init, input, options.iterations),
        };
        try writer.print("{s},{s},{d},{s},{d},{s},{d},{d},{d},{d},{d:.3},{d}", .{
            @tagName(options.scope), @tagName(options.algorithm),          input.len,                                              provenance.sha256Hex(input),
            checked_output.len,      provenance.sha256Hex(checked_output), current.original_pointer,                               sample,
            options.iterations,      result.ns,                            mibPerSecond(input.len, options.iterations, result.ns), result.checksum,
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

fn measureEncode(init: std.process.Init, input: []const u8, iterations: usize) !Measurement {
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const bytes = try encoder.encodeAlloc(init.gpa, input, .{ .block_size_100k = 9 });
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
