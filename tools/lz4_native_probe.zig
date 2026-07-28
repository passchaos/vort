const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var cases = std.ArrayList(Case).empty;
    defer {
        for (cases.items) |case| init.gpa.free(case.payload);
        cases.deinit(init.gpa);
    }
    try addGeneratedCases(init.gpa, &cases);

    var checked: usize = 0;
    for (cases.items) |case| {
        try checkFrameRoundTrips(init.gpa, case);
        try checkBlockRoundTrip(init.gpa, case);
        checked += 1;
    }

    try stdout.print("lz4_native_probe_ok cases={d}\n", .{checked});
    try stdout.flush();
}

const Case = struct {
    name: []const u8,
    payload: []u8,
};

fn addGeneratedCases(allocator: std.mem.Allocator, cases: *std.ArrayList(Case)) !void {
    try cases.append(allocator, .{ .name = "empty", .payload = try allocator.dupe(u8, "") });
    try cases.append(allocator, .{ .name = "tiny", .payload = try allocator.dupe(u8, "hello") });
    try cases.append(allocator, .{ .name = "repeated", .payload = try allocator.dupe(u8, "abcd" ** 256) });
    try cases.append(allocator, .{ .name = "json", .payload = try allocator.dupe(u8, "{\"key\":\"value\",\"array\":[1,2,3],\"text\":\"abcdefg\"}\n" ** 128) });

    var rng = std.Random.DefaultPrng.init(0x4c5a34);
    try cases.append(allocator, .{ .name = "printable", .payload = try randomFromAlphabet(allocator, &rng, 4096, printable_alphabet) });
    try cases.append(allocator, .{ .name = "dna", .payload = try randomFromAlphabet(allocator, &rng, 8192, "ACGTN") });
}

const printable_alphabet =
    " !\"#$%&'()*+,-./0123456789:;<=>?@" ++
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

fn randomFromAlphabet(
    allocator: std.mem.Allocator,
    rng: *std.Random.DefaultPrng,
    len: usize,
    alphabet: []const u8,
) ![]u8 {
    const out = try allocator.alloc(u8, len);
    for (out) |*byte| byte.* = alphabet[rng.random().uintLessThan(usize, alphabet.len)];
    return out;
}

fn checkFrameRoundTrips(allocator: std.mem.Allocator, case: Case) !void {
    const lib_frame = try vort.lz4EncodeFrameAlloc(allocator, case.payload);
    defer allocator.free(lib_frame);
    const native_decoded = try vort.lz4DecodeNativeFrameAlloc(allocator, lib_frame);
    defer allocator.free(native_decoded);
    try expectPayload(case, native_decoded);

    const native_frame = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, case.payload, .{
        .content_checksum = true,
        .include_content_size = true,
        .block_checksum = true,
    });
    defer allocator.free(native_frame);
    const lib_decoded = try vort.lz4DecodeFrameAlloc(allocator, native_frame);
    defer allocator.free(lib_decoded);
    try expectPayload(case, lib_decoded);
}

fn checkBlockRoundTrip(allocator: std.mem.Allocator, case: Case) !void {
    const block = try vort.lz4EncodeBlockAlloc(allocator, case.payload);
    defer allocator.free(block);
    const decoded_len = try vort.lz4DecodedBlockSize(block);
    if (decoded_len != case.payload.len) return error.Lz4ProbeSizeMismatch;
    const decoded = try vort.lz4DecodeBlockAlloc(allocator, block, case.payload.len);
    defer allocator.free(decoded);
    try expectPayload(case, decoded);
}

fn expectPayload(case: Case, decoded: []const u8) !void {
    if (!std.mem.eql(u8, case.payload, decoded)) {
        std.debug.print(
            "lz4 probe mismatch case={s} expected_len={d} got_len={d} expected_crc={d} got_crc={d}\n",
            .{ case.name, case.payload.len, decoded.len, std.hash.Crc32.hash(case.payload), std.hash.Crc32.hash(decoded) },
        );
        return error.Lz4ProbeMismatch;
    }
}
