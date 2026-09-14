const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");
const fixture = @import("q8_records_fixture.zig");

pub fn main(init: std.process.Init) !void {
    var reference = try libbrotli.Runtime.open();
    defer reference.deinit();
    var payload: [64 * 1024]u8 = undefined;
    var decoded: [64 * 1024]u8 = undefined;
    var rows: usize = 0;
    var improved: usize = 0;
    var regressed: usize = 0;
    var record_beats_lazy_but_loses_optimal: usize = 0;
    var total_saved: usize = 0;
    var best_saved: usize = 0;
    for ([_]usize{ 4 * 1024, 8 * 1024, 16 * 1024, 32 * 1024, 64 * 1024 }) |input_len| {
        for ([_]usize{ 32, 64, 128, 256 }) |row_len| {
            const mutation_limit = @max(@as(usize, 1), (row_len - 1) / 8);
            for ([_]usize{ 1, @max(@as(usize, 2), mutation_limit / 2), mutation_limit }) |mutations| {
                for (0..8) |seed| {
                    const input = payload[0..input_len];
                    fixture.fillVariant(input, row_len, mutations, @truncate(0x243f_6a88 +% input_len +% row_len +% seed *% 0x85eb_ca6b), @truncate(0x9e37_79b9 +% mutations *% 0x0100_0193 +% seed *% 0xc2b2_ae35));
                    var profile: vort.BrotliRatioEncodeProfile = .{};
                    const profiled = try vort.brProfilePlannedRatioBlockAlloc(init.gpa, input, init.io, &profile);
                    defer init.gpa.free(profiled);
                    if (!profile.record_optimal_attempted or profile.record_optimal_bytes == 0) return error.ProfileShapeMismatch;
                    const prior = @min(profile.lazy_bytes, profile.optimal_bytes);
                    if (profile.record_optimal_bytes < profile.lazy_bytes and profile.record_optimal_bytes > profile.optimal_bytes) {
                        std.debug.print("record arbitration hazard input={d} row={d} mutations={d} seed={d} lazy={d} optimal={d} record={d}\n", .{ input_len, row_len, mutations, seed, profile.lazy_bytes, profile.optimal_bytes, profile.record_optimal_bytes });
                        record_beats_lazy_but_loses_optimal += 1;
                    }
                    if (profile.record_optimal_bytes > prior) {
                        regressed += 1;
                    }
                    if (profiled.len != @min(prior, profile.record_optimal_bytes)) return error.ProfileShapeMismatch;
                    const encoded = try vort.brEncodePlannedStreamRatioAlloc(init.gpa, input);
                    defer init.gpa.free(encoded);
                    if (encoded.len != @min(profile.lazy_bytes, profile.record_optimal_bytes)) return error.ProfileShapeMismatch;
                    if (encoded.len != profiled.len) return error.RecordOptimalRegression;
                    const written = try vort.brDecodeStreamInto(encoded, decoded[0..input_len]);
                    if (written != input_len or !std.mem.eql(u8, input, decoded[0..input_len])) return error.SizeMismatch;
                    try reference.decode(encoded, decoded[0..input_len]);
                    if (!std.mem.eql(u8, input, decoded[0..input_len])) return error.SizeMismatch;
                    const saved = prior -| profile.record_optimal_bytes;
                    improved += @intFromBool(saved != 0);
                    total_saved += saved;
                    best_saved = @max(best_saved, saved);
                    rows += 1;
                }
            }
        }
    }
    var buffer: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print("br_record_optimal_audit={s} rows={d} improved={d} record_loses={d} arbitration_hazards={d} total_saved={d} best_saved={d}\n", .{ if (record_beats_lazy_but_loses_optimal == 0) "ok" else "failed", rows, improved, regressed, record_beats_lazy_but_loses_optimal, total_saved, best_saved });
    try stdout.interface.flush();
    if (record_beats_lazy_but_loses_optimal != 0) return error.RecordOptimalRegression;
}
