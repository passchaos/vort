const std = @import("std");
const vort = @import("vort");

pub const Measurement = struct {
    matcher_ns: i96,
    emit_ns: i96,
    output_bytes: usize,
    token_mix: u64,
};

pub fn supports(case_name: []const u8) bool {
    return std.mem.eql(u8, case_name, "json-log") or std.mem.eql(u8, case_name, "source");
}

/// Measure the two production planning stages while preserving the same
/// matcher/history/writer lifetime used by the full incremental encoder.
pub fn measure(
    init: std.process.Init,
    input: []const u8,
    compression: vort.CompressionOptions,
    block_len: usize,
    iterations: usize,
) !Measurement {
    const normalized = vort.normalizeCompressionOptionsForStrategy(compression);
    if (normalized.parser != .lazy) return error.InvalidBlockPlan;

    var matcher: vort.deflate.IncrementalDeflateMatcher = .{};
    defer matcher.deinit(init.gpa);
    var tokens: std.ArrayList(vort.lz77.Token) = .empty;
    defer tokens.deinit(init.gpa);
    var history: std.ArrayList(u8) = .empty;
    defer history.deinit(init.gpa);
    var writer: vort.bitstream.BitWriter = .{};
    defer writer.deinit(init.gpa);

    var token_mix: u64 = 0;
    var matcher_ns: i96 = 0;
    var emit_ns: i96 = 0;
    var output_bytes: usize = 0;
    for (0..iterations) |_| {
        matcher.reset();
        tokens.clearRetainingCapacity();
        history.clearRetainingCapacity();
        writer.bytes.clearRetainingCapacity();
        writer.scratch = 0;
        writer.bit_index = 0;
        var offset: usize = 0;
        while (offset < input.len) {
            const end = @min(input.len, offset + block_len);
            const matcher_start = std.Io.Clock.awake.now(init.io);
            const plan = try matcher.plan(
                init.gpa,
                &tokens,
                input[offset..end],
                history.items,
                normalized.lz77_options,
                true,
            );
            matcher_ns += matcher_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
            // Keep token production observable without timing a separate
            // content checksum that does not belong to either measured stage.
            token_mix +%= @intCast(tokens.items.len);
            const emit_start = std.Io.Clock.awake.now(init.io);
            try vort.deflate.writeIncrementalBestPlannedBlock(
                init.gpa,
                &writer,
                input[offset..end],
                plan.tokens,
                end == input.len,
                compression,
                plan.dynamic,
            );
            emit_ns += emit_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
            try retainHistory(init.gpa, &history, input[offset..end]);
            offset = end;
        }
        output_bytes = writer.bytes.items.len + @intFromBool(writer.bit_index != 0);
    }
    return .{
        .matcher_ns = matcher_ns,
        .emit_ns = emit_ns,
        .output_bytes = output_bytes,
        .token_mix = token_mix,
    };
}

fn retainHistory(allocator: std.mem.Allocator, history: *std.ArrayList(u8), block: []const u8) !void {
    const window_len = vort.lz77.default_window_len;
    try history.ensureTotalCapacity(allocator, window_len);
    if (block.len >= window_len) {
        history.clearRetainingCapacity();
        history.appendSliceAssumeCapacity(block[block.len - window_len ..]);
        return;
    }

    const keep = @min(history.items.len, window_len - block.len);
    const start = history.items.len - keep;
    std.mem.copyForwards(u8, history.items[0..keep], history.items[start..]);
    history.items.len = keep;
    history.appendSliceAssumeCapacity(block);
}
