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
    literal_fast_hits: usize,
    literal_fast_misses: usize,
    distance_fast_hits: usize,
    distance_fast_misses: usize,
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
        .literal_fast_hits = profile.literal_fast_hits,
        .literal_fast_misses = profile.literal_fast_misses,
        .distance_fast_hits = profile.distance_fast_hits,
        .distance_fast_misses = profile.distance_fast_misses,
        .mix = profile.mix,
    };
}

fn rawSliceFromZlib(frame: []const u8) []const u8 {
    std.debug.assert(frame.len >= 6);
    return frame[2 .. frame.len - 4];
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("case,input_bytes,raw_bytes,dynamic_hlit,dynamic_hdist,dynamic_literal_max_bits,dynamic_distance_max_bits,literal_lookup_bits,payload_ns,output_bytes,literal_symbols,length_symbols,match_bytes,distance_symbols,literal_fast_hits,literal_fast_misses,distance_fast_hits,distance_fast_misses,literal_fast_miss_ratio,distance_fast_miss_ratio,mix\n");
    for (rows) |row| {
        try writer.print("{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.6},{d:.6},{d}\n", .{
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
            row.literal_fast_hits,
            row.literal_fast_misses,
            row.distance_fast_hits,
            row.distance_fast_misses,
            ratio(row.literal_fast_misses, row.literal_fast_hits + row.literal_fast_misses),
            ratio(row.distance_fast_misses, row.distance_fast_hits + row.distance_fast_misses),
            row.mix,
        });
    }
}

fn ratio(numerator: usize, denominator: usize) f64 {
    if (denominator == 0) return 0;
    return @as(f64, @floatFromInt(numerator)) / @as(f64, @floatFromInt(denominator));
}
