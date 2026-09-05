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

    var rows: [27]Row = undefined;
    rows[0] = try measure(init, "literal-sparse-18", 286, sparseLiteralFreqs(18), 15, iterations, false);
    rows[1] = try measure(init, "literal-sparse-18", 286, sparseLiteralFreqs(18), 15, iterations, true);
    rows[2] = try measure(init, "literal-sparse-48", 286, sparseLiteralFreqs(48), 15, iterations, false);
    rows[3] = try measure(init, "literal-sparse-48", 286, sparseLiteralFreqs(48), 15, iterations, true);
    rows[4] = try measure(init, "literal-dense", 286, denseLiteralFreqs(), 15, iterations, false);
    rows[5] = try measure(init, "literal-dense", 286, denseLiteralFreqs(), 15, iterations, true);
    rows[6] = try measureBackrefTraversal(init, "literal-dense", 286, denseLiteralFreqs(), 15, iterations);
    rows[7] = try measure(init, "distance", 30, distanceFreqs(), 15, iterations, false);
    rows[8] = try measure(init, "code-length", 19, codeLengthFreqs(), 7, iterations, false);
    rows[9] = try measure(init, "zstd-known-32", 256, knownActiveFreqs(32), 11, iterations, false);
    rows[10] = try measureKnownActive(init, "zstd-known-32", knownActiveFreqs(32), 11, iterations);
    rows[11] = try measure(init, "zstd-known-64", 256, knownActiveFreqs(64), 11, iterations, false);
    rows[12] = try measureKnownActive(init, "zstd-known-64", knownActiveFreqs(64), 11, iterations);
    rows[13] = try measure(init, "zstd-known-128", 256, knownActiveFreqs(128), 11, iterations, false);
    rows[14] = try measureKnownActive(init, "zstd-known-128", knownActiveFreqs(128), 11, iterations);
    rows[15] = try measureBackrefTraversal(init, "zstd-known-128", 256, knownActiveFreqs(128), 11, iterations);
    rows[16] = try measure(init, "zstd-known-256", 256, knownActiveFreqs(256), 11, iterations, false);
    rows[17] = try measureKnownActive(init, "zstd-known-256", knownActiveFreqs(256), 11, iterations);
    rows[18] = try measureBackrefTraversal(init, "zstd-known-256", 256, knownActiveFreqs(256), 11, iterations);
    rows[19] = try measureZstdSymbolSort(init, "zstd-sort-64", 64, iterations, false);
    rows[20] = try measureZstdSymbolSort(init, "zstd-sort-64", 64, iterations, true);
    rows[21] = try measureZstdSymbolSort(init, "zstd-sort-128", 128, iterations, false);
    rows[22] = try measureZstdSymbolSort(init, "zstd-sort-128", 128, iterations, true);
    rows[23] = try measureZstdSymbolSort(init, "zstd-sort-256", 256, iterations, false);
    rows[24] = try measureZstdSymbolSort(init, "zstd-sort-256", 256, iterations, true);
    rows[25] = try measureZstdFseHeaderLength(init, iterations, false);
    rows[26] = try measureZstdFseHeaderLength(init, iterations, true);

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

