//! Public q8 wire/guard and optional candidate-work or encode-time probe.
//! Inputs up to 2 MiB exercise the extended prepared distance-pair scope;
//! `profile` remains limited to the public 64 KiB q8 profile API.
const std = @import("std");
const br = @import("vort_br");

const max_input_bytes: usize = 2 * 1024 * 1024;
const profile_input_bytes: usize = 65536;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingInput;
    const mode = args.next() orelse "ordinary";
    const iterations = if (args.next()) |value| try std.fmt.parseInt(usize, value, 10) else 1;
    if (args.next() != null) return error.ExtraArguments;
    if (iterations == 0 or iterations > 64) return error.InvalidIterations;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_input_bytes + 1));
    defer init.gpa.free(input);
    if (input.len > max_input_bytes) return error.InputTooLarge;

    const options: br.PlannedEncodeOptions = .{ .quality = 8, .mode = .generic, .window_bits = 16 };
    var profile: br.QualityQ8Profile = .{};
    var total_ns: u64 = 0;
    const wire = if (std.mem.eql(u8, mode, "profile")) blk: {
        if (input.len > profile_input_bytes) return error.ProfileInputTooLarge;
        break :blk try br.benchmarkQualityQ8ProfileAlloc(init.gpa, input, init.io, &profile);
    } else blk: {
        const encoded = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, options);
        if (std.mem.eql(u8, mode, "timed")) {
            var index: usize = 0;
            while (index < iterations) : (index += 1) {
                const start = std.Io.Clock.awake.now(init.io);
                const current = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, options);
                total_ns += @intCast(start.untilNow(init.io, .awake).nanoseconds);
                init.gpa.free(current);
            }
        }
        break :blk encoded;
    };
    defer init.gpa.free(wire);

    const storage = try init.gpa.alloc(u8, input.len + 64);
    defer init.gpa.free(storage);
    @memset(storage, 0xa5);
    const output = storage[32..][0..input.len];
    const written = try br.decodeStreamInto(wire, output);
    if (written != input.len or !std.mem.eql(u8, input, output)) return error.BadRoundTrip;
    for (storage[0..32]) |byte| if (byte != 0xa5) return error.Guard;
    for (storage[input.len + 32 ..]) |byte| if (byte != 0xa5) return error.Guard;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(wire, &digest, .{});
    const wire_sha = std.fmt.bytesToHex(digest, .lower);
    std.crypto.hash.sha2.Sha256.hash(input, &digest, .{});
    const input_sha = std.fmt.bytesToHex(digest, .lower);
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print("input={d} wire={d} input_sha={s} wire_sha={s} guards=1", .{ input.len, wire.len, &input_sha, &wire_sha });
    if (std.mem.eql(u8, mode, "timed"))
        try stdout.interface.print(" timed_n={d} encode_avg_ns={d}", .{ iterations, total_ns / iterations });
    try stdout.interface.writeByte('\n');
    if (std.mem.eql(u8, mode, "profile")) {
        try std.json.Stringify.value(profile, .{}, &stdout.interface);
        try stdout.interface.writeByte('\n');
    }
    try stdout.interface.flush();
}
