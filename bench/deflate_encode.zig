const std = @import("std");
const vort = @import("vort");

const Case = struct {
    name: []const u8,
    input: []const u8,
};

pub fn main(init: std.process.Init) !void {
    const cases = [_]Case{
        .{ .name = "small-text", .input = "hello hello hello hello" },
        .{ .name = "repeated", .input = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .name = "structured", .input = "abcabcabcabc xyz xyz xyz lorem ipsum lorem ipsum" },
    };
    const iterations: usize = 100_000;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var mix: u64 = 0;
    for (cases) |case| {
        const start = std.Io.Clock.awake.now(init.io);
        var last_size: usize = 0;
        for (0..iterations) |_| {
            const encoded = try vort.encodeRawFixedDeflateAlloc(init.gpa, case.input);
            defer init.gpa.free(encoded);
            const decoded = try vort.decodeRawDeflateAlloc(init.gpa, encoded);
            defer init.gpa.free(decoded);
            if (!std.mem.eql(u8, case.input, decoded)) return error.RoundTripMismatch;
            last_size = encoded.len;
            mix +%= vort.crc32(encoded);
        }
        const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        const elapsed_ns: f64 = @floatFromInt(elapsed_ns_signed);
        const elapsed_s = elapsed_ns / @as(f64, std.time.ns_per_s);
        const total_mib = (@as(f64, @floatFromInt(case.input.len)) * @as(f64, @floatFromInt(iterations))) / (1024.0 * 1024.0);
        try stdout.print("deflate fixed encode {s}: input_bytes={d} compressed_bytes={d} iterations={d} elapsed_s={d:.6} throughput_mib_s={d:.2}\n", .{
            case.name,
            case.input.len,
            last_size,
            iterations,
            elapsed_s,
            total_mib / elapsed_s,
        });
    }
    try stdout.print("deflate fixed encode mix={d}\n", .{mix});
    try stdout.flush();
}
