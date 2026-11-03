//! Guarded public one-shot raw Deflate comparison. Compile against either
//! source snapshot with --dep deflate -Mroot=... -Mdeflate=.../src/deflate.zig.

const std = @import("std");
const codec = @import("deflate");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const wire_path = args.next() orelse return error.MissingWire;
    const plain_path = args.next() orelse return error.MissingPlain;
    const iterations = try std.fmt.parseInt(usize, args.next() orelse "0", 10);
    if (args.next() != null) return error.InvalidArgument;
    const wire = try std.Io.Dir.cwd().readFileAlloc(init.io, wire_path, init.gpa, .limited(256 * 1024 * 1024));
    defer init.gpa.free(wire);
    const plain = try std.Io.Dir.cwd().readFileAlloc(init.io, plain_path, init.gpa, .limited(256 * 1024 * 1024));
    defer init.gpa.free(plain);
    const storage = try init.gpa.alloc(u8, plain.len + 64);
    defer init.gpa.free(storage);
    @memset(storage, 0xa5);
    const output = storage[32..][0..plain.len];
    var ns: u64 = 0;
    var sum: u64 = 0;
    for (0..iterations + 1) |iteration| {
        const start = std.Io.Clock.awake.now(init.io);
        const decoded = try codec.decodeRawAuto(wire, output);
        if (iteration != 0) ns += @intCast(start.durationTo(std.Io.Clock.awake.now(init.io)).nanoseconds);
        if (decoded.input_read != wire.len) return error.BadInputLen;
        if (decoded.output_written != plain.len) return error.BadOutputLen;
        if (!std.mem.eql(u8, output, plain)) return error.BadDecode;
        sum +%= decoded.output_written;
    }
    for (storage[0..32]) |byte| if (byte != 0xa5) return error.Guard;
    for (storage[plain.len + 32 ..]) |byte| if (byte != 0xa5) return error.Guard;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(output, &digest, .{});
    const hash = std.fmt.bytesToHex(digest, .lower);
    var buf: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buf);
    try writer.interface.print("codec=deflate-oneshot input={d} output={d} iterations={d} ns={d} checksum={d} plain_sha={s} guards=1\n", .{ wire.len, plain.len, iterations, ns, sum, &hash });
    try writer.interface.flush();
}
