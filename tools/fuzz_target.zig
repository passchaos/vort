const std = @import("std");
const vort = @import("vort");

pub fn fuzzOne(allocator: std.mem.Allocator, data: []const u8) !void {
    _ = vort.store.parseHeader(data) catch |err| switch (err) {
        error.TruncatedFrame, error.InvalidMagic, error.UnsupportedVersion, error.CorruptFrame => {},
        else => return err,
    };
    _ = vort.store.parseSkippable(data) catch |err| switch (err) {
        error.TruncatedFrame, error.InvalidMagic => {},
        else => return err,
    };
    if (vort.store.decodeFrameIndexAlloc(allocator, data)) |entries| {
        allocator.free(entries);
    } else |err| switch (err) {
        error.TruncatedFrame, error.InvalidMagic, error.TrailingData, error.IntegerOverflow => {},
        else => return err,
    }
    if (vort.decodeRawDeflateAlloc(allocator, data)) |decoded| {
        allocator.free(decoded);
    } else |err| switch (err) {
        error.TruncatedFrame,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.InvalidHuffmanCode,
        error.InvalidDynamicBlockHeader,
        error.InvalidMatch,
        error.UnsupportedDeflateFeature,
        error.TrailingData,
        error.OutputTooSmall,
        => {},
        else => return err,
    }
}

pub fn main(init: std.process.Init) !void {
    const samples = [_][]const u8{
        "",
        "VORT",
        &.{ 0x01, 0x00, 0x00, 0xff, 0xff },
        &.{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 },
        &.{ 'V', 'S', 'K', 'P', 1, 0, 0, 0, 'x' },
    };
    for (samples) |sample| try fuzzOne(init.gpa, sample);

    var stdin_buffer: [4096]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().readerStreaming(init.io, &stdin_buffer);
    const stdin = &stdin_reader.interface;
    const data = stdin.allocRemaining(init.gpa, .limited(1 << 20)) catch |err| switch (err) {
        error.ReadFailed => return stdin_reader.err.?,
        error.StreamTooLong => return error.InputTooSmall,
        else => return err,
    };
    defer init.gpa.free(data);
    if (data.len != 0) try fuzzOne(init.gpa, data);

    var stdout_buffer: [128]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("fuzz target smoke: samples={d} stdin_bytes={d}\n", .{ samples.len, data.len });
    try stdout.flush();
}
