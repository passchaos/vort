//! Independent wire token inspection and public one-shot ownership contracts.
const std = @import("std");
const decoder = @import("decoder.zig");
const stream = @import("stream_encoder.zig");
const candidate = @import("one_shot.zig");

const Reader = struct {
    input: []const u8,
    position: usize = 0,
    fn bits(self: *Reader, count: u6) !u32 {
        if (@as(u128, self.position) + count > @as(u128, self.input.len) * 8) return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..count) |index| {
            const absolute = self.position + index;
            const bit: u32 = (self.input[absolute / 8] >> @as(u3, @intCast(absolute % 8))) & 1;
            value |= bit << @as(u5, @intCast(index));
        }
        self.position += count;
        return value;
    }
    fn symbol(self: *Reader) !u16 {
        var value: u16 = 0;
        for (1..10) |width| {
            value = (value << 1) | @as(u16, @intCast(try self.bits(1)));
            if (width == 7 and value <= 23) return 256 + value;
            if (width == 8) {
                if (value >= 48 and value <= 191) return value - 48;
                if (value >= 192 and value <= 199) return 280 + value - 192;
            }
            if (width == 9 and value >= 400 and value <= 511) return 144 + value - 400;
        }
        return error.InvalidHuffmanCode;
    }
};
const Token = struct { position: usize, length_code: u16, length: usize, distance_code: u16, distance: usize };
const Tokens = struct {
    matches: std.ArrayList(Token) = .empty,
    literals: usize = 0,
    produced: usize = 0,
    fixed_blocks: usize = 0,
    stored_blocks: usize = 0,
    fn deinit(self: *Tokens) void {
        self.matches.deinit(std.testing.allocator);
    }
};

fn inspect(input: []const u8) !Tokens {
    var reader: Reader = .{ .input = input };
    var result: Tokens = .{};
    errdefer result.deinit();
    while (true) {
        const final = try reader.bits(1) != 0;
        switch (try reader.bits(2)) {
            0 => {
                result.stored_blocks += 1;
                reader.position += (8 - reader.position % 8) % 8;
                const count: u16 = @intCast(try reader.bits(16));
                const complement: u16 = @intCast(try reader.bits(16));
                try std.testing.expectEqual(@as(u16, ~count), complement);
                for (0..count) |_| _ = try reader.bits(8);
                result.produced += count;
            },
            1 => {
                result.fixed_blocks += 1;
                while (true) {
                    const code = try reader.symbol();
                    if (code < 256) {
                        result.literals += 1;
                        result.produced += 1;
                        continue;
                    }
                    if (code == 256) break;
                    if (code > 285) return error.InvalidHuffmanCode;
                    const length: usize = if (code <= 264)
                        code - 254
                    else if (code == 285)
                        3 + @as(usize, try reader.bits(16))
                    else blk: {
                        const width: u6 = @intCast((code - 265) / 4 + 1);
                        const slot: usize = (code - 265) % 4;
                        const base = (@as(usize, 1) << @intCast(width + 2)) + 3 + slot * (@as(usize, 1) << @intCast(width));
                        break :blk base + try reader.bits(width);
                    };
                    var distance_code: u16 = 0;
                    for (0..5) |_| distance_code = (distance_code << 1) | @as(u16, @intCast(try reader.bits(1)));
                    const distance: usize = if (distance_code < 4)
                        distance_code + 1
                    else blk: {
                        const width: u6 = @intCast(distance_code / 2 - 1);
                        const base = ((2 + @as(usize, distance_code & 1)) << @intCast(width)) + 1;
                        break :blk base + try reader.bits(width);
                    };
                    try std.testing.expect(distance <= result.produced and distance <= 65536);
                    try result.matches.append(std.testing.allocator, .{ .position = result.produced, .length_code = code, .length = length, .distance_code = distance_code, .distance = distance });
                    result.produced += length;
                }
            },
            else => return error.InvalidDeflateBlockType,
        }
        if (final) break;
    }
    try std.testing.expectEqual(input.len, reader.position / 8 + @intFromBool(reader.position % 8 != 0));
    return result;
}

fn roundTrip(wire: []const u8, input: []const u8) !void {
    var tokens = try inspect(wire);
    defer tokens.deinit();
    try std.testing.expectEqual(input.len, tokens.produced);
    const output = try decoder.decodeAlloc(std.testing.allocator, wire);
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualSlices(u8, input, output);
}

