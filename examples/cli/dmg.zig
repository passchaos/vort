const std = @import("std");
const vort = @import("vort");

const max_file_size = 1024 * 1024 * 1024;

pub fn inspect(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try readFile(init, path);
    defer init.gpa.free(bytes);
    var archive = try vort.parseDmgAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
    try stdout.print(
        "sectors={d} data_bytes={d} xml_bytes={d} partitions={d} front={any}\n",
        .{
            archive.trailer.sector_count,
            archive.trailer.data_fork.length,
            archive.trailer.xml.length,
            archive.partitions.len,
            archive.trailer.at_front,
        },
    );
    for (archive.partitions, 0..) |partition, index| {
        try stdout.print(
            "partition={d}\tname={s}\tdecoded={d}\tpacked={d}\tblocks={d}\n",
            .{
                index,
                partition.name,
                partition.decoded_size,
                partition.packed_size,
                partition.blocks.len,
            },
        );
        for (partition.blocks, 0..) |block, block_index| {
            try stdout.print(
                "block={d}\ttype={s}\toffset={d}\tdecoded={d}\tpacked={d}\n",
                .{
                    block_index,
                    @tagName(block.kind),
                    block.decoded_offset,
                    block.decoded_size,
                    block.packed_size,
                },
            );
        }
    }
}

pub fn decode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const partition_index = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const limit = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        max_file_size;
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    var archive = try vort.parseDmgAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
    const decoded = try archive.decodePartitionAllocLimited(
        init.gpa,
        partition_index,
        limit,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("partition={d} decoded_bytes={d} path={s}\n", .{
        partition_index,
        decoded.len,
        output_path,
    });
}

pub fn decodeRange(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const partition_index = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const offset = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const length = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        10,
    );
    const bytes = try readFile(init, input_path);
    defer init.gpa.free(bytes);
    var archive = try vort.parseDmgAlloc(init.gpa, bytes, .{});
    defer archive.deinit();
    const decoded = try archive.decodePartitionRangeAllocLimited(
        init.gpa,
        partition_index,
        offset,
        length,
        length,
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print("partition={d} offset={d} decoded_bytes={d} path={s}\n", .{
        partition_index,
        offset,
        decoded.len,
        output_path,
    });
}

pub fn encode(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const compression = try parseCompression(
        args.next() orelse return error.MissingCorpusPath,
    );
    const block_size = if (args.next()) |text|
        try std.fmt.parseInt(usize, text, 10)
    else
        1024 * 1024;
    const copy_if_larger = if (args.next()) |text|
        !std.mem.eql(u8, text, "always")
    else
        true;
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.encodeDmgAlloc(init.gpa, input, .{
        .compression = compression,
        .block_size = block_size,
        .copy_if_larger = copy_if_larger,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
    try stdout.print("compression={s} input_bytes={d} dmg_bytes={d} path={s}\n", .{
        @tagName(compression),
        input.len,
        encoded.len,
        output_path,
    });
}

fn parseCompression(text: []const u8) !vort.DmgCompression {
    inline for (std.enums.values(vort.DmgCompression)) |compression|
        if (std.mem.eql(u8, text, @tagName(compression))) return compression;
    return error.InvalidCompressionMode;
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(
        init.io,
        path,
        init.gpa,
        .limited(max_file_size),
    );
}
