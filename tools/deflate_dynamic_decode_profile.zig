const std = @import("std");
const vort = @import("vort");

const Row = struct {
    case: []const u8,
    input_bytes: usize,
    raw_bytes: usize,
    dynamic_hlit: usize,
    dynamic_hdist: usize,
    dynamic_literal_max_bits: usize,
    dynamic_distance_max_bits: usize,
    literal_lookup_bits: u4,
    payload_ns: i128,
    output_bytes: usize,
    literal_symbols: usize,
    length_symbols: usize,
    match_bytes: usize,
    distance_symbols: usize,
    length_symbol_histogram: [vort.DynamicDecodeProfile.length_symbol_count]usize,
    distance_symbol_histogram: [vort.DynamicDecodeProfile.distance_symbol_count]usize,
    length_extra_reads: usize,
    distance_extra_reads: usize,
    length_extra_bits: usize,
    distance_extra_bits: usize,
    literal_fast_hits: usize,
    literal_fast_misses: usize,
    distance_fast_hits: usize,
    distance_fast_misses: usize,
    literal_lookup_covered: usize,
    literal_lookup_size: usize,
    distance_lookup_covered: usize,
    distance_lookup_size: usize,
    match_rle_count: usize,
    match_rle_bytes: usize,
    match_small_distance_count: usize,
    match_small_distance_bytes: usize,
    match_non_overlapping_count: usize,
    match_non_overlapping_bytes: usize,
    match_overlapping_count: usize,
    match_overlapping_bytes: usize,
    mix: u64,
};

const binary_payload = blk: {
    @setEvalBranchQuota(200000);
    var data: [64 * 1024]u8 = undefined;
    for (&data, 0..) |*byte, i| byte.* = @intCast((i * 131 + (i >> 3) * 17 + 29) & 0xff);
    break :blk data;
};

const BuiltinCase = struct {
    name: []const u8,
    payload: []const u8,
};

const builtins = [_]BuiltinCase{
    .{ .name = "tiny", .payload = "hello rust deflate baselines" },
    .{ .name = "repetitive", .payload = "abcabcabcabc" ** 512 },
    .{ .name = "distance-heavy", .payload = ("0123456789abcdef" ** 1024) ++ "----" ++ ("0123456789abcdef" ** 1024) },
    .{ .name = "text", .payload = "the quick brown fox jumps over the lazy dog\n" ** 1024 },
    .{ .name = "dynamic-match", .payload = "literal-heavy dynamic huffman decode stage\n" ** 512 },
    .{ .name = "binary", .payload = &binary_payload },
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var include_builtins = false;
    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(init.gpa);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--builtins-plus-files")) {
            include_builtins = true;
            continue;
        }
        try paths.append(init.gpa, arg);
    }

    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(init.gpa);
    if (paths.items.len == 0 or include_builtins) {
        for (builtins) |case| try rows.append(init.gpa, try measurePayload(init, case.name, case.payload));
    }
    for (paths.items) |path| {
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);
        try rows.append(init.gpa, try measurePayload(init, path, data));
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, rows.items);
    if (csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
        try stdout_writer.interface.writeAll(csv.written());
        try stdout_writer.interface.flush();
    }
}

fn measurePayload(init: std.process.Init, name: []const u8, payload: []const u8) !Row {
    const options = vort.optionsForCompressionLevel(.default);
    const zlib_frame = try vort.encodeZlibDynamicWithOptionsAlloc(init.gpa, payload, options);
    defer init.gpa.free(zlib_frame);
    const raw = rawSliceFromZlib(zlib_frame);
    const header = try vort.parseRawDeflateHeaderInfo(raw);
    if (header.block_type != .dynamic) return error.InvalidDeflateBlockType;

    const profile_start = std.Io.Clock.awake.now(init.io);
    const profile = try vort.profileFirstDynamicDeflateBlock(raw);
    const payload_ns = profile_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    if (profile.output_bytes != payload.len) return error.DecodeLengthMismatch;

    return .{
        .case = name,
        .input_bytes = payload.len,
        .raw_bytes = raw.len,
        .dynamic_hlit = header.dynamic_hlit orelse 0,
        .dynamic_hdist = header.dynamic_hdist orelse 0,
        .dynamic_literal_max_bits = header.dynamic_literal_max_bits orelse 0,
        .dynamic_distance_max_bits = header.dynamic_distance_max_bits orelse 0,
        .literal_lookup_bits = profile.literal_lookup_bits,
        .payload_ns = payload_ns,
        .output_bytes = profile.output_bytes,
        .literal_symbols = profile.literal_symbols,
        .length_symbols = profile.length_symbols,
        .match_bytes = profile.match_bytes,
        .distance_symbols = profile.distance_symbols,
        .length_symbol_histogram = profile.length_symbol_histogram,
        .distance_symbol_histogram = profile.distance_symbol_histogram,
        .length_extra_reads = profile.length_extra_reads,
        .distance_extra_reads = profile.distance_extra_reads,
        .length_extra_bits = profile.length_extra_bits,
        .distance_extra_bits = profile.distance_extra_bits,
        .literal_fast_hits = profile.literal_fast_hits,
        .literal_fast_misses = profile.literal_fast_misses,
        .distance_fast_hits = profile.distance_fast_hits,
        .distance_fast_misses = profile.distance_fast_misses,
        .literal_lookup_covered = profile.literal_lookup_covered,
        .literal_lookup_size = profile.literal_lookup_size,
        .distance_lookup_covered = profile.distance_lookup_covered,
        .distance_lookup_size = profile.distance_lookup_size,
        .match_rle_count = profile.match_rle_count,
        .match_rle_bytes = profile.match_rle_bytes,
        .match_small_distance_count = profile.match_small_distance_count,
        .match_small_distance_bytes = profile.match_small_distance_bytes,
        .match_non_overlapping_count = profile.match_non_overlapping_count,
        .match_non_overlapping_bytes = profile.match_non_overlapping_bytes,
        .match_overlapping_count = profile.match_overlapping_count,
        .match_overlapping_bytes = profile.match_overlapping_bytes,
        .mix = profile.mix,
    };
}

