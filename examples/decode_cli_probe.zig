//! Focused executable for testing the actual codec CLI adapters on WASI.
const std = @import("std");
const brotli = @import("cli/brotli.zig");
const deflate = @import("cli/deflate.zig");
const zstd = @import("cli/zstd_decode.zig");
const zstd_encoder = @import("zstd_cli_probe.zig");

pub fn main(init: std.process.Init) !void {
    var buffer: [2048]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const command = args.next() orelse return error.MissingCommand;
    if (std.mem.eql(u8, command, "decode-br-file-to")) {
        try brotli.decodeFile(init, &args, &writer.interface);
    } else if (std.mem.eql(u8, command, "encode-br-stream-file")) {
        try brotli.encodeFile(init, &args, &writer.interface, true);
    } else if (std.mem.eql(u8, command, "encode-gzip-best-file")) {
        try deflate.encodeGzipBestFile(init, &args, &writer.interface);
    } else if (deflate.isGzipDecodeFileCommand(command)) {
        try deflate.decodeGzipFile(init, &args, &writer.interface);
    } else if (!try zstd.dispatch(command, init, &args, &writer.interface) and
        !try zstd_encoder.dispatch(command, init, &args, &writer.interface))
    {
        return error.UnknownCommand;
    }
    try writer.interface.flush();
}
