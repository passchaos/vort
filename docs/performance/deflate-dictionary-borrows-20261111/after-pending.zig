const std = @import("std");
const builtin = @import("builtin");
const vort = @import("vort");

pub fn main() !void {
    const dictionary = "ABCDEFGHIJ";
    const wire = [_]u8{ 0x43, 0xb0, 0x00 };
    var history: [32768]u8 = @splat(0xa5);
    var decoder = try vort.RawDeflateIncrementalFixedLiteralDecoder.initWithDictionary(.{}, &history, dictionary);
    const first = try decoder.step(&wire, &.{});
    std.debug.print("source_revision=working_tree_from_9a41b4e43e6258f8e10d602b3d7d5312cd683d1f public_module=src/root.zig mode={s} operation=pending_match_short_seed\n", .{@tagName(builtin.mode)});
    std.debug.print("pending_phase={s} distance={d} remaining={d} input_read={d} history_len={d} history_pos={d}\n", .{@tagName(decoder.phase), decoder.match_distance, decoder.match_remaining, first.progress.input_read, decoder.history_len, decoder.history_pos});
    std.debug.print("nonoverlapping_short_seed=12345 expected_refusal=InvalidStreamState expected_preserved_output=ABCDEFGHIJ\n", .{});
    const state_before = std.mem.asBytes(&decoder)[0..@sizeOf(@TypeOf(decoder))].*;
    const history_before = history;
    decoder.seedDictionary("12345") catch |err| {
        std.debug.print("actual_seed_error={s} history_len={d} history_pos={d}\n", .{@errorName(err), decoder.history_len, decoder.history_pos});
        if (err != error.InvalidStreamState) return err;
        if (!std.mem.eql(u8, &state_before, std.mem.asBytes(&decoder))) return error.PendingStateMutation;
        if (!std.mem.eql(u8, &history_before, &history)) return error.PendingHistoryMutation;
        var output: [10]u8 = @splat(0x81);
        const result = try decoder.step(wire[first.progress.input_read..], &output);
        std.debug.print("actual_status={s} actual_input={d} actual_output={d} actual_bytes={any}\n", .{@tagName(result.status), result.progress.input_read, result.progress.output_written, output});
        if (!std.mem.eql(u8, dictionary, &output)) return error.PendingHistoryCorrupted;
        return;
    };
    return error.UnsafeShortSeedAccepted;
}
