const std = @import("std");
const encoder = @import("encoder.zig");
const old = @import("test_support/encoder_full_buffer.zig");
const decoder = @import("decoder.zig");
const Stream = @import("incremental_encoder.zig").Encoder;
const a = std.testing.allocator;

// EncodeAlloc statistics include scratch and returned output, while caller
// inputs/encodeInto buffers are allocated separately and excluded. OOM runs
// track their own prefix fixture solely to verify complete ownership cleanup.
const CountingAllocator = struct {
    backing: std.mem.Allocator = a,
    limit: usize = std.math.maxInt(usize),
    force_move: bool = false,
    allocations: usize = 0,
    resizes: usize = 0,
    remaps: usize = 0,
    live: usize = 0,
    peak: usize = 0,
    largest_request: usize = 0,

    fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn admit(self: *@This(), old_len: usize, new_len: usize) bool {
        self.largest_request = @max(self.largest_request, new_len);
        return self.live - old_len <= self.limit and new_len <= self.limit - (self.live - old_len);
    }
    fn change(self: *@This(), old_len: usize, new_len: usize) void {
        self.live = self.live - old_len + new_len;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(raw));
        if (!self.admit(0, len)) return null;
        const memory = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.allocations += 1;
        self.change(0, len);
        return memory;
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(raw));
        self.resizes += 1;
        if (!self.admit(memory.len, len) or self.force_move) return false;
        if (!self.backing.rawResize(memory, alignment, len, ret)) return false;
        self.change(memory.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(raw));
        self.remaps += 1;
        if (!self.admit(memory.len, len) or self.force_move) return null;
        const result = self.backing.rawRemap(memory, alignment, len, ret) orelse return null;
        self.change(memory.len, len);
        return result;
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(raw));
        self.backing.rawFree(memory, alignment, ret);
        self.change(memory.len, 0);
    }
};

fn fourRuns(bytes: []u8) void {
    for (bytes, 0..) |*byte, index| byte.* = @intCast((index / 4) % 128);
}

test "Bzip2 encoder memory small one-shot wires retain frozen output with bounded scratch" {
    var binary: [512]u8 = undefined;
    for (&binary, 0..) |*byte, index| byte.* = @truncate(index);
    var expanded: [512]u8 = undefined;
    fourRuns(&expanded);
    const source = "fn encode(input: []const u8) usize { return input.len; }\n" ** 8;
    for ([_]u4{ 1, 9 }) |level| {
        for ([_]encoder.EncodeStrategy{ .fast, .balanced, .ratio }) |strategy| {
            for ([_][]const u8{ "", "tiny", &binary, source, &expanded }) |input| {
                var previous: CountingAllocator = .{};
                const reference = try old.encodeAlloc(previous.allocator(), input, .{ .block_size_100k = level, .strategy = strategy });
                // This bound is below even the smallest100k format block, not
                // a mirrored capacity sequence from the growth implementation.
                var current: CountingAllocator = .{ .limit = 64 * 1024 };
                const encoded = try encoder.encodeAlloc(current.allocator(), input, .{ .block_size_100k = level, .strategy = strategy });
                try std.testing.expectEqualSlices(u8, reference, encoded);
                try std.testing.expectEqual(encoded.len, current.live);
                try std.testing.expect(current.largest_request < 100_000);
                try std.testing.expect(current.peak < previous.peak);
                if (input.len == 0) try std.testing.expect(current.allocations < previous.allocations);
                const plain = try decoder.decodeAlloc(a, encoded);
                defer a.free(plain);
                try std.testing.expectEqualSlices(u8, input, plain);
                current.allocator().free(encoded);
                previous.allocator().free(reference);
                try std.testing.expectEqual(@as(usize, 0), current.live);
                try std.testing.expectEqual(@as(usize, 0), previous.live);
                var insufficient: CountingAllocator = .{ .limit = 64 * 1024 };
                try std.testing.expectError(error.OutOfMemory, old.encodeAlloc(insufficient.allocator(), input, .{ .block_size_100k = level, .strategy = strategy }));
                try std.testing.expectEqual(@as(usize, 0), insufficient.live);
            }
        }
    }
}

