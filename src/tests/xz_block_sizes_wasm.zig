//! Real public XZ sized Blocks, checked with independent header/packet readers.
const std = @import("std");
const builtin = @import("builtin");
const xz = @import("xz");
var storage: [4 * 1024 * 1024]u8 = undefined;
var values: [28]u64 = @splat(0);
const text = "XZ sized Wasm blocks | abcdefghabcdefgh | repeated content\n";
fn require(ok: bool) error{SizedBlockMismatch}!void {
    if (!ok) return error.SizedBlockMismatch;
}
fn crc(input: []const u8, polynomial: u64, mask: u64) u64 {
    var value = mask;
    for (input) |byte| {
        value ^= byte;
        for (0..8) |_| value = (value >> 1) ^ ((0 -% (value & 1)) & polynomial);
    }
    return value ^ mask;
}
fn vli(input: []const u8, position: *usize) !u64 {
    var value: u64 = 0;
    for (0..9) |i| {
        try require(position.* < input.len);
        const byte = input[position.*];
        position.* += 1;
        value |= @as(u64, byte & 127) << @intCast(i * 7);
        if (byte < 128) {
            try require(i == 0 or byte != 0);
            return value;
        }
    }
    return error.SizedBlockMismatch;
}
const Scan = struct { blocks: u64 = 0, packet_bytes: u64 = 0, plain: u64 = 0, terminals: u64 = 0, compressed_packets: u64 = 0 };
fn scan(wire: []const u8, original: []const u8) !Scan {
    try require(wire.len >= 24 and wire[6] == 0 and wire[7] == 4);
    var result: Scan = .{};
    var start: usize = 12;
    var plain_at: usize = 0;
    while (start < wire.len and wire[start] != 0) {
        const head_size = (@as(usize, wire[start]) + 1) * 4;
        try require(head_size >= 12 and head_size <= wire.len - start);
        const head = wire[start .. start + head_size - 4];
        try require(head[1] == 0xc0);
        try require(crc(head, 0xedb88320, 0xffffffff) == std.mem.readInt(u32, wire[start + head_size - 4 ..][0..4], .little));
        var at: usize = 2;
        const packet_bytes = try vli(head, &at);
        const plain = try vli(head, &at);
        try require(try vli(head, &at) == 0x21 and try vli(head, &at) == 1 and at < head.len);
        at += 1;
        for (head[at..]) |byte| try require(byte == 0);
        const payload_start = start + head_size;
        var cursor = payload_start;
        var packet_plain: u64 = 0;
        while (true) {
            try require(cursor < wire.len);
            const control = wire[cursor];
            cursor += 1;
            if (control == 0) {
                result.terminals += 1;
                break;
            }
            try require(wire.len - cursor >= 2);
            const size = @as(u64, std.mem.readInt(u16, wire[cursor..][0..2], .big)) + 1;
            cursor += 2;
            var payload_size = size;
            if (control >= 0x80) {
                packet_plain += size + (@as(u64, control & 31) << 16);
                try require(wire.len - cursor >= 2);
                payload_size = @as(u64, std.mem.readInt(u16, wire[cursor..][0..2], .big)) + 1;
                cursor += 2;
                if (control >= 0xc0) {
                    try require(cursor < wire.len);
                    cursor += 1;
                }
                result.compressed_packets += 1;
            } else {
                try require(control == 1 or control == 2);
                packet_plain += size;
            }
            const count = std.math.cast(usize, payload_size) orelse return error.SizedBlockMismatch;
            try require(count <= wire.len - cursor);
            cursor += count;
        }
        try require(packet_bytes == cursor - payload_start and plain == packet_plain);
        const plain_len = std.math.cast(usize, plain) orelse return error.SizedBlockMismatch;
        try require(plain_len == 1024 and plain_len <= original.len - plain_at);
        while ((cursor - start) % 4 != 0) {
            try require(cursor < wire.len and wire[cursor] == 0);
            cursor += 1;
        }
        try require(wire.len - cursor >= 8);
        try require(std.mem.readInt(u64, wire[cursor..][0..8], .little) == crc(original[plain_at..][0..plain_len], 0xc96c5795d7870f42, 0xffffffffffffffff));
        plain_at += plain_len;
        start = cursor + 8;
        result.blocks += 1;
        result.packet_bytes += packet_bytes;
        result.plain += plain;
    }
    try require(plain_at == original.len);
    return result;
}
fn options(profile: *xz.ParallelProfile) xz.EncodeOptions {
    return .{ .include_block_sizes = true, .block_size = 1024, .chunk_size = 1024, .dictionary_size = 4096, .parser = .fast, .check = .crc64, .parallel = .{ .io = std.Io.failing, .worker_count = 3, .max_inflight_blocks = 2, .max_inflight_bytes = 2048, .max_working_memory = storage.len, .profile = profile } };
}
fn verify(comptime compressed: bool, input: []const u8, slot: usize) !void {
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    const a = fixed.allocator();
    var profile: xz.ParallelProfile = .{};
    const opts = options(&profile);
    var serial_opts = opts;
    serial_opts.parallel = null;
    const serial = if (compressed) try xz.encodeAlloc(a, input, serial_opts) else try xz.encodeStoredAlloc(a, input, serial_opts);
    defer a.free(serial);
    var output: [12288]u8 = @splat(0xa5);
    @memcpy(output[0..input.len], input);
    const written = if (compressed) try xz.encodeInto(a, output[0..input.len], &output, opts) else try xz.encodeStoredInto(a, output[0..input.len], &output, opts);
    try require(std.mem.eql(u8, serial, output[0..written]));
    const actual = try scan(output[0..written], input);
    try require(actual.blocks == input.len / 1024 and actual.terminals == actual.blocks);
    try require(profile.serial_fallback and profile.workers_started == 0 and profile.completed_blocks == actual.blocks and profile.published_blocks == actual.blocks);
    try require(profile.peak_inflight_blocks <= 2 and profile.peak_inflight_bytes <= 2048 and profile.peak_requested_bytes > 0 and profile.peak_requested_bytes <= storage.len and profile.live_requested_bytes == 0);
    var decoded: [8192]u8 = undefined;
    const count = try xz.decodeInto(a, output[0..written], decoded[0..input.len]);
    try require(count == input.len and std.mem.eql(u8, input, decoded[0..count]));
    if (compressed) try require(actual.compressed_packets != 0);
    values[slot] = input.len;
    values[slot + 1] = written;
    values[slot + 2] = actual.blocks;
    values[slot + 3] = actual.packet_bytes;
    values[slot + 4] = actual.plain;
    values[slot + 5] = actual.terminals;
    values[slot + 6] = actual.compressed_packets;
    values[slot + 7] = profile.peak_requested_bytes;
    values[slot + 8] = profile.live_requested_bytes;
}
fn boundaries(input: []const u8) !void {
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var output: [4096]u8 = @splat(0xa5);
    for ([_]bool{ false, true }) |byte_credit| {
        var profile: xz.ParallelProfile = .{};
        var opts = options(&profile);
        if (byte_credit) opts.parallel.?.max_inflight_bytes = 1023 else opts.parallel.?.max_working_memory = 0;
        const before = fixed.end_index;
        if (xz.encodeInto(fixed.allocator(), input, &output, opts)) |_| return error.ExpectedQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
        for (output) |byte| try require(byte == 0xa5);
        try require(fixed.end_index == before and profile.live_requested_bytes == 0 and profile.workers_started == 0);
    }
    var unused_profile: xz.ParallelProfile = .{};
    var serial = options(&unused_profile);
    serial.parallel = null;
    serial.include_block_sizes = false;
    const old = try xz.encodeStoredAlloc(fixed.allocator(), input[0..32], serial);
    defer fixed.allocator().free(old);
    try require(old[13] == 0);
    values[20] = 2;
    values[21] = old[13];
    values[22] = @bitSizeOf(usize);
    values[23] = storage.len;
    values[24] = 0xc0;
}
export fn xzBlockSizesWasmReport(index: u32) u64 {
    return if (index < values.len) values[index] else 0;
}
export fn xzBlockSizesWasmRun() u32 {
    if (!builtin.cpu.arch.isWasm() or @bitSizeOf(usize) != 32) return 1;
    var stored: [8192]u8 = undefined;
    for (&stored, 0..) |*byte, i| byte.* = @truncate(i *% 29 + 7);
    verify(false, &stored, 0) catch return 101;
    var compressed: [2048]u8 = undefined;
    for (&compressed, 0..) |*byte, i| byte.* = text[i % text.len];
    verify(true, &compressed, 10) catch return 201;
    boundaries(&compressed) catch return 301;
    return 0;
}
