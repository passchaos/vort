const std = @import("std");
const vort = @import("vort");

const Pattern = enum { one, micro };
const input_chunks = [_]usize{ 1, 2, 3, 5, 7 };
const output_chunks = [_]usize{ 2, 3, 5, 7 };

const Entry = struct {
    options: vort.TarIncrementalEntryOptions,
    data: []const u8,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const pattern_name = args.next() orelse return error.MissingOutputPattern;
    if (args.next() != null) return error.UnexpectedArgument;
    const pattern: Pattern = if (std.mem.eql(u8, pattern_name, "one"))
        .one
    else if (std.mem.eql(u8, pattern_name, "micro"))
        .micro
    else
        return error.InvalidOutputPattern;

    const long_name = "nested/" ++ "long-component-" ** 12 ++ "file.txt";
    const sparse_layout = [_]vort.TarIncrementalSparseExtent{
        .{ .offset = 0, .len = 4 },
        .{ .offset = 524_288, .len = 6 },
        .{ .offset = 1_048_572, .len = 4 },
    };
    const sparse = try init.gpa.alloc(u8, 1024 * 1024);
    defer init.gpa.free(sparse);
    @memset(sparse, 0);
    @memcpy(sparse[0..4], "HEAD");
    @memcpy(sparse[524_288..524_294], "MIDDLE");
    @memcpy(sparse[1_048_572..], "TAIL");
    const entries = [_]Entry{
        .{
            .options = .{ .name = "plain.txt", .size = "Vort TAR payload\n".len, .mode = 0o640 },
            .data = "Vort TAR payload\n",
        },
        .{
            .options = .{ .name = "utf8-目录/数据.txt", .size = "Vort TAR UTF-8\n".len },
            .data = "Vort TAR UTF-8\n",
        },
        .{ .options = .{ .name = long_name, .size = "Vort TAR long path\n".len }, .data = "Vort TAR long path\n" },
        .{ .options = .{ .name = "empty/", .kind = .directory }, .data = "" },
        .{ .options = .{ .name = "link", .kind = .symbolic_link, .link_name = long_name }, .data = "" },
        .{
            .options = .{
                .name = "images/sparse.bin",
                .mode = 0o640,
                .sparse = .{ .logical_size = sparse.len, .extents = &sparse_layout },
            },
            .data = sparse,
        },
        .{
            .options = .{
                .name = "images/sparse-oldgnu.bin",
                .mode = 0o640,
                .sparse = .{
                    .logical_size = sparse.len,
                    .extents = &sparse_layout,
                    .format = .gnu_old,
                },
            },
            .data = sparse,
        },
    };

    var writer = vort.TarIncrementalWriter.init(init.gpa);
    defer writer.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(init.gpa);
    var output_storage: [7]u8 = undefined;
    var output_index: usize = 0;
    for (entries) |entry| {
        try writer.beginEntry(entry.options);
        var input_offset: usize = 0;
        var input_index: usize = 0;
        while (input_offset < entry.data.len) {
            const input_end = @min(
                entry.data.len,
                input_offset + input_chunks[input_index % input_chunks.len],
            );
            input_index += 1;
            while (input_offset < input_end) {
                const output = nextOutput(&output_storage, pattern, &output_index);
                const stepped = try writer.step(entry.data[input_offset..input_end], output);
                input_offset += stepped.input_read;
                try encoded.appendSlice(init.gpa, output[0..stepped.output_written]);
                if (stepped.input_read == 0 and stepped.output_written == 0)
                    return error.WriterMadeNoProgress;
            }
        }
        try writer.finishEntry();
        while (true) {
            const output = nextOutput(&output_storage, pattern, &output_index);
            const stepped = try writer.step("", output);
            try encoded.appendSlice(init.gpa, output[0..stepped.output_written]);
            if (stepped.status == .entry_done) break;
            if (stepped.output_written == 0) return error.WriterMadeNoProgress;
        }
    }
    try writer.finishArchive();
    while (true) {
        const output = nextOutput(&output_storage, pattern, &output_index);
        const stepped = try writer.step("", output);
        try encoded.appendSlice(init.gpa, output[0..stepped.output_written]);
        if (stepped.status == .done) break;
        if (stepped.output_written == 0) return error.WriterMadeNoProgress;
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded.items,
    });
}

fn nextOutput(storage: *[7]u8, pattern: Pattern, index: *usize) []u8 {
    const len = switch (pattern) {
        .one => 1,
        .micro => output_chunks[index.* % output_chunks.len],
    };
    index.* += 1;
    return storage[0..len];
}
