const std = @import("std");
const vort = @import("vort");

const max_file_size = 32 * 1024 * 1024 * 1024;

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    var archive = try vort.parseAndroidOtaAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
    try stdout.print(
        "format=android-ota major={d} minor={d} physical_bytes={d} manifest_bytes={d} metadata_signature_bytes={d} block_bytes={d} partitions={d}\n",
        .{
            archive.header.major,
            archive.manifest.minor_version,
            archive.header.physical_size,
            archive.header.manifest_size,
            archive.header.metadata_signature_size,
            archive.manifest.block_size,
            archive.partitions.len,
        },
    );
    for (archive.partitions, 0..) |partition, index| {
        var raw: usize = 0;
        var bzip2: usize = 0;
        var xz: usize = 0;
        var zero: usize = 0;
        var source: usize = 0;
        var other: usize = 0;
        for (archive.partitionOperations(partition)) |operation|
            switch (operation.kind) {
                .replace => raw += 1,
                .replace_bz => bzip2 += 1,
                .replace_xz => xz += 1,
                .zero => zero += 1,
                .source_copy => source += 1,
                else => other += 1,
            };
        try stdout.print(
            "partition={d} name={s} bytes={d} operations={d} raw={d} bzip2={d} xz={d} zero={d} source={d} other={d}\n",
            .{
                index,
                partition.name,
                partition.new_info.size,
                partition.operation_count,
                raw,
                bzip2,
                xz,
                zero,
                source,
                other,
            },
        );
    }
}

pub fn extract(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const partition_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 0)
    else
        max_file_size;
    const source_path = args.next();
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const source = try readOptionalFile(init, source_path);
    defer if (source) |owned| init.gpa.free(owned);
    var archive = try vort.parseAndroidOtaAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
    const decoded = try archive.decodePartitionByNameAllocLimited(
        init.gpa,
        partition_name,
        source,
        limit,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("partition={s} decoded_bytes={d} path={s}\n", .{
        partition_name,
        decoded.len,
        output_path,
    });
}

pub fn extractRange(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const partition_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const offset = try std.fmt.parseInt(
        u64,
        args.next() orelse return error.MissingCorpusPath,
        0,
    );
    const length = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        0,
    );
    const source_path = args.next();
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    const source = try readOptionalFile(init, source_path);
    defer if (source) |owned| init.gpa.free(owned);
    var archive = try vort.parseAndroidOtaAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
    const partition_index = archive.findPartition(partition_name) orelse
        return error.RangeOutOfBounds;
    const decoded = try archive.readPartitionRangeAllocLimited(
        init.gpa,
        partition_index,
        source,
        offset,
        length,
        length,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print(
        "partition={s} offset={d} decoded_bytes={d} path={s}\n",
        .{ partition_name, offset, decoded.len, output_path },
    );
}

pub fn encode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const partition_name = args.next() orelse return error.MissingCorpusPath;
    const compression = try parseCompression(args.next() orelse "auto");
    const block_size = if (args.next()) |text|
        try std.fmt.parseInt(u32, text, 0)
    else
        4096;
    const operation_size = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 0)
    else
        1024 * 1024;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeAndroidOtaAlloc(
        init.gpa,
        &.{.{ .name = partition_name, .data = input }},
        .{
            .block_size = block_size,
            .operation_size = operation_size,
            .compression = compression,
            .max_output_len = max_file_size,
        },
    );
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print(
        "format=android-ota partition={s} input_bytes={d} compression={s} block_bytes={d} operation_bytes={d} payload_bytes={d} path={s}\n",
        .{
            partition_name,
            input.len,
            @tagName(compression),
            block_size,
            operation_size,
            encoded.len,
            output_path,
        },
    );
}

pub fn puffDeflate(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const bit_offset = if (args.next()) |text|
        try std.fmt.parseInt(u64, text, 0)
    else
        0;
    const bit_length = if (args.next()) |text|
        try std.fmt.parseInt(u64, text, 0)
    else
        @as(u64, input.len) * 8 - bit_offset;
    const result = try vort.puffAndroidDeflatePaddedAlloc(
        init.gpa,
        input,
        bit_offset,
        bit_length,
        max_file_size,
    );
    defer init.gpa.free(result.bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = result.bytes,
    });
    try stdout.print("input_bits={d} consumed_bits={d} puff_bytes={d} path={s}\n", .{
        bit_length,
        result.consumed_bits,
        result.bytes.len,
        output_path,
    });
}

pub fn huffDeflate(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const bit_offset = try std.fmt.parseInt(
        u3,
        args.next() orelse return error.MissingCorpusPath,
        0,
    );
    const bit_length = try std.fmt.parseInt(
        u64,
        args.next() orelse return error.MissingCorpusPath,
        0,
    );
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const output = try vort.huffAndroidDeflateAlloc(
        init.gpa,
        input,
        bit_offset,
        bit_length,
    );
    defer init.gpa.free(output);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = output,
    });
    try stdout.print("puff_bytes={d} deflate_bits={d} output_bytes={d} path={s}\n", .{
        input.len,
        bit_length,
        output.len,
        output_path,
    });
}

fn parseCompression(text: []const u8) !vort.AndroidOtaCompression {
    inline for (std.enums.values(vort.AndroidOtaCompression)) |compression|
        if (std.mem.eql(u8, text, @tagName(compression))) return compression;
    return error.InvalidAndroidOta;
}

fn readOptionalFile(
    init: std.process.Init,
    path: ?[]const u8,
) !?[]u8 {
    const value = path orelse return null;
    if (std.mem.eql(u8, value, "-")) return null;
    return try readFile(init, value);
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
