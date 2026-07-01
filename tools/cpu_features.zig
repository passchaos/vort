const std = @import("std");
const builtin = @import("builtin");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    const report = vort.checksum.cpuFeatureReport();
    try stdout.print("cpu arch={s} os={s} crc32_dispatch={s} crc32_ieee_note={s} crc32c_dispatch={s} x86_sse42={} x86_pclmul={} arm_crc32={} crc32c_hw_candidate={} ieee_crc32_pclmul_candidate={} ieee_crc32_hw={} crc32c_best={s}\n", .{
        @tagName(builtin.cpu.arch),
        @tagName(builtin.os.tag),
        @tagName(vort.checksum.bestCrc32Dispatch()),
        if (report.ieee_crc32_uses_hardware) "hardware" else "portable-ieee-slice16",
        @tagName(vort.checksum.bestCrc32CDispatch()),
        report.x86_sse42,
        report.x86_pclmul,
        report.arm_crc32,
        report.crc32c_hardware_candidate,
        report.ieee_crc32_pclmul_candidate,
        report.ieee_crc32_uses_hardware,
        @tagName(vort.checksum.bestCrc32CDispatch()),
    });
    try stdout.flush();
}
