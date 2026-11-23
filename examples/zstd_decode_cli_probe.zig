//! Focused executable for testing the actual Zstd CLI dispatcher on WASI.
const std = @import("std");
const decoder = @import("cli/zstd_decode.zig");

pub fn main(init: std.process.Init) !void {
    var buffer: [2048]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const command = args.next() orelse return error.MissingCommand;
    if (!try decoder.dispatch(command, init, &args, &writer.interface)) return error.UnknownCommand;
    try writer.interface.flush();
}
