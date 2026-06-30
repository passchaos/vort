const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    const samples = [_][]const u8{
        "alpha beta alpha beta alpha beta\n" ** 16,
        "gamma alpha beta gamma alpha beta\n" ** 16,
        "the quick brown fox jumps over the lazy dog\n" ** 8,
    };
    const target_size: usize = 256;
    const plan = vort.dictionary.planTraining(&samples, target_size);
    const dict = try vort.trainDictionaryAlloc(init.gpa, &samples, .{ .target_size = target_size, .min_phrase_len = 5, .max_phrase_len = 24 });
    defer init.gpa.free(dict);
    const meta = vort.DictionaryMetadata.fromBytes(dict, 32 * 1024);

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("dictionary report: samples={d} sample_bytes={d} target={d} dict_bytes={d} id={x} window={d}\n", .{
        plan.sample_count,
        plan.total_sample_bytes,
        plan.target_size,
        dict.len,
        meta.id.asInt(),
        meta.window_len,
    });
    try stdout.flush();
}
