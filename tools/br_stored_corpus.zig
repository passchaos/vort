const std = @import("std");
const vort = @import("vort");

const binary_payload = [_]u8{ 0x00, 0x01, 0x02, 0x7f, 0x80, 0xfe, 0xff, 0x42 } ** 64;

const ValidCase = struct {
    name: []const u8,
    payload: []const u8,
    window_bits: u5 = 16,
    metadata: []const u8 = "",
};

pub fn main(init: std.process.Init) !void {
    const valid_cases = [_]ValidCase{
        .{ .name = "empty-default", .payload = "" },
        .{ .name = "tiny-w10", .payload = "hello", .window_bits = 10 },
        .{ .name = "text-w16-meta", .payload = "brotli stored corpus\n" ** 32, .window_bits = 16, .metadata = "vort-meta" },
        .{ .name = "binary-w24-meta", .payload = &binary_payload, .window_bits = 24, .metadata = "binary-metadata" },
    };

    var accepted: usize = 0;
    for (&valid_cases) |case| {
        try checkValid(init.gpa, case);
        accepted += 1;
    }

    var rejected: usize = 0;
    try checkInvalid("invalid-window-bits", &[_]u8{0x11}, error.CorruptFrame);
    rejected += 1;
    try checkInvalid("trailing-data", &[_]u8{ 0x06, 0x00 }, error.TrailingData);
    rejected += 1;
    try checkInvalid("unsupported-compressed-block", &[_]u8{ 0x00, 0x00, 0x00 }, error.UnsupportedBrotliFeature);
    rejected += 1;

    const with_metadata = try vort.brEncodeStoredStreamWithOptionsAlloc(init.gpa, "payload", .{ .metadata = "metadata" });
    defer init.gpa.free(with_metadata);
    try checkInvalid("truncated-metadata", with_metadata[0 .. with_metadata.len - 1], error.TruncatedFrame);
    rejected += 1;

    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("br_stored_corpus=ok accepted={d} rejected={d}\n", .{ accepted, rejected });
    try stdout.flush();
}

fn checkValid(allocator: std.mem.Allocator, case: ValidCase) !void {
    const encoded = try vort.brEncodeStoredStreamWithOptionsAlloc(allocator, case.payload, .{
        .window_bits = case.window_bits,
        .metadata = case.metadata,
    });
    defer allocator.free(encoded);

    try expectEqualUsize(case.payload.len, try vort.brDecodedStreamSize(encoded), case.name);
    const decoded = try vort.brDecodeStreamAllocLimited(allocator, encoded, case.payload.len);
    defer allocator.free(decoded);
    try expectEqualBytes(case.payload, decoded, case.name);

    const out = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(out);
    try expectEqualUsize(case.payload.len, try vort.brDecodeStreamInto(encoded, out), case.name);
    try expectEqualBytes(case.payload, out, case.name);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    try expectEqualUsize(case.payload.len, try vort.brDecodeStreamAppend(allocator, &appended, encoded), case.name);
    try expectEqualBytes("prefix:", appended.items[0.."prefix:".len], case.name);
    try expectEqualBytes(case.payload, appended.items["prefix:".len..], case.name);

    if (case.payload.len != 0) {
        try expectError(error.OutputLimitExceeded, vort.brDecodedStreamSizeLimited(encoded, case.payload.len - 1), case.name);
        try expectError(error.OutputLimitExceeded, vort.brDecodeStreamAllocLimited(allocator, encoded, case.payload.len - 1), case.name);
    }
}

fn checkInvalid(name: []const u8, stream: []const u8, expected: anyerror) !void {
    try expectError(expected, vort.brDecodedStreamSize(stream), name);
}

fn expectEqualUsize(expected: usize, actual: usize, _: []const u8) !void {
    if (expected != actual) return error.UnexpectedValue;
}

fn expectEqualBytes(expected: []const u8, actual: []const u8, _: []const u8) !void {
    if (!std.mem.eql(u8, expected, actual)) return error.UnexpectedValue;
}

fn expectError(expected: anyerror, result: anytype, _: []const u8) !void {
    if (result) |_| {
        return error.ExpectedError;
    } else |err| {
        if (err != expected) return error.UnexpectedErrorName;
    }
}
