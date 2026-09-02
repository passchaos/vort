const std = @import("std");
const vort = @import("vort");

const json_payload = "{\"kind\":\"event\",\"active\":true,\"values\":[1,2,3,5,8,13]}\n" ** 48;
const source_payload = "pub fn update(state: *State, value: u32) void { state.total += value; state.count += 1; }\n" ** 40;
const log_payload = "2026-08-21T02:00:00Z level=info service=vort request=compress status=ok bytes=4096\n" ** 40;
const Case = struct { name: []const u8, payload: []const u8 };

pub fn main(init: std.process.Init) !void {
    const cases = [_]Case{ .{ .name = "json", .payload = json_payload }, .{ .name = "source", .payload = source_payload }, .{ .name = "log", .payload = log_payload } };
    var buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (cases) |case| {
        var stats: vort.BrotliPlannedEncodeStats = .{};
        const encoded = try vort.brEncodePlannedStreamAllocWithStatsTimed(init.gpa, case.payload, init.io, &stats);
        defer init.gpa.free(encoded);
        const total_ns = stats.lz77_ns + stats.command_plan_ns + stats.wire_ns;
        try stdout.interface.print("{s}: input={d} encoded={d} tokens={d} commands={d} literal_bytes={d} matched_bytes={d} literal_symbols={d} command_symbols={d} distance_symbols={d} lz77_ns={d} command_ns={d} wire_ns={d} shares={d:.3}/{d:.3}/{d:.3} wire_parts=freq:{d},alpha:{d},lengths:{d},header:{d},encoder:{d},payload:{d}\n", .{
            case.name,                                                                          stats.input_bytes,                                                          stats.encoded_bytes,         stats.token_count, stats.command_count,   stats.literal_bytes, stats.matched_bytes,
            stats.literal_symbol_count,                                                         stats.command_symbol_count,                                                 stats.distance_symbol_count, stats.lz77_ns,     stats.command_plan_ns, stats.wire_ns,       @as(f64, @floatFromInt(stats.lz77_ns)) / @as(f64, @floatFromInt(total_ns)),
            @as(f64, @floatFromInt(stats.command_plan_ns)) / @as(f64, @floatFromInt(total_ns)), @as(f64, @floatFromInt(stats.wire_ns)) / @as(f64, @floatFromInt(total_ns)), stats.frequency_ns,          stats.alphabet_ns, stats.lengths_ns,      stats.header_ns,     stats.encoder_ns,
            stats.payload_ns,
        });
    }
    try stdout.interface.flush();
}
