//! Independent corpus and wire fixtures for the HQ public contracts.
const std = @import("std");

pub const Corpus = enum { empty, tiny, text, json, source, repetitive, binary };
pub const corpora = [_]Corpus{ .empty, .tiny, .text, .json, .source, .repetitive, .binary };

pub fn binaryPlain() [512]u8 {
    var result: [512]u8 = undefined;
    var state: u32 = 0x7bd493a1;
    for (&result) |*byte| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate(state >> 24);
    }
    @memcpy(result[320..448], result[31..159]);
    return result;
}

pub fn corpusAlloc(allocator: std.mem.Allocator, corpus: Corpus) ![]u8 {
    const text: []const u8 = switch (corpus) {
        .empty => "",
        .tiny => "HQ!",
        .text => "Compression keeps repeated words and small edits near their context.\n" ** 4,
        .json => "{\"service\":\"vort\",\"ok\":true,\"items\":[1,4,8],\"message\":\"quality parse\"}\n" ** 4,
        .source => "fn byteAt(bytes: []const u8, i: usize) u8 { return bytes[i]; }\n" ** 4,
        .repetitive => "abcdefghabcdefghXbcdefghYabcdefgh" ** 12,
        .binary => {
            const data = binaryPlain();
            return allocator.dupe(u8, &data);
        },
    };
    return allocator.dupe(u8, text);
}

pub fn decodeHex(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    const bytes = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, hex);
    return bytes;
}

pub fn sentinel(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

pub fn fillRandom(bytes: []u8, seed: u32) void {
    var state = seed;
    for (bytes) |*byte| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate(state >> 24);
    }
}

/// One full 128 KiB block whose profitable match starts beyond old 32 KiB and
/// reaches a distance greater than 65535. Use one representative HQ engine.
pub fn fullBlock(allocator: std.mem.Allocator) ![]u8 {
    const result = try allocator.alloc(u8, 128 * 1024);
    fillRandom(result[0..70000], 0x967be803);
    @memcpy(result[70000..], result[0 .. result.len - 70000]);
    return result;
}

pub fn farDictionary(allocator: std.mem.Allocator) ![]u8 {
    const result = try allocator.alloc(u8, 96 * 1024);
    @memset(result, 0xff);
    fillRandom(result[0..1024], 0x741ad069);
    return result;
}

pub fn stdDecode(allocator: std.mem.Allocator, frame: []const u8) ![]u8 {
    var input: std.Io.Reader = .fixed(frame);
    var output: std.Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    var decoder: std.compress.zstd.Decompress = .init(&input, &.{}, .{ .window_len = 128 * 1024 });
    _ = try decoder.reader.streamRemaining(&output.writer);
    return output.toOwnedSlice();
}

/// RFC 8878 recent-offset transitions, independent of parser/bridge helpers.
pub fn repDistance(reps: [3]u32, literal_len: usize, value: u32) ?u32 {
    if (value > 3) return value - 3;
    if (value == 0) return null;
    if (literal_len == 0) return switch (value) {
        1 => reps[1],
        2 => reps[2],
        3 => if (reps[0] > 1) reps[0] - 1 else null,
        else => unreachable,
    };
    return reps[value - 1];
}

pub fn afterOffset(reps: [3]u32, literal_len: usize, value: u32) ?[3]u32 {
    const distance = repDistance(reps, literal_len, value) orelse return null;
    if (value > 3) return .{ distance, reps[0], reps[1] };
    const rank = value - 1 + @intFromBool(literal_len == 0);
    return switch (rank) {
        0 => reps,
        1 => .{ reps[1], reps[0], reps[2] },
        2 => .{ reps[2], reps[0], reps[1] },
        3 => .{ distance, reps[0], reps[1] },
        else => unreachable,
    };
}

pub fn verifyPlan(allocator: std.mem.Allocator, prefix: []const u8, input: []const u8, initial: [3]u32, plan: anytype) !void {
    const output = try allocator.alloc(u8, input.len);
    defer allocator.free(output);
    var written: usize = 0;
    var reps = initial;
    for (plan.records, plan.offset_values) |record, selected| {
        try std.testing.expect(record.literal_len <= input.len - written);
        @memcpy(output[written..][0..record.literal_len], input[written..][0..record.literal_len]);
        written += record.literal_len;
        try std.testing.expectEqual(@as(?usize, selected), record.offset_value);
        const distance = repDistance(reps, record.literal_len, selected) orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(@as(usize, distance), record.distance);
        reps = afterOffset(reps, record.literal_len, selected) orelse return error.TestUnexpectedResult;
        try std.testing.expect(record.match_len <= input.len - written);
        for (0..record.match_len) |_| {
            try std.testing.expect(record.distance > 0 and record.distance <= prefix.len + written);
            const source_position = prefix.len + written - record.distance;
            output[written] = if (source_position < prefix.len) prefix[source_position] else output[source_position - prefix.len];
            written += 1;
        }
        try std.testing.expectEqual(written, record.match_end);
    }
    @memcpy(output[written..], input[written..]);
    try std.testing.expectEqualSlices(u8, input, output);
    for (reps, plan.final_repeated_offsets) |expected, actual| try std.testing.expectEqual(@as(usize, expected), actual);
}