fn rawSliceFromZlib(frame: []const u8) []const u8 {
    std.debug.assert(frame.len >= 6);
    return frame[2 .. frame.len - 4];
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("case,input_bytes,raw_bytes,dynamic_hlit,dynamic_hdist,dynamic_literal_max_bits,dynamic_distance_max_bits,literal_lookup_bits,payload_ns,output_bytes,literal_symbols,length_symbols,match_bytes,distance_symbols,length_symbol_histogram,distance_symbol_histogram,top_length_symbols,top_distance_symbols,top_length_extra_symbols,top_distance_extra_symbols,length_extra_width_reads,distance_extra_width_reads,length_extra_width_bits,distance_extra_width_bits,length_extra_reads,distance_extra_reads,length_extra_bits,distance_extra_bits,literal_fast_hits,literal_fast_misses,distance_fast_hits,distance_fast_misses,literal_lookup_covered,literal_lookup_size,distance_lookup_covered,distance_lookup_size,literal_lookup_coverage_ratio,distance_lookup_coverage_ratio,dominant_match_class,dominant_match_byte_ratio,match_rle_count,match_rle_bytes,match_small_distance_count,match_small_distance_bytes,match_non_overlapping_count,match_non_overlapping_bytes,match_overlapping_count,match_overlapping_bytes,match_rle_byte_ratio,match_small_distance_byte_ratio,match_non_overlapping_byte_ratio,match_overlapping_byte_ratio,literal_fast_miss_ratio,distance_fast_miss_ratio,extra_bits_per_match,mix\n");
    for (rows) |row| {
        try writer.print("{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},", .{
            row.case,
            row.input_bytes,
            row.raw_bytes,
            row.dynamic_hlit,
            row.dynamic_hdist,
            row.dynamic_literal_max_bits,
            row.dynamic_distance_max_bits,
            row.literal_lookup_bits,
            row.payload_ns,
            row.output_bytes,
            row.literal_symbols,
            row.length_symbols,
            row.match_bytes,
            row.distance_symbols,
        });
        try writeHistogram(writer, &row.length_symbol_histogram);
        try writer.writeByte(',');
        try writeHistogram(writer, &row.distance_symbol_histogram);
        try writer.writeByte(',');
        try writeTopSymbols(writer, &row.length_symbol_histogram, 257);
        try writer.writeByte(',');
        try writeTopSymbols(writer, &row.distance_symbol_histogram, 0);
        try writer.writeByte(',');
        try writeTopExtraSymbols(writer, &row.length_symbol_histogram, &length_extra_bits_by_symbol, 257);
        try writer.writeByte(',');
        try writeTopExtraSymbols(writer, &row.distance_symbol_histogram, &distance_extra_bits_by_symbol, 0);
        try writer.writeByte(',');
        try writeExtraWidthHistogram(writer, &row.length_symbol_histogram, &length_extra_bits_by_symbol, false);
        try writer.writeByte(',');
        try writeExtraWidthHistogram(writer, &row.distance_symbol_histogram, &distance_extra_bits_by_symbol, false);
        try writer.writeByte(',');
        try writeExtraWidthHistogram(writer, &row.length_symbol_histogram, &length_extra_bits_by_symbol, true);
        try writer.writeByte(',');
        try writeExtraWidthHistogram(writer, &row.distance_symbol_histogram, &distance_extra_bits_by_symbol, true);
        const dominant_match = dominantMatchClass(row);
        try writer.print(",{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.6},{d:.6},{s},{d:.6},{d},{d},{d},{d},{d},{d},{d},{d},{d:.6},{d:.6},{d:.6},{d:.6},{d:.6},{d:.6},{d:.6},{d}\n", .{
            row.length_extra_reads,
            row.distance_extra_reads,
            row.length_extra_bits,
            row.distance_extra_bits,
            row.literal_fast_hits,
            row.literal_fast_misses,
            row.distance_fast_hits,
            row.distance_fast_misses,
            row.literal_lookup_covered,
            row.literal_lookup_size,
            row.distance_lookup_covered,
            row.distance_lookup_size,
            ratio(row.literal_lookup_covered, row.literal_lookup_size),
            ratio(row.distance_lookup_covered, row.distance_lookup_size),
            dominant_match.label,
            ratio(dominant_match.bytes, row.match_bytes),
            row.match_rle_count,
            row.match_rle_bytes,
            row.match_small_distance_count,
            row.match_small_distance_bytes,
            row.match_non_overlapping_count,
            row.match_non_overlapping_bytes,
            row.match_overlapping_count,
            row.match_overlapping_bytes,
            ratio(row.match_rle_bytes, row.match_bytes),
            ratio(row.match_small_distance_bytes, row.match_bytes),
            ratio(row.match_non_overlapping_bytes, row.match_bytes),
            ratio(row.match_overlapping_bytes, row.match_bytes),
            ratio(row.literal_fast_misses, row.literal_fast_hits + row.literal_fast_misses),
            ratio(row.distance_fast_misses, row.distance_fast_hits + row.distance_fast_misses),
            ratio(row.length_extra_bits + row.distance_extra_bits, row.length_symbols),
            row.mix,
        });
    }
}

