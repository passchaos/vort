//! Compact internal sequence records for the wide double-fast encoder path.
const std = @import("std");
const lz77 = @import("../../../lz77.zig");

pub const Record = u64;
pub const Fields = struct {
    literal_len: usize,
    distance: usize,
    match_len: usize,
    match_end: usize,
};

pub const Summary = struct {
    tail_start: usize,
    literal_bytes: usize,
    matched_bytes: usize,
};

const literal_len_bits = 17;
const distance_bits = 16;
const match_len_bits = 9;
const match_end_bits = 17;
const distance_shift = literal_len_bits;
const match_len_shift = distance_shift + distance_bits;
const match_end_shift = match_len_shift + match_len_bits;
const literal_len_mask = (@as(Record, 1) << literal_len_bits) - 1;
const distance_mask = (@as(Record, 1) << distance_bits) - 1;
const match_len_mask = (@as(Record, 1) << match_len_bits) - 1;
const match_end_mask = (@as(Record, 1) << match_end_bits) - 1;

pub fn append(
    records: *std.ArrayList(Record),
    allocator: std.mem.Allocator,
    literal_len: usize,
    distance: usize,
    match_len: usize,
    match_end: usize,
) !void {
    if (literal_len > literal_len_mask or distance == 0 or distance > distance_mask or
        match_len < 4 or match_len > match_len_mask or match_end == 0 or
        match_end - 1 > match_end_mask) return error.InvalidBlockPlan;
    const record = @as(Record, @intCast(literal_len)) |
        (@as(Record, @intCast(distance)) << distance_shift) |
        (@as(Record, @intCast(match_len)) << match_len_shift) |
        (@as(Record, @intCast(match_end - 1)) << match_end_shift);
    try records.append(allocator, record);
}

pub fn expand(
    records: []const Record,
    input_len: usize,
    literal_lens: []usize,
    offsets: []usize,
    match_lens: []usize,
    literal_ends: []usize,
) ?Summary {
    if (records.len == 0 or literal_lens.len != records.len or offsets.len != records.len or
        match_lens.len != records.len or literal_ends.len != records.len) return null;
    var previous_end: usize = 0;
    var literal_bytes: usize = 0;
    var matched_bytes: usize = 0;
    for (records, 0..) |record, i| {
        const fields = unpack(record);
        if (!validAfter(fields, previous_end, input_len)) return null;
        literal_lens[i] = fields.literal_len;
        offsets[i] = fields.distance;
        match_lens[i] = fields.match_len;
        literal_ends[i] = fields.match_end;
        previous_end = fields.match_end;
        literal_bytes += fields.literal_len;
        matched_bytes += fields.match_len;
    }
    literal_bytes += input_len - previous_end;
    return .{ .tail_start = previous_end, .literal_bytes = literal_bytes, .matched_bytes = matched_bytes };
}

pub fn materializeTokens(
    tokens: *std.ArrayList(lz77.Token),
    allocator: std.mem.Allocator,
    input: []const u8,
    records: []const Record,
) !bool {
    tokens.clearRetainingCapacity();
    var previous_end: usize = 0;
    for (records) |record| {
        const fields = unpack(record);
        if (!validAfter(fields, previous_end, input.len)) return false;
        const match_start = fields.match_end - fields.match_len;
        const appended = try tokens.addManyAsSlice(allocator, fields.literal_len);
        for (input[previous_end..match_start], appended) |literal, *token| token.* = .{ .literal = literal };
        try tokens.append(allocator, .{ .match = .{
            .length = @intCast(fields.match_len),
            .distance = @intCast(fields.distance),
        } });
        previous_end = fields.match_end;
    }
    const appended = try tokens.addManyAsSlice(allocator, input.len - previous_end);
    for (input[previous_end..], appended) |literal, *token| token.* = .{ .literal = literal };
    return true;
}

fn unpack(record: Record) Fields {
    return .{
        .literal_len = @intCast(record & literal_len_mask),
        .distance = @intCast((record >> distance_shift) & distance_mask),
        .match_len = @intCast((record >> match_len_shift) & match_len_mask),
        .match_end = @as(usize, @intCast((record >> match_end_shift) & match_end_mask)) + 1,
    };
}

fn validAfter(fields: Fields, previous_end: usize, input_len: usize) bool {
    if (fields.distance == 0 or fields.match_len < 4 or fields.match_end > input_len or fields.match_len > fields.match_end) return false;
    const match_start = fields.match_end - fields.match_len;
    return match_start >= previous_end and fields.literal_len == match_start - previous_end and fields.distance <= match_start;
}

test "compact sequence records preserve fields and reject malformed plans" {
    var records: std.ArrayList(Record) = .empty;
    defer records.deinit(std.testing.allocator);
    try append(&records, std.testing.allocator, 7, 1, 9, 16);
    try append(&records, std.testing.allocator, 3, 1, 258, 277);
    var literal_lens: [2]usize = undefined;
    var offsets: [2]usize = undefined;
    var match_lens: [2]usize = undefined;
    var literal_ends: [2]usize = undefined;
    try std.testing.expectEqual(
        @as(?Summary, .{ .tail_start = 277, .literal_bytes = 14, .matched_bytes = 267 }),
        expand(records.items, 281, &literal_lens, &offsets, &match_lens, &literal_ends),
    );
    try std.testing.expectEqualSlices(usize, &.{ 7, 3 }, &literal_lens);
    try std.testing.expectEqualSlices(usize, &.{ 1, 1 }, &offsets);
    try std.testing.expectEqualSlices(usize, &.{ 9, 258 }, &match_lens);
    try std.testing.expectEqualSlices(usize, &.{ 16, 277 }, &literal_ends);
    var tokens: std.ArrayList(lz77.Token) = .empty;
    defer tokens.deinit(std.testing.allocator);
    const input = "a" ** 281;
    try std.testing.expect(try materializeTokens(&tokens, std.testing.allocator, input, records.items));
    const replayed = try lz77.replayAlloc(std.testing.allocator, tokens.items);
    defer std.testing.allocator.free(replayed);
    try std.testing.expectEqualSlices(u8, input, replayed);

    var malformed = records.items[1];
    malformed ^= @as(Record, 1) << match_end_shift;
    try std.testing.expectEqual(@as(?Summary, null), expand(&.{ records.items[0], malformed }, 281, &literal_lens, &offsets, &match_lens, &literal_ends));
    try std.testing.expect(!try materializeTokens(&tokens, std.testing.allocator, input, &.{ records.items[0], malformed }));
}