test "Bzip2 encoder memory caller buffers and append prefixes remain atomic" {
    const input = "caller owned Bzip2 memory transaction\n" ** 7;
    const encoded = try encoder.encodeAlloc(a, input, .{});
    defer a.free(encoded);
    const output = try a.alloc(u8, encoded.len + 13);
    defer a.free(output);
    @memset(output, 0xa5);
    var trace: CountingAllocator = .{};
    try std.testing.expectError(error.OutputTooSmall, encoder.encodeInto(trace.allocator(), input, output[0 .. encoded.len - 1], .{}));
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(@as(usize, 0), trace.live);
    try std.testing.expectEqual(encoded.len, try encoder.encodeInto(trace.allocator(), input, output, .{}));
    try std.testing.expectEqualSlices(u8, encoded, output[0..encoded.len]);
    for (output[encoded.len..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(a);
    try appended.appendSlice(a, "caller prefix:");
    const prefix = appended.items.len;
    try std.testing.expectError(error.InvalidBzip2Header, encoder.encodeAppend(a, &appended, input, .{ .block_size_100k = 0 }));
    try std.testing.expectEqualStrings("caller prefix:", appended.items);
    try std.testing.expectEqual(encoded.len, try encoder.encodeAppend(a, &appended, input, .{}));
    try std.testing.expectEqualStrings("caller prefix:", appended.items[0..prefix]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[prefix..]);
    @memset(output, 0xa5);
    var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, encoder.encodeInto(failing.allocator(), input, output, .{}));
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

const Operation = enum { alloc, append, into, incremental };
fn runFailure(allocator: std.mem.Allocator, input: []const u8, strategy: encoder.EncodeStrategy, operation: Operation) !void {
    // Deny in-place resizing/remapping to exercise each moving RLE growth and
    // the final owned-slice clone, including their allocation failure points.
    var trace: CountingAllocator = .{ .backing = allocator, .force_move = true };
    defer std.testing.expectEqual(@as(usize, 0), trace.live) catch @panic("encoder memory leaked after failure");
    const options: encoder.EncodeOptions = .{ .block_size_100k = 1, .strategy = strategy };
    switch (operation) {
        .alloc => {
            const output = try encoder.encodeAlloc(trace.allocator(), input, options);
            defer trace.allocator().free(output);
        },
        .append => {
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(trace.allocator());
            try output.appendSlice(trace.allocator(), "prefix");
            _ = encoder.encodeAppend(trace.allocator(), &output, input, options) catch |err| {
                try std.testing.expectEqualStrings("prefix", output.items);
                return err;
            };
            try std.testing.expectEqualStrings("prefix", output.items[0..6]);
        },
        .into => {
            var output: [4096]u8 = @splat(0xa5);
            _ = encoder.encodeInto(trace.allocator(), input, &output, options) catch |err| {
                for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
                return err;
            };
        },
        .incremental => {
            var state = try Stream.initExactSize(trace.allocator(), .{ .block_size_100k = 1, .strategy = strategy }, input.len);
            defer state.deinit();
            const output = try drain(&state, input, 17, 13);
            defer a.free(output);
        },
    }
}

test "Bzip2 encoder memory allocation failures clean up growth clones and transactions" {
    var expanded: [512]u8 = undefined;
    fourRuns(&expanded);
    for ([_]encoder.EncodeStrategy{ .fast, .balanced, .ratio }) |strategy| {
        for ([_][]const u8{ "", "tiny failure", &expanded }) |input| {
            for ([_]Operation{ .alloc, .append, .into, .incremental }) |operation|
                try std.testing.checkAllAllocationFailures(a, runFailure, .{ input, strategy, operation });
        }
    }
}

fn drain(state: *Stream, input: []const u8, input_chunk: usize, output_chunk: usize) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(a);
    var buffer: [4096]u8 = undefined;
    var offset: usize = 0;
    var finished = false;
    for (0..input.len * 2 + 8192) |_| {
        if (offset == input.len and !finished) {
            state.finish();
            finished = true;
        }
        const end = @min(input.len, offset + input_chunk);
        const result = try state.step(input[offset..end], buffer[0..output_chunk]);
        offset += result.progress.input_read;
        try output.appendSlice(a, buffer[0..result.progress.output_written]);
        if (result.status == .done) {
            try std.testing.expectEqual(input.len, offset);
            return output.toOwnedSlice(a);
        }
    }
    return error.StreamDidNotFinish;
}

test "Bzip2 encoder memory incremental empty reuse reset and level changes stay exact" {
    var trace: CountingAllocator = .{ .limit = 64 * 1024 };
    var state = try Stream.initExactSize(trace.allocator(), .{}, 0);
    defer state.deinit();
    const empty = try drain(&state, "", 1, 1);
    defer a.free(empty);
    const canonical = try old.encodeAlloc(a, "", .{});
    defer a.free(canonical);
    try std.testing.expectEqualSlices(u8, canonical, empty);
    try std.testing.expectEqual(@as(usize, 0), state.snapshot().retained_rle_capacity);
    var runs: [512]u8 = undefined;
    fourRuns(&runs);
    try state.nextStreamExactSize(.{ .block_size_100k = 1, .strategy = .fast }, runs.len);
    const first = try drain(&state, &runs, 7, 17);
    defer a.free(first);
    const expected = try encoder.encodeAlloc(a, &runs, .{ .block_size_100k = 1, .strategy = .fast });
    defer a.free(expected);
    try std.testing.expectEqualSlices(u8, expected, first);
    const retained = state.snapshot().retained_rle_capacity;
    try std.testing.expect(retained < 100_000);
    state.reset();
    try std.testing.expectEqual(retained, state.snapshot().retained_rle_capacity);
    const repeated = try drain(&state, &runs, 11, 3);
    defer a.free(repeated);
    try std.testing.expectEqualSlices(u8, first, repeated);
    try state.nextStreamExactSize(.{ .block_size_100k = 9, .strategy = .ratio }, 0);
    const second = try drain(&state, "", 1, 2);
    defer a.free(second);
    try std.testing.expectEqualSlices(u8, canonical, second);
    try std.testing.expectEqual(retained, state.snapshot().retained_rle_capacity);
    const snapshot = state.snapshot();
    try std.testing.expectError(error.InvalidBzip2Header, state.nextStream(.{ .block_size_100k = 0 }));
    try std.testing.expectEqualDeep(snapshot, state.snapshot());
}

test "Bzip2 encoder memory growing RLE blocks preserve frozen and incremental wires" {
    // Exactly4-byte runs expand to5 RLE1 bytes; this input crosses100k RLE
    // storage while keeping the original input and Huffman frontier modest.
    const input = try a.alloc(u8, 80004);
    defer a.free(input);
    var random: u32 = 0x63bfa213;
    var byte: u8 = 0;
    for (0..input.len / 4) |group| {
        random = random *% 1664525 +% 1013904223;
        byte = @intCast((@as(u32, byte) + 1 + random % 250) % 251);
        @memset(input[group * 4 ..][0..4], byte);
    }
    const reference = try old.encodeAlloc(a, input, .{ .block_size_100k = 1 });
    defer a.free(reference);
    const current = try encoder.encodeAlloc(a, input, .{ .block_size_100k = 1 });
    defer a.free(current);
    try std.testing.expectEqualSlices(u8, reference, current);
    var state = try Stream.initExactSize(a, .{ .block_size_100k = 1 }, input.len);
    defer state.deinit();
    const streamed = try drain(&state, input, 4093, 257);
    defer a.free(streamed);
    try std.testing.expectEqualSlices(u8, reference, streamed);
    try std.testing.expect(state.snapshot().block_count >= 2);
    const plain = try decoder.decodeAlloc(a, streamed);
    defer a.free(plain);
    try std.testing.expectEqualSlices(u8, input, plain);
}
