const std = @import("std");
const command_plan = @import("command_plan.zig");

/// The two latency-oriented Brotli fragment parsers. Both deliberately keep
/// matches inside the current fragment: a later meta-block may be encoded and
/// decoded without retaining the parser's hash state or depending on an
/// earlier fragment for a copy source.
pub const Variant = enum {
    q0,
    q1,

    fn maxTableLen(self: Variant) usize {
        return switch (self) {
            .q0 => 1 << 15,
            .q1 => 1 << 17,
        };
    }

    fn minMatch(self: Variant, table_bits: u6) usize {
        return switch (self) {
            .q0 => 5,
            .q1 => if (table_bits <= 15) 4 else 6,
        };
    }
};

pub const Stats = struct {
    literal_bytes: usize = 0,
    matches: usize = 0,
    matched_bytes: usize = 0,
    hash_lookups: usize = 0,
    skipped_positions: usize = 0,
    last_distance_matches: usize = 0,
    table_bits: u6 = 0,
};

/// Reusable fixed-hash storage. Zero is the empty marker; populated entries
/// store `position + 1`, so position zero remains representable without a
/// second initialized bitmap.
pub const Scratch = struct {
    table: std.ArrayList(u32) = .empty,

    pub fn deinit(self: *Scratch, allocator: std.mem.Allocator) void {
        self.table.deinit(allocator);
        self.* = .{};
    }

    pub fn retainedCapacity(self: *const Scratch) usize {
        return self.table.capacity * @sizeOf(u32);
    }

    fn prepare(self: *Scratch, allocator: std.mem.Allocator, len: usize) !void {
        try self.table.resize(allocator, len);
        @memset(self.table.items, 0);
    }
};

const hash_mul: u64 = 0x1e35_a7bd;

fn tableLen(variant: Variant, input_len: usize) usize {
    var len: usize = 256;
    while (len < variant.maxTableLen() and len < input_len) len <<= 1;

    // Upstream's q0 hash mixer supports odd table shifts. Preserve that
    // invariant instead of silently changing its candidate distribution.
    if (variant == .q0 and @ctz(len) % 2 == 0 and len < variant.maxTableLen())
        len <<= 1;
    return len;
}

fn hashAt(input: []const u8, position: usize, anchor_len: usize, table_bits: u6) usize {
    std.debug.assert(anchor_len == 4 or anchor_len == 5 or anchor_len == 6);
    std.debug.assert(position <= input.len and anchor_len <= input.len - position);
    var value: u64 = std.mem.readInt(u32, input[position..][0..4], .little);
    if (anchor_len >= 5) value |= @as(u64, input[position + 4]) << 32;
    if (anchor_len == 6) value |= @as(u64, input[position + 5]) << 40;
    const shift: u6 = @intCast((8 - anchor_len) * 8);
    const mixed = (value << shift) *% hash_mul;
    const final_shift: u6 = @intCast(@as(usize, 64) - table_bits);
    return @intCast(mixed >> final_shift);
}

fn prefixMatches(input: []const u8, left: usize, right: usize, len: usize) bool {
    std.debug.assert(left < right);
    if (right > input.len or len > input.len - right) return false;
    return std.mem.eql(u8, input[left..][0..len], input[right..][0..len]);
}

fn matchLength(input: []const u8, left: usize, right: usize, minimum: usize) usize {
    std.debug.assert(prefixMatches(input, left, right, minimum));
    var len = minimum;
    while (len < input.len - right and input[left + len] == input[right + len])
        len += 1;
    return len;
}

fn insertHash(
    scratch: *Scratch,
    input: []const u8,
    position: usize,
    anchor_len: usize,
    table_bits: u6,
) void {
    if (position > input.len or anchor_len > input.len - position) return;
    const slot = hashAt(input, position, anchor_len, table_bits);
    scratch.table.items[slot] = @intCast(position + 1);
}

fn seedMatchTail(
    scratch: *Scratch,
    input: []const u8,
    match_start: usize,
    match_end: usize,
    anchor_len: usize,
    table_bits: u6,
) void {
    if (match_end <= match_start + 1) return;
    const tail_start = @max(match_start + 1, match_end -| anchor_len);
    for (tail_start..match_end) |position|
        insertHash(scratch, input, position, anchor_len, table_bits);
}

