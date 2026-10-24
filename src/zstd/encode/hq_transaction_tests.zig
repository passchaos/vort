const std = @import("std");
const zstd = @import("../../zstd.zig");
const alias = @import("controlled_alias.zig");
const helper = @import("hq_test_helpers.zig");

const MovingPoison = struct {
    backing: std.mem.Allocator,
    pub fn allocator(self: *MovingPoison) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, n: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *MovingPoison = @ptrCast(@alignCast(raw));
        return self.backing.rawAlloc(n, alignment, ret);
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *MovingPoison = @ptrCast(@alignCast(raw));
        @memset(bytes, 0xa5);
        self.backing.rawFree(bytes, alignment, ret);
    }
};

test "Zstd HQ transaction moving poison append preserves original aliased input" {
    const storage = try std.testing.allocator.alloc(u8, 4 * 1024 * 1024);
    defer std.testing.allocator.free(storage);
    var fixed = std.heap.FixedBufferAllocator.init(storage);
    var moving: MovingPoison = .{ .backing = fixed.allocator() };
    const allocator = moving.allocator();
    const input = "ABCD" ** 64;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.ensureTotalCapacityPrecise(allocator, input.len);
    out.appendSliceAssumeCapacity(input);
    _ = try zstd.encodeNativeFrameAppend(allocator, &out, out.items, .{ .strategy = .btopt, .content_checksum = false });
    const decoded = try zstd.decodeNativeFrameAlloc(std.testing.allocator, out.items[input.len..]);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

const ChecksumGate = struct {
    backing: std.mem.Allocator,
    pending: ?*std.ArrayList(u8) = null,
    armed: bool = false,
    rejected: bool = false,
    pub fn allocator(self: *ChecksumGate) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, n: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *ChecksumGate = @ptrCast(@alignCast(raw));
        if (self.armed) if (self.pending) |pending| {
            if (pending.items.len == 104) {
                self.armed = false;
                self.rejected = true;
                return null;
            }
        };
        return self.backing.rawAlloc(n, alignment, ret);
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *ChecksumGate = @ptrCast(@alignCast(raw));
        self.backing.rawFree(bytes, alignment, ret);
    }
};

test "Zstd HQ transaction checksum-only OOM retains final block and codec state" {
    var gate: ChecksumGate = .{ .backing = std.testing.allocator };
    var profile: zstd.EncoderControlProfile = .{};
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(gate.allocator(), .{ .strategy = .btopt, .content_checksum = true, .control_profile = &profile }, 101);
    defer encoder.deinit();
    gate.pending = &encoder.pending;
    var input: [101]u8 = undefined;
    for (&input, 0..) |*byte, index| byte.* = @intCast(index);
    var output: [256]u8 = undefined;
    const initial = try encoder.step(&input, &output);
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try frame.appendSlice(std.testing.allocator, output[0..initial.progress.output_written]);
    encoder.pending.deinit(gate.allocator());
    encoder.pending = .empty;
    try encoder.pending.ensureTotalCapacityPrecise(gate.allocator(), 104);
    const previous_state = encoder.codec_state;
    const previous_emitted = profile.emitted();
    const before = encoder.snapshot();
    encoder.finish();
    gate.armed = true;
    @memset(&output, 0xa5);
    try std.testing.expectError(error.OutOfMemory, encoder.step("", &output));
    try std.testing.expect(gate.rejected);
    try std.testing.expectEqual(@as(usize, input.len), encoder.block.items.len);
    try std.testing.expectEqualDeep(previous_state, encoder.codec_state);
    try std.testing.expectEqualDeep(previous_emitted, profile.emitted());
    try std.testing.expectEqual(@as(usize, 0), encoder.pending.items.len);
    try std.testing.expectEqual(before.input_read, encoder.snapshot().input_read);
    try std.testing.expectEqual(before.output_written, encoder.snapshot().output_written);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    const remainder = try helper.driveEncoder(std.testing.allocator, &encoder, &input, 1, 7, null);
    defer std.testing.allocator.free(remainder);
    try frame.appendSlice(std.testing.allocator, remainder);
    var options = encoder.options;
    options.control_profile = null;
    const expected = try zstd.encodeNativeFrameWithOptionsAlloc(std.testing.allocator, &input, options);
    defer std.testing.allocator.free(expected.frame);
    try std.testing.expectEqualSlices(u8, expected.frame, frame.items);
    try std.testing.expectEqual(@as(u64, 1), profile.raw_blocks);
    try std.testing.expect(encoder.done and encoder.final_written);
    const decoded = try zstd.decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
    // No checksum means no checksum allocation to deny at the same checkpoint.
    var no_crc_gate: ChecksumGate = .{ .backing = std.testing.allocator };
    var no_crc = try zstd.NativeIncrementalFrameEncoder.initExactSize(no_crc_gate.allocator(), .{ .strategy = .btopt, .content_checksum = false }, input.len);
    defer no_crc.deinit();
    no_crc_gate.pending = &no_crc.pending;
    _ = try no_crc.step(&input, &output);
    no_crc.pending.deinit(no_crc_gate.allocator());
    no_crc.pending = .empty;
    try no_crc.pending.ensureTotalCapacityPrecise(no_crc_gate.allocator(), 104);
    no_crc.finish();
    no_crc_gate.armed = true;
    _ = try no_crc.step("", &output);
    try std.testing.expect(!no_crc_gate.rejected and no_crc.done);
}

