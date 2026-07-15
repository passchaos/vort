const std = @import("std");
const vort = @import("vort");

const max_symbols = 16;

const Case = struct {
    name: []const u8,
    max_bits: u4,
    freqs: [max_symbols]u32,
    symbol_count: usize,
};

const Row = struct {
    case_name: []const u8,
    symbol_count: usize,
    max_bits: u4,
    optimal_cost: usize,
    actual_cost: usize,
    gap_bits: isize,
    kraft_cost: usize,
    kraft_limit: usize,
    optimal: bool,
    lengths: [max_symbols]u4,
    optimal_lengths: [max_symbols]u4,
    package_merge_cost: usize,
    package_merge_gap_bits: isize,
    package_merge_optimal: bool,
    package_merge_lengths: [max_symbols]u4,
};

const fixed_cases = [_]Case{
    .{ .name = "classic4", .max_bits = 3, .freqs = freqs(&.{ 5, 7, 10, 15 }), .symbol_count = 4 },
    .{ .name = "skew4", .max_bits = 3, .freqs = freqs(&.{ 100, 50, 25, 1 }), .symbol_count = 4 },
    .{ .name = "equal3", .max_bits = 2, .freqs = freqs(&.{ 1, 1, 1 }), .symbol_count = 3 },
    .{ .name = "equal5", .max_bits = 3, .freqs = freqs(&.{ 1, 1, 1, 1, 1 }), .symbol_count = 5 },
    .{ .name = "ramp5", .max_bits = 3, .freqs = freqs(&.{ 1, 2, 3, 4, 5 }), .symbol_count = 5 },
    .{ .name = "strong-skew7", .max_bits = 4, .freqs = freqs(&.{ 10_000, 1_000, 1, 1, 1, 1, 1 }), .symbol_count = 7 },
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var markdown_path: ?[]const u8 = null;
    var iterations: usize = 200;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--iterations")) {
            iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
            if (iterations == 0) return error.InvalidBlockPlan;
        } else {
            return error.InvalidBlockPlan;
        }
    }

    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(init.gpa);
    for (fixed_cases) |case| try rows.append(init.gpa, buildRow(case));
    try appendGeneratedRows(init.gpa, &rows);

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, rows.items);
    const csv_bytes = csv.written();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(csv_bytes);
    try stdout.flush();

    if (csv_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv_bytes });
    if (markdown_path) |path| {
        var markdown = std.Io.Writer.Allocating.init(init.gpa);
        defer markdown.deinit();
        try writeMarkdown(init, &markdown.writer, rows.items, iterations);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = markdown.written() });
    }
}

fn appendGeneratedRows(allocator: std.mem.Allocator, rows: *std.ArrayList(Row)) !void {
    inline for (.{ 3, 4, 5, 6 }) |symbol_count| {
        inline for (.{ 3, 4 }) |max_bits| {
            if (symbol_count > (@as(usize, 1) << max_bits)) continue;
            try rows.append(allocator, buildGeneratedRow("equal", symbol_count, max_bits, equalFreqs(symbol_count)));
            try rows.append(allocator, buildGeneratedRow("ramp", symbol_count, max_bits, rampFreqs(symbol_count)));
            try rows.append(allocator, buildGeneratedRow("reverse-ramp", symbol_count, max_bits, reverseRampFreqs(symbol_count)));
            try rows.append(allocator, buildGeneratedRow("fibonacci", symbol_count, max_bits, fibonacciFreqs(symbol_count)));
            try rows.append(allocator, buildGeneratedRow("head-heavy", symbol_count, max_bits, headHeavyFreqs(symbol_count)));
        }
    }
}

fn buildGeneratedRow(comptime family: []const u8, comptime symbol_count: usize, comptime max_bits: u4, freq_values: [max_symbols]u32) Row {
    const name = std.fmt.comptimePrint("{s}-{d}-b{d}", .{ family, symbol_count, max_bits });
    return buildRow(.{ .name = name, .max_bits = max_bits, .freqs = freq_values, .symbol_count = symbol_count });
}

