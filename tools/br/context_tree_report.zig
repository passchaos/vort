const std = @import("std");
const vort = @import("vort");
const benchmark_provenance = @import("benchmark_provenance");

const context_text = ("the quick brown fox jumps over the lazy dog\n" ** 32) ++
    ("THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG\n" ** 32);

const Case = struct {
    name: []const u8,
    payload: []const u8,
    owned: bool = false,

    fn deinit(case: Case, allocator: std.mem.Allocator) void {
        if (case.owned) {
            allocator.free(case.name);
            allocator.free(case.payload);
        }
    }
};

const Options = struct {
    csv_path: ?[]const u8 = null,
    limit: usize = 32 * 1024,
    paths: std.ArrayList([]const u8) = .empty,

    fn deinit(options: *Options, allocator: std.mem.Allocator) void {
        for (options.paths.items) |path| allocator.free(path);
        options.paths.deinit(allocator);
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var options = try parseOptions(init.gpa, &args);
    defer options.deinit(init.gpa);
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer provenance.deinit(init.gpa);

    var cases: std.ArrayList(Case) = .empty;
    defer {
        for (cases.items) |case| case.deinit(init.gpa);
        cases.deinit(init.gpa);
    }
    try cases.append(init.gpa, .{ .name = "context-text", .payload = context_text });
    try appendFileCase(init, &cases, "dictionary", "src/br/dictionary.bin", std.math.maxInt(usize));
    try appendFileCase(init, &cases, "source32k", "src/br.zig", options.limit);
    try appendFileCase(init, &cases, "readme32k", "README.md", options.limit);
    try appendFileCase(init, &cases, "roadmap32k", "docs/roadmap.md", options.limit);
    try appendFileCase(init, &cases, "corpus-small", "corpus/native-library-bench-small.txt", options.limit);
    for (options.paths.items, 0..) |path, index| {
        const name = try std.fmt.allocPrint(init.gpa, "path-{d}", .{index});
        try appendFileCaseOwnedName(init, &cases, name, path, options.limit);
    }

    var csv: std.Io.Writer.Allocating = .init(init.gpa);
    defer csv.deinit();
    try csv.writer.print(
        "case,input_bytes,input_sha256,encoded_bytes,size_ratio,window_bits,literal_block_types,literal_context_trees,context_model,literal_lsb6_bytes,literal_msb6_bytes,literal_utf8_bytes,literal_signed_bytes,command_block_types,distance_block_types,distance_context_trees,static_dictionary_copies,lz77_copies,{s}\n",
        .{benchmark_provenance.csv_columns},
    );
    for (cases.items) |case| try reportCase(init, &csv.writer, provenance, case);

    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn reportCase(init: std.process.Init, writer: *std.Io.Writer, provenance: benchmark_provenance.Info, case: Case) !void {
    const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, case.payload, .{ .level = .ratio });
    defer init.gpa.free(encoded);
    const summary = try vort.brSummarizeStreamAlloc(init.gpa, encoded);
    if (summary.decoded_bytes != case.payload.len) return error.SizeMismatch;
    const decoded = try vort.brDecodeStreamAlloc(init.gpa, encoded);
    defer init.gpa.free(decoded);
    if (!std.mem.eql(u8, case.payload, decoded)) return error.SizeMismatch;
    const input_sha256 = benchmark_provenance.sha256Hex(case.payload);
    const context_model = summary.max_literal_block_types == 1 and summary.max_literal_context_trees > 1;
    try writer.print(
        "{s},{d},{s},{d},{d:.6},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
        .{
            case.name,
            case.payload.len,
            &input_sha256,
            encoded.len,
            @as(f64, @floatFromInt(encoded.len)) / @as(f64, @floatFromInt(case.payload.len)),
            summary.window_bits,
            summary.max_literal_block_types,
            summary.max_literal_context_trees,
            @intFromBool(context_model),
            summary.literal_context_mode_bytes[0],
            summary.literal_context_mode_bytes[1],
            summary.literal_context_mode_bytes[2],
            summary.literal_context_mode_bytes[3],
            summary.max_command_block_types,
            summary.max_distance_block_types,
            summary.max_distance_context_trees,
            summary.static_dictionary_copy_count,
            summary.lz77_copy_count,
        },
    );
    try provenance.writeCsvFields(writer);
    try writer.writeByte('\n');
}

fn appendFileCase(init: std.process.Init, cases: *std.ArrayList(Case), name: []const u8, path: []const u8, limit: usize) !void {
    const owned_name = try init.gpa.dupe(u8, name);
    try appendFileCaseOwnedName(init, cases, owned_name, path, limit);
}

fn appendFileCaseOwnedName(init: std.process.Init, cases: *std.ArrayList(Case), owned_name: []u8, path: []const u8, limit: usize) !void {
    errdefer init.gpa.free(owned_name);
    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    const read_len: usize = @intCast(@min(stat.size, limit));
    if (read_len == 0) return error.InputTooSmall;
    const payload = try init.gpa.alloc(u8, read_len);
    errdefer init.gpa.free(payload);
    var reader_buffer: [4096]u8 = undefined;
    var reader = file.reader(init.io, &reader_buffer);
    if (try reader.interface.readSliceShort(payload) != read_len) return error.InputTooSmall;
    try cases.append(init.gpa, .{ .name = owned_name, .payload = payload, .owned = true });
}

fn parseOptions(allocator: std.mem.Allocator, args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    errdefer options.deinit(allocator);
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path = args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--limit")) {
            options.limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--path")) {
            try options.paths.append(allocator, try allocator.dupe(u8, args.next() orelse return error.MissingCorpusPath));
        } else return error.UnknownArgument;
    }
    if (options.limit == 0) return error.InvalidBlockPlan;
    return options;
}