fn measure(init: std.process.Init, comptime name: []const u8, comptime n: usize, seed_freqs: [n]u32, comptime max_bits: u4, iterations: usize, comptime reference: bool) !Row {
    var active: usize = 0;
    var first_active: usize = 0;
    for (seed_freqs, 0..) |freq, symbol| {
        if (freq == 0) continue;
        if (active == 0) first_active = symbol;
        active += 1;
    }
    var freqs = seed_freqs;
    var checksum: u64 = 0;
    var cost_checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |i| {
        // Real block histograms change on every invocation. Alternate one
        // positive count so the optimizer cannot hoist the scan or tree build
        // out of this focused loop while both modes still see identical input.
        freqs[first_active] = seed_freqs[first_active] + @as(u32, @intCast(i & 1));
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

fn measureKnownActive(init: std.process.Init, comptime name: []const u8, seed_freqs: [256]u32, comptime max_bits: u4, iterations: usize) !Row {
    var active_symbols: [256]u8 = undefined;
    var active: usize = 0;
    for (seed_freqs, 0..) |freq, symbol| {
        if (freq == 0) continue;
        active_symbols[active] = @intCast(symbol);
        active += 1;
    }
    const first_active = active_symbols[0];
    var freqs = seed_freqs;
    var checksum: u64 = 0;
    var cost_checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |i| {
        freqs[first_active] = seed_freqs[first_active] + @as(u32, @intCast(i & 1));
        const lengths = vort.huffman.treeCodeLengthsKnownActive(256, &freqs, max_bits, active_symbols[0..active]);
        checksum +%= lengths[i % freqs.len];
        checksum +%= lengths[(i * 17 + 3) % freqs.len];
        for (freqs, lengths) |frequency, code_bits| cost_checksum +%= @as(u64, frequency) * code_bits;
    }
    const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    const seconds = @as(f64, @floatFromInt(elapsed)) / @as(f64, std.time.ns_per_s);
    return .{ .case = name, .mode = "known-active", .symbols = freqs.len, .active = active, .max_bits = max_bits, .iterations = iterations, .elapsed_ns = elapsed, .builds_per_s = @as(f64, @floatFromInt(iterations)) / seconds, .checksum = checksum, .cost_checksum = cost_checksum };
}

fn measureBackrefTraversal(init: std.process.Init, comptime name: []const u8, comptime n: usize, seed_freqs: [n]u32, comptime max_bits: u4, iterations: usize) !Row {
    var active: usize = 0;
    var first_active: usize = 0;
    for (seed_freqs, 0..) |freq, symbol| {
        if (freq == 0) continue;
        if (active == 0) first_active = symbol;
        active += 1;
    }
    var freqs = seed_freqs;
    var checksum: u64 = 0;
    var cost_checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |i| {
        freqs[first_active] = seed_freqs[first_active] + @as(u32, @intCast(i & 1));
        const lengths = vort.huffman.treeCodeLengthsBackrefTraversal(n, &freqs, max_bits);
        checksum +%= lengths[i % n];
        checksum +%= lengths[(i * 17 + 3) % n];
        for (freqs, lengths) |frequency, code_bits| cost_checksum +%= @as(u64, frequency) * code_bits;
    }
    const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    const seconds = @as(f64, @floatFromInt(elapsed)) / @as(f64, std.time.ns_per_s);
    return .{ .case = name, .mode = "root-traversal", .symbols = n, .active = active, .max_bits = max_bits, .iterations = iterations, .elapsed_ns = elapsed, .builds_per_s = @as(f64, @floatFromInt(iterations)) / seconds, .checksum = checksum, .cost_checksum = cost_checksum };
}

fn measureZstdSymbolSort(init: std.process.Init, comptime name: []const u8, comptime active: usize, iterations: usize, comptime reference: bool) !Row {
    const seed_freqs = knownActiveFreqs(active);
    const seed_lengths = vort.huffman.treeCodeLengths(256, &seed_freqs, 11);
    var base_symbols: [256]u8 = undefined;
    var symbol_count: usize = 0;
    for (seed_freqs, 0..) |frequency, symbol| {
        if (frequency == 0) continue;
        base_symbols[symbol_count] = @intCast(symbol);
        symbol_count += 1;
    }
    std.debug.assert(symbol_count == active);

    var symbols: [256]u8 = undefined;
    var lengths = seed_lengths;
    var checksum: u64 = 0;
    var cost_checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |i| {
        @memcpy(symbols[0..active], base_symbols[0..active]);
        const first = base_symbols[0];
        lengths[first] = if ((i & 1) == 0)
            seed_lengths[first]
        else if (seed_lengths[first] == 11)
            10
        else
            seed_lengths[first] + 1;
        std.mem.doNotOptimizeAway(&lengths);
        if (reference)
            vort.zstd.benchmarkSmallHuffmanSymbolComparisonSort(symbols[0..active], &lengths)
        else
            vort.zstd.benchmarkSmallHuffmanSymbolBucketSort(symbols[0..active], &lengths, 11);
        checksum +%= symbols[i % active];
        checksum +%= symbols[(i * 17 + 3) % active];
        for (symbols[0..active], 0..) |symbol, position|
            cost_checksum +%= (@as(u64, position) + 1) * (@as(u64, symbol) + 1);
    }
    const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    const seconds = @as(f64, @floatFromInt(elapsed)) / @as(f64, std.time.ns_per_s);
    return .{ .case = name, .mode = if (reference) "comparison-sort" else "bucket-sort", .symbols = 256, .active = active, .max_bits = 11, .iterations = iterations, .elapsed_ns = elapsed, .builds_per_s = @as(f64, @floatFromInt(iterations)) / seconds, .checksum = checksum, .cost_checksum = cost_checksum };
}

fn measureZstdFseHeaderLength(init: std.process.Init, iterations: usize, comptime reference: bool) !Row {
    var normalized = [_]i16{ -1, 0, 0, 0, 3, 0, 0, 5, 7, 11, 0, 0, 13, 0, 0, 24 };
    var output: [128]u8 = undefined;
    var checksum: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |i| {
        const delta: i16 = @intCast(i & 1);
        normalized[12] = 13 + delta;
        normalized[15] = 24 - delta;
        const len = if (reference)
            try vort.zstd.benchmarkEmitFseNormalizedCountFixed(&output, &normalized, 15, 6)
        else
            try vort.zstd.benchmarkFseNormalizedCountSerializedLen(&normalized, 15, 6);
        checksum +%= len;
        if (reference) std.mem.doNotOptimizeAway(&output);
    }
    const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    const seconds = @as(f64, @floatFromInt(elapsed)) / @as(f64, std.time.ns_per_s);
    return .{ .case = "zstd-fse-header-length", .mode = if (reference) "fixed-writer" else "count-only", .symbols = normalized.len, .active = 7, .max_bits = 6, .iterations = iterations, .elapsed_ns = elapsed, .builds_per_s = @as(f64, @floatFromInt(iterations)) / seconds, .checksum = checksum, .cost_checksum = checksum };
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

fn knownActiveFreqs(comptime active: usize) [256]u32 {
    var freqs: [256]u32 = @splat(0);
    for (0..active) |index| {
        const symbol = (index * 149 + 37) % freqs.len;
        freqs[symbol] = @intCast(1 + ((index * 19 + (index / 5) * 23) % 251));
    }
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
