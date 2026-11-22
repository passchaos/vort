const std = @import("std");
pub const t = std.testing;
pub const prefix = "prefix with repeated words repeated words and enough bytes to publish";
pub const suffix = " a disjoint retry keeps the original payload intact";

pub fn rawOf(encoder: anytype) if (@hasField(@TypeOf(encoder.*), "raw")) @TypeOf(&encoder.raw) else @TypeOf(encoder) {
    return if (@hasField(@TypeOf(encoder.*), "raw")) &encoder.raw else encoder;
}

pub fn options(comptime D: type, comptime E: type) !E.Options {
    if (@hasField(E, "raw"))
        return .{ .raw = .{ .block_len = 32, .compression = try D.optionsForZlibLevel(1) } };
    if (@hasField(E.Options, "compression"))
        return .{ .block_len = 32, .compression = try D.optionsForZlibLevel(1) };
    return .{ .block_len = 32 };
}

pub fn init(comptime D: type, comptime E: type) !E {
    return E.initWithOptions(t.allocator, try options(D, E));
}

pub fn capacityBytes(list: anytype) []u8 {
    return std.mem.sliceAsBytes(list.items.ptr[0..list.capacity]);
}

fn reserveSpare(list: anytype) !void {
    try list.ensureTotalCapacity(t.allocator, list.items.len + 16);
    @memset(std.mem.sliceAsBytes(list.items.ptr[list.items.len..list.capacity]), 0xa5);
}

/// Populate spare bytes explicitly so the transaction check observes retained
/// allocation storage even when reset left the logical list empty.
pub fn reserveAll(encoder: anytype) !void {
    const raw = rawOf(encoder);
    try reserveSpare(&raw.plain);
    try reserveSpare(&raw.pending);
    try reserveSpare(&raw.state.bytes);
    if (@hasField(@TypeOf(raw.*), "history")) {
        try reserveSpare(&raw.history);
        try reserveSpare(&raw.plan_tokens);
        try reserveSpare(&raw.match_finder.head);
        try reserveSpare(&raw.match_finder.head_epoch);
        try reserveSpare(&raw.match_finder.prev);
    }
    if (@hasField(@TypeOf(encoder.*), "raw")) try reserveSpare(&encoder.pending);
}

pub const Owned = struct {
    entries: [9][]u8 = undefined,
    len: usize = 0,

    fn add(self: *Owned, list: anytype) void {
        self.entries[self.len] = capacityBytes(list);
        self.len += 1;
    }

    pub fn collect(encoder: anytype) Owned {
        var owned: Owned = .{};
        const raw = rawOf(encoder);
        owned.add(&raw.plain);
        owned.add(&raw.pending);
        owned.add(&raw.state.bytes);
        if (@hasField(@TypeOf(raw.*), "history")) {
            owned.add(&raw.history);
            owned.add(&raw.plan_tokens);
            owned.add(&raw.match_finder.head);
            owned.add(&raw.match_finder.head_epoch);
            owned.add(&raw.match_finder.prev);
        }
        if (@hasField(@TypeOf(encoder.*), "raw")) owned.add(&encoder.pending);
        return owned;
    }
};

pub const Saved = struct {
    receiver: []u8,
    owned: Owned,
    copies: [9][]u8 = undefined,
    copied: usize = 0,

    pub fn init(encoder: anytype) !Saved {
        var saved = Saved{
            .receiver = try t.allocator.dupe(u8, std.mem.asBytes(encoder)),
            .owned = Owned.collect(encoder),
        };
        errdefer saved.deinit();
        for (saved.owned.entries[0..saved.owned.len]) |bytes| {
            saved.copies[saved.copied] = try t.allocator.dupe(u8, bytes);
            saved.copied += 1;
        }
        return saved;
    }

    pub fn deinit(self: *Saved) void {
        t.allocator.free(self.receiver);
        for (self.copies[0..self.copied]) |bytes| t.allocator.free(bytes);
    }

    pub fn expectUnchanged(self: *const Saved, encoder: anytype) !void {
        try t.expectEqualSlices(u8, self.receiver, std.mem.asBytes(encoder));
        for (self.owned.entries[0..self.owned.len], self.copies[0..self.copied]) |bytes, before|
            try t.expectEqualSlices(u8, before, bytes);
    }
};

