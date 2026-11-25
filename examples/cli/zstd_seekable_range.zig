const std = @import("std");
const vort = @import("vort");
const stream_files = @import("stream_files.zig");

const Option = enum {
    @"--max-frames",
    @"--max-window-size",
    @"--max-frame-decoded-size",
};

const Controls = struct {
    max_frames: usize = 1_048_576,
    options: vort.ZstdSourceSeekableDecodeOptions = .{
        .max_window_size = 128 * 1024 * 1024,
        .frame_decoded_max = 128 * 1024 * 1024,
    },

    fn parse(args: *std.process.Args.Iterator) !Controls {
        var result: Controls = .{};
        var seen: std.EnumSet(Option) = .initEmpty();
        while (args.next()) |arg| {
            const split = std.mem.indexOfScalar(u8, arg, '=');
            const option = std.meta.stringToEnum(Option, arg[0 .. split orelse arg.len]) orelse return error.UnknownZstdOption;
            if (seen.contains(option)) return error.DuplicateZstdOption;
            seen.insert(option);
            const value = if (split) |i| arg[i + 1 ..] else args.next() orelse return error.MissingZstdOptionValue;
            switch (option) {
                .@"--max-frames" => result.max_frames = try std.fmt.parseInt(usize, value, 10),
                .@"--max-window-size" => result.options.max_window_size = try std.fmt.parseInt(u64, value, 10),
                .@"--max-frame-decoded-size" => result.options.frame_decoded_max = try std.fmt.parseInt(u64, value, 10),
            }
        }
        return result;
    }
};

pub fn decodeFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    if (stream_files.isStdio(input_path)) return error.UnsupportedZstdSeekableInput;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    if (std.mem.startsWith(u8, input_path, "--") or std.mem.startsWith(u8, output_path, "--")) return error.MissingCorpusPath;
    const offset = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
    const length = try std.fmt.parseInt(u64, args.next() orelse return error.MissingCorpusPath, 10);
    const controls = try Controls.parse(args);

    const cwd = std.Io.Dir.cwd();
    const input = try cwd.openFile(init.io, input_path, .{});
    var close_input = true;
    defer if (close_input) input.close(init.io);
    var source = try vort.FileByteSource.init(init.io, input);
    const table = try vort.zstdOpenSourceSeekTable(source.source());
    if (table.entry_count > controls.max_frames) return error.OutputLimitExceeded;
    const entries = try init.gpa.alloc(vort.ZstdNativeSeekTableEntry, @intCast(table.entry_count));
    defer init.gpa.free(entries);
    const index = try table.buildIndex(entries);
    const needed = try vort.zstdSourceSeekableRangeRequirementsWide(index, offset, length, controls.options);

    const history = try init.gpa.alloc(u8, needed.history);
    defer init.gpa.free(history);
    const staging = try init.gpa.alloc(u8, needed.staging);
    defer init.gpa.free(staging);
    const literal_page = try init.gpa.alloc(u8, needed.literal_page);
    defer init.gpa.free(literal_page);
    const sequence_page = try init.gpa.alloc(u8, needed.sequence_page);
    defer init.gpa.free(sequence_page);
    const range_scratch = try init.gpa.alloc(u8, needed.range_scratch);
    defer init.gpa.free(range_scratch);
    const workspace: vort.ZstdSourceFrameWorkspace = .{
        .history = history,
        .staging = staging,
        .literal_page = literal_page,
        .sequence_page = sequence_page,
    };

    if (stream_files.isStdio(output_path)) {
        var writer = std.Io.File.stdout().writerStreaming(init.io, &.{});
        _ = try vort.zstdDecodeSourceSeekableRangeToWriter(index, offset, length, &writer.interface, workspace, range_scratch, controls.options);
        try writer.interface.flush();
        return;
    }

    var output = try cwd.createFileAtomic(init.io, output_path, .{ .replace = true });
    defer output.deinit(init.io);
    var buffer: [32 * 1024]u8 = undefined;
    var writer = output.file.writerStreaming(init.io, &buffer);
    const written = try vort.zstdDecodeSourceSeekableRangeToWriter(index, offset, length, &writer.interface, workspace, range_scratch, controls.options);
    try writer.interface.flush();
    input.close(init.io);
    close_input = false;
    try output.replace(init.io);
    try stdout.print("zstd_seekable_range_decoded_bytes={d} offset={d} path={s}\n", .{ written, offset, output_path });
}
