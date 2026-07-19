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

    var checked_cases: usize = 0;
    for (cases) |case| {
        try checkCase(case);
        checked_cases += 1;
    }

    var large: [8192 + 31]u8 = undefined;
    for (&large, 0..) |*byte, i| {
        byte.* = @truncate((i * 131 + 17) & 0xff);
    }
    const large_cases = [_][]const u8{
        large[0..],
        large[1..],
        large[17..],
        large[31..8192],
    };
    for (large_cases) |case| {
        try checkCase(case);
        checked_cases += 1;
    }

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("checksum diff smoke: cases={d} against=zig-std-adler32-crc32-crc32c\n", .{checked_cases});
    try stdout.flush();
}

fn checkCase(input: []const u8) !void {
    if (vort.adler32(input) != std.hash.Adler32.hash(input)) return error.AdlerMismatch;

    const expected_crc32 = std.hash.crc.Crc32IsoHdlc.hash(input);
    if (vort.crc32(input) != expected_crc32) return error.Crc32Mismatch;
    if (vort.crc32Slice4(input) != expected_crc32) return error.Crc32Mismatch;
    if (vort.crc32Slice8(input) != expected_crc32) return error.Crc32Mismatch;
    if (vort.crc32Slice16(input) != expected_crc32) return error.Crc32Mismatch;
    if (vort.crc32Slice32(input) != expected_crc32) return error.Crc32Mismatch;
    if (vort.crc32Best(input) != expected_crc32) return error.Crc32Mismatch;

    const expected_crc32c = std.hash.crc.Crc32Iscsi.hash(input);
    if (vort.crc32c(input) != expected_crc32c) return error.Crc32CMismatch;
    if (vort.crc32cSlice8(input) != expected_crc32c) return error.Crc32CMismatch;
    if (vort.crc32cSlice16(input) != expected_crc32c) return error.Crc32CMismatch;
    if (vort.crc32cBest(input) != expected_crc32c) return error.Crc32CMismatch;
}