pub fn driveEncoder(allocator: std.mem.Allocator, encoder: anytype, input: []const u8, input_chunk: usize, output_chunk: usize, flush_at: ?usize) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    const initial = encoder.snapshot();
    var read = initial.input_read;
    var finished = initial.finishing;
    var flushed = flush_at == null;
    var drain_flush = false;
    var incoming: [257]u8 = undefined;
    var outgoing: [31]u8 = undefined;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < (input.len + 1) * 16 + 4096);
        if (!flushed and read == flush_at.?) {
            encoder.flush();
            flushed = true;
            drain_flush = true;
        }
        if (read == input.len and !finished and !drain_flush) {
            encoder.finish();
            finished = true;
        }
        var take = if (drain_flush) 0 else @min(input_chunk, input.len - read);
        if (!flushed) take = @min(take, flush_at.? - read);
        @memcpy(incoming[0..take], input[read..][0..take]);
        @memset(&outgoing, 0xa5);
        const quota = if (calls % 5 == 0) 0 else output_chunk;
        const before = encoder.snapshot();
        const step = try encoder.step(incoming[0..take], outgoing[0..quota]);
        const after = encoder.snapshot();
        try std.testing.expect(step.progress.input_read <= take and step.progress.output_written <= quota);
        try std.testing.expectEqual(step.progress.input_read, after.input_read - before.input_read);
        try std.testing.expectEqual(step.progress.output_written, after.output_written - before.output_written);
        try sentinel(outgoing[step.progress.output_written..]);
        read += step.progress.input_read;
        try result.appendSlice(allocator, outgoing[0..step.progress.output_written]);
        @memset(&incoming, 0x3c);
        if (drain_flush and after.buffered_input == 0 and after.pending_output == 0) drain_flush = false;
        if (step.status == .done) {
            try std.testing.expectEqual(input.len, read);
            try std.testing.expectEqual(result.items.len, after.output_written - initial.output_written);
            return result.toOwnedSlice(allocator);
        }
    }
}

// Requested bytes are tracked independently of allocator bookkeeping.
pub const HeapLedger = struct {
    backing: std.mem.Allocator,
    limit: usize,
    live: usize = 0,
    peak: usize = 0,
    largest_request: usize = 0,
    denied_requests: usize = 0,
    force_moving_growth: bool = false,

    pub fn init(backing: std.mem.Allocator, limit: usize) HeapLedger {
        return .{ .backing = backing, .limit = limit };
    }

    pub fn allocator(self: *HeapLedger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn permit(self: *HeapLedger, previous_len: usize, next_len: usize) bool {
        self.largest_request = @max(self.largest_request, next_len);
        const next_live = std.math.add(usize, self.live - previous_len, next_len) catch {
            self.denied_requests += 1;
            return false;
        };
        if (next_live > self.limit) {
            self.denied_requests += 1;
            return false;
        }
        return true;
    }

    fn update(self: *HeapLedger, previous_len: usize, next_len: usize) void {
        self.live = self.live - previous_len + next_len;
        self.peak = @max(self.peak, self.live);
    }

    fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        if (!self.permit(0, len)) return null;
        const result = self.backing.rawAlloc(len, alignment, return_address) orelse return null;
        self.update(0, len);
        return result;
    }

    fn resize(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) bool {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        if (self.force_moving_growth) return false;
        if (!self.permit(memory.len, new_len)) return false;
        if (!self.backing.rawResize(memory, alignment, new_len, return_address)) return false;
        self.update(memory.len, new_len);
        return true;
    }

    fn remap(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) ?[*]u8 {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        if (self.force_moving_growth) return null;
        if (!self.permit(memory.len, new_len)) return null;
        const result = self.backing.rawRemap(memory, alignment, new_len, return_address) orelse return null;
        self.update(memory.len, new_len);
        return result;
    }

    fn free(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, return_address: usize) void {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        self.backing.rawFree(memory, alignment, return_address);
        self.update(memory.len, 0);
    }
};

