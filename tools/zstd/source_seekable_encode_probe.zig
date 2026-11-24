//! File-backed driver for the independent contrib seekable verifier.
const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const frame_size = try std.fmt.parseInt(usize, args.next() orelse return error.MissingFrameSize, 10);
    const checksum_mode = args.next() orelse return error.MissingChecksumMode;
    if (args.next() != null) return error.TooManyArguments;
    const seek_checksums = if (std.mem.eql(u8, checksum_mode, "1")) true else if (std.mem.eql(u8, checksum_mode, "0")) false else return error.InvalidChecksumMode;
    const options: vort.ZstdNativeSeekableOptions = .{ .frame_size = frame_size, .seek_checksums = seek_checksums };

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
    const result = try vort.zstdEncodeSourceSeekableTo(init.gpa, source, output.sink(), .{ .frame_input = plain, .entries = entries }, options);
    std.debug.print("seekable archive: input={d} output={d} frames={d}\n", .{ result.input_read, result.output_written, result.frame_count });
}
