const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    const samples = [_][]const u8{
        "alpha beta alpha beta alpha beta\n" ** 16,
        "gamma alpha beta gamma alpha beta\n" ** 16,
        "the quick brown fox jumps over the lazy dog\n" ** 8,
    };
    const target_size: usize = 256;
    const plan = vort.dictionary.planTraining(&samples, target_size);
    const dict = try vort.trainDictionaryAlloc(init.gpa, &samples, .{ .target_size = target_size, .min_phrase_len = 5, .max_phrase_len = 24 });
    defer init.gpa.free(dict);
    const meta = vort.DictionaryMetadata.fromBytes(dict, 32 * 1024);

    var covered: usize = 0;
    var compressed_total: usize = 0;
    for (samples) |sample| {
        covered += dictionaryCoveredBytes(dict, sample, 5);
        const encoded = try vort.encodeRawBestAlloc(init.gpa, sample, vort.optionsForCompressionLevel(.fastest));
        defer init.gpa.free(encoded);
        compressed_total += encoded.len;
    }
    const coverage = if (plan.total_sample_bytes == 0) 0.0 else @as(f64, @floatFromInt(covered)) / @as(f64, @floatFromInt(plan.total_sample_bytes));
    const ratio = if (plan.total_sample_bytes == 0) 0.0 else @as(f64, @floatFromInt(compressed_total)) / @as(f64, @floatFromInt(plan.total_sample_bytes));

    var stdout_buffer: [768]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("dictionary report: samples={d} sample_bytes={d} target={d} dict_bytes={d} id={x} window={d} covered_bytes={d} coverage={d:.4} baseline_deflate_bytes={d} baseline_ratio={d:.4}\n", .{
        plan.sample_count,
        plan.total_sample_bytes,
        plan.target_size,
        dict.len,
        meta.id.asInt(),
        meta.window_len,
        covered,
        coverage,
        compressed_total,
        ratio,
    });
    try stdout.flush();
}

fn dictionaryCoveredBytes(dict: []const u8, sample: []const u8, min_phrase_len: usize) usize {
    var covered: usize = 0;
    var i: usize = 0;
    while (i + min_phrase_len <= sample.len) {
        var best: usize = 0;
        var len: usize = min_phrase_len;
        while (i + len <= sample.len) : (len += 1) {
            if (std.mem.indexOf(u8, dict, sample[i..][0..len]) != null) best = len;
        }
        if (best != 0) {
            covered += best;
            i += best;
        } else {
            i += 1;
        }
    }
    return covered;
}
