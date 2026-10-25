//! Public container contracts for explicitly selected magicless Zstd frames.
//! The supplied root owns module wiring; this file never imports it recursively.
const std = @import("std");
const a = std.testing.allocator;

pub fn contracts(comptime V: type) !void {
    try publicTypes(V);
    try zfsWireAndBounds(V);
    try zfsBorrowedDecode(V);
    try zipFormatAdmission(V);
    try archiveFormatAdmission(V);
    try seekableFormatAdmission(V);
}

fn publicTypes(comptime V: type) !void {
    try std.testing.expect(V.ZstdFrameFormat == V.zstd.FrameFormat);
    try std.testing.expect(V.ZstdFrameDecodeOptions == V.zstd.FrameDecodeOptions);
    const options: V.ZstdFrameDecodeOptions = .{ .format = .magicless, .expected_output_len = 0, .max_output_len = 0 };
    try options.validate();
    try std.testing.expectEqual(V.ZstdFrameFormat.magicless, options.format);
    try std.testing.expectEqual(V.ZstdFrameFormat.standard, (@as(V.zstd.FrameOptions, .{})).format);
    try std.testing.expectEqual(V.ZstdFrameFormat.standard, (@as(V.zstd.NativeFrameOptions, .{})).format);
}

/// Reconstruct the former ZFS representation from a real standard frame.
/// No magicless encoder or ZFS writer is used to construct this expected wire.
fn oldZfsWire(comptime V: type, input: []const u8, level: c_int) ![]u8 {
    const frame = try V.zstd.encodeFrameWithLevelAndOptionsAlloc(a, input, level, .{
        .format = .standard,
        .include_content_size = false,
        .content_checksum = false,
    });
    defer a.free(frame);
    try std.testing.expect(frame.len >= 4);
    try std.testing.expectEqualSlices(u8, &.{ 0x28, 0xb5, 0x2f, 0xfd }, frame[0..4]);
    const result = try a.alloc(u8, 8 + frame.len - 4);
    errdefer a.free(result);
    std.mem.writeInt(u32, result[0..4], @intCast(frame.len - 4), .big);
    const wire_level: u8 = if (level == -1) 103 else @intCast(level);
    std.mem.writeInt(u32, result[4..8], (@as(u32, wire_level) << 24) | 10507, .big);
    @memcpy(result[8..], frame[4..]);
    return result;
}

fn fillRandom(bytes: []u8) void {
    var state: u32 = 0x6535_2026;
    for (bytes) |*byte| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate(state >> 24);
    }
}

fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn zfsWireAndBounds(comptime V: type) !void {
    const repetitive = "ZFS magicless retains the historical frame body\n" ** 24;
    var random: [513]u8 = undefined;
    fillRandom(&random);
    const cases = [_][]const u8{ "", "x", "tiny", random[0..255], &random, repetitive };
    for ([_]c_int{ 1, -1 }) |level| {
        for (cases) |input| {
            const expected = try oldZfsWire(V, input, level);
            defer a.free(expected);
            const metadata = try V.zfs.parseZstdMetadata(expected);
            try std.testing.expectEqual(expected.len - 8, metadata.compressed_size);
            try std.testing.expectEqual(@as(u8, if (level == -1) 103 else 1), metadata.level);
            try std.testing.expectEqual(@as(u32, 10507), metadata.version);
            const header = try V.zstdInspectNativeFrameHeaderWithFormat(expected[8..], .magicless);
            try std.testing.expect(header.content_size == null);
            try std.testing.expect(!header.has_checksum);
            try std.testing.expectEqual(@as(u32, 0), header.dictionary_id);
            const first = try V.zstdInspectNativeFrameFirstBlockWithFormat(expected[8..], .magicless);
            try std.testing.expectEqual(header.payload_offset, first.header_offset);
            try std.testing.expectEqual(first.header_offset + 3, first.payload_offset);
            const same = try V.zstdInspectNativeFrameBlockAtWithFormat(expected[8..], first.header_offset, .magicless);
            try std.testing.expectEqualDeep(first, same);
            const decoded = try V.zfs.decodeBlockAllocExactSize(a, .zstd, expected, input.len);
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
            if (input.len == 0) {
                try std.testing.expectError(error.InvalidZfsBlock, V.zfs.encodeBlockAlloc(a, .zstd, input, .{ .zstd_level = level }));
            } else if (expected.len >= input.len) {
                try std.testing.expectError(error.IncompressibleZfsBlock, V.zfs.encodeBlockAlloc(a, .zstd, input, .{ .zstd_level = level }));
            } else {
                const actual = try V.zfs.encodeBlockAlloc(a, .zstd, input, .{ .zstd_level = level });
                defer a.free(actual);
                try std.testing.expectEqualSlices(u8, expected, actual);
            }
        }
    }

    const expected = try oldZfsWire(V, repetitive, -1);
    defer a.free(expected);
    const padded = try a.alloc(u8, expected.len + 512);
    defer a.free(padded);
    @memcpy(padded[0..expected.len], expected);
    @memset(padded[expected.len..], 0xa5);
    const padding_before = padded[expected.len..][0..512].*;
    const decoded = try V.zfs.decodeBlockAllocExactSize(a, .zstd, padded, repetitive.len);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, repetitive, decoded);
    try std.testing.expectEqualSlices(u8, &padding_before, padded[expected.len..]);
    try std.testing.expectError(error.SizeMismatch, V.zfs.decodeBlockAllocExactSize(a, .zstd, expected, repetitive.len + 1));
    try std.testing.expectError(error.OutputLimitExceeded, V.zfs.decodeBlockAllocExactSize(a, .zstd, expected, repetitive.len - 1));
    try std.testing.expectError(error.TruncatedFrame, V.zfs.decodeBlockAllocExactSize(a, .zstd, expected[0..7], repetitive.len));

    const corrupt = try a.dupe(u8, expected);
    defer a.free(corrupt);
    corrupt[8] |= 0x08; // Reserved frame-descriptor bit, independent of block coding.
    try std.testing.expectError(error.CorruptFrame, V.zfs.decodeBlockAllocExactSize(a, .zstd, corrupt, repetitive.len));
    @memcpy(corrupt, expected);
    std.mem.writeInt(u32, corrupt[0..4], @intCast(expected.len - 7), .big);
    try std.testing.expectError(error.InvalidZfsBlock, V.zfs.decodeBlockAllocExactSize(a, .zstd, corrupt, repetitive.len));

    var output: [repetitive.len + 8]u8 = @splat(0xa5);
    const options: V.ZstdFrameDecodeOptions = .{ .format = .magicless, .expected_output_len = repetitive.len, .max_output_len = repetitive.len };
    try std.testing.expectEqual(repetitive.len, try V.zstdDecodeFrameIntoWithOptions(a, expected[8..], &output, options));
    try std.testing.expectEqualSlices(u8, repetitive, output[0..repetitive.len]);
    try untouched(output[repetitive.len..]);
    @memset(&output, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, V.zstdDecodeFrameIntoWithOptions(a, expected[8..], output[0 .. repetitive.len - 1], options));
    try untouched(&output);
    try std.testing.expectEqual(repetitive.len, try V.zstdDecodedFrameSizeWithOptions(expected[8..], options));
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(a);
    try appended.appendSlice(a, "old-prefix|");
    try std.testing.expectError(error.OutputLimitExceeded, V.zstdDecodeFrameAppendWithOptions(a, &appended, expected[8..], .{ .format = .magicless, .max_output_len = repetitive.len - 1 }));
    try std.testing.expectEqualStrings("old-prefix|", appended.items);
    try std.testing.expectEqual(repetitive.len, try V.zstdDecodeFrameAppendWithOptions(a, &appended, expected[8..], options));
    try std.testing.expectEqualSlices(u8, repetitive, appended.items["old-prefix|".len..]);
}

/// Observe allocation requests, not implementation-specific entropy workspace.
/// An obsolete compressed-body-plus-magic allocation is refused independently.
const RequestLedger = struct {
    backing: std.mem.Allocator,
    forbidden: usize,
    decoded_size: usize,
    forbidden_requests: usize = 0,
    decoded_requests: usize = 0,
    live: usize = 0,

    fn allocator(self: *RequestLedger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *RequestLedger = @ptrCast(@alignCast(context));
        if (len == self.forbidden) {
            self.forbidden_requests += 1;
            return null;
        }
        const result = self.backing.rawAlloc(len, alignment, address) orelse return null;
        self.live += len;
        if (len == self.decoded_size) self.decoded_requests += 1;
        return result;
    }
    fn resize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }
    fn remap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }
    fn free(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *RequestLedger = @ptrCast(@alignCast(context));
        self.backing.rawFree(memory, alignment, address);
        self.live -= memory.len;
    }
};

