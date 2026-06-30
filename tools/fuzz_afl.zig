const std = @import("std");
const fuzz_target = @import("fuzz_target.zig");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var cases: usize = 0;
    while (args.next()) |path| {
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(1 << 20));
        defer init.gpa.free(data);
        try fuzz_target.fuzzOne(init.gpa, data);
        cases += 1;
    }

    if (cases == 0) {
        const samples = [_][]const u8{
            "",
            "VORT",
            &.{ 0x01, 0x00, 0x00, 0xff, 0xff },
        };
        for (samples) |sample| {
            try fuzz_target.fuzzOne(init.gpa, sample);
            cases += 1;
        }
    }

    var stdout_buffer: [128]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("afl fuzz driver smoke: cases={d}\n", .{cases});
    try stdout.flush();
}
