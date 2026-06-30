const std = @import("std");
const builtin = @import("builtin");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("cpu arch={s} os={s} crc32_dispatch={s}\n", .{
        @tagName(builtin.cpu.arch),
        @tagName(builtin.os.tag),
        @tagName(vort.checksum.bestCrc32Dispatch()),
    });
    try stdout.flush();
}
