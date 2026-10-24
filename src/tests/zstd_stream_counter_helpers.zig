//! Independent stream-byte accounting, real small frame fixtures and allocator ledger.
const std = @import("std");

pub const Count = if (@bitSizeOf(usize) < 64) u64 else usize;
pub const plain = "Zstd stream counters abcdefghabcdefghXabcdefgh\n" ** 4;
pub const rle = [_]u8{'R'} ** 512;
pub const prefix = "Zstd stream counters abcdefghabcdefghXabcdefgh\n";

/// Read a normal Zstd frame's content-size field without any native decoder
/// size conversion. It is a wire u64 even when local slices use32-bit usize.
pub fn pledgedContentSize(bytes: []const u8) !u64 {
    try std.testing.expect(bytes.len >= 6);
    try std.testing.expectEqualSlices(u8, &.{ 0x28, 0xb5, 0x2f, 0xfd }, bytes[0..4]);
    const flags = bytes[4];
    const single = flags & 0x20 != 0;
    var offset: usize = 5 + @as(usize, @intFromBool(!single));
    offset += switch (flags & 3) {
        0 => @as(usize, 0),
        1 => 1,
        2 => 2,
        3 => 4,
        else => unreachable,
    };
    const width: usize = switch (flags >> 6) {
        0 => if (single) 1 else 0,
        1 => 2,
        2 => 4,
        3 => 8,
        else => unreachable,
    };
    try std.testing.expect(width != 0);
    var value: u64 = 0;
    for (0..width) |i| value |= @as(u64, bytes[offset + i]) << @intCast(8 * i);
    return value + if (width == 2) @as(u64, 256) else 0;
}

pub const Completed = struct { frames: Count, input_bytes: Count, output_bytes: Count };

/// These are repeated fully completed frames, not an arbitrary active-history
/// counter assignment. Per-frame state can remain that of the one real frame.
pub fn repeatedFrames(frames: Count, input_len: usize, output_len: usize) Completed {
    const inputs = @as(u128, frames) * input_len;
    const outputs = @as(u128, frames) * output_len;
    std.debug.assert(inputs <= std.math.maxInt(Count) and outputs <= std.math.maxInt(Count));
    return .{ .frames = frames, .input_bytes = @intCast(inputs), .output_bytes = @intCast(outputs) };
}

pub fn seedCompletedEncoder(encoder: anytype, frames: Count) !Completed {
    const snapshot = encoder.snapshot();
    try std.testing.expect(snapshot.done);
    try std.testing.expectEqual(@as(usize, 0), snapshot.pending_output);
    try std.testing.expectEqual(@as(Count, 1), snapshot.frame_count);
    try std.testing.expectEqual(snapshot.frame_input, snapshot.input_read);
    try std.testing.expectEqual(snapshot.frame_output, snapshot.output_written);
    // Keep the actual last frame, checksum, block and history untouched.
    const completed = repeatedFrames(frames, @intCast(snapshot.frame_input), @intCast(snapshot.frame_output));
    encoder.stream_input = completed.input_bytes;
    encoder.stream_output = completed.output_bytes;
    encoder.frame_count = completed.frames;
    return completed;
}

pub fn seedCompletedDecoder(decoder: anytype, frames: Count) !Completed {
    const snapshot = decoder.snapshot();
    try std.testing.expectEqual(.done, snapshot.phase);
    try std.testing.expectEqual(@as(usize, 0), snapshot.trailing_input_bytes);
    try std.testing.expectEqual(@as(Count, 1), snapshot.data_frame_count);
    try std.testing.expect(decoder.failure == null and decoder.requiredDictionaryId() == null);
    const completed = repeatedFrames(frames, @intCast(snapshot.input_received), @intCast(snapshot.output_written));
    decoder.input_received = completed.input_bytes;
    decoder.output_written = completed.output_bytes;
    decoder.data_frame_count = completed.frames;
    return completed;
}

