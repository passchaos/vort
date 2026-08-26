const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

const Case = struct {
    name: []const u8,
    first: []const u8,
    second: []const u8,
};

pub fn main(init: std.process.Init) !void {
    var reference = try libbrotli.Runtime.open();
    defer reference.deinit();

    const text = "The quick brown fox jumps over the lazy dog. " ** 64;
    const json = "{\"service\":\"vort\",\"status\":\"ok\",\"value\":12345}\n" ** 48;
    const first_pattern = "abcdefghijklmnopqrstuvwxyz012345" ** 64;
    const second_pattern = "zyxwvutsrqponmlkjihgfedcba543210" ** 64;
    const cases = [_]Case{
        .{ .name = "repeated-text", .first = text, .second = text },
        .{ .name = "structured-json", .first = json, .second = json },
        .{ .name = "changed-pattern", .first = first_pattern, .second = second_pattern },
    };
    const qualities = [_]u32{ 0, 1, 3, 4, 5, 6, 9, 11 };

    var cases_run: usize = 0;
    for (cases) |case| {
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(init.gpa);
        try expected.appendSlice(init.gpa, case.first);
        try expected.appendSlice(init.gpa, case.second);
        for (qualities) |quality| {
            const encoded = try reference.encodeFlushedChunksAlloc(
                init.gpa,
                &.{ case.first, case.second },
                quality,
                16,
                16,
            );
            defer init.gpa.free(encoded);
            try decodeByteProgressive(init.gpa, encoded, expected.items);
            cases_run += 1;
        }
    }

    var stdout_buffer: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout.interface.print(
        "br_upstream_multiblock_diff=ok cases={d} reference_version={x}\n",
        .{ cases_run, reference.version() },
    );
    try stdout.interface.flush();
}

fn decodeByteProgressive(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8) !void {
    // lgwin=16 advertises at most 65,520 bytes of backward history. Keeping the
    // exact window makes this probe exercise the public caller-owned contract.
    var history: [65_520]u8 = undefined;
    var decoder = vort.BrotliIncrementalCopyStreamDecoder.initWithOptions(&history, .{
        .max_output_len = expected.len,
        .expected_output_len = expected.len,
    });
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 7);
        const step = try decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    if (input_offset != encoded.len or output_offset != expected.len or !std.mem.eql(u8, output, expected))
        return error.SizeMismatch;
}
