const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [2048]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    const command = args.next() orelse {
        try printHelp(stdout);
        try stdout.flush();
        return;
    };

    if (std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "help")) {
        try printHelp(stdout);
    } else if (std.mem.eql(u8, command, "checksum")) {
        const payload = args.next() orelse "";
        try stdout.print("input_bytes={d} adler32={d} crc32={d} crc32c={d}\n", .{
            payload.len,
            vort.adler32(payload),
            vort.crc32(payload),
            vort.crc32c(payload),
        });
    } else if (std.mem.eql(u8, command, "store-roundtrip")) {
        const payload = args.next() orelse "";
        const encoded = try vort.storeEncodeAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const decoded = try vort.storeDecodeAlloc(init.gpa, encoded);
        defer init.gpa.free(decoded);
        try stdout.print("input_bytes={d} encoded_bytes={d} decoded_ok={} crc32={d}\n", .{
            payload.len,
            encoded.len,
            std.mem.eql(u8, payload, decoded),
            vort.crc32(decoded),
        });
    } else {
        try stdout.print("unknown command: {s}\n\n", .{command});
        try printHelp(stdout);
    }

    try stdout.flush();
}

fn printHelp(stdout: *std.Io.Writer) !void {
    try stdout.print(
        \\vort bootstrap CLI
        \\
        \\commands:
        \\  help | --help              Show this message
        \\  checksum [text]            Print Adler-32, CRC-32, and CRC-32C for text
        \\  store-roundtrip [text]     Encode/decode the native store frame
        \\
        \\This CLI is a smoke surface for the library-first Vort APIs.
        \\
    , .{});
}
