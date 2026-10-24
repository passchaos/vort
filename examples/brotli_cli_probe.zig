const std = @import("std");
const cli = @import("cli/brotli.zig");
pub fn main(init: std.process.Init) !void {
    var buffer: [2048]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const command = args.next() orelse return error.MissingCommand;
    if (std.mem.eql(u8, command, "encode-br-file")) try cli.encodeFile(init, &args, &writer.interface, false) else if (std.mem.eql(u8, command, "encode-br-stream-file")) try cli.encodeFile(init, &args, &writer.interface, true) else if (std.mem.eql(u8, command, "encode-br-hex")) try cli.encodeHex(init, &args, &writer.interface) else if (std.mem.eql(u8, command, "encode-br-stored-file")) try cli.encodeStoredFile(init, &args, &writer.interface) else if (std.mem.eql(u8, command, "encode-br-stored-hex")) try cli.encodeStoredHex(init, &args, &writer.interface) else return error.UnknownCommand;
    try writer.interface.flush();
}
