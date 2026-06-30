const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    const cases = [_][]const u8{
        "",
        "a",
        "hello",
        "The quick brown fox jumps over the lazy dog",
        "gzip stored differential" ** 64,
    };

    for (cases) |case| {
        const encoded = try vort.encodeGzipStoredAlloc(init.gpa, case);
        defer init.gpa.free(encoded);
        const decoded = try vort.decodeGzipStoredAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, case, decoded)) return error.RoundTripMismatch;
    }

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("gzip stored smoke: cases={d} mode=stored-deflate-wrapper\n", .{cases.len});
    try stdout.flush();
}
