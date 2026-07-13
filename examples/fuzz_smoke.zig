const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    const store_stats = try vort.fuzz.runStoreSmokeCorpus(init.gpa);
    const deflate_stats = try vort.fuzz.runDeflateSmokeCorpus(init.gpa);

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("fuzz smoke: store_cases={d} store_valid={d} store_errors={d} deflate_cases={d} deflate_valid={d} deflate_errors={d}\n", .{
        store_stats.cases,
        store_stats.valid_frames,
        store_stats.expected_errors,
        deflate_stats.cases,
        deflate_stats.valid_frames,
        deflate_stats.expected_errors,
    });
    try stdout.flush();
}
