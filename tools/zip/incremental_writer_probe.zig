const std = @import("std");
const vort = @import("vort");

const Entry = struct {
    name: []const u8,
    data: []const u8,
    method: vort.ZipCompressionMethod,
    expected_size: ?u64,
    comment: []const u8 = "",
};

const OutputPattern = enum {
    one,
    micro,
};

const input_chunks = [_]usize{ 1, 2, 3, 5, 7 };
const micro_output_chunks = [_]usize{ 2, 3, 5, 7 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const mode_name = args.next() orelse return error.MissingZipMode;
    const pattern_name = args.next() orelse return error.MissingOutputPattern;
    if (args.next() != null) return error.UnexpectedArgument;

    const zip64: vort.Zip64Mode = if (std.mem.eql(u8, mode_name, "zip32"))
        .never
    else if (std.mem.eql(u8, mode_name, "zip64"))
        .always
    else
        return error.InvalidZipMode;
    const output_pattern: OutputPattern = if (std.mem.eql(u8, pattern_name, "one"))
        .one
    else if (std.mem.eql(u8, pattern_name, "micro"))
        .micro
    else
        return error.InvalidOutputPattern;

    const known_stored = "\x00known-stored-PK\x07\x08-payload\xff";
    const unknown_stored = "PK\x07\x08unknown-stored-PK\x07\x08tail";
    const known_deflate = "known deflate stream crosses block boundaries.\n" ** 900;
    const unknown_deflate = "unknown deflate UTF-8 path payload.\n" ** 61;
    const known_bzip2 = "known Bzip2 incremental ZIP payload.\n" ** 96;
    const unknown_bzip2 = "unknown Bzip2 incremental ZIP payload.\n" ** 73;
    const entries = [_]Entry{
        .{
            .name = "known-stored.bin",
            .data = known_stored,
            .method = .stored,
            .expected_size = known_stored.len,
            .comment = "known size",
        },
        .{
            .name = "unknown-stored.bin",
            .data = unknown_stored,
            .method = .stored,
            .expected_size = null,
            .comment = "descriptor signatures are payload data",
        },
        .{
            .name = "known-deflate.txt",
            .data = known_deflate,
            .method = .deflate,
            .expected_size = known_deflate.len,
        },
        .{
            .name = "utf8-目录/未知-deflate.txt",
            .data = unknown_deflate,
            .method = .deflate,
            .expected_size = null,
            .comment = "UTF-8 条目",
        },
        .{
            .name = "empty-stored.bin",
            .data = "",
            .method = .stored,
            .expected_size = 0,
        },
        .{
            .name = "empty-deflate.bin",
            .data = "",
            .method = .deflate,
            .expected_size = 0,
        },
        .{
            .name = "known-bzip2.txt",
            .data = known_bzip2,
            .method = .bzip2,
            .expected_size = known_bzip2.len,
        },
        .{
            .name = "unknown-bzip2.txt",
            .data = unknown_bzip2,
            .method = .bzip2,
            .expected_size = null,
        },
        .{
            .name = "empty-bzip2.bin",
            .data = "",
            .method = .bzip2,
            .expected_size = 0,
        },
    };

    const encoded = try encodeArchive(init.gpa, &entries, zip64, output_pattern);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
}

fn encodeArchive(
    allocator: std.mem.Allocator,
    entries: []const Entry,
    zip64: vort.Zip64Mode,
    output_pattern: OutputPattern,
) ![]u8 {
    var writer = try vort.ZipIncrementalWriter.initWithOptions(allocator, .{
        .archive_comment = "vort incremental writer interop",
        .zip64 = zip64,
        .bzip2_options = .{ .block_size_100k = 1 },
    });
    defer writer.deinit();

    var archive: std.ArrayList(u8) = .empty;
    errdefer archive.deinit(allocator);
    var output_storage: [7]u8 = undefined;
    var output_index: usize = 0;

    for (entries, 0..) |entry, entry_index| {
        try writer.beginEntry(.{
            .name = entry.name,
            .comment = entry.comment,
            .method = entry.method,
            .expected_size = entry.expected_size,
        });
        if (entry_index == 0) {
            const blocked = try writer.step(entry.data[0..1], &.{});
            if (blocked.status != .need_output or
                blocked.progress.input_read != 0 or
                blocked.progress.output_written != 0)
                return error.ZeroOutputBackpressureMismatch;
        }

        var input_offset: usize = 0;
        var input_index: usize = 0;
        while (input_offset < entry.data.len) {
            const input_end = @min(
                entry.data.len,
                input_offset + input_chunks[input_index % input_chunks.len],
            );
            input_index += 1;
            while (input_offset < input_end) {
                const output = nextOutput(&output_storage, output_pattern, &output_index);
                const stepped = try writer.step(entry.data[input_offset..input_end], output);
                input_offset += stepped.progress.input_read;
                try archive.appendSlice(allocator, output[0..stepped.progress.output_written]);
                if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
                    return error.WriterMadeNoProgress;
            }
        }

        try writer.finishEntry();
        while (writer.snapshot().phase != .ready) {
            const output = nextOutput(&output_storage, output_pattern, &output_index);
            const stepped = try writer.step("", output);
            try archive.appendSlice(allocator, output[0..stepped.progress.output_written]);
            if (stepped.progress.output_written == 0) return error.WriterMadeNoProgress;
        }
    }

    try writer.finishArchive();
    while (true) {
        const output = nextOutput(&output_storage, output_pattern, &output_index);
        const stepped = try writer.step("", output);
        try archive.appendSlice(allocator, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (stepped.progress.output_written == 0) return error.WriterMadeNoProgress;
    }
    return archive.toOwnedSlice(allocator);
}

fn nextOutput(storage: *[7]u8, pattern: OutputPattern, index: *usize) []u8 {
    const len = switch (pattern) {
        .one => 1,
        .micro => micro_output_chunks[index.* % micro_output_chunks.len],
    };
    index.* += 1;
    return storage[0..len];
}
