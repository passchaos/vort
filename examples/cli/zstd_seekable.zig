const std = @import("std");
const vort = @import("vort");
const stream_files = @import("stream_files.zig");

const Option = enum {
    @"--frame-size",
    @"--max-frames",
    @"--seek-checksum",
    @"--frame-checksum",
    @"--max-total-memory",
};

const Controls = struct {
    options: vort.ZstdNativeSeekableOptions = .{},
    max_frames: ?usize = null,

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
                .@"--frame-size" => result.options.frame_size = try std.fmt.parseInt(usize, value, 10),
                .@"--max-frames" => result.max_frames = try std.fmt.parseInt(usize, value, 10),
                .@"--seek-checksum" => result.options.seek_checksums = try parseBool(value),
                .@"--frame-checksum" => result.options.frame_options.content_checksum = try parseBool(value),
                .@"--max-total-memory" => result.options.frame_options.max_total_working_memory = try std.fmt.parseInt(usize, value, 10),
            }
        }
        _ = try vort.zstdSourceSeekableEncodeRequirements(0, result.options);
        if (result.max_frames) |cap| {
            if (cap == 0) return error.InvalidZstdSeekableMaxFrames;
            _ = try vort.zstdEncodedNativeSeekTableBound(cap, result.options.seek_checksums);
        }
        return result;
    }

    fn frameCapacity(self: Controls, input_size: ?u64) !usize {
        const size = input_size orelse return self.max_frames orelse error.MissingZstdSeekableMaxFrames;
        const needed = try vort.zstdSourceSeekableEncodeRequirements(size, self.options);
        if (self.max_frames) |cap| if (needed.frame_count > cap) return error.OutputLimitExceeded;
        return needed.frame_count;
    }
};

fn parseBool(value: []const u8) !bool {
    if (std.mem.eql(u8, value, "true")) return true;
    if (std.mem.eql(u8, value, "false")) return false;
    return error.InvalidBoolean;
}

pub fn encodeFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    if (std.mem.startsWith(u8, input_path, "--") or std.mem.startsWith(u8, output_path, "--")) return error.MissingCorpusPath;
    const controls = try Controls.parse(args);
    const from_stdin = stream_files.isStdio(input_path);
    if (from_stdin and controls.max_frames == null) return error.MissingZstdSeekableMaxFrames;

    const cwd = std.Io.Dir.cwd();
    const input = if (from_stdin) std.Io.File.stdin() else try cwd.openFile(init.io, input_path, .{});
    var close_input = !from_stdin;
    defer if (close_input) input.close(init.io);
    const input_size: ?u64 = if (from_stdin) null else blk: {
        const stat = try input.stat(init.io);
        break :blk if (stat.kind == .file) stat.size else null;
    };
    const frame_capacity = try controls.frameCapacity(input_size);
    const frame_input = try init.gpa.alloc(u8, controls.options.frame_size);
    defer init.gpa.free(frame_input);
    const entries = try init.gpa.alloc(vort.ZstdNativeSeekTableFrameSize, frame_capacity);
    defer init.gpa.free(entries);
    const workspace: vort.ZstdSourceSeekableEncodeWorkspace = .{ .frame_input = frame_input, .entries = entries };

    var reader = input.readerStreaming(init.io, &.{});
    if (stream_files.isStdio(output_path)) {
        var writer = std.Io.File.stdout().writerStreaming(init.io, &.{});
        _ = try vort.zstdEncodeSeekableReaderToWriter(init.gpa, &reader.interface, &writer.interface, workspace, controls.options);
        try writer.interface.flush();
        return;
    }

    var output = try cwd.createFileAtomic(init.io, output_path, .{ .replace = true });
    defer output.deinit(init.io);
    var buffer: [32 * 1024]u8 = undefined;
    var writer = output.file.writerStreaming(init.io, &buffer);
    const result = try vort.zstdEncodeSeekableReaderToWriter(init.gpa, &reader.interface, &writer.interface, workspace, controls.options);
    try writer.interface.flush();
    if (close_input) {
        input.close(init.io);
        close_input = false;
    }
    try output.replace(init.io);
    if (!from_stdin) try stdout.print("zstd_seekable_compressed_bytes={d} decoded_bytes={d} frames={d} path={s}\n", .{
        result.output_written, result.input_read, result.frame_count, output_path,
    });
}
