const std = @import("std");
const vort = @import("vort");
const liblz4 = @import("liblz4_runtime.zig");

const Case = struct { name: []const u8, payload: []const u8 };
const Options = struct { iterations: usize = 5000, only_case: ?[]const u8 = null, csv_path: ?[]const u8 = null };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    var runtime = try liblz4.Runtime.open();
    defer runtime.deinit();

    const incompressible256k = try init.gpa.alloc(u8, 256 * 1024);
    defer init.gpa.free(incompressible256k);
    var state: u32 = 0x6d2b_79f5;
    for (incompressible256k) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 16);
    }
    const cases = [_]Case{
        .{ .name = "text", .payload = "LZ4 benchmark text payload. " ** 1024 },
        .{ .name = "structured", .payload = "{\"service\":\"vort\",\"codec\":\"lz4\",\"value\":12345}\n" ** 768 },
        .{ .name = "repetitive", .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256 },
        .{ .name = "incompressible256k", .payload = incompressible256k },
    };

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,input_bytes,encoded_bytes,iterations,vort_ns,vort_mib_s,checksum,literal_count,literal_bytes,match_count,match_bytes\n");
    var selected: usize = 0;
    for (cases) |case| {
        if (options.only_case) |wanted| if (!std.mem.eql(u8, wanted, case.name)) continue;
        selected += 1;
        const encoded = try runtime.encodeAlloc(init.gpa, case.payload);
        defer init.gpa.free(encoded);
        const summary = try vort.lz4SummarizeBlock(encoded);
        const output = try init.gpa.alloc(u8, case.payload.len);
        defer init.gpa.free(output);
        const written = try vort.lz4DecodeBlockIntoSlice(encoded, output, case.payload.len);
        if (written != case.payload.len or !std.mem.eql(u8, case.payload, output)) return error.SizeMismatch;

        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(init.io);
        for (0..options.iterations) |_| {
            mix +%= try vort.lz4DecodeBlockIntoSlice(encoded, output, case.payload.len);
            if (output.len != 0) mix +%= output[0];
        }
        const elapsed_ns = elapsedNs(init.io, start);
        try csv.writer.print("{s},{d},{d},{d},{d},{d:.2},{d},{d},{d},{d},{d}\n", .{
            case.name,                                                       case.payload.len, encoded.len,           options.iterations,    elapsed_ns,
            mibPerSecond(case.payload.len * options.iterations, elapsed_ns), mix,              summary.literal_count, summary.literal_bytes, summary.match_count,
            summary.match_bytes,
        });
    }
    if (selected == 0) return error.InvalidBlockPlan;
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--case"))
            options.only_case = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingCorpusPath
        else
            return error.UnknownArgument;
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    return options;
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    return (@as(f64, @floatFromInt(bytes)) / (1024 * 1024)) / (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}
