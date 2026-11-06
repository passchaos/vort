//! Small public heap-quota consumers executed on wasm32-wasi.
const std = @import("std");
const zstd = @import("zstd");
const a = std.heap.page_allocator;
const payload_len = 512;
const prefix = "caller-prefix";
var values: [32]u64 = @splat(0);

const DeniedAllocator = struct {
    attempts: usize = 0,
    fn allocator(self: *DeniedAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, _: usize, _: std.mem.Alignment, _: usize) ?[*]u8 {
        const self: *DeniedAllocator = @ptrCast(@alignCast(raw));
        self.attempts += 1;
        return null;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize) void {
        unreachable;
    }
};

fn require(ok: bool) error{DecodeMemoryConsumerMismatch}!void {
    if (!ok) return error.DecodeMemoryConsumerMismatch;
}
fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try require(byte == 0xa5);
}
fn fill(bytes: []u8, rle: bool) void {
    for (bytes, 0..) |*byte, i| byte.* = if (rle) 'R' else @truncate(i *% 29 + 7);
}
fn frame(input: []const u8, rle: bool) ![]u8 {
    const wire = try zstd.encodeRawOrRleFrameWithOptionsAlloc(a, input, .{ .content_checksum = true });
    errdefer a.free(wire);
    const header = try zstd.inspectNativeFrameHeader(wire);
    const first = try zstd.inspectNativeFrameFirstBlock(wire);
    try require(header.has_checksum and header.content_size == input.len);
    const expected_type: zstd.NativeBlockType = if (rle) .rle else .raw;
    try require(first.block_type == expected_type);
    return wire;
}

export fn zstdDecodeMemoryWasmReport(index: u32) u64 {
    return if (index < values.len) values[index] else 0;
}

fn owned() !void {
    var input: [payload_len]u8 = undefined;
    for ([_]bool{ false, true }, 0..) |rle, index| {
        fill(&input, rle);
        const wire = try frame(&input, rle);
        defer a.free(wire);
        var memory: zstd.DecodeMemoryProfile = .{};
        var options: zstd.FrameDecodeOptions = .{ .memory_profile = &memory };
        const decoded = try zstd.decodeFrameAllocWithOptions(a, wire, options);
        try require(std.mem.eql(u8, &input, decoded));
        try require(memory.available and memory.live_requested_bytes == 0);
        const peak = memory.peak_requested_bytes;
        try require(peak >= input.len);
        a.free(decoded);
        memory.reset();
        options.max_total_working_memory = peak;
        const exact = try zstd.decodeFrameAllocWithOptions(a, wire, options);
        defer a.free(exact);
        try require(std.mem.eql(u8, &input, exact));
        try require(memory.peak_requested_bytes == peak and memory.live_requested_bytes == 0 and memory.limit == peak);
        memory.reset();
        options.max_total_working_memory = peak - 1;
        if (zstd.decodeFrameAllocWithOptions(a, wire, options)) |unexpected| {
            a.free(unexpected);
            return error.ExpectedOwnedQuotaRefusal;
        } else |err| try require(err == error.WorkingMemoryLimitExceeded);
        try require(memory.live_requested_bytes == 0 and memory.peak_requested_bytes <= peak - 1);
        values[4 + index] = peak;
        values[8 + index] = wire.len;
    }
    values[0] = @bitSizeOf(usize);
    values[1] = payload_len;
    values[6] = 0;
    values[7] = 2;
}
export fn zstdDecodeMemoryWasmOwned() u32 {
    owned() catch |err| {
        values[31] = @intFromError(err);
        return 101;
    };
    return 0;
}

fn append() !void {
    var input: [payload_len]u8 = undefined;
    fill(&input, false);
    const wire = try frame(&input, false);
    defer a.free(wire);
    const capacity = prefix.len + payload_len + 1024;
    var peak: usize = 0;
    for (0..3) |pass| {
        var out = std.ArrayList(u8).fromOwnedSlice(try a.alloc(u8, capacity));
        defer out.deinit(a);
        @memset(out.items, 0xa5);
        out.items.len = prefix.len;
        @memcpy(out.items, prefix);
        const pointer = out.items.ptr;
        var memory: zstd.DecodeMemoryProfile = .{};
        var options: zstd.FrameDecodeOptions = .{ .memory_profile = &memory };
        if (pass != 0) options.max_total_working_memory = if (pass == 1) peak else peak - 1;
        if (pass == 2) {
            if (zstd.decodeFrameAppendWithOptions(a, &out, wire, options)) |_| return error.ExpectedAppendQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
            try require(out.items.ptr == pointer and out.capacity == capacity and std.mem.eql(u8, prefix, out.items));
            try untouched(out.items.ptr[prefix.len..capacity]);
            try require(memory.live_requested_bytes == 0);
            options.max_total_working_memory = peak;
        }
        const written = try zstd.decodeFrameAppendWithOptions(a, &out, wire, options);
        try require(written == input.len and out.items.ptr == pointer and out.capacity == capacity);
        try require(std.mem.eql(u8, prefix, out.items[0..prefix.len]) and std.mem.eql(u8, &input, out.items[prefix.len..]));
        try require(memory.live_requested_bytes == 0);
        if (pass == 0) {
            peak = memory.peak_requested_bytes;
            try require(peak >= capacity + input.len);
        } else try require(memory.peak_requested_bytes == peak);
    }
    values[12] = capacity;
    values[13] = peak;
    values[14] = 1;
    values[15] = 1;
}
export fn zstdDecodeMemoryWasmAppend() u32 {
    append() catch |err| {
        values[31] = @intFromError(err);
        return 201;
    };
    return 0;
}

