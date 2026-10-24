const std = @import("std");
const core = @import("../core.zig");
const block_format = @import("block_format.zig");
const fast = @import("fast_options.zig");
const alias = @import("fast_input.zig");
pub const Error = core.Error || std.mem.Allocator.Error || error{WorkingMemoryLimitExceeded};
pub const Match = struct { start: usize = 0, len: usize = 0 };
const max_match_offset = std.math.maxInt(u16);
const hash_table_len = 64 * 1024;
const hash_occupancy_words = hash_table_len / @bitSizeOf(u64);
const chain_table_len = 64 * 1024;
const chain_table_mask = chain_table_len - 1;
const invalid_pos = std.math.maxInt(u32);
const good_match_len = 64;
const lazy_extra_gain = 1;

pub fn encodeBlockInto(
    comptime Emitter: type,
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    caller_input: []const u8,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
    options: fast.Work,
) Error!usize {
    options.begin();
    const out_start = out.items.len;
    if (caller_input.len == 0) return 0;
    if (table.len < hash_table_len or
        occupancy_bits.len < hash_occupancy_words or
        chain_table.len < chain_table_len or
        caller_input.len > std.math.maxInt(u32))
    {
        return error.IntegerOverflow;
    }
    var snapshot = try alias.Snapshot.init(allocator, out.allocatedSlice(), caller_input, "");
    defer snapshot.deinit(allocator);
    const input = snapshot.input;
    // Only clear a small occupancy bitset per block. The position table is
    // intentionally left uninitialized/reused; entries are read only when their
    // occupancy bit is set. The chain table is also initialized lazily because
    // candidates outside LZ4's 64 KiB window are never followed.
    @memset(occupancy_bits[0..hash_occupancy_words], 0);
    try out.ensureUnusedCapacity(allocator, try maxCompressedLen(input.len));

    var anchor: usize = 0;
    var index: usize = 0;
    var schedule = fast.MissSchedule.init(options.acceleration);
    while (block_format.hasMatchSearchRoom(index, input.len)) {
        var match_index = index;
        var best = insertAndFindBest(input, index, table, occupancy_bits, chain_table, options);
        if (best.len != 0 and 13 <= input.len - index and best.len < good_match_len) {
            const next = insertAndFindBest(input, index + 1, table, occupancy_bits, chain_table, options);
            if (next.len > best.len + lazy_extra_gain) {
                match_index = index + 1;
                best = next;
            }
        }

        if (best.len != 0) {
            var match_start = match_index;
            var candidate_start = best.start;
            var match_len = best.len;
            while (match_start > anchor and candidate_start > 0 and input[match_start - 1] == input[candidate_start - 1]) {
                match_start -= 1;
                candidate_start -= 1;
                match_len += 1;
            }
            match_len = @min(
                match_len,
                block_format.maxMatchLen(match_start, input.len),
            );
            std.debug.assert(match_len >= block_format.min_match_len);
            try Emitter.emitSequence(allocator, out, input[anchor..match_start], @intCast(match_start - candidate_start), match_len);
            index = match_start + match_len;
            anchor = index;
            schedule.reset();
            if (index >= input.len) break;
            const seed_start = match_start + 1;
            var seed = seed_start;
            while (seed < index and 4 <= input.len - seed) : (seed += 1) {
                _ = insertHash(input, seed, table, occupancy_bits, chain_table);
                options.count("match_positions_seeded", 1);
            }
        } else {
            index = schedule.advance(index, input.len - block_format.match_find_limit, options);
        }
    }
    try Emitter.emitLastLiteral(allocator, out, input[anchor..]);
    return out.items.len - out_start;
}

