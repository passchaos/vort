const std = @import("std");
const vort = @import("vort");

const Options = struct { iterations: usize = 20, rounds: usize = 3, csv_path: ?[]const u8 = null };
const Case = struct { name: []const u8, samples: []const []const u8 };
const Mode = enum { basic, validated };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);

    var text_samples: [24][]const u8 = undefined;
    var text_storage: [24][320]u8 = undefined;
    var json_samples: [24][]const u8 = undefined;
    var json_storage: [24][320]u8 = undefined;
    var binary_samples: [24][]const u8 = undefined;
    var binary_storage: [24][320]u8 = undefined;
    for (0..24) |sample_index| {
        fillCorpusSample(&text_storage[sample_index], .text, sample_index);
        fillCorpusSample(&json_storage[sample_index], .json, sample_index);
        fillCorpusSample(&binary_storage[sample_index], .binary, sample_index);
        text_samples[sample_index] = &text_storage[sample_index];
        json_samples[sample_index] = &json_storage[sample_index];
        binary_samples[sample_index] = &binary_storage[sample_index];
    }
    const cases = [_]Case{
        .{ .name = "text", .samples = &text_samples },
        .{ .name = "json", .samples = &json_samples },
        .{ .name = "binary", .samples = &binary_samples },
    };

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("mode,case,samples,sample_bytes,target_size,max_phrases,iterations,rounds,best_ns,bytes_per_second,checksum\n");
    for (cases) |case| {
        try benchmarkCase(init, &csv.writer, case, .basic, options);
        try benchmarkCase(init, &csv.writer, case, .validated, options);
    }
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [2048]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn benchmarkCase(init: std.process.Init, writer: *std.Io.Writer, case: Case, mode: Mode, options: Options) !void {
    const training = if (mode == .validated) case.samples[0 .. case.samples.len - 4] else case.samples;
    const validation = if (mode == .validated) case.samples[case.samples.len - 4 ..] else &.{};
    var best_ns: u64 = std.math.maxInt(u64);
    var best_checksum: usize = 0;
    for (0..options.rounds) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(init.io);
        for (0..options.iterations) |_| {
            const dictionary = switch (mode) {
                .basic => try vort.trainDictionaryAlloc(init.gpa, training, .{ .target_size = 512, .max_phrases = 1024 }),
                .validated => try vort.dictionary.trainValidatedAlloc(init.gpa, training, validation, .{ .target_size = 512, .max_phrases = 1024 }),
            };
            checksum +%= dictionary.len;
            for (dictionary) |byte| checksum +%= byte;
            init.gpa.free(dictionary);
        }
        const elapsed_ns = elapsed(start, init.io);
        if (elapsed_ns < best_ns) {
            best_ns = elapsed_ns;
            best_checksum = checksum;
        }
    }
    const input_bytes = case.samples.len * case.samples[0].len;
    const bytes_per_second = if (best_ns == 0) 0 else @as(u64, @intFromFloat(@as(f64, @floatFromInt(input_bytes * options.iterations)) * 1_000_000_000.0 / @as(f64, @floatFromInt(best_ns))));
    try writer.print("{s},{s},{d},{d},512,1024,{d},{d},{d},{d},{d}\n", .{
        @tagName(mode), case.name, case.samples.len, input_bytes, options.iterations, options.rounds, best_ns, bytes_per_second, best_checksum,
    });
}

const CorpusKind = enum { text, json, binary };
const text_pattern = "compression dictionary stream history entropy buffer codec packet ";
const json_pattern = "{\"kind\":\"event\",\"service\":\"vort\",\"status\":\"ok\",\"id\":12345}\n";

fn fillCorpusSample(output: *[320]u8, kind: CorpusKind, sample_index: usize) void {
    var state: u32 = 0x243f_6a88 +% @as(u32, @intCast(sample_index * 977));
    for (output, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = switch (kind) {
            // Preserve the original 59-byte text workload period. Unlike the
            // former JSON `% 67`, this bound stays inside the source literal.
            .text => text_pattern[(index + sample_index) % 59],
            .json => json_pattern[(index + sample_index * 3) % json_pattern.len],
            .binary => if (index % 32 < 24) @truncate(index + sample_index) else @truncate(state >> 24),
        };
    }
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseUnsigned(usize, args.next() orelse return error.InvalidBlockPlan, 10)
        else if (std.mem.eql(u8, arg, "--rounds"))
            options.rounds = try std.fmt.parseUnsigned(usize, args.next() orelse return error.InvalidBlockPlan, 10)
        else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.InvalidBlockPlan
        else
            return error.InvalidBlockPlan;
    }
    if (options.iterations == 0 or options.rounds == 0) return error.InvalidBlockPlan;
    return options;
}
