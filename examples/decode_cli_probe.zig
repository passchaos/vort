//! Focused executable for testing the actual decode CLI adapters on WASI.
const std = @import("std");
const brotli = @import("cli/brotli.zig");
const zstd = @import("cli/zstd_decode.zig");

pub fn main(init: std.process.Init) !void {
    var buffer: [2048]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const command = args.next() orelse return error.MissingCommand;
    if (std.mem.eql(u8, command, "decode-br-file-to")) {
        try brotli.decodeFile(init, &args, &writer.interface);
    } else if (!try zstd.dispatch(command, init, &args, &writer.interface)) {
        return error.UnknownCommand;
    }
    try writer.interface.flush();
}