fn reusable() !void {
    var input: [payload_len]u8 = undefined;
    fill(&input, true);
    const wire = try frame(&input, true);
    defer a.free(wire);
    var peak: usize = 0;
    for (0..3) |pass| {
        var decoder = zstd.NativeFrameDecoder.init(a);
        defer decoder.deinit();
        var memory: zstd.DecodeMemoryProfile = .{};
        var options: zstd.FrameDecodeOptions = .{ .memory_profile = &memory };
        try require(!decoder.memorySnapshot().available);
        if (pass != 0) options.max_total_working_memory = if (pass == 1) peak else peak - 1;
        if (pass == 2) {
            if (decoder.decodeScratchWithOptions(wire, options)) |_| return error.ExpectedScratchQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
            try require(decoder.scratch.items.len == 0 and decoder.scratch.capacity == 0);
            options.max_total_working_memory = peak;
            memory.reset();
        }
        const decoded = try decoder.decodeScratchWithOptions(wire, options);
        try require(std.mem.eql(u8, &input, decoded));
        const snapshot = decoder.memorySnapshot();
        try require(snapshot.available and snapshot.live_requested_bytes == memory.live_requested_bytes);
        try require(snapshot.live_requested_bytes >= decoder.scratch.capacity and snapshot.live_requested_bytes > 0);
        if (pass == 0) peak = memory.peak_requested_bytes else try require(memory.peak_requested_bytes == peak);
        const pointer = decoded.ptr;
        const capacity = decoder.scratch.capacity;
        options.max_total_working_memory = snapshot.live_requested_bytes - 1;
        if (decoder.decodeScratchWithOptions(wire, options)) |_| return error.ExpectedRetainedQuotaRefusal else |err| try require(err == error.WorkingMemoryLimitExceeded);
        try require(decoder.scratch.items.ptr == pointer and decoder.scratch.capacity == capacity and std.mem.eql(u8, &input, decoder.scratch.items));
        options.max_total_working_memory = peak;
        const retry = try decoder.decodeScratchWithOptions(wire, options);
        try require(retry.ptr == pointer and std.mem.eql(u8, &input, retry));
        values[17] = decoder.memorySnapshot().live_requested_bytes;
        values[18] = decoder.scratch.capacity;
        values[19] += 1;
    }
    values[16] = peak;
    values[20] = 1;
}
export fn zstdDecodeMemoryWasmReusable() u32 {
    reusable() catch |err| {
        values[31] = @intFromError(err);
        return 301;
    };
    return 0;
}

fn sizeOnly() !void {
    var input: [payload_len]u8 = undefined;
    fill(&input, false);
    const wire = try frame(&input, false);
    defer a.free(wire);
    var denied: DeniedAllocator = .{};
    var memory: zstd.DecodeMemoryProfile = .{};
    const options: zstd.FrameDecodeOptions = .{ .max_total_working_memory = 0, .memory_profile = &memory };
    var decoder = zstd.NativeFrameDecoder.initWithOptions(denied.allocator(), options);
    defer decoder.deinit();
    try require(try zstd.decodedFrameSizeWithOptions(wire, options) == input.len);
    try require(try decoder.decodedSizeWithOptions(wire, options) == input.len);
    try require(try decoder.decodedSize(wire) == input.len);
    try require(!decoder.memorySnapshot().available and !memory.available and denied.attempts == 0);
    var output: [payload_len + 17]u8 = @splat(0xa5);
    var legacy = zstd.NativeFrameDecoder.init(denied.allocator());
    defer legacy.deinit();
    try require(try legacy.decodeIntoSlice(wire, output[0..payload_len]) == input.len);
    try require(std.mem.eql(u8, &input, output[0..payload_len]));
    try untouched(output[payload_len..]);
    try require(!legacy.memorySnapshot().available and denied.attempts == 0);
    values[24] = input.len;
    values[25] = denied.attempts;
    values[26] = 1;
}
export fn zstdDecodeMemoryWasmSizeOnly() u32 {
    sizeOnly() catch |err| {
        values[31] = @intFromError(err);
        return 401;
    };
    return 0;
}

pub fn main() !void {
    try owned();
    try append();
    try reusable();
    try sizeOnly();
}
