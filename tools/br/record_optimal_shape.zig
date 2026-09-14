const std = @import("std");
const vort = @import("vort");
const fixture = @import("q8_records_fixture.zig");

pub fn main(init: std.process.Init) !void {
    var input: [fixture.input_len]u8 = undefined;
    fixture.fill(&input);
    var profile: vort.BrotliRatioEncodeProfile = .{};
    const encoded = try vort.brProfilePlannedRatioBlockAlloc(init.gpa, &input, init.io, &profile);
    defer init.gpa.free(encoded);
    const decoded = try vort.brDecodeStreamAllocExactSize(init.gpa, encoded, input.len);
    defer init.gpa.free(decoded);
    if (!std.mem.eql(u8, decoded, &input)) return error.SizeMismatch;

    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const writer = &stdout.interface;
    try writer.writeAll("plan,wire_bytes,tokens,literals,matches,matched_bytes,fixed_bits,commands,recent,last,explicit,insert_codes,copy_codes,recent_symbols,top_distances,top_distance_counts\n");
    try writeRow(writer, "lazy", profile.lazy_bytes, profile.lazy_token_count, profile.lazy_literal_count, profile.lazy_match_count, profile.lazy_matched_bytes, profile.lazy_fixed_bits, profile.lazy_command_count, profile.lazy_recent_distance_count, profile.lazy_last_distance_count, profile.lazy_explicit_distance_count, &profile.lazy_insert_code_histogram, &profile.lazy_copy_code_histogram, &profile.lazy_recent_symbol_histogram, &profile.lazy_top_distances, &profile.lazy_top_distance_counts);
    try writeRow(writer, "optimal", profile.optimal_bytes, profile.optimal_token_count, profile.optimal_literal_count, profile.optimal_match_count, profile.optimal_matched_bytes, profile.optimal_fixed_bits, profile.optimal_command_count, profile.optimal_recent_distance_count, profile.optimal_last_distance_count, profile.optimal_explicit_distance_count, &profile.optimal_insert_code_histogram, &profile.optimal_copy_code_histogram, &profile.optimal_recent_symbol_histogram, &profile.optimal_top_distances, &profile.optimal_top_distance_counts);
    try writeRow(writer, "record", profile.record_optimal_bytes, profile.record_optimal_token_count, profile.record_optimal_literal_count, profile.record_optimal_match_count, profile.record_optimal_matched_bytes, profile.record_optimal_fixed_bits, profile.record_optimal_command_count, profile.record_optimal_recent_distance_count, profile.record_optimal_last_distance_count, profile.record_optimal_explicit_distance_count, &profile.record_optimal_insert_code_histogram, &profile.record_optimal_copy_code_histogram, &profile.record_optimal_recent_symbol_histogram, &profile.record_optimal_top_distances, &profile.record_optimal_top_distance_counts);
    try stdout.interface.flush();
}

fn writeRow(writer: *std.Io.Writer, name: []const u8, wire: usize, tokens: usize, literals: usize, matches: usize, matched: usize, fixed_bits: usize, commands: usize, recent: usize, last: usize, explicit: usize, insert_codes: []const usize, copy_codes: []const usize, recent_symbols: []const usize, top_distances: []const usize, top_distance_counts: []const usize) !void {
    try writer.print("{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},", .{ name, wire, tokens, literals, matches, matched, fixed_bits, commands, recent, last, explicit });
    try writeHistogram(writer, insert_codes);
    try writer.writeByte(',');
    try writeHistogram(writer, copy_codes);
    try writer.writeByte(',');
    try writeHistogram(writer, recent_symbols);
    try writer.writeByte(',');
    try writeHistogram(writer, top_distances);
    try writer.writeByte(',');
    try writeHistogram(writer, top_distance_counts);
    try writer.writeByte('\n');
}

fn writeHistogram(writer: *std.Io.Writer, values: []const usize) !void {
    for (values, 0..) |value, index| {
        if (index != 0) try writer.writeByte(';');
        try writer.print("{d}", .{value});
    }
}