pub fn encodeLinkedBlockInto(
    comptime Emitter: type,
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    caller_history: []const u8,
    caller_input: []const u8,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
    options: fast.Work,
) Error!usize {
    options.begin();
    const out_start = out.items.len;
    if (caller_input.len == 0) return 0;
    const block_start = caller_history.len;
    const virtual_len = try checkedAdd(caller_history.len, caller_input.len);
    if (table.len < hash_table_len or
        occupancy_bits.len < hash_occupancy_words or
        chain_table.len < chain_table_len or
        virtual_len > std.math.maxInt(u32))
    {
        return error.IntegerOverflow;
    }
    var snapshot = try alias.Snapshot.init(allocator, out.allocatedSlice(), caller_input, caller_history);
    defer snapshot.deinit(allocator);
    const input = snapshot.input;
    const history = snapshot.prefix;

    @memset(occupancy_bits[0..hash_occupancy_words], 0);
    try out.ensureUnusedCapacity(allocator, try maxCompressedLen(input.len));

    // Linked LZ4 blocks may reference the previous 64 KiB of decoded frame
    // history. Seed that prefix into the same bounded hash-chain tables used by
    // independent blocks, then emit only sequences whose literals live in the
    // current block. Candidate positions near the history/block boundary are
    // intentionally allowed to hash across the boundary: the decoder can replay
    // such matches by copying the history bytes first and then overlapping with
    // the output it just produced.
    var seed: usize = 0;
    while (seed < block_start and 4 <= virtual_len - seed) : (seed += 1) {
        _ = insertLinkedHash(history, input, seed, table, occupancy_bits, chain_table);
        options.count("history_positions_seeded", 1);
    }

    var anchor: usize = block_start;
    var index: usize = block_start;
    var schedule = fast.MissSchedule.init(options.acceleration);
    while (block_format.hasMatchSearchRoom(index, virtual_len)) {
        var match_index = index;
        var best = insertAndFindBestLinked(history, input, index, table, occupancy_bits, chain_table, options);
        if (best.len != 0 and 13 <= virtual_len - index and best.len < good_match_len) {
            const next = insertAndFindBestLinked(history, input, index + 1, table, occupancy_bits, chain_table, options);
            if (next.len > best.len + lazy_extra_gain) {
                match_index = index + 1;
                best = next;
            }
        }

        if (best.len != 0) {
            var match_start = match_index;
            var candidate_start = best.start;
            var match_len = best.len;
            while (match_start > anchor and candidate_start > 0 and linkedByteAt(history, input, match_start - 1) == linkedByteAt(history, input, candidate_start - 1)) {
                match_start -= 1;
                candidate_start -= 1;
                match_len += 1;
            }
            match_len = @min(
                match_len,
                block_format.maxMatchLen(match_start, virtual_len),
            );
            std.debug.assert(match_len >= block_format.min_match_len);
            const literal_start = anchor - block_start;
            const literal_end = match_start - block_start;
            try Emitter.emitSequence(
                allocator,
                out,
                input[literal_start..literal_end],
                @intCast(match_start - candidate_start),
                match_len,
            );
            index = match_start + match_len;
            anchor = index;
            schedule.reset();
            if (index >= virtual_len) break;
            seed = match_start + 1;
            while (seed < index and 4 <= virtual_len - seed) : (seed += 1) {
                _ = insertLinkedHash(history, input, seed, table, occupancy_bits, chain_table);
                options.count("match_positions_seeded", 1);
            }
        } else {
            index = schedule.advance(index, virtual_len - block_format.match_find_limit, options);
        }
    }

    try Emitter.emitLastLiteral(allocator, out, input[anchor - block_start ..]);
    return out.items.len - out_start;
}

pub fn insertAndFindBest(
    input: []const u8,
    index: usize,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
    options: fast.Work,
) Match {
    options.count("positions_inspected", 1);
    const candidate_entry = insertHash(input, index, table, occupancy_bits, chain_table);

    var best: Match = .{};
    var candidate = candidate_entry;
    var depth: usize = 0;
    while (candidate != invalid_pos and depth < options.chain_depth) : (depth += 1) {
        const candidate_start: usize = @intCast(candidate);
        if (candidate_start >= index) break;
        if (index - candidate_start > max_match_offset) break;
        options.count("chain_candidates", 1);
        if (input[candidate_start] == input[index] and
            input[candidate_start + 1] == input[index + 1] and
            input[candidate_start + 2] == input[index + 2] and
            input[candidate_start + 3] == input[index + 3])
        {
            var match_len: usize = 4;
            while (index + match_len < input.len and input[candidate_start + match_len] == input[index + match_len]) {
                match_len += 1;
            }
            if (match_len > best.len) {
                best = .{ .start = candidate_start, .len = match_len };
                if (match_len >= good_match_len) break;
            }
        }
        candidate = chain_table[candidate_start & chain_table_mask];
    }
    return best;
}

