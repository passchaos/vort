//! Repeatedly decodes one raw-deflate corpus prefix to expose the decoder's
//! hot path to sampling profilers. Not a benchmark gate.

const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var path: ?[]const u8 = null;
    var limit: usize = 128 * 1024;
    var iterations: usize = 200;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--limit")) {
            limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--iterations")) {
            iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else if (path == null) {
            path = arg;
        } else {
            return error.UnknownArgument;
        }
    }
    const input_path = path orelse return error.MissingArgument;
    if (limit == 0 or iterations == 0) return error.InvalidArguments;

    const file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer file.close(init.io);
    const read_len: usize = @intCast(@min(limit, (try file.stat(init.io)).size));
    if (read_len == 0) return error.InputTooSmall;
    const input = try init.gpa.alloc(u8, read_len);
    defer init.gpa.free(input);
    var read_buffer: [64 * 1024]u8 = undefined;
    var reader = file.reader(init.io, &read_buffer);
    if (try reader.interface.readSliceShort(input) != read_len) return error.InputTooSmall;

    const compressed = try vort.deflate.encodeRawBestAlloc(
        init.gpa,
        input,
        vort.optionsForCompressionLevel(.default),
    );
    defer init.gpa.free(compressed);
    const output = try init.gpa.alloc(u8, input.len);
    defer init.gpa.free(output);

    var mix: usize = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const result = try vort.decodeRawDeflate(compressed, output);
        mix +%= result.output_written;
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    const total_mib = (@as(f64, @floatFromInt(input.len)) * @as(f64, @floatFromInt(iterations))) /
        (1024.0 * 1024.0);
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, std.time.ns_per_s);
    std.debug.print(
        "path={s} input={d} compressed={d} iterations={d} mib_s={d:.2} mix={d}\n",
        .{ input_path, input.len, compressed.len, iterations, total_mib / seconds, mix },
    );
}
