const std = @import("std");
const rle = @import("code_length_rle");

const iterations_default: usize = 200_000;

const Case = enum { sparse, mixed, boundary, dense };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var iterations = iterations_default;
    var csv_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingReportPath, 10);
        } else if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingReportPath;
        } else return error.UnknownArgument;
    }
    if (iterations == 0) return error.InvalidBlockPlan;

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,mode,iterations,elapsed_ns,plans_per_s,checksum\n");
    inline for (.{ Case.sparse, Case.mixed, Case.boundary, Case.dense }) |case| {
        try run(&csv.writer, init, case, false, iterations);
        try run(&csv.writer, init, case, true, iterations);
    }
    var stdout_buffer: [2048]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout_writer.interface.writeAll(csv.written());
    try stdout_writer.interface.flush();
    if (csv_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
}

fn run(writer: *std.Io.Writer, init: std.process.Init, comptime case: Case, comptime reference: bool, iterations: usize) !void {
    const lengths = caseLengths(case);
    const literal = lengths[0..286];
    const distance = lengths[286..];
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        if (reference) {
            const plan = try referencePlan(literal, distance);
            checksum +%= plan.len + plan.extra_bit_count + plan.frequencies[16] + plan.frequencies[17] + plan.frequencies[18];
        } else {
            const plan = try rle.build(literal, distance);
            checksum +%= plan.len + plan.extra_bit_count + plan.frequencies[16] + plan.frequencies[17] + plan.frequencies[18];
        }
    }
    const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    const per_second = @as(f64, @floatFromInt(iterations)) / (@as(f64, @floatFromInt(elapsed)) / @as(f64, std.time.ns_per_s));
    try writer.print("{s},{s},{d},{d},{d:.2},{d}\n", .{ @tagName(case), if (reference) "reference" else "fused", iterations, elapsed, per_second, checksum });
}

fn referencePlan(literal: []const u4, distance: []const u4) !rle.Plan {
    var joined: [316]u4 = undefined;
    @memcpy(joined[0..literal.len], literal);
    @memcpy(joined[literal.len..][0..distance.len], distance);
    // Preserve the old architecture: materialize concatenation, build ops,
    // then rescan ops for frequency and extra-bit accounting. The production
    // module performs all three in one source pass.
    var raw = try rle.build(joined[0 .. literal.len + distance.len], &.{});
    var frequencies: [19]u32 = @splat(0);
    var extra_bits: usize = 0;
    for (raw.slice()) |op| {
        frequencies[op.symbol] += 1;
        extra_bits += op.extra_bits;
    }
    raw.frequencies = frequencies;
    raw.extra_bit_count = extra_bits;
    return raw;
}

fn caseLengths(comptime case: Case) [316]u4 {
    var lengths: [316]u4 = @splat(0);
    switch (case) {
        .sparse => {
            lengths[65] = 5;
            lengths[97] = 4;
            lengths[256] = 3;
            lengths[257] = 6;
            lengths[285] = 7;
            lengths[286] = 1;
        },
        .mixed => {
            for (&lengths, 0..) |*length, i| length.* = if (i % 11 < 4) 0 else @intCast(3 + (i * 7) % 9);
        },
        .boundary => {
            for (250..286) |i| lengths[i] = 0;
            for (286..316) |i| lengths[i] = 0;
            lengths[249] = 5;
        },
        .dense => {
            for (&lengths, 0..) |*length, i| length.* = @intCast(5 + (i * 13) % 8);
        },
    }
    return lengths;
}
