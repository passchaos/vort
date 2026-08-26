const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

const Case = struct {
    name: []const u8,
    chunks: []const []const u8,
    expected: []const u8,
    qualities: []const u32,
};

pub fn main(init: std.process.Init) !void {
    var reference = try libbrotli.Runtime.open();
    defer reference.deinit();

    const text = "The quick brown fox jumps over the lazy dog. " ** 64;
    const json = "{\"service\":\"vort\",\"status\":\"ok\",\"value\":12345}\n" ** 48;
    const first_pattern = "abcdefghijklmnopqrstuvwxyz012345" ** 64;
    const second_pattern = "zyxwvutsrqponmlkjihgfedcba543210" ** 64;
    const third_pattern = "012345abcdefghijklmnopqrstuvwxyz" ** 64;
    var binary: [4096]u8 = undefined;
    for (&binary, 0..) |*byte, index| byte.* = @intCast((index * 29) % 251);
    const text_chunks = [_][]const u8{ text, text };
    const json_chunks = [_][]const u8{ json, json };
    const pattern_chunks = [_][]const u8{ first_pattern, second_pattern, third_pattern };
    const binary_chunks = [_][]const u8{ binary[0..2048], binary[2048..] };
    const all_qualities = [_]u32{ 0, 1, 3, 4, 5, 6, 9, 11 };
    const cases = [_]Case{
        .{ .name = "repeated-text", .chunks = &text_chunks, .expected = text ++ text, .qualities = &all_qualities },
        .{ .name = "structured-json", .chunks = &json_chunks, .expected = json ++ json, .qualities = &all_qualities },
        .{ .name = "changed-pattern-three-block", .chunks = &pattern_chunks, .expected = first_pattern ++ second_pattern ++ third_pattern, .qualities = &all_qualities },
        .{ .name = "binary-cycle", .chunks = &binary_chunks, .expected = &binary, .qualities = &all_qualities },
    };

    var cases_run: usize = 0;
    for (cases) |case| {
        for (case.qualities) |quality| {
            const encoded = try reference.encodeFlushedChunksAlloc(
                init.gpa,
                case.chunks,
                quality,
                16,
                16,
            );
            defer init.gpa.free(encoded);
            const summary = try vort.brSummarizeStream(encoded);
            if (summary.compressed_meta_block_count < case.chunks.len) {
                std.debug.print(
                    "{s} quality={d}: expected at least {d} compressed blocks, got {d} (stored={d}, empty={d})\n",
                    .{ case.name, quality, case.chunks.len, summary.compressed_meta_block_count, summary.uncompressed_meta_block_count, summary.empty_meta_block_count },
                );
                return error.ReferenceEncodeFailed;
            }
            decodeByteProgressive(init.gpa, encoded, case.expected) catch |err| {
                std.debug.print("{s} quality={d}: {s}\n", .{ case.name, quality, @errorName(err) });
                return err;
            };
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
