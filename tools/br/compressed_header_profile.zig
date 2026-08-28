const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

const Case = struct {
    name: []const u8,
    payload: []const u8,
    quality: c_int,
};

const Options = struct {
    iterations: usize = 1000,
    csv_path: ?[]const u8 = null,
    only_case: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);

    var runtime = try libbrotli.Runtime.open();
    defer runtime.deinit();
    const clustered = try makeClusteredPayload(init.io, init.gpa);
    defer init.gpa.free(clustered);

    const cases = [_]Case{
        .{ .name = "text_q0", .payload = "Brotli benchmark text payload. " ** 1024, .quality = 0 },
        .{ .name = "structured_q3", .payload = "{\"service\":\"vort\",\"codec\":\"brotli\",\"value\":12345}\n" ** 512, .quality = 3 },
        .{ .name = "structured_q4", .payload = "{\"service\":\"vort\",\"codec\":\"brotli\",\"value\":12345}\n" ** 512, .quality = 4 },
        .{ .name = "structured_q11", .payload = "{\"service\":\"vort\",\"codec\":\"brotli\",\"value\":12345}\n" ** 512, .quality = 11 },
        .{ .name = "clustered_q8", .payload = clustered, .quality = 8 },
    };

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,reference_version,quality,input_bytes,encoded_bytes,iterations,headers,header_bits,parse_ns,block_switch_ns,context_map_ns,literal_tree_ns,command_tree_ns,distance_tree_ns,total_ns,block_switch_share,context_map_share,literal_tree_share,command_tree_share,distance_tree_share,code_length_header_ns,code_length_rle_ns,canonical_build_ns,simple_tree_ns,literal_block_types,command_block_types,distance_block_types,literal_trees,command_trees,distance_trees,tree_symbols,tree_entries,complex_trees,simple_trees,code_length_symbols,repeat_symbols,repeated_lengths,checksum\n");
    for (cases) |case| {
        if (options.only_case) |wanted| {
            if (!std.mem.eql(u8, wanted, case.name)) continue;
        }
        const encoded = try runtime.encodeAlloc(init.gpa, case.payload, case.quality);
        defer init.gpa.free(encoded);
        const profile = try vort.br.profileCompressedHeaders(init.io, init.gpa, encoded, options.iterations);
        const sample = try vort.br.benchmarkCompressedHeaders(init.io, init.gpa, encoded, options.iterations);
        const total_ns = profile.elapsedNs();
        const divisor = options.iterations;
        try csv.writer.print(
            "{s},{x},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.6},{d:.6},{d:.6},{d:.6},{d:.6}",
            .{
                case.name,
                runtime.version(),
                case.quality,
                case.payload.len,
                encoded.len,
                options.iterations,
                profile.compressed_meta_block_count / divisor,
                profile.input_bits / divisor,
                sample.elapsed_ns,
                profile.block_switch_ns,
                profile.context_map_ns,
                profile.literal_tree_ns,
                profile.command_tree_ns,
                profile.distance_tree_ns,
                total_ns,
                share(profile.block_switch_ns, total_ns),
                share(profile.context_map_ns, total_ns),
                share(profile.literal_tree_ns, total_ns),
                share(profile.command_tree_ns, total_ns),
                share(profile.distance_tree_ns, total_ns),
            },
        );
        try csv.writer.print(
            ",{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n",
            .{
                profile.code_length_header_ns,
                profile.code_length_rle_ns,
                profile.canonical_build_ns,
                profile.simple_tree_ns,
                profile.literal_block_types / divisor,
                profile.command_block_types / divisor,
                profile.distance_block_types / divisor,
                profile.literal_context_trees / divisor,
                profile.command_trees / divisor,
                profile.distance_context_trees / divisor,
                profile.tree_symbols / divisor,
                profile.tree_entries / divisor,
                profile.complex_trees / divisor,
                profile.simple_trees / divisor,
                profile.code_length_symbols / divisor,
                profile.repeat_symbols / divisor,
                profile.repeated_lengths / divisor,
                profile.checksum() +% sample.checksum,
            },
        );
    }

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
        } else if (std.mem.eql(u8, arg, "--case")) {
            options.only_case = args.next() orelse return error.MissingCorpusPath;
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