/// Preserve the complete receiver, every byte of retained capacity, both
/// offered slices, and caller canaries outside those slices on refusal.
pub fn reject(encoder: anytype, input: []const u8, output: []u8, caller: []const u8) !void {
    var saved = try Saved.init(encoder);
    defer saved.deinit();
    const input_before = try t.allocator.dupe(u8, input);
    defer t.allocator.free(input_before);
    const output_before = try t.allocator.dupe(u8, output);
    defer t.allocator.free(output_before);
    const caller_before = try t.allocator.dupe(u8, caller);
    defer t.allocator.free(caller_before);
    try t.expectError(error.InvalidBlockPlan, encoder.step(input, output));
    try saved.expectUnchanged(encoder);
    try t.expectEqualSlices(u8, input_before, input);
    try t.expectEqualSlices(u8, output_before, output);
    try t.expectEqualSlices(u8, caller_before, caller);
}

pub fn feedWithOutput(encoder: anytype, input: []const u8, output: []u8, wire: *std.ArrayList(u8)) !void {
    var consumed: usize = 0;
    for (0..128) |_| {
        if (consumed == input.len) return;
        const result = try encoder.step(input[consumed..], output);
        consumed += result.progress.input_read;
        try wire.appendSlice(t.allocator, output[0..result.progress.output_written]);
        try t.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
    return error.TestUnexpectedResult;
}

pub fn feed(encoder: anytype, input: []const u8, wire: *std.ArrayList(u8)) !void {
    var output: [256]u8 = undefined;
    try feedWithOutput(encoder, input, &output, wire);
}

pub fn finish(encoder: anytype, wire: *std.ArrayList(u8)) !void {
    encoder.finish();
    var output: [256]u8 = undefined;
    for (0..128) |_| {
        const result = try encoder.step("", &output);
        try wire.appendSlice(t.allocator, output[0..result.progress.output_written]);
        if (result.status == .done) return;
        try t.expect(result.progress.output_written != 0);
    }
    return error.TestUnexpectedResult;
}

pub fn verify(comptime D: type, comptime E: type, wire: []const u8, plain: []const u8, dictionary: []const u8) !void {
    const decoded = if (E == D.GzipIncrementalFixedEncoder or E == D.GzipIncrementalBestEncoder)
        try D.decodeGzipAlloc(t.allocator, wire)
    else if (E == D.ZlibIncrementalFixedEncoder or E == D.ZlibIncrementalBestEncoder)
        try D.decodeZlibAllocWithDictionary(t.allocator, wire, dictionary)
    else
        try D.decodeRawAutoAllocWithDictionary(t.allocator, wire, dictionary);
    defer t.allocator.free(decoded);
    try t.expectEqualSlices(u8, plain, decoded);
}

/// Compare continuation wire against an independent retained-state clone,
/// then decode the stream to the requested unmodified caller input.
pub fn retry(comptime D: type, encoder: anytype, input: []const u8, wire: *std.ArrayList(u8), plain: []const u8, dictionary: []const u8) !void {
    var oracle = try encoder.clone(t.allocator);
    defer oracle.deinit();
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(t.allocator);
    try expected.appendSlice(t.allocator, wire.items);
    try feed(&oracle, input, &expected);
    try finish(&oracle, &expected);
    try feed(encoder, input, wire);
    try finish(encoder, wire);
    try t.expectEqualSlices(u8, expected.items, wire.items);
    try verify(D, @TypeOf(encoder.*), wire.items, plain, dictionary);
}

pub fn allowDone(encoder: anytype, output: []u8, caller: []const u8) !void {
    var saved = try Saved.init(encoder);
    defer saved.deinit();
    const before = try t.allocator.dupe(u8, caller);
    defer t.allocator.free(before);
    const result = try encoder.step("", output);
    try t.expectEqual(.done, result.status);
    try t.expectEqual(@as(usize, 0), result.progress.input_read);
    try t.expectEqual(@as(usize, 0), result.progress.output_written);
    try saved.expectUnchanged(encoder);
    try t.expectEqualSlices(u8, before, caller);
}
