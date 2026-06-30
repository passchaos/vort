const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("path,input_bytes,raw_fixed_bytes,raw_ratio,encode_mib_s,decode_mib_s\n", .{});

    var any = false;
    while (args.next()) |path| {
        any = true;
        const data = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
        defer init.gpa.free(data);

        const encode_start = std.Io.Clock.awake.now(init.io);
        const encoded = try vort.encodeRawFixedDeflateAlloc(init.gpa, data);
        const encode_elapsed = encode_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        defer init.gpa.free(encoded);

        const decode_start = std.Io.Clock.awake.now(init.io);
        const decoded = try vort.decodeRawDeflateAlloc(init.gpa, encoded);
        const decode_elapsed = decode_start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, data, decoded)) return error.RoundTripMismatch;

        const ratio = if (data.len == 0) 0.0 else @as(f64, @floatFromInt(encoded.len)) / @as(f64, @floatFromInt(data.len));
        const mib = @as(f64, @floatFromInt(data.len)) / (1024.0 * 1024.0);
        const encode_s = @as(f64, @floatFromInt(encode_elapsed)) / @as(f64, std.time.ns_per_s);
        const decode_s = @as(f64, @floatFromInt(decode_elapsed)) / @as(f64, std.time.ns_per_s);
        const encode_mib_s = if (encode_s == 0) 0 else mib / encode_s;
        const decode_mib_s = if (decode_s == 0) 0 else mib / decode_s;
        try stdout.print("{s},{d},{d},{d:.4},{d:.2},{d:.2}\n", .{ path, data.len, encoded.len, ratio, encode_mib_s, decode_mib_s });
    }
    if (!any) return error.MissingCorpusPath;
    try stdout.flush();
}
