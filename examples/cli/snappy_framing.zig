const std = @import("std");
const vort = @import("vort");

const max_file_size = 512 * 1024 * 1024;

pub fn encodeXerial(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const block_size = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 32 * 1024;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeXerialSnappyAlloc(init.gpa, input, .{ .block_size = block_size });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("xerial_input_bytes={d} xerial_bytes={d} block_size={d} path={s}\n", .{
        input.len,
        encoded.len,
        block_size,
        output_path,
    });
}

pub fn decodeXerial(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = try parseLimit(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const decoded = try vort.decodeXerialSnappyAllocLimited(init.gpa, input, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("xerial_bytes={d} decoded_bytes={d} path={s}\n", .{
        input.len,
        decoded.len,
        output_path,
    });
}

pub fn decodeXerialIncremental(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    return decodeIncremental(vort.XerialSnappyIncrementalDecoder, "xerial", init, args, stdout);
}

pub fn inspectXerial(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseXerialSnappy(input);
    try stdout.print("xerial_chunks={d} decoded_bytes={d} compressed_bytes={d}\n", .{
        archive.chunk_count,
        archive.decoded_size,
        input.len,
    });
}

pub fn encodeHadoop(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const block_size = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 256 * 1024;
    const chunk_size = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 64 * 1024;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeHadoopSnappyAlloc(init.gpa, input, .{
        .block_size = block_size,
        .chunk_size = chunk_size,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print(
        "hadoop_snappy_input_bytes={d} compressed_bytes={d} block_size={d} chunk_size={d} path={s}\n",
        .{ input.len, encoded.len, block_size, chunk_size, output_path },
    );
}

pub fn decodeHadoop(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = try parseLimit(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const decoded = try vort.decodeHadoopSnappyAllocLimited(init.gpa, input, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("hadoop_snappy_bytes={d} decoded_bytes={d} path={s}\n", .{
        input.len,
        decoded.len,
        output_path,
    });
}

pub fn decodeHadoopIncremental(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    return decodeIncremental(vort.HadoopSnappyIncrementalDecoder, "hadoop_snappy", init, args, stdout);
}

fn decodeIncremental(
    comptime DecoderType: type,
    comptime label: []const u8,
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const expected_output_len = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const input_step = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 17;
    const output_step = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 31;
    if (input_step == 0 or output_step == 0) return error.InvalidBlockPlan;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const output = try init.gpa.alloc(u8, expected_output_len);
    defer init.gpa.free(output);
    var decoder = DecoderType.initWithOptions(init.gpa, .{
        .max_compressed_chunk_len = max_file_size,
        .max_decoded_chunk_len = max_file_size,
        .max_output_len = expected_output_len,
        .expected_output_len = expected_output_len,
    });
    defer decoder.deinit();
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + input_step);
        const output_end = @min(output.len, output_offset + output_step);
        const step = try decoder.step(input[input_offset..input_end], output[output_offset..output_end]);
        if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.InvalidBlockPlan;
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    while (decoder.snapshot().phase != .done) {
        const output_end = @min(output.len, output_offset + output_step);
        const step = try decoder.step("", output[output_offset..output_end]);
        if (step.progress.output_written == 0 and step.status != .done) return error.InvalidBlockPlan;
        output_offset += step.progress.output_written;
    }
    if (output_offset != output.len) return error.SizeMismatch;
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = output });
    try stdout.print("{s}_incremental_bytes={d} decoded_bytes={d} input_step={d} output_step={d} path={s}\n", .{
        label,
        input.len,
        output.len,
        input_step,
        output_step,
        output_path,
    });
}

pub fn inspectHadoop(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseHadoopSnappy(input);
    try stdout.print(
        "hadoop_snappy_blocks={d} chunks={d} decoded_bytes={d} compressed_bytes={d}\n",
        .{ archive.block_count, archive.chunk_count, archive.decoded_size, input.len },
    );
}

pub fn encodeHadoopLz4(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const block_size = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 256 * 1024;
    const chunk_size = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 64 * 1024;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeHadoopLz4Alloc(init.gpa, input, .{
        .block_size = block_size,
        .chunk_size = chunk_size,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print(
        "hadoop_lz4_input_bytes={d} compressed_bytes={d} block_size={d} chunk_size={d} path={s}\n",
        .{ input.len, encoded.len, block_size, chunk_size, output_path },
    );
}

pub fn decodeHadoopLz4(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = try parseLimit(args.next());
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const decoded = try vort.decodeHadoopLz4AllocLimited(init.gpa, input, limit);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("hadoop_lz4_bytes={d} decoded_bytes={d} path={s}\n", .{
        input.len,
        decoded.len,
        output_path,
    });
}

pub fn inspectHadoopLz4(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const archive = try vort.parseHadoopLz4(input);
    try stdout.print(
        "hadoop_lz4_blocks={d} chunks={d} decoded_bytes={d} compressed_bytes={d}\n",
        .{ archive.block_count, archive.chunk_count, archive.decoded_size, input.len },
    );
}

fn parseLimit(value: ?[]const u8) !usize {
    return if (value) |text| try std.fmt.parseInt(usize, text, 10) else max_file_size;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(max_file_size));
}
