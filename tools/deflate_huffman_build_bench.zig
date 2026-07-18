const std = @import("std");
const vort = @import("vort");

const huffman = vort.huffman;
const iterations_default: usize = 4096;

const BuildKind = enum {
    table,
    fast5,
    fast8,
    fast7,
    fast9,
    fast11,
    fast12,

    fn label(self: BuildKind) []const u8 {
        return switch (self) {
            .table => "table",
            .fast5 => "fast5",
            .fast8 => "fast8",
            .fast7 => "fast7",
            .fast9 => "fast9",
            .fast11 => "fast11",
            .fast12 => "fast12",
        };
    }

    fn lookupBits(self: BuildKind) u8 {
        return switch (self) {
            .table => 0,
            .fast5 => 5,
            .fast7 => 7,
            .fast8 => 8,
            .fast9 => 9,
            .fast11 => 11,
            .fast12 => 12,
        };
    }
};

const CaseKind = enum {
    literal_mixed,
    literal_long_tail,
    distance_mixed,
    code_length,

    fn label(self: CaseKind) []const u8 {
        return switch (self) {
            .literal_mixed => "literal-mixed",
            .literal_long_tail => "literal-long-tail",
            .distance_mixed => "distance-mixed",
            .code_length => "code-length",
        };
    }
};

const Row = struct {
    case: []const u8,
    build: []const u8,
    lookup_bits: u8,
    symbols: usize,
    iterations: usize,
    elapsed_ns: i128,
    builds_per_s: f64,
    checksum: u64,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var csv_path: ?[]const u8 = null;
    var iterations = iterations_default;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--iterations")) {
            iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingReportPath, 10);
            if (iterations == 0) return error.InvalidBlockPlan;
            continue;
        }
        return error.UnknownArgument;
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,build,lookup_bits,symbols,iterations,elapsed_ns,builds_per_s,checksum\n");
    inline for (.{ CaseKind.literal_mixed, CaseKind.literal_long_tail, CaseKind.distance_mixed, CaseKind.code_length }) |case| {
        try runCase(init, &csv.writer, case, iterations);
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout_writer.interface.writeAll(csv.written());
    try stdout_writer.interface.flush();
    if (csv_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
}

fn runCase(init: std.process.Init, writer: *std.Io.Writer, comptime case: CaseKind, iterations: usize) !void {
    var lengths: [288]u4 = @splat(0);
    switch (case) {
        .literal_mixed => fillLiteralMixed(&lengths),
        .literal_long_tail => fillLiteralLongTail(&lengths),
        .distance_mixed => fillDistanceMixed(&lengths),
        .code_length => fillCodeLength(&lengths),
    }
    try writeRow(writer, try runBuild(init, case, .table, &lengths, iterations));
    switch (case) {
        .literal_mixed, .literal_long_tail => {
            try writeRow(writer, try runBuild(init, case, .fast9, &lengths, iterations));
            try writeRow(writer, try runBuild(init, case, .fast11, &lengths, iterations));
            try writeRow(writer, try runBuild(init, case, .fast12, &lengths, iterations));
        },
        .distance_mixed => {
            try writeRow(writer, try runBuild(init, case, .fast5, &lengths, iterations));
            try writeRow(writer, try runBuild(init, case, .fast8, &lengths, iterations));
        },
        .code_length => {
            try writeRow(writer, try runBuild(init, case, .fast5, &lengths, iterations));
            try writeRow(writer, try runBuild(init, case, .fast7, &lengths, iterations));
        },
    }
}

fn runBuild(init: std.process.Init, comptime case: CaseKind, kind: BuildKind, lengths: *const [288]u4, iterations: usize) !Row {
    const start = std.Io.Clock.awake.now(init.io);
    var checksum: u64 = 0;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const table = try huffman.HuffmanTable(288).init(lengths);
        checksum +%= table.len + table.max_bits + table.count_by_bits[(i % 15) + 1];
        switch (kind) {
            .table => {},
            .fast5 => {
                const decoder = huffman.FastDecoder(288, 5).init(table);
                checksum +%= decoder.lookupCoverage();
            },
            .fast8 => {
                const decoder = huffman.FastDecoder(288, 8).init(table);
                checksum +%= decoder.lookupCoverage();
            },
            .fast7 => {
                const decoder = huffman.FastDecoder(288, 7).init(table);
                checksum +%= decoder.lookupCoverage();
            },
            .fast9 => {
                const decoder = huffman.FastDecoder(288, 9).init(table);
                checksum +%= decoder.lookupCoverage();
            },
            .fast11 => {
                const decoder = huffman.FastDecoder(288, 11).init(table);
                checksum +%= decoder.lookupCoverage();
            },
            .fast12 => {
                const decoder = huffman.FastDecoder(288, 12).init(table);
                checksum +%= decoder.lookupCoverage();
            },
        }
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    return .{
        .case = case.label(),
        .build = kind.label(),
        .lookup_bits = kind.lookupBits(),
        .symbols = activeSymbols(lengths),
        .iterations = iterations,
        .elapsed_ns = elapsed_ns,
        .builds_per_s = perSecond(iterations, elapsed_ns),
        .checksum = checksum,
    };
}

fn fillCodeLength(lengths: *[288]u4) void {
    @memset(lengths, 0);
    lengths[0] = 3;
    lengths[3] = 3;
    lengths[8] = 3;
    lengths[16] = 3;
    lengths[17] = 3;
    lengths[18] = 3;
}

fn fillLiteralMixed(lengths: *[288]u4) void {
    @memset(lengths, 0);
    for (0..144) |i| lengths[i] = 8;
    for (144..256) |i| lengths[i] = 9;
    lengths[256] = 7;
    for (257..286) |i| lengths[i] = 10;
}

fn fillLiteralLongTail(lengths: *[288]u4) void {
    @memset(lengths, 0);
    for (0..32) |i| lengths[i] = 7;
    for (32..96) |i| lengths[i] = 10;
    for (96..256) |i| lengths[i] = 13;
    lengths[256] = 7;
    for (257..286) |i| lengths[i] = 15;
}

fn fillDistanceMixed(lengths: *[288]u4) void {
    @memset(lengths, 0);
    for (0..6) |i| lengths[i] = 4;
    for (6..18) |i| lengths[i] = 7;
    for (18..30) |i| lengths[i] = 10;
}

fn activeSymbols(lengths: []const u4) usize {
    var n: usize = 0;
    for (lengths) |bits| n += @intFromBool(bits != 0);
    return n;
}

fn writeRow(writer: *std.Io.Writer, row: Row) !void {
    try writer.print("{s},{s},{d},{d},{d},{d},{d:.2},{d}\n", .{
        row.case,
        row.build,
        row.lookup_bits,
        row.symbols,
        row.iterations,
        row.elapsed_ns,
        row.builds_per_s,
        row.checksum,
    });
}

fn perSecond(count: usize, elapsed_ns: i128) f64 {
    if (elapsed_ns <= 0) return 0;
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    return @as(f64, @floatFromInt(count)) / seconds;
}
