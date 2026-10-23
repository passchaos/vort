const std = @import("std");
const lzms = @import("lzms");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingOutputPath;
    var options = lzms.EncodeOptions{};
    if (args.next()) |mode| {
        if (std.mem.eql(u8, mode, "literals")) options.strategy = .literals else if (std.mem.eql(u8, mode, "lz")) options.enable_delta = false else if (!std.mem.eql(u8, mode, "greedy")) return error.InvalidLzms;
    }
    if (args.next()) |value| options.hash_log = try std.fmt.parseInt(u8, value, 10);
    if (args.next()) |value| options.max_match_distance = try std.fmt.parseInt(usize, value, 10);
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(lzms.maxBufferSize));
    defer init.gpa.free(input);
    var result = try lzms.encodeWithSummaryAlloc(init.gpa, input, options);
    defer result.deinit(init.gpa);
    const literal = try lzms.encodeLiteralAlloc(init.gpa, input);
    defer init.gpa.free(literal);
    const restored = try lzms.decodeAllocExactSize(init.gpa, result.bytes, input.len);
    defer init.gpa.free(restored);
    if (!std.mem.eql(u8, input, restored) or result.bytes.len > literal.len) return error.SizeMismatch;
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = result.bytes });
    std.debug.print("{{\"input\":{d},\"encoded\":{d},\"literal\":{d},\"literal_selected\":{s},\"lz\":{d},\"lz_rep\":{d},\"delta\":{d},\"delta_rep\":{d},\"delta_power_mask\":{d},\"matched_bytes\":{d},\"peak_working\":{d},\"max_lz_offset\":{d},\"max_delta_offset\":{d}}}\n", .{
        input.len,                       result.bytes.len,             literal.len,                     if (result.used_literal_reference) "true" else "false", result.summary.lz_matches, result.summary.lz_repeats,
        result.summary.delta_matches,    result.summary.delta_repeats, result.summary.delta_power_mask, result.summary.matched_bytes,                           result.peak_working_bytes, result.summary.max_lz_offset,
        result.summary.max_delta_offset,
    });
}