test "Zstd HQ transaction raw dictionary borrowed from moving output remains valid" {
    const storage = try std.testing.allocator.alloc(u8, 4 * 1024 * 1024);
    defer std.testing.allocator.free(storage);
    var fixed = std.heap.FixedBufferAllocator.init(storage);
    var moving: MovingPoison = .{ .backing = fixed.allocator() };
    const allocator = moving.allocator();
    var content: [64]u8 = undefined;
    for (&content, 0..) |*byte, index| byte.* = @intCast(index);
    const input = [_]u8{0xa5} ** 12 ++ [_]u8{'Y'} ++ [_]u8{0xa5} ** 12 ++ [_]u8{'Z'};
    const original = zstd.NativeDictionary.init(93, &content);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.ensureTotalCapacityPrecise(allocator, content.len);
    out.appendSliceAssumeCapacity(&content);
    const borrowed = zstd.NativeDictionary.init(93, out.items);
    _ = try zstd.encodeNativeFrameAppendWithDictionary(allocator, &out, &input, .{ .strategy = .btopt, .content_checksum = false }, borrowed);
    const decoded = try zstd.decodeNativeFrameAllocWithDictionary(std.testing.allocator, out.items[content.len..], original);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "Zstd HQ transaction full dictionary borrowed from moving output remains valid" {
    const full = try helper.fullDictionary(std.testing.allocator);
    defer std.testing.allocator.free(full);
    const original = (try zstd.NativeDictionary.initFromStandardDictionary(full)).dictionary;
    const storage = try std.testing.allocator.alloc(u8, 4 * 1024 * 1024);
    defer std.testing.allocator.free(storage);
    var fixed = std.heap.FixedBufferAllocator.init(storage);
    var moving: MovingPoison = .{ .backing = fixed.allocator() };
    const allocator = moving.allocator();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.ensureTotalCapacityPrecise(allocator, full.len);
    out.appendSliceAssumeCapacity(full);
    const borrowed = (try zstd.NativeDictionary.initFromStandardDictionary(out.items)).dictionary;
    _ = try zstd.encodeNativeFrameAppendWithDictionary(allocator, &out, helper.positive_ll_plain, .{ .strategy = .btopt, .content_checksum = false }, borrowed);
    const decoded = try zstd.decodeNativeFrameAllocWithDictionary(std.testing.allocator, out.items[full.len..], original);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, helper.positive_ll_plain, decoded);
}

test "Zstd HQ transaction snapshot copies only aliases and preserves validation and OOM" {
    const allocator = std.testing.allocator;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.ensureTotalCapacityPrecise(allocator, 256);
    output.appendSliceAssumeCapacity("prior-output");
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    const source = "independent plaintext";
    const preserved = try alias.preserve(failing.allocator(), source, &output);
    defer preserved.deinit(failing.allocator());
    try std.testing.expect(preserved.owned == null);
    try std.testing.expectEqual(source.ptr, preserved.bytes.ptr);
    const raw = zstd.NativeDictionary.init(93, source);
    const raw_snapshot = try alias.preserveDictionary(zstd.NativeDictionary, failing.allocator(), raw, &output);
    defer raw_snapshot.deinit(failing.allocator());
    try std.testing.expect(raw_snapshot.owned == null);
    try std.testing.expectEqual(raw.content.ptr, raw_snapshot.dictionary.?.content.ptr);
    const full = try helper.fullDictionary(allocator);
    defer allocator.free(full);
    const standard = (try zstd.NativeDictionary.initFromStandardDictionary(full)).dictionary;
    const full_snapshot = try alias.preserveDictionary(zstd.NativeDictionary, failing.allocator(), standard, &output);
    defer full_snapshot.deinit(failing.allocator());
    try std.testing.expect(full_snapshot.owned == null);
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
    // Initialized spare capacity participates in alias detection.
    @memset(output.items.ptr[64..96], 0xa5);
    const borrowed = output.items.ptr[64..96];
    try std.testing.expectError(error.OutOfMemory, alias.preserve(failing.allocator(), borrowed, &output));
    try std.testing.expectEqualSlices(u8, "prior-output", output.items);
    const invalid = zstd.NativeFrameOptions{ .strategy = .btopt, .hq = .{ .search_depth = 0 } };
    try std.testing.expectError(error.InvalidBlockPlan, zstd.encodeNativeFrameAppend(failing.allocator(), &output, output.items, invalid));
    try std.testing.expectEqualSlices(u8, "prior-output", output.items);
}