const DominantMatchClass = struct {
    label: []const u8,
    bytes: usize,
};

fn dominantMatchClass(row: Row) DominantMatchClass {
    var best = DominantMatchClass{ .label = "rle", .bytes = row.match_rle_bytes };
    const candidates = [_]DominantMatchClass{
        .{ .label = "small_distance", .bytes = row.match_small_distance_bytes },
        .{ .label = "non_overlapping", .bytes = row.match_non_overlapping_bytes },
        .{ .label = "overlapping", .bytes = row.match_overlapping_bytes },
    };
    for (candidates) |candidate| {
        if (candidate.bytes > best.bytes) best = candidate;
    }
    return best;
}

fn writeHistogram(writer: *std.Io.Writer, histogram: []const usize) !void {
    for (histogram, 0..) |count, i| {
        if (i != 0) try writer.writeByte(';');
        try writer.print("{d}", .{count});
    }
}

const length_extra_bits_by_symbol = [_]usize{
    0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 2, 2, 2, 2,
    3, 3, 3, 3, 4, 4, 4, 4,
    5, 5, 5, 5, 0,
};

const distance_extra_bits_by_symbol = [_]usize{
    0,  0,  0,  0,
    1,  1,  2,  2,
    3,  3,  4,  4,
    5,  5,  6,  6,
    7,  7,  8,  8,
    9,  9,  10, 10,
    11, 11, 12, 12,
    13, 13,
};

const TopSymbol = struct {
    symbol: usize = 0,
    count: usize = 0,
};

fn writeTopSymbols(writer: *std.Io.Writer, histogram: []const usize, symbol_base: usize) !void {
    var top: [3]TopSymbol = @splat(.{});
    for (histogram, 0..) |count, i| {
        const symbol = symbol_base + i;
        var pos: usize = 0;
        while (pos < top.len) : (pos += 1) {
            if (count > top[pos].count or (count == top[pos].count and count != 0 and symbol < top[pos].symbol)) {
                var shift = top.len - 1;
                while (shift > pos) : (shift -= 1) top[shift] = top[shift - 1];
                top[pos] = .{ .symbol = symbol, .count = count };
                break;
            }
        }
    }
    for (top, 0..) |entry, i| {
        if (i != 0) try writer.writeByte(';');
        try writer.print("{d}:{d}", .{ entry.symbol, entry.count });
    }
}

fn writeTopExtraSymbols(writer: *std.Io.Writer, histogram: []const usize, extra_bits: []const usize, symbol_base: usize) !void {
    var top: [3]TopSymbol = @splat(.{});
    for (histogram, 0..) |count, i| {
        const cost = count * extra_bits[i];
        const symbol = symbol_base + i;
        var pos: usize = 0;
        while (pos < top.len) : (pos += 1) {
            if (cost > top[pos].count or (cost == top[pos].count and cost != 0 and symbol < top[pos].symbol)) {
                var shift = top.len - 1;
                while (shift > pos) : (shift -= 1) top[shift] = top[shift - 1];
                top[pos] = .{ .symbol = symbol, .count = cost };
                break;
            }
        }
    }
    for (top, 0..) |entry, i| {
        if (i != 0) try writer.writeByte(';');
        try writer.print("{d}:{d}", .{ entry.symbol, entry.count });
    }
}

fn writeExtraWidthHistogram(writer: *std.Io.Writer, histogram: []const usize, extra_bits: []const usize, comptime weighted_bits: bool) !void {
    var by_width: [14]usize = @splat(0);
    for (histogram, 0..) |count, i| {
        const width = extra_bits[i];
        by_width[width] += if (weighted_bits) count * width else count;
    }
    for (by_width, 0..) |value, i| {
        if (i != 0) try writer.writeByte(';');
        try writer.print("{d}", .{value});
    }
}

fn ratio(numerator: usize, denominator: usize) f64 {
    if (denominator == 0) return 0;
    return @as(f64, @floatFromInt(numerator)) / @as(f64, @floatFromInt(denominator));
}
