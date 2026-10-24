const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

const Options = struct {
    iterations: usize = 1000,
    csv_path: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);

    var runtime = try libbrotli.Runtime.open();
    defer runtime.deinit();
    const payload = try makeClusteredPayload(init.io, init.gpa);
    defer init.gpa.free(payload);
    const encoded = try runtime.encodeAlloc(init.gpa, payload, 8);
    defer init.gpa.free(encoded);
    const summary = try vort.brSummarizeStreamAlloc(init.gpa, encoded);
    const sample = try vort.br.benchmarkClusteredDecodeStages(init.io, init.gpa, encoded, payload, options.iterations);
    const lookup_ns = sample.lookupNs();
    const stage_ns = sample.header_ns + lookup_ns + sample.payload_ns;
    const unattributed_ns = sample.total_ns -| stage_ns;

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,reference_version,quality,input_bytes,encoded_bytes,iterations,literal_trees,command_block_types,distance_trees,npostfix,ndirect,header_ns,literal_lookup_ns,command_lookup_ns,distance_lookup_ns,lookup_ns,payload_ns,total_ns,unattributed_ns,header_share,lookup_share,payload_share,unattributed_share,checksum\n");
    try csv.writer.print(
        "clustered_q8,{x},8,{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.6},{d:.6},{d:.6},{d:.6},{d}\n",
        .{
            runtime.version(),
            payload.len,
            encoded.len,
            sample.iterations,
            summary.max_literal_context_trees,
            summary.max_command_block_types,
            summary.max_distance_context_trees,
            summary.max_distance_postfix_bits,
            summary.max_direct_distance_codes,
            sample.header_ns,
            sample.literal_lookup_ns,
            sample.command_lookup_ns,
            sample.distance_lookup_ns,
            lookup_ns,
            sample.payload_ns,
            sample.total_ns,
            unattributed_ns,
            share(sample.header_ns, sample.total_ns),
            share(lookup_ns, sample.total_ns),
            share(sample.payload_ns, sample.total_ns),
            share(unattributed_ns, sample.total_ns),
            sample.checksum,
        },
    );
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path = args.next() orelse return error.MissingCorpusPath;
        } else return error.UnknownArgument;
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    return options;
}

fn makeClusteredPayload(io: std.Io, allocator: std.mem.Allocator) ![]u8 {
    const dictionary = try std.Io.Dir.cwd().readFileAlloc(io, "src/br/dictionary.bin", allocator, .limited(128 * 1024));
    defer allocator.free(dictionary);
    const payload = try allocator.alloc(u8, 1024 * 1024);
    for (payload, 0..) |*byte, i| {
        const segment = i / 1024;
        const base = (segment * 3571) % dictionary.len;
        byte.* = dictionary[(base + i % 1024) % dictionary.len];
    }
    return payload;
}

fn share(stage_ns: u64, total_ns: u64) f64 {
    if (total_ns == 0) return 0;
    return @as(f64, @floatFromInt(stage_ns)) / @as(f64, @floatFromInt(total_ns));
}