fn appendMatch(
    commands: *std.ArrayList(command_plan.Command),
    allocator: std.mem.Allocator,
    insert_start: usize,
    insert_len: usize,
    copy_len: usize,
    distance: usize,
) !void {
    // Adjacent copies at the same distance are one equivalent Brotli copy.
    // Coalescing here avoids manufacturing extra command/distance symbols when
    // the fragment scanner finds an immediately following match.
    if (insert_len == 0 and commands.items.len != 0) {
        const previous = &commands.items[commands.items.len - 1];
        if (previous.has_copy and previous.isLz77() and previous.distance == distance) {
            previous.copy_len = std.math.add(usize, previous.copy_len, copy_len) catch
                return error.IntegerOverflow;
            return;
        }
    }
    try commands.append(allocator, .{
        .insert_start = insert_start,
        .insert_len = insert_len,
        .copy_len = copy_len,
        .distance = distance,
        .has_copy = true,
    });
}

/// Build a block-local Brotli command plan with the fast-fragment invariants:
/// one fixed hash candidate, recent-distance probing, Snappy-style skip-ahead
/// on incompressible data, and sparse hash seeding inside consumed matches.
///
/// This is the parsing half of the q0/q1 engines. The shared Brotli writer
/// still builds exact Huffman histograms from the returned commands, so Vort
/// does not claim byte identity with libbrotli's specialized entropy writers.
pub fn planReuse(
    commands: *std.ArrayList(command_plan.Command),
    scratch: *Scratch,
    allocator: std.mem.Allocator,
    input: []const u8,
    variant: Variant,
    max_backward_distance: usize,
) !Stats {
    commands.clearRetainingCapacity();
    if (max_backward_distance == 0 or max_backward_distance > std.math.maxInt(u16))
        return error.InvalidBlockPlan;
    if (input.len > std.math.maxInt(u32) - 1) return error.InvalidBlockPlan;

    var stats: Stats = .{};
    if (input.len == 0) return stats;

    const table_len = tableLen(variant, input.len);
    const table_bits: u6 = @intCast(@ctz(table_len));
    const anchor_len = variant.minMatch(table_bits);
    stats.table_bits = table_bits;
    if (input.len < anchor_len + 1) {
        try commands.append(allocator, .{ .insert_start = 0, .insert_len = input.len });
        stats.literal_bytes = input.len;
        return stats;
    }

    try scratch.prepare(allocator, table_len);
    insertHash(scratch, input, 0, anchor_len, table_bits);

    var position: usize = 1;
    var next_emit: usize = 0;
    var last_distance: usize = 0;
    var skip: usize = 32;

    while (position <= input.len - anchor_len) {
        const slot = hashAt(input, position, anchor_len, table_bits);
        const encoded_candidate = scratch.table.items[slot];
        scratch.table.items[slot] = @intCast(position + 1);
        stats.hash_lookups += 1;

        var candidate: ?usize = null;
        var used_last_distance = false;
        if (last_distance != 0 and last_distance <= position and
            last_distance <= max_backward_distance)
        {
            const recent = position - last_distance;
            if (prefixMatches(input, recent, position, anchor_len)) {
                candidate = recent;
                used_last_distance = true;
            }
        }
        if (candidate == null and encoded_candidate != 0) {
            const hashed: usize = encoded_candidate - 1;
            const distance = position - hashed;
            if (distance <= max_backward_distance and
                prefixMatches(input, hashed, position, anchor_len))
            {
                candidate = hashed;
            }
        }

        if (candidate) |match_position| {
            const distance = position - match_position;
            const copy_len = matchLength(input, match_position, position, anchor_len);
            const insert_len = position - next_emit;
            try appendMatch(
                commands,
                allocator,
                next_emit,
                insert_len,
                copy_len,
                distance,
            );
            stats.literal_bytes += insert_len;
            stats.matches += 1;
            stats.matched_bytes += copy_len;
            stats.last_distance_matches += @intFromBool(used_last_distance);

            const match_end = position + copy_len;
            seedMatchTail(
                scratch,
                input,
                position,
                match_end,
                anchor_len,
                table_bits,
            );
            position = match_end;
            next_emit = match_end;
            last_distance = distance;
            skip = 32;
            continue;
        }

        const step = @max(@as(usize, 1), skip >> 5);
        skip += 1;
        const remaining = input.len - position;
        const advance = @min(step, remaining);
        stats.skipped_positions += advance - 1;
        position += advance;
    }

    if (next_emit < input.len) {
        const insert_len = input.len - next_emit;
        try commands.append(allocator, .{
            .insert_start = next_emit,
            .insert_len = insert_len,
        });
        stats.literal_bytes += insert_len;
    }
    std.debug.assert(stats.literal_bytes + stats.matched_bytes == input.len);
    return stats;
}

