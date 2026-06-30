const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var cases: usize = 0;
    var accepted: usize = 0;
    var rejected: usize = 0;

    while (args.next()) |hex| {
        const bytes = try hexToOwnedBytes(init.gpa, hex);
        defer init.gpa.free(bytes);
        cases += 1;
        if (vort.store.parseHeader(bytes)) |_| {
            accepted += 1;
        } else |err| switch (err) {
            error.TruncatedFrame,
            error.InvalidMagic,
            error.UnsupportedVersion,
            error.CorruptFrame,
            => rejected += 1,
            else => return err,
        }
    }

    if (cases == 0) {
        const stats = try vort.fuzz.runStoreSmokeCorpus(init.gpa);
        cases = stats.cases;
        accepted = stats.valid_frames;
        rejected = stats.expected_errors;
    }

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("fuzz corpus: cases={d} accepted={d} rejected={d}\n", .{ cases, accepted, rejected });
    try stdout.flush();
}

fn hexToOwnedBytes(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if ((hex.len & 1) != 0) return error.InvalidHexInput;
    const bytes = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(bytes);
    var i: usize = 0;
    while (i < bytes.len) : (i += 1) {
        bytes[i] = try std.fmt.parseInt(u8, hex[i * 2 .. i * 2 + 2], 16);
    }
    return bytes;
}
