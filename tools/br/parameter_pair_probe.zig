//! Public q8 wire/guard and optional candidate-work validation; not a timer.
const std = @import("std");
const br = @import("vort_br");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingInput;
    const observed = std.mem.eql(u8, args.next() orelse "ordinary", "profile");
    if (args.next() != null) return error.ExtraArguments;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(65537));
    defer init.gpa.free(input);
    if (input.len > 65536) return error.InputTooLarge;
    var profile: br.QualityQ8Profile = .{};
    const wire = if (observed)
        try br.benchmarkQualityQ8ProfileAlloc(init.gpa, input, init.io, &profile)
    else
        try br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, .{ .quality = 8, .mode = .generic, .window_bits = 16 });
    defer init.gpa.free(wire);
    const storage = try init.gpa.alloc(u8, input.len + 64);
    defer init.gpa.free(storage);
    @memset(storage, 0xa5);
    const output = storage[32..][0..input.len];
    if (try br.decodeStreamInto(wire, output) != input.len or !std.mem.eql(u8, input, output)) return error.BadRoundTrip;
    for (storage[0..32]) |byte| if (byte != 0xa5) return error.Guard;
    for (storage[input.len + 32 ..]) |byte| if (byte != 0xa5) return error.Guard;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(wire, &digest, .{});
    const wire_sha = std.fmt.bytesToHex(digest, .lower);
    std.crypto.hash.sha2.Sha256.hash(input, &digest, .{});
    const input_sha = std.fmt.bytesToHex(digest, .lower);
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print("input={d} wire={d} input_sha={s} wire_sha={s} guards=1\n", .{ input.len, wire.len, &input_sha, &wire_sha });
    if (observed) {
        try std.json.Stringify.value(profile, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}