fn buildRow(case: Case) Row {
    const lengths = vort.huffman.treeCodeLengths(max_symbols, &case.freqs, case.max_bits);
    const actual = codeLengthCost(&case.freqs, &lengths, case.symbol_count);
    const oracle = bruteForceOptimal(case);
    const package_merge_lengths = packageMergeCandidate(case);
    const package_merge_cost = codeLengthCost(&case.freqs, &package_merge_lengths, case.symbol_count);
    const package_merge_kraft = kraftCost(&package_merge_lengths, case.symbol_count, case.max_bits);
    const kraft = kraftCost(&lengths, case.symbol_count, case.max_bits);
    return .{
        .case_name = case.name,
        .symbol_count = case.symbol_count,
        .max_bits = case.max_bits,
        .optimal_cost = oracle.cost,
        .actual_cost = actual,
        .gap_bits = @as(isize, @intCast(actual)) - @as(isize, @intCast(oracle.cost)),
        .kraft_cost = kraft,
        .kraft_limit = @as(usize, 1) << case.max_bits,
        .optimal = actual == oracle.cost and kraft <= (@as(usize, 1) << case.max_bits),
        .lengths = lengths,
        .optimal_lengths = oracle.lengths,
        .package_merge_cost = package_merge_cost,
        .package_merge_gap_bits = @as(isize, @intCast(package_merge_cost)) - @as(isize, @intCast(oracle.cost)),
        .package_merge_optimal = package_merge_cost == oracle.cost and package_merge_kraft <= (@as(usize, 1) << case.max_bits),
        .package_merge_lengths = package_merge_lengths,
    };
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("case,symbol_count,max_bits,optimal_cost,actual_cost,gap_bits,kraft_cost,kraft_limit,optimal,lengths,optimal_lengths,package_merge_cost,package_merge_gap_bits,package_merge_optimal,package_merge_lengths\n");
    for (rows) |row| {
        try writer.print("{s},{d},{d},{d},{d},{d},{d},{d},{},", .{
            row.case_name,
            row.symbol_count,
            row.max_bits,
            row.optimal_cost,
            row.actual_cost,
            row.gap_bits,
            row.kraft_cost,
            row.kraft_limit,
            row.optimal,
        });
        try writeLengths(writer, row);
        try writer.writeByte(',');
        try writeLengthSlice(writer, row.optimal_lengths[0..row.symbol_count]);
        try writer.print(",{d},{d},{},", .{ row.package_merge_cost, row.package_merge_gap_bits, row.package_merge_optimal });
        try writeLengthSlice(writer, row.package_merge_lengths[0..row.symbol_count]);
        try writer.writeByte('\n');
    }
}

fn writeMarkdown(init: std.process.Init, writer: *std.Io.Writer, rows: []const Row, iterations: usize) !void {
    try writer.writeAll("# Huffman length-limit report\n\n");
    try writer.writeAll("Small fixed cases are brute-forced at runtime to guard future package-merge work.\n\n");
    const summary = summarizeRows(rows);
    try writer.print("- rows: {d}\n- optimal rows: {d}\n- non-optimal rows: {d}\n- worst gap bits: {d}\n\n", .{
        rows.len,
        summary.optimal_rows,
        rows.len - summary.optimal_rows,
        summary.worst_gap_bits,
    });
    try writer.print("- package-merge optimal rows: {d}\n- package-merge non-optimal rows: {d}\n- package-merge worst gap bits: {d}\n\n", .{
        summary.package_merge_optimal_rows,
        rows.len - summary.package_merge_optimal_rows,
        summary.package_merge_worst_gap_bits,
    });
    try writer.writeAll("| case | symbols | max bits | optimal cost | actual cost | gap bits | package-merge cost | package-merge gap | Kraft | optimal? | package-merge optimal? | lengths | oracle lengths | package-merge lengths |\n");
    try writer.writeAll("|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|---|\n");
    for (rows) |row| {
        try writer.print("| {s} | {d} | {d} | {d} | {d} | {d} | {d} | {d} | {d}/{d} | {} | {} | ", .{
            row.case_name,
            row.symbol_count,
            row.max_bits,
            row.optimal_cost,
            row.actual_cost,
            row.gap_bits,
            row.package_merge_cost,
            row.package_merge_gap_bits,
            row.kraft_cost,
            row.kraft_limit,
            row.optimal,
            row.package_merge_optimal,
        });
        try writeLengths(writer, row);
        try writer.writeAll(" | ");
        try writeLengthSlice(writer, row.optimal_lengths[0..row.symbol_count]);
        try writer.writeAll(" | ");
        try writeLengthSlice(writer, row.package_merge_lengths[0..row.symbol_count]);
        try writer.writeAll(" |\n");
    }
    try writeLargeAlphabetMarkdown(init, writer, iterations);
}

