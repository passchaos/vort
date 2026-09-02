const std = @import("std");
const vort = @import("vort");

const json_payload =
    "{\"kind\":\"event\",\"active\":true,\"values\":[1,2,3,5,8,13]}\n" ** 48;
const source_payload =
    "pub fn update(state: *State, value: u32) void { state.total += value; state.count += 1; }\n" ** 40;
const log_payload =
    "2026-08-21T02:00:00Z level=info service=vort request=compress status=ok bytes=4096\n" ** 40;

const Case = struct { name: []const u8, payload: []const u8 };

pub fn main(init: std.process.Init) !void {
    const cases = [_]Case{
        .{ .name = "json", .payload = json_payload },
        .{ .name = "source", .payload = source_payload },
        .{ .name = "log", .payload = log_payload },
    };
    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    for (cases) |case| {
        try stdout.print("checking {s} input={d}\n", .{ case.name, case.payload.len });
        try stdout.flush();
        var stats: vort.BrotliPlannedEncodeStats = .{};
        const planned = try vort.brEncodePlannedStreamAllocWithStats(init.gpa, case.payload, &stats);
        defer init.gpa.free(planned);
        const decoded = try vort.brDecodeStreamAlloc(init.gpa, planned);
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;
        const stored = try vort.brEncodeStoredStreamAlloc(init.gpa, case.payload);
        defer init.gpa.free(stored);
        if (planned.len >= stored.len) return error.InvalidBlockPlan;
        const lazy = try vort.brEncodePlannedStreamLazyAlloc(init.gpa, case.payload);
        defer init.gpa.free(lazy);
        const lazy_decoded = try vort.brDecodeStreamAlloc(init.gpa, lazy);
        defer init.gpa.free(lazy_decoded);
        if (!std.mem.eql(u8, case.payload, lazy_decoded)) return error.SizeMismatch;
        try stdout.print("brotli planned corpus {s}: input={d} planned={d} lazy={d} stored={d} tokens={d} commands={d} literals={d} matches={d} alphabets={d}/{d}/{d}\n", .{
            case.name,                  case.payload.len,           planned.len,                 lazy.len, stored.len, stats.token_count, stats.command_count, stats.literal_bytes, stats.matched_bytes,
            stats.literal_symbol_count, stats.command_symbol_count, stats.distance_symbol_count,
        });
    }
    const mixed_chunks = [_][]const u8{
        "alpha beta gamma delta alpha beta gamma delta " ** 64,
        "qzxwvbnm1234567890QZXWVBNM!@#$%^&*",
        "omega theta lambda omega theta lambda " ** 64,
    };
    const mixed_expected = mixed_chunks[0] ++ mixed_chunks[1] ++ mixed_chunks[2];
    const mixed = try vort.brEncodePlannedStreamChunksAlloc(init.gpa, &mixed_chunks);
    defer init.gpa.free(mixed);
    const mixed_bound = try vort.brEncodedPlannedStreamChunksBound(&mixed_chunks);
    if (mixed.len > mixed_bound) return error.InvalidBlockPlan;
    const mixed_summary = try vort.brSummarizeStream(mixed);
    if (mixed_summary.compressed_meta_block_count < 2 or mixed_summary.uncompressed_meta_block_count < 1)
        return error.InvalidBlockPlan;
    const mixed_decoded = try vort.brDecodeStreamAllocExactSize(init.gpa, mixed, mixed_expected.len);
    defer init.gpa.free(mixed_decoded);
    if (!std.mem.eql(u8, mixed_expected, mixed_decoded)) return error.SizeMismatch;
    try stdout.print("brotli planned chunked: input={d} encoded={d} bound={d} compressed_blocks={d} stored_blocks={d}\n", .{
        mixed_expected.len,
        mixed.len,
        mixed_bound,
        mixed_summary.compressed_meta_block_count,
        mixed_summary.uncompressed_meta_block_count,
    });
    try stdout.flush();
}
