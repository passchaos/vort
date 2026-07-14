const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(init.gpa);
    while (args.next()) |path| {
        if (std.mem.eql(u8, path, "--csv")) {
            csv_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        try paths.append(init.gpa, path);
    }

    var output = std.Io.Writer.Allocating.init(init.gpa);
    defer output.deinit();
    const writer = &output.writer;
    try writer.print("path,input_bytes,token_count,literal_tokens,match_tokens,matched_bytes,avg_match_len_x100,avg_match_distance,short_match_tokens,far_match_tokens,stored_bytes,fixed_bytes,dynamic_bytes,hlit,hdist,hclen,code_length_ops,stats_ns,dynamic_encode_ns,best_encode_ns,dynamic_zlib_bytes,best_zlib_bytes,best_preset_token_count,best_preset_literal_tokens,best_preset_match_tokens,best_preset_matched_bytes,best_preset_avg_match_len_x100,best_preset_avg_match_distance,best_preset_short_match_tokens,best_preset_far_match_tokens,best_preset_zlib_bytes,best_preset_default_size_ratio,best_preset_default_token_ratio,best_preset_default_avg_len_ratio,best_preset_default_avg_distance_ratio,fixed_dynamic_size_ratio,best_dynamic_time_ratio,stats_dynamic_time_ratio\n", .{});

    if (paths.items.len == 0) {
        try reportPath(init, writer, "README.md");
        try reportPath(init, writer, "docs/roadmap.md");
    } else {
        for (paths.items) |path| try reportPath(init, writer, path);
    }
    const bytes = output.written();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(bytes);
    try stdout.flush();

    if (csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
    }
}

fn reportPath(init: std.process.Init, stdout: *std.Io.Writer, path: []const u8) !void {
    const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(data);

    const options = vort.optionsForCompressionLevel(.default);
    const stats_start = std.Io.Clock.awake.now(init.io);
    const stats = try vort.dynamicDeflatePlanStatsAlloc(init.gpa, data, options);
    const stats_ns = stats_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    const dynamic_start = std.Io.Clock.awake.now(init.io);
    const dynamic_zlib = try vort.encodeZlibDynamicWithOptionsAlloc(init.gpa, data, options);
    defer init.gpa.free(dynamic_zlib);
    const dynamic_encode_ns = dynamic_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    const best_start = std.Io.Clock.awake.now(init.io);
    const best_zlib = try vort.encodeZlibBestAlloc(init.gpa, data, options);
    defer init.gpa.free(best_zlib);
    const best_encode_ns = best_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    const best_preset_options = vort.optionsForCompressionLevel(.best);
    const best_preset_stats = try vort.dynamicDeflatePlanStatsAlloc(init.gpa, data, best_preset_options);
    const best_preset_zlib = try vort.encodeZlibBestAlloc(init.gpa, data, best_preset_options);
    defer init.gpa.free(best_preset_zlib);

    const fixed_dynamic_size_ratio = ratio(stats.fixed_bytes, stats.dynamic_bytes);
    const best_dynamic_time_ratio = ratioSigned(best_encode_ns, dynamic_encode_ns);
    const stats_dynamic_time_ratio = ratioSigned(stats_ns, dynamic_encode_ns);
    const best_preset_default_size_ratio = ratio(best_preset_zlib.len, best_zlib.len);
    const best_preset_default_token_ratio = ratio(best_preset_stats.token_count, stats.token_count);
    const best_preset_default_avg_len_ratio = ratio(best_preset_stats.avg_match_len_x100, stats.avg_match_len_x100);
    const best_preset_default_avg_distance_ratio = ratio(best_preset_stats.avg_match_distance, stats.avg_match_distance);

    try stdout.print("{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}", .{
        path,
        stats.input_bytes,
        stats.token_count,
        stats.literal_tokens,
        stats.match_tokens,
        stats.matched_bytes,
        stats.avg_match_len_x100,
        stats.avg_match_distance,
        stats.short_match_tokens,
        stats.far_match_tokens,
        stats.stored_bytes,
        stats.fixed_bytes,
        stats.dynamic_bytes,
        stats.hlit,
        stats.hdist,
        stats.hclen,
        stats.code_length_ops,
        stats_ns,
        dynamic_encode_ns,
        best_encode_ns,
        dynamic_zlib.len,
        best_zlib.len,
    });
    try stdout.print(",{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4},{d:.4}\n", .{
        best_preset_stats.token_count,
        best_preset_stats.literal_tokens,
        best_preset_stats.match_tokens,
        best_preset_stats.matched_bytes,
        best_preset_stats.avg_match_len_x100,
        best_preset_stats.avg_match_distance,
        best_preset_stats.short_match_tokens,
        best_preset_stats.far_match_tokens,
        best_preset_zlib.len,
        best_preset_default_size_ratio,
        best_preset_default_token_ratio,
        best_preset_default_avg_len_ratio,
        best_preset_default_avg_distance_ratio,
        fixed_dynamic_size_ratio,
        best_dynamic_time_ratio,
        stats_dynamic_time_ratio,
    });
}

fn ratio(numerator: usize, denominator: usize) f64 {
    if (denominator == 0) return 0;
    return @as(f64, @floatFromInt(numerator)) / @as(f64, @floatFromInt(denominator));
}

fn ratioSigned(numerator: i128, denominator: i128) f64 {
    if (denominator == 0) return 0;
    return @as(f64, @floatFromInt(numerator)) / @as(f64, @floatFromInt(denominator));
}
