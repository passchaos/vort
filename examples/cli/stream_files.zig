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

/// Caller buffers and each StepResult.Progress remain locally addressable.
/// Logical totals and limits are checked before feeding or publishing bytes.
pub fn pump(init: std.process.Init, input_file: std.Io.File, writer: *std.Io.Writer, encoder: anytype, max_input: ?vort.StreamCount, max_output: ?vort.StreamCount) !Totals {
    var read_buffer: [32 * 1024]u8 = undefined;
    var reader = input_file.readerStreaming(init.io, &read_buffer);
    var input: [32 * 1024]u8 = undefined;
    var output: [32 * 1024]u8 = undefined;
    var total_input: vort.StreamCount = 0;
    var total_output: vort.StreamCount = 0;
    while (true) {
        const amount = try reader.interface.readSliceShort(&input);
        if (amount == 0) break;
        _ = try checkedAdvance(total_input, amount, max_input);
        var offset: usize = 0;
        while (offset != amount) {
            const step = try encoder.step(input[offset..amount], &output);
            offset += step.progress.input_read;
            total_input = try checkedAdvance(total_input, step.progress.input_read, max_input);
            total_output = try checkedAdvance(total_output, step.progress.output_written, max_output);
            try writer.writeAll(output[0..step.progress.output_written]);
            if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.InvalidBlockPlan;
        }
    }
    const Encoder = @TypeOf(encoder.*);
    const Finish = @typeInfo(@TypeOf(Encoder.finish)).@"fn".return_type.?;
    if (Finish == void) encoder.finish() else try encoder.finish();
    while (true) {
        const step = try encoder.step(&.{}, &output);
        total_output = try checkedAdvance(total_output, step.progress.output_written, max_output);
        try writer.writeAll(output[0..step.progress.output_written]);
        if (step.status == .done) break;
        if (step.progress.output_written == 0) return error.InvalidBlockPlan;
    }
    const snapshot = encoder.snapshot();
    if (snapshot.input_read != total_input or snapshot.output_written != total_output) return error.InvalidBlockPlan;
    return .{ .input_read = snapshot.input_read, .output_written = snapshot.output_written };
}