fn fixedStream(input: []const u8, options: anytype) ![]u8 {
    var encoder = stream.Encoder.initExactSize(std.testing.allocator, .{ .compression = .fixed, .block_len = 131072, .max_chain = options.max_chain, .nice_length = options.nice_length }, input.len);
    defer encoder.deinit();
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(std.testing.allocator);
    var scratch: [521]u8 = undefined;
    var offset: usize = 0;
    var finishing = false;
    for (0..input.len * 2 + 4096) |_| {
        if (offset == input.len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        const result = try encoder.step(input[offset..], &scratch);
        offset += result.progress.input_read;
        try output.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) return output.toOwnedSlice(std.testing.allocator);
    }
    return error.TestUnexpectedResult;
}

fn fill(input: []u8, seed: u32) void {
    var state = seed;
    for (input) |*byte| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate(state >> 24);
    }
}
fn untouched(input: []const u8) !void {
    for (input) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn boundAndWire(comptime Codec: type, input: []const u8, options: Codec.EncodeOptions) !void {
    const a = std.testing.allocator;
    const before = try a.dupe(u8, input);
    defer a.free(before);
    const wire = try Codec.encodeAlloc(a, input, options);
    defer a.free(wire);
    const block_count: usize = if (input.len == 0) 1 else input.len / 65535 + @intFromBool(input.len % 65535 != 0);
    try std.testing.expectEqual(input.len + block_count * 5, try Codec.encodedBound(input.len));
    try std.testing.expect(wire.len <= try Codec.encodedBound(input.len));
    try std.testing.expectEqualSlices(u8, before, input);
    try roundTrip(wire, input);
    if (options.nice_length >= 3) {
        const fixed = try fixedStream(input, options);
        defer a.free(fixed);
        if (fixed.len < try Codec.encodedBound(input.len)) {
            try std.testing.expectEqualSlices(u8, fixed, wire);
        } else {
            const stored = try a.alloc(u8, try Codec.encodedBound(input.len));
            defer a.free(stored);
            _ = try Codec.encodeStoredInto(input, stored);
            try std.testing.expectEqualSlices(u8, stored, wire);
        }
    }
}

fn fullRange(comptime Codec: type) !void {
    for ([_][]const u8{ "", "x", "abc", "one-shot Deflate64 ownership and bounded matching\n" ** 24 }) |input|
        try boundAndWire(Codec, input, .{});
    const a = std.testing.allocator;
    const input = try a.alloc(u8, 2 * 131072 + 17);
    defer a.free(input);
    fill(input, 0x243f6a88);
    try boundAndWire(Codec, input, .{});
    try boundAndWire(Codec, input[0..4097], .{ .nice_length = 0 });
    @memset(input, 'R');
    try boundAndWire(Codec, input, .{ .nice_length = 65538 });
    const long = try Codec.encodeAlloc(a, input[0..65539], .{});
    defer a.free(long);
    var tokens = try inspect(long);
    defer tokens.deinit();
    try std.testing.expectEqual(@as(usize, 1), tokens.literals);
    try std.testing.expectEqual(@as(usize, 1), tokens.matches.items.len);
    try std.testing.expectEqual(@as(u16, 285), tokens.matches.items[0].length_code);
    try std.testing.expectEqual(@as(usize, 65538), tokens.matches.items[0].length);
    const short = try Codec.encodeAlloc(a, input[0..259], .{});
    defer a.free(short);
    var short_tokens = try inspect(short);
    defer short_tokens.deinit();
    try std.testing.expectEqual(@as(usize, 1), short_tokens.matches.items.len);
    try std.testing.expectEqual(@as(u16, 284), short_tokens.matches.items[0].length_code);
    try std.testing.expectEqual(@as(usize, 258), short_tokens.matches.items[0].length);
    fill(input[0..65536], 0x243f6a88);
    @memcpy(input[65536..131072], input[0..65536]);
    const distant = try Codec.encodeAlloc(a, input[0..131072], .{ .nice_length = 65538 });
    defer a.free(distant);
    var distant_tokens = try inspect(distant);
    defer distant_tokens.deinit();
    var saw_boundary = false;
    for (distant_tokens.matches.items) |token| if (token.distance == 65536) {
        saw_boundary = true;
        try std.testing.expectEqual(@as(u16, 31), token.distance_code);
    };
    try std.testing.expect(saw_boundary);
    try roundTrip(distant, input[0..131072]);
    @memset(input, 'R');
    const literal_only = try Codec.encodeAlloc(a, input, .{ .max_chain = 0 });
    defer a.free(literal_only);
    var literal_tokens = try inspect(literal_only);
    defer literal_tokens.deinit();
    try std.testing.expectEqual(@as(usize, 0), literal_tokens.matches.items.len);
    try roundTrip(literal_only, input);
    try boundAndWire(Codec, input, .{ .max_chain = 0 });
    // Uniform random byte values include 9-bit fixed literals, so this
    // separate no-match candidate is genuinely larger than global stored.
    fill(input, 0x243f6a88);
    const stored_fallback = try Codec.encodeAlloc(a, input, .{ .max_chain = 0 });
    defer a.free(stored_fallback);
    const stored = try a.alloc(u8, try Codec.encodedBound(input.len));
    defer a.free(stored);
    _ = try Codec.encodeStoredInto(input, stored);
    try std.testing.expectEqualSlices(u8, stored, stored_fallback);
}

fn outputAliases(comptime Codec: type) !void {
    const a = std.testing.allocator;
    const input = "Deflate64 append input alias and caller output\n" ** 8;
    const expected = try Codec.encodeAlloc(a, input, .{});
    defer a.free(expected);
    const output = try a.alloc(u8, expected.len + 17);
    defer a.free(output);
    @memset(output, 0xa5);
    try std.testing.expectEqual(expected.len, try Codec.encodeInto(a, input, output, .{}));
    try std.testing.expectEqualSlices(u8, expected, output[0..expected.len]);
    try untouched(output[expected.len..]);
    @memset(output, 0xa5);
    try std.testing.expectEqual(expected.len, try Codec.encodeInto(a, input, output[0..expected.len], .{}));
    try std.testing.expectEqualSlices(u8, expected, output[0..expected.len]);
    try untouched(output[expected.len..]);
    @memset(output, 0xa5);
    try std.testing.expectError(error.OutputTooSmall, Codec.encodeInto(a, input, output[0 .. expected.len - 1], .{}));
    try untouched(output);
    const overlapping = try a.alloc(u8, input.len + 512);
    defer a.free(overlapping);
    @memset(overlapping, 0xa5);
    @memcpy(overlapping[16..][0..input.len], input);
    const untouched_tail = try a.dupe(u8, overlapping[expected.len..]);
    defer a.free(untouched_tail);
    const written = try Codec.encodeInto(a, overlapping[16..][0..input.len], overlapping, .{});
    try std.testing.expectEqualSlices(u8, expected, overlapping[0..written]);
    try std.testing.expectEqualSlices(u8, untouched_tail, overlapping[written..]);
    var heap = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
    var appended = std.ArrayList(u8).fromOwnedSlice(try heap.allocator().dupe(u8, input));
    defer appended.deinit(heap.allocator());
    const original_pointer = appended.items.ptr;
    try std.testing.expectEqual(expected.len, try Codec.encodeAppend(heap.allocator(), &appended, appended.items, .{}));
    try std.testing.expect(appended.items.ptr != original_pointer);
    try std.testing.expectEqualSlices(u8, input, appended.items[0..input.len]);
    try std.testing.expectEqualSlices(u8, expected, appended.items[input.len..]);
    // An allocation refusal occurs while the complete caller input aliases
    // the old destination; neither length nor bytes may be published early.
    var refused = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
    var unchanged = std.ArrayList(u8).fromOwnedSlice(try refused.allocator().dupe(u8, input));
    refused.fail_index = refused.alloc_index;
    const unchanged_pointer = unchanged.items.ptr;
    try std.testing.expectError(error.OutOfMemory, Codec.encodeAppend(refused.allocator(), &unchanged, unchanged.items, .{}));
    try std.testing.expectEqual(unchanged_pointer, unchanged.items.ptr);
    try std.testing.expectEqualSlices(u8, input, unchanged.items);
    unchanged.deinit(refused.allocator());
    try std.testing.expectEqual(refused.allocated_bytes, refused.freed_bytes);
}

fn failures(comptime Codec: type) !void {
    const input = "Deflate64 one-shot failing allocator contract\n" ** 8;
    var baseline = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    const expected = try Codec.encodeAlloc(baseline.allocator(), input, .{});
    baseline.allocator().free(expected);
    try std.testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
    try std.testing.expect(baseline.alloc_index > 0 and baseline.alloc_index < 32);
    for (0..baseline.alloc_index) |failure| {
        var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        try std.testing.expectError(error.OutOfMemory, Codec.encodeAlloc(heap.allocator(), input, .{}));
        try std.testing.expect(heap.has_induced_failure);
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
    }
    var append_baseline = std.testing.FailingAllocator.init(std.testing.allocator, .{ .resize_fail_index = 0 });
    var out = std.ArrayList(u8).fromOwnedSlice(try append_baseline.allocator().dupe(u8, "prefix|"));
    _ = try Codec.encodeAppend(append_baseline.allocator(), &out, input, .{});
    const count = append_baseline.alloc_index;
    out.deinit(append_baseline.allocator());
    try std.testing.expectEqual(append_baseline.allocated_bytes, append_baseline.freed_bytes);
    for (1..count) |failure| {
        var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .resize_fail_index = 0 });
        var output = std.ArrayList(u8).fromOwnedSlice(try heap.allocator().dupe(u8, "prefix|"));
        const pointer = output.items.ptr;
        heap.fail_index = failure;
        try std.testing.expectError(error.OutOfMemory, Codec.encodeAppend(heap.allocator(), &output, input, .{}));
        try std.testing.expectEqual(pointer, output.items.ptr);
        try std.testing.expectEqualSlices(u8, "prefix|", output.items);
        try std.testing.expectEqual(@as(usize, 7), output.capacity);
        try std.testing.expectEqual(@as(usize, 7), heap.allocated_bytes - heap.freed_bytes);
        output.deinit(heap.allocator());
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
    }
    var refusing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var destination: [512]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutOfMemory, Codec.encodeInto(refusing.allocator(), input, &destination, .{}));
    try untouched(&destination);
    const invalid: Codec.EncodeOptions = .{ .nice_length = 65539 };
    var invalid_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidBlockPlan, Codec.encodeAlloc(invalid_heap.allocator(), input, invalid));
    try std.testing.expectError(error.InvalidBlockPlan, Codec.encodeInto(invalid_heap.allocator(), input, &destination, invalid));
    var empty: std.ArrayList(u8) = .empty;
    try std.testing.expectError(error.InvalidBlockPlan, Codec.encodeAppend(invalid_heap.allocator(), &empty, input, invalid));
    try std.testing.expectEqual(@as(usize, 0), invalid_heap.alloc_index);
    try std.testing.expect(!invalid_heap.has_induced_failure);
    try untouched(&destination);
    try std.testing.expectEqual(@as(usize, 0), empty.items.len);
    try std.testing.expectError(error.IntegerOverflow, Codec.encodedBound(std.math.maxInt(usize)));
    for ([_]usize{ 0, 1, 65534, 65535, 65536, 131072, 262161 }) |length| {
        const blocks: u128 = if (length == 0) 1 else @as(u128, length) / 65535 + @intFromBool(length % 65535 != 0);
        try std.testing.expectEqual(@as(usize, @intCast(length + blocks * 5)), try Codec.encodedBound(length));
    }
}

