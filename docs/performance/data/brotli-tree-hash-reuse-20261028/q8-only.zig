const std = @import("std");
const br = @import("vort_br");
pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingInput;
    const iterations = try std.fmt.parseInt(usize, args.next() orelse "128", 10);
    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    if (stat.size > 65536) return error.InputTooLarge;
    const input = try init.gpa.alloc(u8, @intCast(stat.size));
    var read_buffer: [4096]u8 = undefined;
    var reader = file.reader(init.io, &read_buffer);
    if (try reader.interface.readSliceShort(input) != input.len) return error.InputTooSmall;
    defer init.gpa.free(input);
    const expected = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, .{ .quality = 8, .mode = .generic });
    defer init.gpa.free(expected);
    const decoded = try br.decodeStreamAlloc(init.gpa, expected);
    defer init.gpa.free(decoded);
    if (!std.mem.eql(u8, input, decoded)) return error.DecodeMismatch;
    var sum: u64 = 0;
    var ns: u64 = 0;
    for (0..iterations) |_| {
        const start = std.Io.Clock.awake.now(init.io);
        const wire = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, .{ .quality = 8, .mode = .generic });
        ns += @intCast(start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds());
        if (!std.mem.eql(u8, expected, wire)) return error.WireMismatch;
        sum +%= wire.len;
        init.gpa.free(wire);
    }
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(expected, &digest, .{});
    const wire_sha = std.fmt.bytesToHex(digest, .lower);
    var buf: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buf);
    try writer.interface.print("input={d} wire={d} iterations={d} ns={d} checksum={d} wire_sha={s}\n", .{ input.len, expected.len, iterations, ns, sum, &wire_sha });
    try writer.interface.flush();
}
