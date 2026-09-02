const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

const Case = struct { name: []const u8, payload: []const u8, quality: c_int };

const Options = struct {
    iterations: usize = 1_000,
    only_case: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    var runtime = try libbrotli.Runtime.open();
    defer runtime.deinit();

    const alternating = "abcabcXabcabcYabcabcZabcabcW" ** 1024;
    var distance_heavy: [64 * 1024]u8 = undefined;
    var state: u32 = 0x243f_6a88;
    for (&distance_heavy, 0..) |*byte, i| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (i >= 257 and i % 37 < 24) distance_heavy[i - 257] else @truncate(state >> 24);
    }
    const cases = [_]Case{
        .{ .name = "structured_q4", .payload = "{\"service\":\"vort\",\"codec\":\"brotli\",\"value\":12345}\n" ** 512, .quality = 4 },
        .{ .name = "alternating_q5", .payload = alternating, .quality = 5 },
        .{ .name = "distance_q8", .payload = &distance_heavy, .quality = 8 },
    };

    var buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll("case,input_bytes,encoded_bytes,iterations,elapsed_ns,mib_s,command_block_types,distance_context_trees,checksum\n");
    for (cases) |case| {
        if (options.only_case) |wanted| if (!std.mem.eql(u8, wanted, case.name)) continue;
        const encoded = try runtime.encodeAlloc(init.gpa, case.payload, case.quality);
        defer init.gpa.free(encoded);
        const summary = try vort.brSummarizeStreamAlloc(init.gpa, encoded);
        const history_len = @min(case.payload.len, (@as(usize, 1) << summary.window_bits) - 16);
        const history = try init.gpa.alloc(u8, history_len);
        defer init.gpa.free(history);
        const output = try init.gpa.alloc(u8, case.payload.len);
        defer init.gpa.free(output);
        const iterations = options.iterations;
        const sample = try measure(init.io, encoded, case.payload, history, output, iterations);
        try stdout.interface.print("{s},{d},{d},{d},{d},{d:.2},{d},{d},{d}\n", .{
            case.name,                                                      case.payload.len,                encoded.len,                        iterations,      sample.elapsed_ns,
            mibPerSecond(case.payload.len * iterations, sample.elapsed_ns), summary.max_command_block_types, summary.max_distance_context_trees, sample.checksum,
        });
    }
    try stdout.interface.flush();
}

const Sample = struct { elapsed_ns: u64, checksum: usize };

fn measure(io: std.Io, encoded: []const u8, expected: []const u8, history: []u8, output: []u8, iterations: usize) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .checksum = 0 };
    for (0..5) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            var decoder = vort.BrotliIncrementalCopyStreamDecoder.initWithOptions(history, .{ .expected_output_len = expected.len });
            var input_offset: usize = 0;
            var output_offset: usize = 0;
            while (decoder.snapshot().phase != .done) {
                const step = try decoder.step(encoded[input_offset..], output[output_offset..]);
                if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.ReferenceDecodeFailed;
                input_offset += step.progress.input_read;
                output_offset += step.progress.output_written;
            }
            try decoder.finish();
            if (input_offset != encoded.len or output_offset != expected.len or !std.mem.eql(u8, output, expected))
                return error.SizeMismatch;
            checksum +%= output_offset + output[0] + output[output.len - 1];
        }
        const ns_value = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
        const elapsed_ns: u64 = if (ns_value <= 0) 0 else @intCast(ns_value);
        if (elapsed_ns < best.elapsed_ns) best = .{ .elapsed_ns = elapsed_ns, .checksum = checksum };
    }
    return best;
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--case")) {
            options.only_case = args.next() orelse return error.MissingCorpusPath;
        } else return error.UnknownArgument;
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    return options;
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) /
        (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}