// Full RFC 8878 dictionary entropy header frozen from f95c3446; caller
// content is independent of that portable baseline model. Duplicate initial
// reps deliberately exercise multiple legal selectors for the same distance.
pub const full_dictionary_header_hex = "37a430ec485100002f10804f63fcffffffffffffffffffffffffffffff706fa185165a68a185165a04ee2de596121dea901a6aa8436a200c03412010085004ddd6412222f254a0404141810d86028c828282828282828282828282828282028c828202889702638e293e48514a29a5945255d50324155528140a455114455114455114455114a594524a2955553d010000000100000008000000";

pub fn fullDictionary(allocator: std.mem.Allocator) ![]u8 {
    const header = try decodeHex(allocator, full_dictionary_header_hex);
    defer allocator.free(header);
    const result = try allocator.alloc(u8, header.len + 128);
    @memcpy(result[0..header.len], header);
    @memset(result[header.len..], 'a');
    return result;
}

pub const ll0_plain = "a" ** 64 ++ "b";
pub const positive_ll_plain = "b" ++ "a" ** 64 ++ "c" ++ "a" ** 64;

// Frozen from f95c3446 before HQ strategies were added.
pub const LegacyWire = struct { native: bool, corpus: Corpus, strategy: []const u8, hex: []const u8 };
pub const legacy_wires = [_]LegacyWire{
    .{ .native = false, .corpus = .empty, .strategy = "auto", .hex = "28b52ffd2000010000" },
    .{ .native = true, .corpus = .empty, .strategy = "auto", .hex = "28b52ffd240001000099e9d851" },
    .{ .native = false, .corpus = .empty, .strategy = "fast", .hex = "28b52ffd2000010000" },
    .{ .native = true, .corpus = .empty, .strategy = "fast", .hex = "28b52ffd240001000099e9d851" },
    .{ .native = false, .corpus = .empty, .strategy = "double_fast", .hex = "28b52ffd2000010000" },
    .{ .native = true, .corpus = .empty, .strategy = "double_fast", .hex = "28b52ffd240001000099e9d851" },
    .{ .native = false, .corpus = .empty, .strategy = "greedy", .hex = "28b52ffd2000010000" },
    .{ .native = true, .corpus = .empty, .strategy = "greedy", .hex = "28b52ffd240001000099e9d851" },
    .{ .native = false, .corpus = .empty, .strategy = "lazy", .hex = "28b52ffd2000010000" },
    .{ .native = true, .corpus = .empty, .strategy = "lazy", .hex = "28b52ffd240001000099e9d851" },
    .{ .native = false, .corpus = .empty, .strategy = "optimal", .hex = "28b52ffd2000010000" },
    .{ .native = true, .corpus = .empty, .strategy = "optimal", .hex = "28b52ffd240001000099e9d851" },
    .{ .native = false, .corpus = .tiny, .strategy = "auto", .hex = "28b52ffd2003190000485121" },
    .{ .native = true, .corpus = .tiny, .strategy = "auto", .hex = "28b52ffd2403190000485121e45a5d79" },
    .{ .native = false, .corpus = .tiny, .strategy = "fast", .hex = "28b52ffd2003190000485121" },
    .{ .native = true, .corpus = .tiny, .strategy = "fast", .hex = "28b52ffd2403190000485121e45a5d79" },
    .{ .native = false, .corpus = .tiny, .strategy = "double_fast", .hex = "28b52ffd2003190000485121" },
    .{ .native = true, .corpus = .tiny, .strategy = "double_fast", .hex = "28b52ffd2403190000485121e45a5d79" },
    .{ .native = false, .corpus = .tiny, .strategy = "greedy", .hex = "28b52ffd2003190000485121" },
    .{ .native = true, .corpus = .tiny, .strategy = "greedy", .hex = "28b52ffd2403190000485121e45a5d79" },
    .{ .native = false, .corpus = .tiny, .strategy = "lazy", .hex = "28b52ffd2003190000485121" },
    .{ .native = true, .corpus = .tiny, .strategy = "lazy", .hex = "28b52ffd2403190000485121e45a5d79" },
    .{ .native = false, .corpus = .tiny, .strategy = "optimal", .hex = "28b52ffd2003190000485121" },
    .{ .native = true, .corpus = .tiny, .strategy = "optimal", .hex = "28b52ffd2403190000485121e45a5d79" },
    .{ .native = false, .corpus = .text, .strategy = "auto", .hex = "28b52ffd6014000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214" },
    .{ .native = true, .corpus = .text, .strategy = "auto", .hex = "28b52ffd6414000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214f6abb331" },
    .{ .native = false, .corpus = .text, .strategy = "fast", .hex = "28b52ffd6014000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214" },
    .{ .native = true, .corpus = .text, .strategy = "fast", .hex = "28b52ffd6414000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214f6abb331" },
    .{ .native = false, .corpus = .text, .strategy = "double_fast", .hex = "28b52ffd6014000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214" },
    .{ .native = true, .corpus = .text, .strategy = "double_fast", .hex = "28b52ffd6414000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214f6abb331" },
    .{ .native = false, .corpus = .text, .strategy = "greedy", .hex = "28b52ffd6014000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214" },
    .{ .native = true, .corpus = .text, .strategy = "greedy", .hex = "28b52ffd6414000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214f6abb331" },
    .{ .native = false, .corpus = .text, .strategy = "lazy", .hex = "28b52ffd6014000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214" },
    .{ .native = true, .corpus = .text, .strategy = "lazy", .hex = "28b52ffd6414000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214f6abb331" },
    .{ .native = false, .corpus = .text, .strategy = "optimal", .hex = "28b52ffd6014000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214" },
    .{ .native = true, .corpus = .text, .strategy = "optimal", .hex = "28b52ffd6414000d020052c40d13b0a701c072b24d72b739f89be1128d726a9507409087d36e28121359245b9fa4dc52c8bc65d4179ed172928fb13f76513bf21b8f392101000513a14214f6abb331" },
    .{ .native = false, .corpus = .json, .strategy = "auto", .hex = "28b52ffd601c0045020072840f16903b014cd83b25289d9975db647762bad0fb9ba7320ec0e36ba2256836298831461f41aa573e83b8e18402adea9b7c67b9e864f9bcb99ad13f52cbab9d01008754a14214" },
    .{ .native = true, .corpus = .json, .strategy = "auto", .hex = "28b52ffd641c0045020072840f16903b014cd83b25289d9975db647762bad0fb9ba7320ec0e36ba2256836298831461f41aa573e83b8e18402adea9b7c67b9e864f9bcb99ad13f52cbab9d01008754a1421483d02ba3" },
    .{ .native = false, .corpus = .json, .strategy = "fast", .hex = "28b52ffd601c004d020032440f16903b014cd83b25289d15e4b6c9eea458f9fb9ba7320ec0e36ba625681695c41824a95ef90ce286130a64555ff49de52227cbe7cdd58cfc035b5eed040200a44aa035ce5250" },
    .{ .native = true, .corpus = .json, .strategy = "fast", .hex = "28b52ffd641c004d020032440f16903b014cd83b25289d15e4b6c9eea458f9fb9ba7320ec0e36ba625681695c41824a95ef90ce286130a64555ff49de52227cbe7cdd58cfc035b5eed040200a44aa035ce525083d02ba3" },
    .{ .native = false, .corpus = .json, .strategy = "double_fast", .hex = "28b52ffd601c004d020032440f16903b014cd83b25289d15e4b6c9eea458f9fb9ba7320ec0e36ba625681695c41824a95ef90ce286130a64555ff49de52227cbe7cdd58cfc035b5eed040200a44aa035ce5250" },
    .{ .native = true, .corpus = .json, .strategy = "double_fast", .hex = "28b52ffd641c004d020032440f16903b014cd83b25289d15e4b6c9eea458f9fb9ba7320ec0e36ba625681695c41824a95ef90ce286130a64555ff49de52227cbe7cdd58cfc035b5eed040200a44aa035ce525083d02ba3" },
    .{ .native = false, .corpus = .json, .strategy = "greedy", .hex = "28b52ffd601c004d020032440f16903b014cd83b25289d15e4b6c9eea458f9fb9ba7320ec0e36ba625681695c41824a95ef90ce286130a64555ff49de52227cbe7cdd58cfc035b5eed040200a44aa035ce5250" },
    .{ .native = true, .corpus = .json, .strategy = "greedy", .hex = "28b52ffd641c004d020032440f16903b014cd83b25289d15e4b6c9eea458f9fb9ba7320ec0e36ba625681695c41824a95ef90ce286130a64555ff49de52227cbe7cdd58cfc035b5eed040200a44aa035ce525083d02ba3" },
    .{ .native = false, .corpus = .json, .strategy = "lazy", .hex = "28b52ffd601c004d020032440f16903b014cd83b25289d15e4b6c9eea458f9fb9ba7320ec0e36ba625681695c41824a95ef90ce286130a64555ff49de52227cbe7cdd58cfc035b5eed040200a44aa035ce5250" },
    .{ .native = true, .corpus = .json, .strategy = "lazy", .hex = "28b52ffd641c004d020032440f16903b014cd83b25289d15e4b6c9eea458f9fb9ba7320ec0e36ba625681695c41824a95ef90ce286130a64555ff49de52227cbe7cdd58cfc035b5eed040200a44aa035ce525083d02ba3" },
    .{ .native = false, .corpus = .json, .strategy = "optimal", .hex = "28b52ffd601c004d020032440f16903b014cd83b25289d15e4b6c9eea458f9fb9ba7320ec0e36ba625681695c41824a95ef90ce286130a64555ff49de52227cbe7cdd58cfc035b5eed040200a44aa035ce5250" },
    .{ .native = true, .corpus = .json, .strategy = "optimal", .hex = "28b52ffd641c004d020032440f16903b014cd83b25289d15e4b6c9eea458f9fb9ba7320ec0e36ba625681695c41824a95ef90ce286130a64555ff49de52227cbe7cdd58cfc035b5eed040200a44aa035ce525083d02ba3" },
    .{ .native = false, .corpus = .source, .strategy = "auto", .hex = "28b52ffd20fc1502005403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207538207b207265747572735b695d3b207d0a03003a2150bea9e6292848" },
    .{ .native = true, .corpus = .source, .strategy = "auto", .hex = "28b52ffd24fc1502005403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207538207b207265747572735b695d3b207d0a03003a2150bea9e62928481c870402" },
    .{ .native = false, .corpus = .source, .strategy = "fast", .hex = "28b52ffd20fc1502005403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207538207b207265747572735b695d3b207d0a03003a2150bea9e6292848" },
    .{ .native = true, .corpus = .source, .strategy = "fast", .hex = "28b52ffd24fc1502005403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207538207b207265747572735b695d3b207d0a03003a2150bea9e62928481c870402" },
    .{ .native = false, .corpus = .source, .strategy = "double_fast", .hex = "28b52ffd20fc1502005403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207538207b207265747572735b695d3b207d0a03003a2150bea9e6292848" },
    .{ .native = true, .corpus = .source, .strategy = "double_fast", .hex = "28b52ffd24fc1502005403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207538207b207265747572735b695d3b207d0a03003a2150bea9e62928481c870402" },
    .{ .native = false, .corpus = .source, .strategy = "greedy", .hex = "28b52ffd20fc1502002403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207b207265747572735b695d3b207d0a04003a21503ed5c089094341e902" },
    .{ .native = true, .corpus = .source, .strategy = "greedy", .hex = "28b52ffd24fc1502002403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207b207265747572735b695d3b207d0a04003a21503ed5c089094341e9021c870402" },
    .{ .native = false, .corpus = .source, .strategy = "lazy", .hex = "28b52ffd20fc1502002403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207b207265747572735b695d3b207d0a04003a21503ed5c089094341e902" },
    .{ .native = true, .corpus = .source, .strategy = "lazy", .hex = "28b52ffd24fc1502002403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207b207265747572735b695d3b207d0a04003a21503ed5c089094341e9021c870402" },
    .{ .native = false, .corpus = .source, .strategy = "optimal", .hex = "28b52ffd20fc1502002403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207b207265747572735b695d3b207d0a04003a21503ed5c089094341e902" },
    .{ .native = true, .corpus = .source, .strategy = "optimal", .hex = "28b52ffd24fc1502002403666e2062797465417428733a205b5d636f6e73742075382c20693a207573697a6529207b207265747572735b695d3b207d0a04003a21503ed5c089094341e9021c870402" },
    .{ .native = false, .corpus = .repetitive, .strategy = "auto", .hex = "28b52ffd608c00dd00005061626364656667685859050086a874ff4451a349d84a16230a17" },
    .{ .native = true, .corpus = .repetitive, .strategy = "auto", .hex = "28b52ffd648c00dd0000506162636465666768585905004ed4b47fa228e389d84a16230a1705c66d1e" },
    .{ .native = false, .corpus = .repetitive, .strategy = "fast", .hex = "28b52ffd608c00d50000506162636465666768585905005844a9bb828c26612b598c285c" },
    .{ .native = true, .corpus = .repetitive, .strategy = "fast", .hex = "28b52ffd648c00d50000506162636465666768585905005844a9bb828c26612b598c285c05c66d1e" },
    .{ .native = false, .corpus = .repetitive, .strategy = "double_fast", .hex = "28b52ffd608c00d50000506162636465666768585905005844a9bb828c26612b598c285c" },
    .{ .native = true, .corpus = .repetitive, .strategy = "double_fast", .hex = "28b52ffd648c00d50000506162636465666768585905005844a9bb828c26612b598c285c05c66d1e" },
    .{ .native = false, .corpus = .repetitive, .strategy = "greedy", .hex = "28b52ffd608c00c50000506162636465666768585904006044a9c613b1952c46142e" },
    .{ .native = true, .corpus = .repetitive, .strategy = "greedy", .hex = "28b52ffd648c00c50000506162636465666768585904006044a9c613b1952c46142e05c66d1e" },
    .{ .native = false, .corpus = .repetitive, .strategy = "lazy", .hex = "28b52ffd608c00c50000506162636465666768585904006044a9c613b1952c46142e" },
    .{ .native = true, .corpus = .repetitive, .strategy = "lazy", .hex = "28b52ffd648c00c50000506162636465666768585904006044a9c613b1952c46142e05c66d1e" },
    .{ .native = false, .corpus = .repetitive, .strategy = "optimal", .hex = "28b52ffd608c00d50000506162636465666768585905005844a9bb828c26612b598c285c" },
    .{ .native = true, .corpus = .repetitive, .strategy = "optimal", .hex = "28b52ffd648c00c5000050616263646566676858590400684429a3f9d88a137b0b1705c66d1e" },
    .{ .native = false, .corpus = .binary, .strategy = "auto", .hex = "28b52ffd6000014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d53" },
    .{ .native = true, .corpus = .binary, .strategy = "auto", .hex = "28b52ffd6400014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d537dd609cf" },
    .{ .native = false, .corpus = .binary, .strategy = "fast", .hex = "28b52ffd6000014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d53" },
    .{ .native = true, .corpus = .binary, .strategy = "fast", .hex = "28b52ffd6400014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d537dd609cf" },
    .{ .native = false, .corpus = .binary, .strategy = "double_fast", .hex = "28b52ffd6000014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d53" },
    .{ .native = true, .corpus = .binary, .strategy = "double_fast", .hex = "28b52ffd6400014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d537dd609cf" },
    .{ .native = false, .corpus = .binary, .strategy = "greedy", .hex = "28b52ffd6000014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d53" },
    .{ .native = true, .corpus = .binary, .strategy = "greedy", .hex = "28b52ffd6400014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d537dd609cf" },
    .{ .native = false, .corpus = .binary, .strategy = "lazy", .hex = "28b52ffd6000014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d53" },
    .{ .native = true, .corpus = .binary, .strategy = "lazy", .hex = "28b52ffd6400014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d537dd609cf" },
    .{ .native = false, .corpus = .binary, .strategy = "optimal", .hex = "28b52ffd6000014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d53" },
    .{ .native = true, .corpus = .binary, .strategy = "optimal", .hex = "28b52ffd6400014d0c000418a32d5a0fc060f5c55b891a293df86b6720424a4373e928376e9c49b588be43d5da0ddeed1a901ae5223672333bbfb8e095e014ffb7b9ff6ebf0c50dcb6d3a7536f16d5dd9c330dec0be4efa34ec5d1382f24c6eeb54a467ba1a37ec69e67ae6495a6162cded74dcf3b5f215ed49d410da86e4fb12d4e35c4046fbfed046ee0570c9a294b49d150e8e978d2f07a190be24d9e5409b33dfd14e982356c031f37602f574dce1b3a7df56303fa844455a31e001b2cddae4ebf9d68f3340307f42498e8c5736e67ec311609d9caed8aacf40936cde2395c8292efabdd4614d1ad88fbb64f42081289bdd050d7a4a2f6c05bd3fa22384acc998004f05f26aa774dbd69aee4149dd774650dc1dc1fbb8775a88ee80ba164e21987358b99c66e611b8da677f7f65245d4611bf8ce06f691f6223033ff44fe574d9a43e2b44cb14da1375c0bae7393a7b6aa7b89b8d2ed2d8d55eb5785958b50908bf119bb942ed7afc045dc163be90e04a0a19fd446683d0cec0c403a40c078ed29baa420ded5b2d21e770100409d245d537dd609cf" },
};
