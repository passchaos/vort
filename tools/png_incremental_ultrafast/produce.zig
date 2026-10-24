//! Ordinary public-module producer; only caller-owned output grows with input.
const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const partition = try std.fmt.parseInt(usize, args.next() orelse return error.MissingPartition, 10);
    const capacity = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCapacity, 10);
    const flush_at = if (args.next()) |word| try std.fmt.parseInt(usize, word, 10) else null;
    if (partition == 0 or capacity == 0 or capacity > 4096 or args.next() != null) return error.InvalidArguments;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(16 * 1024 * 1024));
    defer init.gpa.free(input);
    var encoder = vort.ZlibIncrementalPngUltraFastEncoder.initExactSize(std.testing.failing_allocator, .{}, input.len);
    defer encoder.deinit();
    var out: std.Io.Writer.Allocating = .init(init.gpa);
    defer out.deinit();
    var scratch: [4096]u8 = undefined;
    var offset: usize = 0;
    var flushed = false;
    while (offset != input.len) {
        const end = @min(input.len, offset + partition);
        const next = try encoder.step(input[offset..end], scratch[0..capacity]);
        offset += next.progress.input_read;
        try out.writer.writeAll(scratch[0..next.progress.output_written]);
        if (next.progress.input_read == 0 and next.progress.output_written == 0) return error.NoProgress;
        if (flush_at) |at| {
            if (!flushed and offset >= at) {
                encoder.flush();
                while (true) {
                    const drain = try encoder.step(&.{}, scratch[0..capacity]);
                    try out.writer.writeAll(scratch[0..drain.progress.output_written]);
                    if (drain.status == .need_input) break;
                    if (drain.progress.input_read != 0 or drain.progress.output_written == 0) return error.NoProgress;
                }
                const prefix_path = try std.fmt.allocPrint(init.gpa, "{s}.flush", .{output_path});
                defer init.gpa.free(prefix_path);
                try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = prefix_path, .data = out.written() });
                const length_path = try std.fmt.allocPrint(init.gpa, "{s}.accepted", .{output_path});
                defer init.gpa.free(length_path);
                const length = try std.fmt.allocPrint(init.gpa, "{d}", .{offset});
                defer init.gpa.free(length);
                try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = length_path, .data = length });
                flushed = true;
            }
        }
    }
    encoder.finish();
    while (true) {
        const next = try encoder.step(&.{}, scratch[0..capacity]);
        try out.writer.writeAll(scratch[0..next.progress.output_written]);
        if (next.status == .done) break;
        if (next.progress.output_written == 0) return error.NoProgress;
    }
    if (encoder.snapshot().input_read != input.len or encoder.snapshot().output_written != out.written().len) return error.InvalidProgress;
    if (vort.ZlibIncrementalPngUltraFastEncoder.heap_workspace_bytes != 0) return error.UnexpectedWorkspace;
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = out.written() });
}
