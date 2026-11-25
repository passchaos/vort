//! Driver for the independent contrib seekable verifier.
//! With two named paths: INPUT OUTPUT FRAME_SIZE CHECKSUM
//! If either path is `-` (stdin or stdout): INPUT OUTPUT FRAME_SIZE CHECKSUM MAX_FRAMES
const std = @import("std");
const vort = @import("vort");

// Maximum number of entries permitted by the Zstandard seekable format.
const max_seek_table_frames = 0x0800_0000;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const frame_size = try std.fmt.parseInt(usize, args.next() orelse return error.MissingFrameSize, 10);
    const checksum_mode = args.next() orelse return error.MissingChecksumMode;
    const max_frames: ?usize = if (isStdio(input_path) or isStdio(output_path))
        try std.fmt.parseInt(usize, args.next() orelse return error.MissingMaxFrames, 10)
    else
        null;
    if (args.next() != null) return error.TooManyArguments;
    const seek_checksums = if (std.mem.eql(u8, checksum_mode, "1")) true else if (std.mem.eql(u8, checksum_mode, "0")) false else return error.InvalidChecksumMode;
    const options: vort.ZstdNativeSeekableOptions = .{ .frame_size = frame_size, .seek_checksums = seek_checksums };

    const result = if (max_frames) |capacity|
        try encodeStreaming(init, input_path, output_path, options, capacity)
    else
        try encodeKnownLength(init, input_path, output_path, options);
    std.debug.print("seekable archive: input={d} output={d} frames={d}\n", .{ result.input_read, result.output_written, result.frame_count });
}

fn isStdio(path: []const u8) bool {
    return std.mem.eql(u8, path, "-");
}

fn encodeKnownLength(
    init: std.process.Init,
    input_path: []const u8,
    output_path: []const u8,
    options: vort.ZstdNativeSeekableOptions,
) !vort.ZstdSourceSeekableEncodeResult {
    const cwd = std.Io.Dir.cwd();
    const input_file = try cwd.openFile(init.io, input_path, .{});
    defer input_file.close(init.io);
    var input = try vort.FileByteSource.init(init.io, input_file);
    const source = input.source();
    const needed = try vort.zstdSourceSeekableEncodeRequirements(source.len, options);
    const plain = try init.gpa.alloc(u8, needed.frame_input_len);
    defer init.gpa.free(plain);
    const entries = try init.gpa.alloc(vort.ZstdNativeSeekTableFrameSize, needed.frame_count);
    defer init.gpa.free(entries);

    const output_file = try cwd.createFile(init.io, output_path, .{ .exclusive = true });
    defer output_file.close(init.io);
    var output = vort.FileByteSink.init(init.io, output_file);
    return vort.zstdEncodeSourceSeekableTo(init.gpa, source, output.sink(), .{ .frame_input = plain, .entries = entries }, options);
}

fn encodeStreaming(
    init: std.process.Init,
    input_path: []const u8,
    output_path: []const u8,
    options: vort.ZstdNativeSeekableOptions,
    max_frames: usize,
) !vort.ZstdSourceSeekableEncodeResult {
    if (max_frames == 0 or max_frames > max_seek_table_frames) return error.InvalidMaxFrames;
    // Validate the options and reserve room for a full frame regardless of input length.
    const needed = try vort.zstdSourceSeekableEncodeRequirements(options.frame_size, options);
    const plain = try init.gpa.alloc(u8, needed.frame_input_len);
    defer init.gpa.free(plain);
    const entries = try init.gpa.alloc(vort.ZstdNativeSeekTableFrameSize, max_frames);
    defer init.gpa.free(entries);

    const cwd = std.Io.Dir.cwd();
    const from_stdin = isStdio(input_path);
    const to_stdout = isStdio(output_path);
    const input = if (from_stdin) std.Io.File.stdin() else try cwd.openFile(init.io, input_path, .{});
    defer if (!from_stdin) input.close(init.io);
    const output = if (to_stdout) std.Io.File.stdout() else try cwd.createFile(init.io, output_path, .{ .exclusive = true });
    defer if (!to_stdout) output.close(init.io);

    var read_buffer: [32 * 1024]u8 = undefined;
    var write_buffer: [32 * 1024]u8 = undefined;
    var reader = input.readerStreaming(init.io, &read_buffer);
    var writer = output.writerStreaming(init.io, &write_buffer);
    const workspace: vort.ZstdSourceSeekableEncodeWorkspace = .{ .frame_input = plain, .entries = entries };
    const result = try vort.zstdEncodeSeekableReaderToWriter(init.gpa, &reader.interface, &writer.interface, workspace, options);
    try writer.interface.flush();
    return result;
}