const Summary = struct {
    optimal_rows: usize = 0,
    worst_gap_bits: isize = 0,
    package_merge_optimal_rows: usize = 0,
    package_merge_worst_gap_bits: isize = 0,
};

fn summarizeRows(rows: []const Row) Summary {
    var summary = Summary{};
    for (rows) |row| {
        if (row.optimal) summary.optimal_rows += 1;
        if (row.gap_bits > summary.worst_gap_bits) summary.worst_gap_bits = row.gap_bits;
        if (row.package_merge_optimal) summary.package_merge_optimal_rows += 1;
        if (row.package_merge_gap_bits > summary.package_merge_worst_gap_bits) summary.package_merge_worst_gap_bits = row.package_merge_gap_bits;
    }
    return summary;
}

fn writeLengths(writer: *std.Io.Writer, row: Row) !void {
    try writeLengthSlice(writer, row.lengths[0..row.symbol_count]);
}

fn writeLengthSlice(writer: *std.Io.Writer, lengths: []const u4) !void {
    for (lengths, 0..) |bits, i| {
        if (i != 0) try writer.writeByte(';');
        try writer.print("{d}", .{bits});
    }
}

const Oracle = struct {
    cost: usize,
    lengths: [max_symbols]u4,
};

fn bruteForceOptimal(case: Case) Oracle {
    var current: [max_symbols]u4 = @splat(0);
    var best = Oracle{ .cost = std.math.maxInt(usize), .lengths = @splat(0) };
    bruteForceLengths(case, 0, &current, &best);
    std.debug.assert(best.cost != std.math.maxInt(usize));
    return best;
}

fn bruteForceLengths(case: Case, index: usize, current: *[max_symbols]u4, best: *Oracle) void {
    if (index == case.symbol_count) {
        const kraft = kraftCost(current, case.symbol_count, case.max_bits);
        if (kraft > (@as(usize, 1) << case.max_bits)) return;
        const cost = codeLengthCost(&case.freqs, current, case.symbol_count);
        if (cost < best.cost or (cost == best.cost and lengthsLess(current, &best.lengths, case.symbol_count))) {
            best.cost = cost;
            best.lengths = current.*;
        }
        return;
    }

    var bits: u4 = 1;
    while (bits <= case.max_bits) : (bits += 1) {
        current[index] = bits;
        bruteForceLengths(case, index + 1, current, best);
    }
    current[index] = 0;
}

fn lengthsLess(lhs: *const [max_symbols]u4, rhs: *const [max_symbols]u4, symbol_count: usize) bool {
    for (lhs[0..symbol_count], rhs[0..symbol_count]) |left, right| {
        if (left != right) return left < right;
    }
    return false;
}

const Package = struct {
    weight: u64,
    counts: [max_symbols]u8,
};

fn packageMergeCandidate(case: Case) [max_symbols]u4 {
    var leaves: [max_symbols]Package = undefined;
    for (0..case.symbol_count) |i| {
        var counts: [max_symbols]u8 = @splat(0);
        counts[i] = 1;
        leaves[i] = .{ .weight = case.freqs[i], .counts = counts };
    }
    std.mem.sort(Package, leaves[0..case.symbol_count], {}, packageLess);

    var current: [max_symbols * (max_symbols + 1)]Package = undefined;
    var next: [max_symbols * (max_symbols + 1)]Package = undefined;
    var current_len = case.symbol_count;
    @memcpy(current[0..current_len], leaves[0..case.symbol_count]);

    var depth: u4 = 1;
    while (depth < case.max_bits) : (depth += 1) {
        var pair_len: usize = 0;
        var i: usize = 0;
        while (i + 1 < current_len) : (i += 2) {
            next[pair_len] = combinePackages(current[i], current[i + 1]);
            pair_len += 1;
        }
        std.mem.sort(Package, next[0..pair_len], {}, packageLess);
        current_len = mergePackageLists(current.len, &current, leaves[0..case.symbol_count], next[0..pair_len]);
    }

    const selected_count = 2 * case.symbol_count - 2;
    var length_counts: [max_symbols]u8 = @splat(0);
    for (current[0..selected_count]) |package| {
        for (package.counts[0..case.symbol_count], 0..) |count, symbol| length_counts[symbol] += count;
    }
    var lengths: [max_symbols]u4 = @splat(0);
    for (length_counts[0..case.symbol_count], 0..) |count, symbol| {
        std.debug.assert(count <= case.max_bits);
        lengths[symbol] = @intCast(count);
    }
    return lengths;
}