fn candidateGeometry() !void {
    const vectors = [_]struct { bits: u128, stored: usize, expected: ?usize }{
        .{ .bits = 0, .stored = 5, .expected = 0 },
        .{ .bits = 0, .stored = 0, .expected = null },
        .{ .bits = 1, .stored = 3, .expected = 1 },
        .{ .bits = 7, .stored = 3, .expected = 1 },
        .{ .bits = 8, .stored = 3, .expected = 1 },
        .{ .bits = 9, .stored = 3, .expected = 2 },
        .{ .bits = 10, .stored = 5, .expected = 2 },
        .{ .bits = 10, .stored = 2, .expected = null },
        .{ .bits = 15, .stored = 3, .expected = 2 },
        .{ .bits = 16, .stored = 3, .expected = 2 },
        .{ .bits = 17, .stored = 3, .expected = null },
        // A fixed candidate with 9 bits per 4e9 literals requires 4.5e9
        // bytes. It loses to this representable stored size on both targets;
        // 32-bit usize narrowing must not turn the loss into an encode error.
        .{ .bits = 36_000_000_000, .stored = 4_000_400_000, .expected = null },
        .{ .bits = std.math.maxInt(u128), .stored = std.math.maxInt(usize), .expected = null },
    };
    for (vectors) |sample| try std.testing.expectEqual(sample.expected, candidate.candidateSize(sample.bits, sample.stored));
    const maximum: usize = std.math.maxInt(usize);
    const full_bits = @as(u128, maximum) * 8;
    try std.testing.expectEqual(@as(?usize, null), candidate.candidateSize(full_bits, maximum));
    try std.testing.expectEqual(@as(?usize, null), candidate.candidateSize(full_bits + 1, maximum));
    try std.testing.expectEqual(@as(?usize, maximum - 1), candidate.candidateSize(@as(u128, maximum - 1) * 8, maximum));
    try std.testing.expectEqual(@as(?usize, maximum - 1), candidate.candidateSize(@as(u128, maximum - 2) * 8 + 1, maximum));
    try std.testing.expectEqual(@as(?usize, null), candidate.candidateSize(full_bits - 1, maximum));
}

pub fn contracts(comptime Codec: type) !void {
    try std.testing.expect(@TypeOf(@as(Codec.EncodeOptions, .{}).nice_length) == u32);
    try candidateGeometry();
    try fullRange(Codec);
    try outputAliases(Codec);
    try failures(Codec);
}
