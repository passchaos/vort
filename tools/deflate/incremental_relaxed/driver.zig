const std = @import("std");
const ref = @import("reference.zig");
pub const D = @import("codec");
pub const payload = "system libz member: abcdefghabcdefghXabcdefgh checksum boundary\n" ** 4;
pub const second_payload = "second independently compressed member 0123456789\n" ** 3;

pub const Counts = struct {
    valid_splits: usize = 0,
    footer_matrix: usize = 0,
    partial_footers: usize = 0,
    malformed_payloads: usize = 0,
    tails: usize = 0,
    dictionaries: usize = 0,
    recognized_headers: usize = 0,
    finish_seals: usize = 0,
    steps: usize = 0,
    zero_output_steps: usize = 0,
    need_input: usize = 0,
    need_output: usize = 0,
    done: usize = 0,
};
pub const Cursor = struct { read: usize = 0, written: usize = 0 };
pub fn require(ok: bool) !void {
    if (!ok) return error.IncrementalRelaxedInteropMismatch;
}
pub fn equal(expected: []const u8, actual: []const u8) !void {
    try require(std.mem.eql(u8, expected, actual));
}
pub fn Decoder(comptime wrapper: ref.Wrapper) type {
    return switch (wrapper) {
        .zlib => D.ZlibIncrementalDecoder,
        .gzip => D.GzipIncrementalDecoder,
        .raw => D.RawDeflateIncrementalFixedLiteralDecoder,
    };
}

pub fn step(decoder: anytype, input: []const u8, output: []u8, counts: *Counts) !@typeInfo(@TypeOf(decoder.step(input, output))).error_union.payload {
    const before = decoder.snapshot();
    counts.steps += 1;
    if (output.len == 0) counts.zero_output_steps += 1;
    const result = decoder.step(input, output) catch |err| {
        try progress(decoder, before, decoder.snapshot().last_step_progress);
        const after = decoder.snapshot();
        try require(after.last_error_input_offset == after.total_input and after.last_error_output_offset == after.total_output);
        return err;
    };
    try progress(decoder, before, result.progress);
    switch (result.status) {
        .need_input => counts.need_input += 1,
        .need_output => counts.need_output += 1,
        .done => counts.done += 1,
    }
    return result;
}
fn progress(decoder: anytype, before: anytype, advanced: anytype) !void {
    const after = decoder.snapshot();
    try require(after.total_input == before.total_input + advanced.input_read);
    try require(after.total_output == before.total_output + advanced.output_written);
    try require(std.meta.eql(advanced, after.last_step_progress));
    const diagnostics = decoder.diagnostics();
    try require(std.meta.eql(advanced, diagnostics.last_step_progress.?));
    try require(diagnostics.input_read == after.total_input and diagnostics.output_written == after.total_output);
}

/// Once the expected output is full, pass empty output while draining final
/// EOB bits and the footer. Each failed step's accepted bytes remain accounted.
pub fn pump(decoder: anytype, wire: []const u8, output: []u8, cursor: *Cursor, end: usize, quota: usize, counts: *Counts) !void {
    for (0..wire.len * 16 + output.len * 8 + 4096) |_| {
        const offered_end = @min(end, cursor.read + quota);
        const out_end = @min(output.len, cursor.written + 3);
        const result = step(decoder, wire[cursor.read..offered_end], output[cursor.written..out_end], counts) catch |err| {
            const accepted = decoder.snapshot().last_step_progress;
            cursor.read += accepted.input_read;
            cursor.written += accepted.output_written;
            return err;
        };
        cursor.read += result.progress.input_read;
        cursor.written += result.progress.output_written;
        switch (result.status) {
            .done => return,
            .need_input => if (cursor.read == end) return,
            .need_output => {},
        }
        if (result.progress.input_read == 0 and result.progress.output_written == 0) return error.DecoderNoProgress;
    }
    return error.DecoderNoProgress;
}
pub fn hash(comptime wrapper: ref.Wrapper, decoder: anytype, bytes: []const u8) !void {
    if (wrapper == .zlib) try require(decoder.adler.digest() == ref.adler(bytes)) else if (wrapper == .gzip) try require(decoder.crc.digest() == ref.crc(bytes));
}
pub fn sealed(decoder: anytype, counts: *Counts) !void {
    if (step(decoder, "x", &.{}, counts)) |_| return error.ExpectedSealedInputRefusal else |err| try require(err == error.TrailingData);
    counts.finish_seals += 1;
}
