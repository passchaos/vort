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
    var dictionary_matches: usize = 0;
    var dictionary_longest: usize = 0;
    var compressed_total: usize = 0;
    var patch_total: usize = 0;
    var best_with_dict_total: usize = 0;
    var best_with_dict_patches: usize = 0;
    for (samples) |sample| {
        const summary = try vort.summarizeDictionaryMatchesAlloc(init.gpa, dict, sample, 5);
        covered += summary.covered_bytes;
        dictionary_matches += summary.matches;
        dictionary_longest = @max(dictionary_longest, summary.longest);
        const patch = try vort.encodeDictionaryPatchAlloc(init.gpa, dict, sample, 5);
        defer init.gpa.free(patch);
        const patched = try vort.decodeDictionaryPatchAlloc(init.gpa, dict, patch);
        defer init.gpa.free(patched);
        if (!std.mem.eql(u8, sample, patched)) return error.RoundTripMismatch;
        patch_total += patch.len;
        const best_with_dict = try vort.storeEncodeBestWithDictionaryAlloc(init.gpa, dict, sample, 5);
        defer init.gpa.free(best_with_dict);
        const info = try vort.store.parseHeader(best_with_dict);
        if (info.flags == 3) {
            best_with_dict_patches += 1;
            const decoded = try vort.storeDecodeDictionaryPatchAlloc(init.gpa, dict, best_with_dict);
            defer init.gpa.free(decoded);
            if (!std.mem.eql(u8, sample, decoded)) return error.RoundTripMismatch;
        } else {
            const decoded = try vort.storeDecodeAnyAlloc(init.gpa, best_with_dict);
            defer init.gpa.free(decoded);
            if (!std.mem.eql(u8, sample, decoded)) return error.RoundTripMismatch;
        }
        best_with_dict_total += best_with_dict.len;
        const encoded = try vort.encodeRawBestAlloc(init.gpa, sample, vort.optionsForCompressionLevel(.fastest));
        defer init.gpa.free(encoded);
        compressed_total += encoded.len;
    }
    const coverage = if (plan.total_sample_bytes == 0) 0.0 else @as(f64, @floatFromInt(covered)) / @as(f64, @floatFromInt(plan.total_sample_bytes));
    const ratio = if (plan.total_sample_bytes == 0) 0.0 else @as(f64, @floatFromInt(compressed_total)) / @as(f64, @floatFromInt(plan.total_sample_bytes));
    const patch_ratio = if (plan.total_sample_bytes == 0) 0.0 else @as(f64, @floatFromInt(patch_total)) / @as(f64, @floatFromInt(plan.total_sample_bytes));
    const best_with_dict_ratio = if (plan.total_sample_bytes == 0) 0.0 else @as(f64, @floatFromInt(best_with_dict_total)) / @as(f64, @floatFromInt(plan.total_sample_bytes));

    var stdout_buffer: [768]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("dictionary report: samples={d} sample_bytes={d} target={d} dict_bytes={d} id={x} window={d} matches={d} covered_bytes={d} longest={d} coverage={d:.4} patch_bytes={d} patch_ratio={d:.4} best_with_dict_bytes={d} best_with_dict_ratio={d:.4} best_with_dict_patches={d} baseline_deflate_bytes={d} baseline_ratio={d:.4}\n", .{
        plan.sample_count,
        plan.total_sample_bytes,
        plan.target_size,
        dict.len,
        meta.id.asInt(),
        meta.window_len,
        dictionary_matches,
        covered,
        dictionary_longest,
        coverage,
        patch_total,
        patch_ratio,
        best_with_dict_total,
        best_with_dict_ratio,
        best_with_dict_patches,
        compressed_total,
        ratio,
    });
    try stdout.flush();
}