pub fn insertAndFindBestLinked(
    history: []const u8,
    input: []const u8,
    index: usize,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
    options: fast.Work,
) Match {
    const virtual_len = history.len + input.len;
    options.count("positions_inspected", 1);
    const candidate_entry = insertLinkedHash(history, input, index, table, occupancy_bits, chain_table);

    var best: Match = .{};
    var candidate = candidate_entry;
    var depth: usize = 0;
    while (candidate != invalid_pos and depth < options.chain_depth) : (depth += 1) {
        const candidate_start: usize = @intCast(candidate);
        if (candidate_start >= index) break;
        if (index - candidate_start > max_match_offset) break;
        options.count("chain_candidates", 1);
        if (linkedByteAt(history, input, candidate_start) == linkedByteAt(history, input, index) and
            linkedByteAt(history, input, candidate_start + 1) == linkedByteAt(history, input, index + 1) and
            linkedByteAt(history, input, candidate_start + 2) == linkedByteAt(history, input, index + 2) and
            linkedByteAt(history, input, candidate_start + 3) == linkedByteAt(history, input, index + 3))
        {
            var match_len: usize = 4;
            while (index + match_len < virtual_len and linkedByteAt(history, input, candidate_start + match_len) == linkedByteAt(history, input, index + match_len)) {
                match_len += 1;
            }
            if (match_len > best.len) {
                best = .{ .start = candidate_start, .len = match_len };
                if (match_len >= good_match_len) break;
            }
        }
        candidate = chain_table[candidate_start & chain_table_mask];
    }
    return best;
}

pub fn insertHash(
    input: []const u8,
    index: usize,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
) u32 {
    const h = hash4(input[index..][0..4]);
    const candidate_seen = hashOccupied(occupancy_bits, h);
    const candidate_entry = if (candidate_seen) table[h] else invalid_pos;
    markHashOccupied(occupancy_bits, h);

    // Lazy matching can probe index+1 before knowing whether the current match
    // wins; back-extension and seeding can later revisit the same index. Avoid
    // turning that ring slot into a self-loop that wastes bounded chain depth.
    if (candidate_entry == index) return chain_table[index & chain_table_mask];

    table[h] = @intCast(index);
    chain_table[index & chain_table_mask] = candidate_entry;
    return candidate_entry;
}

pub fn insertLinkedHash(
    history: []const u8,
    input: []const u8,
    index: usize,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
) u32 {
    const h = hashLinked4(history, input, index);
    const candidate_seen = hashOccupied(occupancy_bits, h);
    const candidate_entry = if (candidate_seen) table[h] else invalid_pos;
    markHashOccupied(occupancy_bits, h);

    if (candidate_entry == index) return chain_table[index & chain_table_mask];

    table[h] = @intCast(index);
    chain_table[index & chain_table_mask] = candidate_entry;
    return candidate_entry;
}

fn hashOccupied(occupancy_bits: []const u64, hash: usize) bool {
    const word = hash >> 6;
    const bit: u6 = @intCast(hash & 63);
    return (occupancy_bits[word] & (@as(u64, 1) << bit)) != 0;
}

fn markHashOccupied(occupancy_bits: []u64, hash: usize) void {
    const word = hash >> 6;
    const bit: u6 = @intCast(hash & 63);
    occupancy_bits[word] |= @as(u64, 1) << bit;
}

fn hash4(bytes: *const [4]u8) usize {
    const value = std.mem.readInt(u32, bytes, .little);
    return @intCast((value *% 2654435761) >> 16);
}

fn hashLinked4(history: []const u8, input: []const u8, index: usize) usize {
    var bytes: [4]u8 = undefined;
    inline for (0..4) |i| bytes[i] = linkedByteAt(history, input, index + i);
    return hash4(&bytes);
}

fn linkedByteAt(history: []const u8, input: []const u8, index: usize) u8 {
    return if (index < history.len) history[index] else input[index - history.len];
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}
fn maxCompressedLen(input_len: usize) Error!usize {
    return checkedAdd(try checkedAdd(input_len, input_len / 255), 16);
}
