const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    const stats = try vort.fuzz.runStoreSmokeCorpus(init.gpa);

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("store fuzz smoke: cases={d} valid_frames={d} expected_errors={d}\n", .{
        stats.cases,
        stats.valid_frames,
        stats.expected_errors,
    });
    try stdout.flush();
}
