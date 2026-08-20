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
        const planned = try vort.brEncodePlannedStreamAlloc(init.gpa, case.payload);
        defer init.gpa.free(planned);
        const decoded = try vort.brDecodeStreamAlloc(init.gpa, planned);
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;
        const stored = try vort.brEncodeStoredStreamAlloc(init.gpa, case.payload);
        defer init.gpa.free(stored);
        if (planned.len >= stored.len) return error.InvalidBlockPlan;
        try stdout.print("brotli planned corpus {s}: input={d} planned={d} stored={d}\n", .{ case.name, case.payload.len, planned.len, stored.len });
    }
    try stdout.flush();
}
