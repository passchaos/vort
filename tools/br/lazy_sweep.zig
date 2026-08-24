const std = @import("std");
const vort = @import("vort");

const json_payload = "{\"kind\":\"event\",\"active\":true,\"values\":[1,2,3,5,8,13]}\n" ** 48;
const source_payload = "pub fn update(state: *State, value: u32) void { state.total += value; state.count += 1; }\n" ** 40;
const log_payload = "2026-08-21T02:00:00Z level=info service=vort request=compress status=ok bytes=4096\n" ** 40;
const Case = struct { name: []const u8, payload: []const u8 };
const expected_sizes = [3]usize{ 62, 91, 83 };

pub fn main(init: std.process.Init) !void {
    const cases = [_]Case{ .{ .name = "json", .payload = json_payload }, .{ .name = "source", .payload = source_payload }, .{ .name = "log", .payload = log_payload } };
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for ([_]usize{ 64, 128, 256, 512 }) |chain| {
        for ([_]usize{ 64, 128, 258 }) |nice| {
            for ([_]usize{ 1, 2 }) |gain| {
                try stdout.interface.print("chain={d} nice={d} gain={d}", .{ chain, nice, gain });
                for (cases, expected_sizes) |case, expected_size| {
                    const encoded = try vort.brEncodePlannedStreamLazyWithOptionsAlloc(init.gpa, case.payload, .{ .max_chain = chain, .nice_len = nice, .lazy_min_gain = gain });
                    defer init.gpa.free(encoded);
                    if (encoded.len != expected_size) return error.UnexpectedEncodedSize;
                    try stdout.interface.print(" {s}={d}", .{ case.name, encoded.len });
                }
                try stdout.interface.writeByte('\n');
            }
        }
    }
    try stdout.interface.flush();
}