pub fn validatedRepeatedRleEncoderPrefix(encoder: anytype, actual_block: []const u8, header_len: usize, repetitions: Count) !Count {
    const block_len: usize = 128 * 1024;
    try std.testing.expectEqualSlices(u8, &.{ 0x02, 0x00, 0x10, 'R' }, actual_block);
    try std.testing.expectEqual(@as(usize, 14), header_len);
    try std.testing.expectEqual(.raw_or_rle, encoder.options.selection);
    try std.testing.expect(encoder.options.include_content_size and !encoder.options.content_checksum);
    try std.testing.expectEqual(@as(?u6, 20), encoder.options.window_log);
    try std.testing.expectEqual(block_len, encoder.options.block_size_max);
    try std.testing.expect(encoder.options.control_profile == null);
    try std.testing.expect(encoder.dictionary == null and encoder.dictionary_id == null);
    try std.testing.expectEqual(@as(u32, 0), encoder.options.dictionary_id);
    try std.testing.expect(encoder.header_written and !encoder.flush_requested and !encoder.finishing and !encoder.final_written and !encoder.done and !encoder.skippable_only);
    try std.testing.expectEqual(@as(usize, 0), encoder.block.items.len);
    try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
    try std.testing.expectEqual(@as(usize, 0), encoder.pending_offset);
    try std.testing.expectEqual(@as(usize, 0), encoder.history.bytes.items.len);
    try std.testing.expectEqual(@as(usize, 0), encoder.history.index.recent_entries.items.len);
    try std.testing.expectEqual(@as(usize, 0), encoder.history.index.long_entries.items.len);
    try std.testing.expectEqual(@as(Count, block_len), encoder.total_input);
    try std.testing.expectEqual(@as(Count, block_len), encoder.stream_input);
    try std.testing.expectEqual(@as(Count, header_len + actual_block.len), encoder.total_output);
    try std.testing.expectEqual(@as(Count, header_len + actual_block.len), encoder.stream_output);
    try std.testing.expectEqual(@as(Count, block_len), encoder.history.absolute_start);
    try std.testing.expectEqual(@as(Count, block_len), encoder.history.absolute_end);
    try std.testing.expectEqual(@as(Count, 0), encoder.frame_count);
    const wide_input = @as(u128, repetitions) * block_len;
    const wide_output = @as(u128, header_len) + @as(u128, repetitions) * actual_block.len;
    try std.testing.expect(wide_input <= std.math.maxInt(Count) and wide_output <= std.math.maxInt(Count));
    const input_count: Count = @intCast(wide_input);
    const output_count: Count = @intCast(wide_output);
    try std.testing.expect(input_count <= (encoder.expected_input_len orelse return error.TestUnexpectedResult));
    // Identical completed raw/RLE blocks leave no matching history, checksum
    // update, or entropy state. This derives a valid repeated-prefix model,
    // without claiming that its4GiB bytes were physically passed to the codec.
    encoder.total_input = input_count;
    encoder.stream_input = input_count;
    encoder.total_output = output_count;
    encoder.stream_output = output_count;
    encoder.history.absolute_start = input_count;
    encoder.history.absolute_end = input_count;
    return input_count;
}

pub fn decodeDrive(a: std.mem.Allocator, decoder: anytype, wire: []const u8, maximum_output: usize) ![]u8 {
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(a);
    var offset: usize = 0;
    var output: [7]u8 = undefined;
    for (0..wire.len * 16 + maximum_output * 16 + 4096) |call| {
        const end = @min(wire.len, offset + 3);
        const before = decoder.snapshot();
        @memset(&output, 0xa5);
        const result = try decoder.step(wire[offset..end], output[0..if (call % 7 == 0) 0 else 1]);
        const after = decoder.snapshot();
        try std.testing.expectEqual(@as(Count, result.progress.input_read), after.input_received - before.input_received);
        try std.testing.expectEqual(@as(Count, result.progress.output_written), after.output_written - before.output_written);
        try untouched(output[result.progress.output_written..]);
        offset += result.progress.input_read;
        try decoded.appendSlice(a, output[0..result.progress.output_written]);
        if (result.status == .done) break;
        if (offset == wire.len and result.status == .need_input and result.progress.output_written == 0) {
            try decoder.finish();
            break;
        }
    }
    try std.testing.expectEqual(wire.len, offset);
    return decoded.toOwnedSlice(a);
}