fn zfsBorrowedDecode(comptime V: type) !void {
    const input = "borrowed ZFS compressed wire needs decoded storage only\n" ** 19;
    const wire = try oldZfsWire(V, input, -1);
    defer a.free(wire);
    const before = try a.dupe(u8, wire);
    defer a.free(before);
    const metadata = try V.zfs.parseZstdMetadata(wire);
    var ledger: RequestLedger = .{ .backing = a, .forbidden = metadata.compressed_size + 4, .decoded_size = input.len };
    try std.testing.expect(ledger.forbidden != input.len);
    const allocator = ledger.allocator();
    {
        const decoded = try V.zfs.decodeBlockAllocExactSize(allocator, .zstd, wire, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        try std.testing.expectEqualSlices(u8, before, wire);
        try std.testing.expectEqual(@as(usize, 0), ledger.forbidden_requests);
        try std.testing.expect(ledger.decoded_requests != 0);
        try std.testing.expectEqual(input.len, ledger.live);
    }
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
}

fn zipFormatAdmission(comptime V: type) !void {
    for ([_]V.zip.CompressionMethod{ .zstandard, .zstandard_legacy }) |method| {
        const entries = [_]V.zip.writer.EncodeEntry{.{ .name = "magicless.bin", .data = "zip frame", .method = method }};
        var heap = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(a);
        try output.appendSlice(a, "caller-prefix|");
        const pointer = output.items.ptr;
        const capacity = output.capacity;
        try std.testing.expectError(error.InvalidBlockPlan, V.zipEncodeAppend(heap.allocator(), &output, &entries, .{ .zstd_options = .{ .format = .magicless } }));
        try std.testing.expectEqualStrings("caller-prefix|", output.items);
        try std.testing.expectEqual(pointer, output.items.ptr);
        try std.testing.expectEqual(capacity, output.capacity);
        try std.testing.expectEqual(@as(usize, 0), heap.alloc_index);
        try std.testing.expect(!heap.has_induced_failure);

        var incremental_heap = std.testing.FailingAllocator.init(a, .{});
        var writer = try V.zip.IncrementalWriter.initWithOptions(incremental_heap.allocator(), .{ .zstd_options = .{ .format = .magicless } });
        defer writer.deinit();
        const before = writer.snapshot();
        const allocations = incremental_heap.alloc_index;
        incremental_heap.fail_index = allocations;
        try std.testing.expectError(error.InvalidBlockPlan, writer.beginEntry(.{ .name = "magicless.bin", .method = method }));
        try std.testing.expectEqualDeep(before, writer.snapshot());
        try std.testing.expectEqual(V.zip.IncrementalWriterPhase.ready, writer.snapshot().phase);
        try std.testing.expectEqual(allocations, incremental_heap.alloc_index);
        try std.testing.expect(!incremental_heap.has_induced_failure);
    }
    const stored = [_]V.zip.writer.EncodeEntry{.{ .name = "stored.bin", .data = "unused Zstd controls", .method = .stored }};
    const ordinary = try V.zipEncodeAlloc(a, &stored, .{});
    defer a.free(ordinary);
    const ignored = try V.zipEncodeAlloc(a, &stored, .{ .zstd_options = .{ .format = .magicless } });
    defer a.free(ignored);
    try std.testing.expectEqualSlices(u8, ordinary, ignored);
    var writer = try V.zip.IncrementalWriter.initWithOptions(a, .{ .zstd_options = .{ .format = .magicless } });
    defer writer.deinit();
    try writer.beginEntry(.{ .name = "stored.bin", .method = .stored });
}

fn archiveFormatAdmission(comptime V: type) !void {
    var heap = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidBlockPlan, V.tar.encodeCompressedAlloc(heap.allocator(), &.{}, .{ .compression = .zstandard, .zstd_options = .{ .format = .magicless } }));
    try std.testing.expectError(error.InvalidBlockPlan, V.cpio.encodeCompressedAlloc(heap.allocator(), &.{}, .{ .compression = .zstandard, .zstd_options = .{ .format = .magicless } }));
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(a);
    try output.appendSlice(a, "archive-prefix|");
    try std.testing.expectError(error.InvalidBlockPlan, V.tar.encodeCompressedAppend(heap.allocator(), &output, &.{}, .{ .compression = .zstandard, .zstd_options = .{ .format = .magicless } }));
    try std.testing.expectError(error.InvalidBlockPlan, V.cpio.encodeCompressedAppend(heap.allocator(), &output, &.{}, .{ .compression = .zstandard, .zstd_options = .{ .format = .magicless } }));
    try std.testing.expectEqualStrings("archive-prefix|", output.items);
    try std.testing.expectEqual(@as(usize, 0), heap.alloc_index);
    try std.testing.expect(!heap.has_induced_failure);

    const tar_ordinary = try V.tar.encodeCompressedAlloc(a, &.{}, .{});
    defer a.free(tar_ordinary);
    const tar_ignored = try V.tar.encodeCompressedAlloc(a, &.{}, .{ .compression = .none, .zstd_options = .{ .format = .magicless } });
    defer a.free(tar_ignored);
    try std.testing.expectEqualSlices(u8, tar_ordinary, tar_ignored);
    const cpio_ordinary = try V.cpio.encodeCompressedAlloc(a, &.{}, .{});
    defer a.free(cpio_ordinary);
    const cpio_ignored = try V.cpio.encodeCompressedAlloc(a, &.{}, .{ .compression = .none, .zstd_options = .{ .format = .magicless } });
    defer a.free(cpio_ignored);
    try std.testing.expectEqualSlices(u8, cpio_ordinary, cpio_ignored);
}

fn seekableFormatAdmission(comptime V: type) !void {
    const options: V.ZstdNativeSeekableOptions = .{ .frame_options = .{ .format = .magicless } };
    var heap = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidBlockPlan, V.zstdEncodeNativeSeekableStreamAlloc(heap.allocator(), "xy", options));
    try std.testing.expectError(error.InvalidBlockPlan, V.zstdEncodedNativeSeekableStreamBound(2, options));
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(a);
    try output.appendSlice(a, "seek-prefix|");
    try std.testing.expectError(error.InvalidBlockPlan, V.zstdEncodeNativeSeekableStreamAppend(heap.allocator(), &output, "xy", options));
    try std.testing.expectEqualStrings("seek-prefix|", output.items);
    try std.testing.expectEqual(@as(usize, 0), heap.alloc_index);
    try std.testing.expect(!heap.has_induced_failure);
}
