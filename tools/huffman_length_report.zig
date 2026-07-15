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
};

const cases = [_]Case{
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
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingCorpusPath;
        } else {
            return error.InvalidBlockPlan;
        }
    }

    var rows: [cases.len]Row = undefined;
    for (cases, 0..) |case, i| rows[i] = buildRow(case);

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, &rows);
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
        try writeMarkdown(&markdown.writer, &rows);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = markdown.written() });
    }
}

fn buildRow(case: Case) Row {
    const lengths = vort.huffman.treeCodeLengths(max_symbols, &case.freqs, case.max_bits);
    const actual = codeLengthCost(&case.freqs, &lengths, case.symbol_count);
    const oracle = bruteForceOptimal(case);
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
    };
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("case,symbol_count,max_bits,optimal_cost,actual_cost,gap_bits,kraft_cost,kraft_limit,optimal,lengths,optimal_lengths\n");
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
        try writer.writeByte('\n');
    }
}

fn writeMarkdown(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("# Huffman length-limit report\n\n");
    try writer.writeAll("Small fixed cases are brute-forced at runtime to guard future package-merge work.\n\n");
    try writer.writeAll("| case | symbols | max bits | optimal cost | actual cost | gap bits | Kraft | optimal? | lengths | oracle lengths |\n");
    try writer.writeAll("|---|---:|---:|---:|---:|---:|---:|---|---|---|\n");
    for (rows) |row| {
        try writer.print("| {s} | {d} | {d} | {d} | {d} | {d} | {d}/{d} | {} | ", .{
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
        try writer.writeAll(" | ");
        try writeLengthSlice(writer, row.optimal_lengths[0..row.symbol_count]);
        try writer.writeAll(" |\n");
    }
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