pub fn drive(collector: std.mem.Allocator, encoder: anytype, input: []const u8, input_quota: usize, output_quota: usize) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(collector);
    try std.testing.expect(encoder.snapshot().frame_input <= input.len);
    var offset: usize = @intCast(encoder.snapshot().frame_input);
    var finishing = encoder.snapshot().finishing;
    var output: [257]u8 = undefined;
    for (0..input.len * 16 + 4096) |call| {
        if (offset == input.len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        @memset(&output, 0xa5);
        const end = @min(input.len, offset + input_quota);
        const before = encoder.snapshot();
        const result = try encoder.step(input[offset..end], output[0..if (call % 7 == 0) 0 else output_quota]);
        const after = encoder.snapshot();
        try std.testing.expectEqual(@as(Count, result.progress.input_read), after.frame_input - before.frame_input);
        try std.testing.expectEqual(@as(Count, result.progress.output_written), after.frame_output - before.frame_output);
        try untouched(output[result.progress.output_written..]);
        offset += result.progress.input_read;
        try bytes.appendSlice(collector, output[0..result.progress.output_written]);
        if (result.status == .done) {
            try std.testing.expectEqual(input.len, offset);
            return bytes.toOwnedSlice(collector);
        }
    }
    return error.TestUnexpectedResult;
}

pub const JointLedger = struct {
    live: usize = 0,
    peak: usize = 0,

    pub fn beginMeasurement(self: *JointLedger) void {
        self.peak = self.live;
    }
};

pub const TrackingAllocator = struct {
    backing: std.mem.Allocator,
    joint: ?*JointLedger = null,
    live: usize = 0,
    peak: usize = 0,
    allocated_bytes: usize = 0,
    freed_bytes: usize = 0,
    alloc_attempts: usize = 0,
    resize_attempts: usize = 0,
    remap_attempts: usize = 0,
    free_calls: usize = 0,
    successful_resizes: usize = 0,
    successful_remaps: usize = 0,
    fail_alloc_after: ?usize = null,
    fail_resize_after: ?usize = null,
    fail_remap_after: ?usize = null,
    forced_failures: usize = 0,
    force_moving_growth: bool = false,
    force_copy_reallocation: bool = false,
    poison_before_free: bool = false,
    peak_operation: Operation = .allocate,
    peak_before: usize = 0,
    peak_request: usize = 0,
    owned_peak: usize = 0,
    slots: [1024]Slot = @splat(.{}),

    pub const Operation = enum { allocate, resize, remap };
    const Slot = struct { pointer: ?[*]u8 = null, len: usize = 0, excluded_bytes: usize = 0 };

    pub fn init(backing: std.mem.Allocator) TrackingAllocator {
        return .{ .backing = backing };
    }

    pub fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = allocate, .resize = resize, .remap = remap, .free = free } };
    }

    pub fn clearFailures(self: *TrackingAllocator) void {
        self.fail_alloc_after = null;
        self.fail_resize_after = null;
        self.fail_remap_after = null;
    }

    pub fn beginMeasurement(self: *TrackingAllocator) void {
        self.peak = self.live;
        self.peak_before = self.live;
        self.peak_request = 0;
        self.owned_peak = self.ownedLive();
    }

    /// Exclude only this pre-existing caller allocation. A moving replacement
    /// is a new request and stays counted until the caller explicitly takes it.
    pub fn excludeInitialAllocation(self: *TrackingAllocator, memory: []u8) void {
        self.slot(memory).excluded_bytes = memory.len;
        self.owned_peak = self.ownedLive();
    }

    pub fn ownedLive(self: *const TrackingAllocator) usize {
        var borrowed: usize = 0;
        for (self.slots) |record| borrowed += record.excluded_bytes;
        return self.live - borrowed;
    }

    fn recordOwnedPeak(self: *TrackingAllocator) void {
        self.owned_peak = @max(self.owned_peak, self.ownedLive());
    }

    fn slot(self: *TrackingAllocator, memory: []u8) *Slot {
        for (&self.slots) |*record| if (record.pointer == memory.ptr) {
            std.debug.assert(record.len == memory.len);
            return record;
        };
        @panic("untracked allocator pointer");
    }

    fn increase(self: *TrackingAllocator, amount: usize, operation: Operation, requested: usize) void {
        const previous = self.live;
        self.live += amount;
        self.allocated_bytes += amount;
        if (self.joint) |joint| {
            joint.live += amount;
            joint.peak = @max(joint.peak, joint.live);
        }
        if (self.live > self.peak) {
            self.peak = self.live;
            self.peak_operation = operation;
            self.peak_before = previous;
            self.peak_request = requested;
        }
    }

    fn decrease(self: *TrackingAllocator, amount: usize) void {
        std.debug.assert(amount <= self.live);
        self.live -= amount;
        self.freed_bytes += amount;
        if (self.joint) |joint| joint.live -= amount;
    }

    fn failure(self: *TrackingAllocator, after: ?usize, index: usize) bool {
        if (after) |limit| if (index >= limit) {
            self.forced_failures += 1;
            return true;
        };
        return false;
    }

    fn allocate(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const call = self.alloc_attempts;
        self.alloc_attempts += 1;
        if (self.failure(self.fail_alloc_after, call)) return null;
        const memory = self.backing.rawAlloc(len, alignment, address) orelse return null;
        for (&self.slots) |*record| if (record.pointer == null) {
            record.* = .{ .pointer = memory, .len = len };
            self.increase(len, .allocate, len);
            self.recordOwnedPeak();
            return memory;
        };
        @panic("tracking allocation table exhausted");
    }

    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const call = self.resize_attempts;
        self.resize_attempts += 1;
        const record = self.slot(memory);
        if (self.failure(self.fail_resize_after, call) or
            (self.force_moving_growth and len > memory.len) or
            (self.force_copy_reallocation and len != memory.len)) return false;
        if (!self.backing.rawResize(memory, alignment, len, address)) return false;
        self.successful_resizes += 1;
        if (len > memory.len) self.increase(len - memory.len, .resize, len) else self.decrease(memory.len - len);
        record.len = len;
        record.excluded_bytes = @min(record.excluded_bytes, len);
        self.recordOwnedPeak();
        return true;
    }

    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const call = self.remap_attempts;
        self.remap_attempts += 1;
        const record = self.slot(memory);
        if (self.failure(self.fail_remap_after, call) or
            (self.force_moving_growth and len > memory.len) or
            (self.force_copy_reallocation and len != memory.len)) return null;
        const result = self.backing.rawRemap(memory, alignment, len, address) orelse return null;
        self.successful_remaps += 1;
        if (len > memory.len) self.increase(len - memory.len, .remap, len) else self.decrease(memory.len - len);
        record.* = .{ .pointer = result, .len = len, .excluded_bytes = @min(record.excluded_bytes, len) };
        self.recordOwnedPeak();
        return result;
    }

    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(raw));
        const record = self.slot(memory);
        if (self.poison_before_free) @memset(memory, 0xdd);
        self.backing.rawFree(memory, alignment, address);
        record.* = .{};
        self.free_calls += 1;
        self.decrease(memory.len);
        self.recordOwnedPeak();
    }
};

