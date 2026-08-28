const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");

const Case = struct { name: []const u8, payload: []const u8, level: c_int = 1 };
const Options = struct { iterations: usize = 1000, only_case: ?[]const u8 = null, csv_path: ?[]const u8 = null };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();

    var numbered_json: std.ArrayList(u8) = .empty;
    defer numbered_json.deinit(init.gpa);
    for (0..20) |index| {
        var line: [96]u8 = undefined;
        const formatted = try std.fmt.bufPrint(&line, "{{\"k\":\"{d:0>4}\",\"n\":{d},\"txt\":\"abcdefghijklmnopqrstuvwxyz0123456789\"}}\n", .{ index, index });
        try numbered_json.appendSlice(init.gpa, formatted);
    }
    const huffman_payload = try init.gpa.alloc(u8, 80_000);
    defer init.gpa.free(huffman_payload);
    const huffman_alphabet = "ACGTN";
    for (huffman_payload, 0..) |*byte, index| byte.* = huffman_alphabet[(index * 17 + index / 7 + index / 31) % huffman_alphabet.len];
    var large_json: std.ArrayList(u8) = .empty;
    defer large_json.deinit(init.gpa);
    while (large_json.items.len < 512 * 1024) {
        var line: [128]u8 = undefined;
        const index = large_json.items.len / 64;
        const formatted = try std.fmt.bufPrint(&line, "{{\"id\":{d},\"service\":\"vort\",\"message\":\"structured zstd corpus payload\"}}\n", .{index});
        try large_json.appendSlice(init.gpa, formatted);
    }
    const binary_mixed = try init.gpa.alloc(u8, 512 * 1024);
    defer init.gpa.free(binary_mixed);
    var binary_state: u32 = 0xfeed_beef;
    for (binary_mixed, 0..) |*byte, index| {
        binary_state = binary_state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(binary_state >> 16);
    }
    const cases = [_]Case{
        .{ .name = "numbered_json", .payload = numbered_json.items },
        .{ .name = "huffman80k", .payload = huffman_payload },
        .{ .name = "large_json", .payload = large_json.items },
        .{ .name = "binary_mixed", .payload = binary_mixed },
    };

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,input_bytes,encoded_bytes,iterations,vort_ns,vort_mib_s,checksum,block_count,compressed_blocks,literals_kind,sequence_count,ll_mode,of_mode,ml_mode\n");
    var selected: usize = 0;
    for (cases) |case| {
        if (options.only_case) |wanted| if (!std.mem.eql(u8, wanted, case.name)) continue;
        selected += 1;
        const encoded = try runtime.encodeAlloc(init.gpa, case.payload, case.level);
        defer init.gpa.free(encoded);
        const output = try init.gpa.alloc(u8, case.payload.len);
        defer init.gpa.free(output);
        const written = try vort.zstdDecodeFrameInto(encoded, output);
        if (written != case.payload.len or !std.mem.eql(u8, case.payload, output)) return error.SizeMismatch;
        const block = try vort.zstdInspectNativeFrameFirstBlock(encoded);
        const shape = try vort.zstdInspectNativeFrameBlockSequenceModes(encoded, block);
        const summary = try vort.zstdSummarizeNativeFrameBlocks(encoded);
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(init.io);
        for (0..options.iterations) |_| {
            mix +%= try vort.zstdDecodeFrameInto(encoded, output);
            if (output.len != 0) mix +%= output[0];
        }
        const elapsed_ns = elapsedNs(init.io, start);
        try csv.writer.print("{s},{d},{d},{d},{d},{d:.2},{d},{d},{d},{s},{d},{s},{s},{s}\n", .{
            case.name,                      case.payload.len,                                                encoded.len,          options.iterations,
            elapsed_ns,                     mibPerSecond(case.payload.len * options.iterations, elapsed_ns), mix,                  summary.block_count,
            summary.compressed_block_count, @tagName(shape.literals_kind),                                   shape.sequence_count, @tagName(shape.literal_length_mode),
            @tagName(shape.offset_mode),    @tagName(shape.match_length_mode),
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
