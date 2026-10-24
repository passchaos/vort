const std = @import("std");
const cli = @import("cli/lz4_controls.zig");
pub fn main(init: std.process.Init) !void {
    var buffer: [2048]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const command = args.next() orelse return error.MissingCommand;
    if (std.mem.eql(u8, command, "encode-lz4-native-file")) try cli.encodeNativeFile(init, &args, &writer.interface, false) else if (std.mem.eql(u8, command, "encode-lz4-native-stream-file")) try cli.encodeNativeFile(init, &args, &writer.interface, true) else if (std.mem.eql(u8, command, "encode-lz4-block-file")) try cli.encodeBlockFile(init, &args, &writer.interface) else if (std.mem.eql(u8, command, "encode-lz4-block-hex")) try cli.encodeBlockHex(init, &args, &writer.interface, false) else if (std.mem.eql(u8, command, "encode-lz4-block-prefix-hex")) try cli.encodeBlockHex(init, &args, &writer.interface, true) else if (std.mem.eql(u8, command, "decode-lz4-block-hex")) try cli.decodeBlockHex(init, &args, &writer.interface) else return error.UnknownCommand;
    try writer.interface.flush();
}