fn expectReplays(input: []const u8, commands: []const command_plan.Command) !void {
    const output = try std.testing.allocator.alloc(u8, input.len);
    defer std.testing.allocator.free(output);
    var written: usize = 0;
    for (commands) |command| {
        try std.testing.expectEqual(written, command.insert_start);
        try std.testing.expect(command.insert_len <= input.len - written);
        @memcpy(output[written..][0..command.insert_len], input[written..][0..command.insert_len]);
        written += command.insert_len;
        if (!command.has_copy) continue;
        try std.testing.expect(command.distance != 0 and command.distance <= written);
        for (0..command.copy_len) |index|
            output[written + index] = output[written + index - command.distance];
        written += command.copy_len;
    }
    try std.testing.expectEqual(input.len, written);
    try std.testing.expectEqualSlices(u8, input, output);
}

test "fast fragment variants replay block-local commands" {
    const input = "fragment-local phrase 0123456789\n" ** 96;
    inline for (std.meta.tags(Variant)) |variant| {
        var scratch: Scratch = .{};
        defer scratch.deinit(std.testing.allocator);
        var commands: std.ArrayList(command_plan.Command) = .empty;
        defer commands.deinit(std.testing.allocator);
        const stats = try planReuse(
            &commands,
            &scratch,
            std.testing.allocator,
            input,
            variant,
            65520,
        );
        try std.testing.expect(stats.matches != 0);
        try std.testing.expect(stats.matched_bytes > stats.literal_bytes);
        try expectReplays(input, commands.items);
        for (commands.items) |command|
            if (command.has_copy) try std.testing.expect(command.distance <= command.insert_start + command.insert_len);
    }
}

test "q1 finds four-byte fragments that q0 leaves literal" {
    const input = "abcdXabcdY";
    var scratch: Scratch = .{};
    defer scratch.deinit(std.testing.allocator);
    var commands: std.ArrayList(command_plan.Command) = .empty;
    defer commands.deinit(std.testing.allocator);

    const q0 = try planReuse(&commands, &scratch, std.testing.allocator, input, .q0, 65520);
    try std.testing.expectEqual(@as(usize, 0), q0.matches);
    try expectReplays(input, commands.items);

    const q1 = try planReuse(&commands, &scratch, std.testing.allocator, input, .q1, 65520);
    try std.testing.expectEqual(@as(usize, 1), q1.matches);
    try std.testing.expectEqual(@as(usize, 4), q1.matched_bytes);
    try expectReplays(input, commands.items);
}

test "fast fragment respects narrow Brotli windows" {
    var input: [2304]u8 = undefined;
    for (input[0..1152], 0..) |*byte, index| byte.* = @intCast((index *% 73 +% 19) & 0xff);
    @memcpy(input[1152..], input[0..1152]);

    var scratch: Scratch = .{};
    defer scratch.deinit(std.testing.allocator);
    var commands: std.ArrayList(command_plan.Command) = .empty;
    defer commands.deinit(std.testing.allocator);
    const stats = try planReuse(&commands, &scratch, std.testing.allocator, &input, .q1, 1008);
    try std.testing.expect(stats.matches != 0);
    for (commands.items) |command|
        if (command.has_copy) try std.testing.expect(command.distance <= 1008);
    try expectReplays(&input, commands.items);
}

test "fast fragment preserves reusable capacity" {
    const first = "capacity-preserving-fragment-" ** 128;
    const second = "second-fragment-" ** 64;
    var scratch: Scratch = .{};
    defer scratch.deinit(std.testing.allocator);
    var commands: std.ArrayList(command_plan.Command) = .empty;
    defer commands.deinit(std.testing.allocator);

    _ = try planReuse(&commands, &scratch, std.testing.allocator, first, .q1, 65520);
    const table_capacity = scratch.table.capacity;
    const command_capacity = commands.capacity;
    _ = try planReuse(&commands, &scratch, std.testing.allocator, second, .q1, 65520);
    try std.testing.expectEqual(table_capacity, scratch.table.capacity);
    try std.testing.expectEqual(command_capacity, commands.capacity);
    try expectReplays(second, commands.items);
}
