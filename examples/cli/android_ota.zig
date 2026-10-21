const std = @import("std");
const vort = @import("vort");

const max_file_size = 32 * 1024 * 1024 * 1024;

const FileSource = struct {
    file: std.Io.File,
    io: std.Io,
    read_calls: usize = 0,
    bytes_read: usize = 0,

    fn source(self: *FileSource, len: u64) vort.AndroidOtaSource {
        return .{ .context = self, .len = len, .read_at = readAt };
    }

    fn readAt(
        raw_context: *anyopaque,
        offset: u64,
        output: []u8,
    ) error{SourceReadFailed}!usize {
        const self: *FileSource = @ptrCast(@alignCast(raw_context));
        const amount = self.file.readPositional(self.io, &.{output}, offset) catch
            return error.SourceReadFailed;
        self.read_calls = std.math.add(usize, self.read_calls, 1) catch
            return error.SourceReadFailed;
        self.bytes_read = std.math.add(usize, self.bytes_read, amount) catch
            return error.SourceReadFailed;
        return amount;
    }
};

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

pub fn inspectSource(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    var file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    var context = FileSource{ .file = file, .io = init.io };
    var ota = try vort.parseAndroidOtaSourceAlloc(
        init.gpa,
        context.source(stat.size),
        .{},
    );
    defer ota.deinit();
    try stdout.print(
        "format=android-ota-source major={d} minor={d} physical_bytes={d} manifest_bytes={d} block_bytes={d} partitions={d} reads={d} bytes_read={d}\n",
        .{
            ota.header.major,
            ota.manifest.minor_version,
            ota.header.physical_size,
            ota.header.manifest_size,
            ota.manifest.block_size,
            ota.partitions.len,
            context.read_calls,
            context.bytes_read,
        },
    );
    for (ota.partitions, 0..) |partition, index|
        try stdout.print(
            "partition={d} name={s} bytes={d} operations={d}\n",
            .{ index, partition.name, partition.new_info.size, partition.operation_count },
        );
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

pub fn extractSource(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const partition_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const chunk_size = try std.fmt.parseInt(
        usize,
        args.next() orelse return error.MissingCorpusPath,
        0,
    );
    if (chunk_size == 0 or chunk_size > max_file_size)
        return error.OutputLimitExceeded;
    const old_path = args.next();

    var payload_file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer payload_file.close(init.io);
    const payload_stat = try payload_file.stat(init.io);
    var payload_context = FileSource{ .file = payload_file, .io = init.io };
    var ota = try vort.parseAndroidOtaSourceAlloc(
        init.gpa,
        payload_context.source(payload_stat.size),
        .{},
    );
    defer ota.deinit();
    const partition_index = ota.findPartition(partition_name) orelse
        return error.RangeOutOfBounds;
    const partition = ota.partitions[partition_index];

    var old_file: ?std.Io.File = null;
    defer if (old_file) |file| file.close(init.io);
    var old_context: FileSource = undefined;
    var old_source: ?vort.AndroidOtaSource = null;
    if (old_path) |path| if (!std.mem.eql(u8, path, "-")) {
        const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
        old_file = file;
        const stat = try file.stat(init.io);
        old_context = .{ .file = file, .io = init.io };
        old_source = old_context.source(stat.size);
    };
    if (partition.old_info) |old_info| {
        const source = old_source orelse return error.MissingAndroidOtaSource;
        if (source.len != old_info.size) return error.SizeMismatch;
        if (old_info.hash.len != 0)
            try source.verifySha256(0, source.len, old_info.hash);
    }

    var output_file = try std.Io.Dir.cwd().createFile(init.io, output_path, .{});
    defer output_file.close(init.io);
    const buffer = try init.gpa.alloc(u8, chunk_size);
    defer init.gpa.free(buffer);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var offset: u64 = 0;
    while (offset < partition.new_info.size) {
        const remaining = partition.new_info.size - offset;
        const amount = @min(
            buffer.len,
            std.math.cast(usize, remaining) orelse buffer.len,
        );
        try ota.readPartitionRangeInto(
            init.gpa,
            partition_index,
            old_source,
            offset,
            buffer[0..amount],
            .{
                .max_output_len = amount,
                .verify_partition_hash = false,
                .verify_source_hashes = false,
            },
        );
        try output_file.writePositionalAll(init.io, buffer[0..amount], offset);
        hash.update(buffer[0..amount]);
        offset += amount;
    }
    if (partition.new_info.hash.len != 0) {
        var actual: [32]u8 = undefined;
        hash.final(&actual);
        if (!std.mem.eql(u8, &actual, partition.new_info.hash))
            return error.ChecksumMismatch;
    }
    try stdout.print(
        "partition={s} decoded_bytes={d} chunk_bytes={d} payload_reads={d} payload_bytes_read={d} old_reads={d} old_bytes_read={d} path={s}\n",
        .{
            partition_name,
            partition.new_info.size,
            chunk_size,
            payload_context.read_calls,
            payload_context.bytes_read,
            if (old_source != null) old_context.read_calls else 0,
            if (old_source != null) old_context.bytes_read else 0,
            output_path,
        },
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
