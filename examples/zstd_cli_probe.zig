//! Thin validation surface using the same modules as vort CLI.
const std = @import("std");
const controls = @import("cli/zstd_controls.zig");
pub fn main(init: std.process.Init) !void {
    var buffer: [2048]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const command = args.next() orelse return error.MissingCommand;
    if (std.mem.eql(u8, command, "encode-zstd-native-hex")) try controls.encodeTextHex(init, &args, &writer.interface) else if (std.mem.eql(u8, command, "encode-zstd-native-bytes-hex")) try controls.encodeBytesHex(init, &args, &writer.interface) else if (std.mem.eql(u8, command, "encode-zstd-native-file-hex")) try controls.encodeFileHex(init, &args, &writer.interface) else if (std.mem.eql(u8, command, "encode-zstd-native-file")) try controls.encodeFile(init, &args, &writer.interface) else if (std.mem.eql(u8, command, "encode-zstd-level-file")) try controls.encodeLevelFile(init, &args, &writer.interface) else return error.UnknownCommand;
    try writer.interface.flush();
}
