const std = @import("std");
const vort = @import("vort");
const Decoder = vort.ZstdNativeIncrementalFrameDecoder;

pub const default_window_size: vort.StreamCount = 128 * 1024 * 1024;

pub fn isStdio(path: []const u8) bool {
    return std.mem.eql(u8, path, "-");
}

pub fn decode(init: std.process.Init, input_path: []const u8, output_path: []const u8, options: Decoder.Options) !void {
    const dir = std.Io.Dir.cwd();
    const from_stdin = isStdio(input_path);
    const input = if (from_stdin) std.Io.File.stdin() else try dir.openFile(init.io, input_path, .{});
    defer if (!from_stdin) input.close(init.io);

    if (isStdio(output_path)) {
        // A producer may wait for decoded output before writing its next chunk.
        var writer = std.Io.File.stdout().writerStreaming(init.io, &.{});
        return pump(init, input, &writer.interface, options);
    }

    var atomic = try dir.createFileAtomic(init.io, output_path, .{ .replace = true });
    defer atomic.deinit(init.io);
    var buffer: [32 * 1024]u8 = undefined;
    var writer = atomic.file.writerStreaming(init.io, &buffer);
    try pump(init, input, &writer.interface, options);
    try writer.interface.flush();
    try atomic.replace(init.io);
}

fn pump(init: std.process.Init, input: std.Io.File, writer: *std.Io.Writer, options: Decoder.Options) !void {
    var decoder = Decoder.initWithOptions(init.gpa, options);
    defer decoder.deinit();
    var compressed: [32 * 1024]u8 = undefined;
    var decoded: [32 * 1024]u8 = undefined;
    while (true) {
        // Use a single short read rather than waiting to fill the buffer.
        const amount = input.readStreaming(init.io, &.{&compressed}) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        if (amount == 0) continue;
        var offset: usize = 0;
        while (true) {
            const step = try decoder.step(compressed[offset..amount], &decoded);
            offset += step.progress.input_read;
            try writer.writeAll(decoded[0..step.progress.output_written]);
            if (offset == amount and step.status != .need_output) break;
            if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.InvalidStreamState;
        }
    }
    if (decoder.snapshot().input_received == 0) return error.TruncatedFrame;
    try decoder.finish();
}
