const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    const cases = [_][]const u8{
        "",
        "a",
        "abc",
        "123456789",
        "The quick brown fox jumps over the lazy dog",
        "vort differential checksum smoke" ** 16,
    };

    for (cases) |case| {
        if (vort.adler32(case) != std.hash.Adler32.hash(case)) return error.AdlerMismatch;
        if (vort.crc32(case) != std.hash.crc.Crc32IsoHdlc.hash(case)) return error.Crc32Mismatch;
        if (vort.crc32c(case) != std.hash.crc.Crc32Iscsi.hash(case)) return error.Crc32CMismatch;
    }

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("checksum diff smoke: cases={d} against=zig-std-adler32-crc32-crc32c\n", .{cases.len});
    try stdout.flush();
}