pub fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

test "Zstd stream counters independent tracker observes in place growth shrink and overlapping live requests" {
    var storage: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var tracked = TrackingAllocator.init(fixed.allocator());
    const a = tracked.allocator();
    var bytes = try a.alloc(u8, 16);
    try std.testing.expect(a.resize(bytes, 64));
    bytes = bytes.ptr[0..64];
    bytes = a.remap(bytes, 8) orelse return error.TestUnexpectedResult;
    const other = try a.alloc(u8, 24);
    try std.testing.expectEqual(@as(usize, 32), tracked.live);
    try std.testing.expectEqual(@as(usize, 64), tracked.peak);
    a.free(other);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expectEqual(tracked.allocated_bytes, tracked.freed_bytes);
}

test "Zstd stream counters independent tracker charges old and new buffers during moving fallback growth" {
    var tracked = TrackingAllocator.init(std.testing.allocator);
    tracked.force_moving_growth = true;
    const a = tracked.allocator();
    var bytes = try a.dupe(u8, "12345678");
    bytes = try a.realloc(bytes, 16);
    try std.testing.expectEqualSlices(u8, "12345678", bytes[0..8]);
    try std.testing.expectEqual(@as(usize, 24), tracked.peak);
    try std.testing.expectEqual(@as(usize, 8), tracked.peak_before);
    try std.testing.expectEqual(@as(usize, 16), tracked.peak_request);
    try std.testing.expectEqual(TrackingAllocator.Operation.allocate, tracked.peak_operation);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    tracked.force_copy_reallocation = true;
    bytes = try a.dupe(u8, "12345678");
    tracked.beginMeasurement();
    bytes = try a.realloc(bytes, 4);
    try std.testing.expectEqualSlices(u8, "1234", bytes);
    try std.testing.expectEqual(@as(usize, 12), tracked.peak);
    try std.testing.expectEqual(@as(usize, 4), tracked.live);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
}

