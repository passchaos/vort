const std = @import("std");

pub fn isStdio(path: []const u8) bool {
    return std.mem.eql(u8, path, "-");
}

/// Drive a library decoder through real short reads and publish a named
/// destination only after its complete compressed stream has been validated.
pub fn decode(io: std.Io, input_path: []const u8, output_path: []const u8, decoder: anytype) !void {
    const dir = std.Io.Dir.cwd();
    const from_stdin = isStdio(input_path);
    const input = if (from_stdin) std.Io.File.stdin() else try dir.openFile(io, input_path, .{});
    defer if (!from_stdin) input.close(io);

    if (isStdio(output_path)) {
        // A producer may wait for decoded output before writing its next chunk.
        var writer = std.Io.File.stdout().writerStreaming(io, &.{});
        return pump(io, input, &writer.interface, decoder);
    }

    var atomic = try dir.createFileAtomic(io, output_path, .{ .replace = true });
    defer atomic.deinit(io);
    var buffer: [32 * 1024]u8 = undefined;
    var writer = atomic.file.writerStreaming(io, &buffer);
    try pump(io, input, &writer.interface, decoder);
    try writer.interface.flush();
    try atomic.replace(io);
}

fn pump(io: std.Io, input: std.Io.File, writer: *std.Io.Writer, decoder: anytype) !void {
    var compressed: [32 * 1024]u8 = undefined;
    var decoded: [32 * 1024]u8 = undefined;
    var saw_input = false;
    while (true) {
        // Use a single short read rather than waiting to fill the buffer.
        const amount = input.readStreaming(io, &.{&compressed}) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        if (amount == 0) continue;
        saw_input = true;
        var offset: usize = 0;
        while (true) {
            const step = try decoder.step(compressed[offset..amount], &decoded);
            offset += step.progress.input_read;
            try writer.writeAll(decoded[0..step.progress.output_written]);
            if (offset == amount and step.status != .need_output) break;
            if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.InvalidStreamState;
        }
    }
    if (!saw_input) return error.TruncatedFrame;
    try decoder.finish();
    while (true) {
        const step = try decoder.step(&.{}, &decoded);
        try writer.writeAll(decoded[0..step.progress.output_written]);
        switch (step.status) {
            .done => return,
            .need_input => return error.TruncatedFrame,
            .need_output => if (step.progress.output_written == 0) return error.InvalidStreamState,
        }
    }
}
