const std = @import("std");
const vort = @import("vort");

const payload = "abcd" ** 16_384;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |arg| try std.fmt.parseInt(usize, arg, 10) else 1_000;
    if (iterations == 0 or args.next() != null) return error.InvalidBlockPlan;

    const encoded = try vort.brEncodePlannedStreamAlloc(init.gpa, payload);
    defer init.gpa.free(encoded);
    var history: [32 * 1024]u8 = undefined;
    var output: [payload.len]u8 = undefined;

    var best_ns: u64 = std.math.maxInt(u64);
    var best_checksum: usize = 0;
    for (0..5) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            var decoder = vort.BrotliIncrementalCopyStreamDecoder.initWithOptions(&history, .{ .expected_output_len = payload.len });
            var input_offset: usize = 0;
            var output_offset: usize = 0;
            while (decoder.snapshot().phase != .done) {
                const step = try decoder.step(encoded[input_offset..], output[output_offset..]);
                if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.ReferenceDecodeFailed;
                input_offset += step.progress.input_read;
                output_offset += step.progress.output_written;
            }
            try decoder.finish();
            if (input_offset != encoded.len or output_offset != payload.len or !std.mem.eql(u8, payload, &output))
                return error.SizeMismatch;
            checksum +%= output_offset + output[0] + output[output.len - 1];
        }
        const ns_value = start.durationTo(std.Io.Clock.awake.now(init.io)).nanoseconds;
        const elapsed_ns: u64 = if (ns_value <= 0) 0 else @intCast(ns_value);
        if (elapsed_ns < best_ns) {
            best_ns = elapsed_ns;
            best_checksum = checksum;
        }
    }

    var buffer: [512]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll("input_bytes,encoded_bytes,iterations,elapsed_ns,mib_s,checksum\n");
    try stdout.interface.print("{d},{d},{d},{d},{d:.2},{d}\n", .{
        payload.len,
        encoded.len,
        iterations,
        best_ns,
        mibPerSecond(payload.len * iterations, best_ns),
        best_checksum,
    });
    try stdout.interface.flush();
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) /
        (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}