fn combinePackages(lhs: Package, rhs: Package) Package {
    var out = Package{ .weight = lhs.weight + rhs.weight, .counts = @splat(0) };
    for (&out.counts, lhs.counts, rhs.counts) |*value, left, right| value.* = left + right;
    return out;
}

fn packageLess(_: void, lhs: Package, rhs: Package) bool {
    if (lhs.weight != rhs.weight) return lhs.weight < rhs.weight;
    var i: usize = max_symbols;
    while (i > 0) {
        i -= 1;
        if (lhs.counts[i] != rhs.counts[i]) return lhs.counts[i] < rhs.counts[i];
    }
    return false;
}

fn mergePackageLists(comptime n: usize, out: *[n]Package, leaves: []const Package, packages: []const Package) usize {
    var out_len: usize = 0;
    var leaf_i: usize = 0;
    var package_i: usize = 0;
    while (leaf_i < leaves.len or package_i < packages.len) {
        const take_leaf = if (package_i >= packages.len)
            true
        else if (leaf_i >= leaves.len)
            false
        else
            packageLess({}, leaves[leaf_i], packages[package_i]);
        out[out_len] = if (take_leaf) leaves[leaf_i] else packages[package_i];
        out_len += 1;
        if (take_leaf) {
            leaf_i += 1;
        } else {
            package_i += 1;
        }
    }
    return out_len;
}

fn writeLargeAlphabetMarkdown(init: std.process.Init, writer: *std.Io.Writer, iterations: usize) !void {
    try writer.writeAll("\n## Large DEFLATE alphabet regression cases\n\n");
    try writer.writeAll("These rows are not brute-forced; they guard Kraft validity, maximum length, and deterministic output for production-sized alphabets.\n\n");
    try writer.print("Timing iterations per row: {d}\n\n", .{iterations});
    try writer.writeAll("| case | symbols | max bits | nonzero | max length | Kraft | deterministic? | cost | ns/op |\n");
    try writer.writeAll("|---|---:|---:|---:|---:|---:|---|---:|---:|\n");
    try writeLargeAlphabetRow(init, writer, "literal-length-286", 286, maxLiteralFreqs(), 15, iterations);
    try writeLargeAlphabetRow(init, writer, "distance-30", 30, maxDistanceFreqs(), 15, iterations);
    try writeLargeAlphabetRow(init, writer, "code-length-19", 19, maxCodeLengthFreqs(), 7, iterations);
    try writeLargeAlphabetRow(init, writer, "sparse-literal-286", 286, sparseLiteralFreqs(), 15, iterations);
}

fn writeLargeAlphabetRow(
    init: std.process.Init,
    writer: *std.Io.Writer,
    comptime name: []const u8,
    comptime n: usize,
    freqs_value: [n]u32,
    comptime max_bits: u4,
    iterations: usize,
) !void {
    const first = vort.huffman.treeCodeLengths(n, &freqs_value, max_bits);
    const second = vort.huffman.treeCodeLengths(n, &freqs_value, max_bits);
    const deterministic = std.meta.eql(first, second);
    const ns_per_op = try timeCodeLengths(init, n, &freqs_value, max_bits, iterations);
    var nonzero: usize = 0;
    var max_length: u4 = 0;
    for (freqs_value, first) |freq, bits| {
        if (freq == 0) continue;
        nonzero += 1;
        max_length = @max(max_length, bits);
    }
    try writer.print("| {s} | {d} | {d} | {d} | {d} | {d}/{d} | {} | {d} | {d} |\n", .{
        name,
        n,
        max_bits,
        nonzero,
        max_length,
        kraftCostGeneric(n, &first, max_bits),
        @as(usize, 1) << max_bits,
        deterministic,
        codeLengthCostGeneric(n, &freqs_value, &first),
        ns_per_op,
    });
}

