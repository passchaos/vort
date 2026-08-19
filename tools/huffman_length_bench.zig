const std = @import("std");
const vort = @import("vort");

const iterations_default: usize = 4096;

const Row = struct {
    case: []const u8,
    mode: []const u8,
    symbols: usize,
    active: usize,
    max_bits: u4,
    iterations: usize,
    elapsed_ns: i96,
    builds_per_s: f64,
    checksum: u64,
    cost_checksum: u64,
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
        } else if (std.mem.eql(u8, arg, "--iterations")) {
            iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingReportPath, 10);
            if (iterations == 0) return error.InvalidBlockPlan;
        } else return error.UnknownArgument;
    }

    var rows: [8]Row = undefined;
    rows[0] = try measure(init, "literal-sparse-18", 286, sparseLiteralFreqs(18), 15, iterations, false);
    rows[1] = try measure(init, "literal-sparse-18", 286, sparseLiteralFreqs(18), 15, iterations, true);
    rows[2] = try measure(init, "literal-sparse-48", 286, sparseLiteralFreqs(48), 15, iterations, false);
    rows[3] = try measure(init, "literal-sparse-48", 286, sparseLiteralFreqs(48), 15, iterations, true);
    rows[4] = try measure(init, "literal-dense", 286, denseLiteralFreqs(), 15, iterations, false);
    rows[5] = try measure(init, "literal-dense", 286, denseLiteralFreqs(), 15, iterations, true);
    rows[6] = try measure(init, "distance", 30, distanceFreqs(), 15, iterations, false);
    rows[7] = try measure(init, "code-length", 19, codeLengthFreqs(), 7, iterations, false);

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,mode,symbols,active,max_bits,iterations,elapsed_ns,builds_per_s,checksum,cost_checksum\n");
    for (rows) |row| try csv.writer.print("{s},{s},{d},{d},{d},{d},{d},{d:.2},{d},{d}\n", .{ row.case, row.mode, row.symbols, row.active, row.max_bits, row.iterations, row.elapsed_ns, row.builds_per_s, row.checksum, row.cost_checksum });

    var stdout_buffer: [2048]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout_writer.interface.writeAll(csv.written());
    try stdout_writer.interface.flush();
    if (csv_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
}

fn measure(init: std.process.Init, comptime name: []const u8, comptime n: usize, freqs: [n]u32, comptime max_bits: u4, iterations: usize, comptime reference: bool) !Row {
    var active: usize = 0;
    for (freqs) |freq| active += @intFromBool(freq != 0);
    var checksum: u64 = 0;
    var cost_checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |i| {
        const lengths = if (reference)
            vort.huffman.treeCodeLengthsFullWidth(n, &freqs, max_bits)
        else
            vort.huffman.treeCodeLengths(n, &freqs, max_bits);
        checksum +%= lengths[i % n];
        checksum +%= lengths[(i * 17 + 3) % n];
        for (freqs, lengths) |frequency, code_bits| cost_checksum +%= @as(u64, frequency) * code_bits;
    }
    const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    const seconds = @as(f64, @floatFromInt(elapsed)) / @as(f64, std.time.ns_per_s);
    return .{ .case = name, .mode = if (reference) "full-width" else "production", .symbols = n, .active = active, .max_bits = max_bits, .iterations = iterations, .elapsed_ns = elapsed, .builds_per_s = @as(f64, @floatFromInt(iterations)) / seconds, .checksum = checksum, .cost_checksum = cost_checksum };
}

fn sparseLiteralFreqs(comptime active: usize) [286]u32 {
    var freqs: [286]u32 = @splat(0);
    for (0..active) |i| freqs[(i * 17 + 5) % freqs.len] = @intCast(1 + ((i * 13 + 7) % 97));
    return freqs;
}

fn denseLiteralFreqs() [286]u32 {
    var freqs: [286]u32 = undefined;
    for (&freqs, 0..) |*freq, i| freq.* = @intCast(1 + ((i * 17 + (i / 7) * 31) % 251));
    return freqs;
}

fn distanceFreqs() [30]u32 {
    var freqs: [30]u32 = undefined;
    for (&freqs, 0..) |*freq, i| freq.* = @intCast(1 + ((i * 11 + 3) % 29));
    return freqs;
}

fn codeLengthFreqs() [19]u32 {
    var freqs: [19]u32 = undefined;
    for (&freqs, 0..) |*freq, i| freq.* = @intCast(1 + ((i * 5 + 7) % 23));
    return freqs;
}
