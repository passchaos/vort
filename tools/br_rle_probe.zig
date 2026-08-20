const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    const payload = "a" ** 4096;
    const encoded = try vort.brEncodeRleStreamAlloc(init.gpa, payload);
    defer init.gpa.free(encoded);
    var stdout_buffer: [128]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout_writer.interface.writeAll(encoded);
    try stdout_writer.interface.flush();
}