test "Zstd stream counters independent failed allocation resize and remap preserve live bytes and old content" {
    var storage: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var tracked = TrackingAllocator.init(fixed.allocator());
    const a = tracked.allocator();
    var bytes = try a.dupe(u8, "12345678");
    tracked.fail_resize_after = tracked.resize_attempts;
    try std.testing.expect(!a.resize(bytes, 16));
    tracked.fail_remap_after = tracked.remap_attempts;
    try std.testing.expect(a.remap(bytes, 16) == null);
    tracked.fail_alloc_after = tracked.alloc_attempts;
    try std.testing.expectError(error.OutOfMemory, a.realloc(bytes, 16));
    try std.testing.expectEqualSlices(u8, "12345678", bytes);
    try std.testing.expectEqual(@as(usize, 8), tracked.live);
    try std.testing.expectEqual(@as(usize, 8), tracked.peak);
    tracked.clearFailures();
    bytes = a.remap(bytes, 16) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 16), tracked.live);
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    try std.testing.expect(tracked.forced_failures >= 3);
}

test "Zstd stream counters independent tracker excludes one borrowed identity but counts its moving replacement" {
    var tracked = TrackingAllocator.init(std.testing.allocator);
    tracked.force_moving_growth = true;
    const a = tracked.allocator();
    var bytes = try a.dupe(u8, "12345678");
    tracked.excludeInitialAllocation(bytes);
    tracked.beginMeasurement();
    try std.testing.expectEqual(@as(usize, 0), tracked.ownedLive());
    bytes = try a.realloc(bytes, 16);
    try std.testing.expectEqual(@as(usize, 24), tracked.peak);
    try std.testing.expectEqual(@as(usize, 16), tracked.owned_peak);
    try std.testing.expectEqual(@as(usize, 16), tracked.ownedLive());
    a.free(bytes);
    try std.testing.expectEqual(@as(usize, 0), tracked.live);
    var storage: [256]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&storage);
    var shrinking = TrackingAllocator.init(fixed.allocator());
    const shrink_a = shrinking.allocator();
    var borrowed = try shrink_a.alloc(u8, 16);
    shrinking.excludeInitialAllocation(borrowed);
    try std.testing.expect(shrink_a.resize(borrowed, 8));
    borrowed = borrowed.ptr[0..8];
    try std.testing.expectEqual(@as(usize, 0), shrinking.ownedLive());
    try std.testing.expectEqual(@as(usize, 0), shrinking.owned_peak);
    shrink_a.free(borrowed);
    try std.testing.expectEqual(@as(usize, 0), shrinking.live);
}

// Captured from isolated dacd500a and decoded through both old input policies.
pub const Wire = enum { rle_single, empty_single, structured_single, rle_incremental_exact, rle_incremental_unknown, dictionary_incremental_exact };
pub const Frozen = struct { name: Wire, hex: []const u8 };
pub const frozen_wires = [_]Frozen{
    .{ .name = .rle_single, .hex = "28b52ffd60000103100052" },
    .{ .name = .empty_single, .hex = "28b52ffd2000010000" },
    .{ .name = .structured_single, .hex = "28b52ffd20bc5d0100f85a7374642073747265616d20636f756e74657273206162636465666768580a03000aa9286321a211c509" },
    .{ .name = .rle_incremental_exact, .hex = "28b52ffd60000102040052020400520204005203040052" },
    .{ .name = .rle_incremental_unknown, .hex = "28b52ffd006802040052020400520204005203040052" },
    .{ .name = .dictionary_incremental_exact, .hex = "28b52ffd212abc3c00000001005da60a083d000000015000059152" },
};

pub fn frozenAlloc(a: std.mem.Allocator, name: Wire) ![]u8 {
    for (frozen_wires) |sample| if (sample.name == name) {
        const bytes = try a.alloc(u8, sample.hex.len / 2);
        errdefer a.free(bytes);
        _ = try std.fmt.hexToBytes(bytes, sample.hex);
        return bytes;
    };
    unreachable;
}

// Separate checksum=true capture from the same archived baseline; old six rows untouched.
pub const checksum_rle_hex = "28b52ffd64000103100052e02deac3";

pub fn checksumWireAlloc(a: std.mem.Allocator) ![]u8 {
    const bytes = try a.alloc(u8, checksum_rle_hex.len / 2);
    errdefer a.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, checksum_rle_hex);
    return bytes;
}