fn timeCodeLengths(
    init: std.process.Init,
    comptime n: usize,
    freqs_value: *const [n]u32,
    comptime max_bits: u4,
    iterations: usize,
) !u128 {
    const start = std.Io.Clock.awake.now(init.io);
    var checksum: usize = 0;
    for (0..iterations) |_| {
        const lengths = vort.huffman.treeCodeLengths(n, freqs_value, max_bits);
        checksum +%= lengths[0];
        checksum +%= lengths[n - 1];
    }
    std.mem.doNotOptimizeAway(checksum);
    const elapsed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    return @intCast(@divTrunc(elapsed, @as(i128, @intCast(iterations))));
}

fn maxLiteralFreqs() [286]u32 {
    var out: [286]u32 = @splat(0);
    for (&out, 0..) |*freq, i| freq.* = @intCast(1 + ((i * 17 + (i / 7) * 31) % 251));
    return out;
}

fn sparseLiteralFreqs() [286]u32 {
    var out: [286]u32 = @splat(0);
    for (0..286) |i| {
        if (i == 256 or i % 17 == 0) out[i] = @intCast(1 + ((i * 13 + 5) % 97));
    }
    return out;
}

fn maxDistanceFreqs() [30]u32 {
    var out: [30]u32 = @splat(0);
    for (&out, 0..) |*freq, i| freq.* = @intCast(1 + ((i * 11 + 3) % 29));
    return out;
}

fn maxCodeLengthFreqs() [19]u32 {
    var out: [19]u32 = @splat(0);
    for (&out, 0..) |*freq, i| freq.* = @intCast(1 + ((i * 5 + 7) % 23));
    return out;
}

fn codeLengthCostGeneric(comptime n: usize, freq_values: *const [n]u32, lengths: *const [n]u4) usize {
    var cost: usize = 0;
    for (freq_values.*, lengths.*) |freq, bits| cost += @as(usize, freq) * bits;
    return cost;
}

fn kraftCostGeneric(comptime n: usize, lengths: *const [n]u4, max_bits: u4) usize {
    var cost: usize = 0;
    for (lengths.*) |bits| {
        if (bits == 0) continue;
        cost += @as(usize, 1) << @intCast(max_bits - bits);
    }
    return cost;
}

fn codeLengthCost(freq_values: *const [max_symbols]u32, lengths: *const [max_symbols]u4, symbol_count: usize) usize {
    var cost: usize = 0;
    for (freq_values[0..symbol_count], lengths[0..symbol_count]) |freq, bits| cost += @as(usize, freq) * bits;
    return cost;
}

fn kraftCost(lengths: *const [max_symbols]u4, symbol_count: usize, max_bits: u4) usize {
    var cost: usize = 0;
    for (lengths[0..symbol_count]) |bits| {
        if (bits == 0) continue;
        cost += @as(usize, 1) << @intCast(max_bits - bits);
    }
    return cost;
}

fn freqs(values: []const u32) [max_symbols]u32 {
    var out: [max_symbols]u32 = @splat(0);
    for (values, 0..) |value, i| out[i] = value;
    return out;
}

fn equalFreqs(comptime symbol_count: usize) [max_symbols]u32 {
    var out: [max_symbols]u32 = @splat(0);
    for (0..symbol_count) |i| out[i] = 1;
    return out;
}

fn rampFreqs(comptime symbol_count: usize) [max_symbols]u32 {
    var out: [max_symbols]u32 = @splat(0);
    for (0..symbol_count) |i| out[i] = @intCast(i + 1);
    return out;
}

fn reverseRampFreqs(comptime symbol_count: usize) [max_symbols]u32 {
    var out: [max_symbols]u32 = @splat(0);
    for (0..symbol_count) |i| out[i] = @intCast(symbol_count - i);
    return out;
}

fn fibonacciFreqs(comptime symbol_count: usize) [max_symbols]u32 {
    var out: [max_symbols]u32 = @splat(0);
    var a: u32 = 1;
    var b: u32 = 1;
    for (0..symbol_count) |i| {
        out[i] = a;
        const next = a + b;
        a = b;
        b = next;
    }
    return out;
}

fn headHeavyFreqs(comptime symbol_count: usize) [max_symbols]u32 {
    var out: [max_symbols]u32 = @splat(0);
    if (symbol_count == 0) return out;
    out[0] = @intCast(symbol_count * symbol_count * 10);
    if (symbol_count > 1) out[1] = @intCast(symbol_count * 3);
    var i: usize = 2;
    while (i < symbol_count) : (i += 1) out[i] = 1;
    return out;
}
