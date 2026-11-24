const std = @import("std");
const vort = @import("vort");
const count = vort.core.stream_count;

pub const Totals = struct { input_read: vort.StreamCount, output_written: vort.StreamCount };

/// File metadata describes a logical length, never one caller buffer's size.
pub fn fileSizeCounter(size: u64) !vort.StreamCount {
    return std.math.cast(vort.StreamCount, size) orelse error.IntegerOverflow;
}

pub fn checkedAdvance(current: vort.StreamCount, amount: usize, limit: ?vort.StreamCount) !vort.StreamCount {
    const next = try count.addLocal(current, amount);
    if (limit) |maximum| if (next > maximum) return error.OutputLimitExceeded;
    return next;
}

pub const Limits = struct {
    max_input: ?vort.StreamCount = null,
    max_output: ?vort.StreamCount = null,
    expected_input: ?vort.StreamCount = null,
};

pub fn isStdio(path: []const u8) bool {
    return std.mem.eql(u8, path, "-");
}

pub fn pump(init: std.process.Init, input_file: std.Io.File, writer: *std.Io.Writer, encoder: anytype, max_input: ?vort.StreamCount, max_output: ?vort.StreamCount) !Totals {
    return pumpWithLimits(init.io, input_file, writer, encoder, .{ .max_input = max_input, .max_output = max_output }, false);
}

/// Publish directly to binary stdout, or atomically replace a named output.
/// The caller holds the input handle; STDIO must not close inherited handles.
pub fn pumpStdio(io: std.Io, input_file: std.Io.File, output_path: []const u8, encoder: anytype, limits: Limits) !Totals {
    if (isStdio(output_path)) {
        var writer = std.Io.File.stdout().writerStreaming(io, &.{});
        return pumpWithLimits(io, input_file, &writer.interface, encoder, limits, true);
    }
    var atomic = try std.Io.Dir.cwd().createFileAtomic(io, output_path, .{ .replace = true });
    defer atomic.deinit(io);
    var buffer: [32 * 1024]u8 = undefined;
    var writer = atomic.file.writerStreaming(io, &buffer);
    const totals = try pumpWithLimits(io, input_file, &writer.interface, encoder, limits, true);
    try writer.interface.flush();
    try atomic.replace(io);
    return totals;
}

/// Caller buffers and each StepResult.Progress remain locally addressable.
/// Logical totals and limits are checked before feeding or publishing bytes.
fn pumpWithLimits(io: std.Io, input_file: std.Io.File, writer: *std.Io.Writer, encoder: anytype, limits: Limits, comptime short_reads: bool) !Totals {
    var read_buffer: [if (short_reads) 0 else 32 * 1024]u8 = undefined;
    var reader = input_file.readerStreaming(io, &read_buffer);
    var input: [32 * 1024]u8 = undefined;
    var output: [32 * 1024]u8 = undefined;
    var total_input: vort.StreamCount = 0;
    var total_output: vort.StreamCount = 0;
    while (true) {
        const amount = if (short_reads)
            input_file.readStreaming(io, &.{&input}) catch |err| switch (err) {
                error.EndOfStream => break,
                else => return err,
            }
        else
            try reader.interface.readSliceShort(&input);
        if (amount == 0) {
            if (short_reads) continue;
            break;
        }
        const offered = try checkedAdvance(total_input, amount, limits.max_input);
        if (limits.expected_input) |expected| if (offered > expected) return error.SizeMismatch;
        var offset: usize = 0;
        while (true) {
            const step = try encoder.step(input[offset..amount], &output);
            offset += step.progress.input_read;
            total_input = try checkedAdvance(total_input, step.progress.input_read, limits.max_input);
            total_output = try checkedAdvance(total_output, step.progress.output_written, limits.max_output);
            try writer.writeAll(output[0..step.progress.output_written]);
            if (offset == amount and (!short_reads or step.status != .need_output)) break;
            if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.InvalidBlockPlan;
        }
    }
    if (limits.expected_input) |expected| if (total_input != expected) return error.SizeMismatch;
    const Encoder = @TypeOf(encoder.*);
    const Finish = @typeInfo(@TypeOf(Encoder.finish)).@"fn".return_type.?;
    if (Finish == void) encoder.finish() else try encoder.finish();
    while (true) {
        const step = try encoder.step(&.{}, &output);
        total_output = try checkedAdvance(total_output, step.progress.output_written, limits.max_output);
        try writer.writeAll(output[0..step.progress.output_written]);
        if (step.status == .done) break;
        if (step.progress.output_written == 0) return error.InvalidBlockPlan;
    }
    const snapshot = encoder.snapshot();
    if (snapshot.input_read != total_input or snapshot.output_written != total_output) return error.InvalidBlockPlan;
    return .{ .input_read = snapshot.input_read, .output_written = snapshot.output_written };
}
