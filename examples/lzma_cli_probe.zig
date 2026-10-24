//! Thin validation surface: the commands call the same modules as vort CLI.
const std = @import("std");
const lzma = @import("cli/lzma.zig");
const xz = @import("cli/xz.zig");
const micro = @import("cli/microlzma.zig");

pub fn main(init: std.process.Init) !void {
    var buffer: [2048]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const command = args.next() orelse return error.MissingCommand;
    if (std.mem.eql(u8, command, "encode-lzma-file")) {
        try lzma.encode(init, &args, &writer.interface);
    } else if (std.mem.eql(u8, command, "encode-xz-file")) {
        try xz.encode(init, &args, &writer.interface, false);
    } else if (std.mem.eql(u8, command, "encode-xz-stored-file")) {
        try xz.encode(init, &args, &writer.interface, true);
    } else if (std.mem.eql(u8, command, "encode-microlzma-file")) {
        try micro.encode(init, &args, &writer.interface);
    } else if (std.mem.eql(u8, command, "encode-microlzma-prefix-file")) {
        try micro.encodeLimited(init, &args, &writer.interface);
    } else if (std.mem.eql(u8, command, "encode-microlzma-aligned-prefix-file")) {
        try micro.encodeAlignedLimited(init, &args, &writer.interface);
    } else return error.UnknownCommand;
    try writer.interface.flush();
}
