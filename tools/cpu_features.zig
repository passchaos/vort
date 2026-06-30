const std = @import("std");
const builtin = @import("builtin");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    const report = vort.checksum.cpuFeatureReport();
    try stdout.print("cpu arch={s} os={s} crc32_dispatch={s} x86_sse42={} x86_pclmul={} crc32c_hw_candidate={} ieee_crc32_hw={}\n", .{
        @tagName(builtin.cpu.arch),
        @tagName(builtin.os.tag),
        @tagName(vort.checksum.bestCrc32Dispatch()),
        report.x86_sse42,
        report.x86_pclmul,
        report.crc32c_hardware_candidate,
        report.ieee_crc32_uses_hardware,
    });
    try stdout.flush();
}
