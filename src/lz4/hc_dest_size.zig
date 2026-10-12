const std = @import("std");
const dest_size = @import("dest_size.zig");

pub const Error = std.mem.Allocator.Error || error{
    InputTooLarge,
    OutputTooSmall,
};

pub const Result = dest_size.Result;

const min_match = 4;
const last_literals = 5;
const match_find_margin = 12;
const min_input_len = match_find_margin + 1;
const max_distance = std.math.maxInt(u16);
const hash_log = 15;
const hash_table_len = 1 << hash_log;
const chain_table_len = 1 << 16;
const chain_mask = chain_table_len - 1;
const base_index: u32 = chain_table_len;
const optimal_match_len = 18;
const optimal_slots = 1 << 12;
const trailing_literals = 3;
const max_input_len = 0x7e00_0000;

const Optimal = struct {
    price: usize = 0,
    offset: usize = 0,
    match_len: usize = 0,
    literal_len: usize = 0,
};

const Match = struct {
    len: usize,
    position: usize = 0,
    start: usize = 0,
};

const Context = struct {
    input: []const u8,
    hash_table: []u32,
    chain_table: []u16,
    next_to_update: u32 = base_index,

    fn reset(self: *Context, input: []const u8) void {
        self.input = input;
        @memset(self.hash_table, 0);
        @memset(self.chain_table, max_distance);
        self.next_to_update = base_index;
    }

    fn insert(self: *Context, target_position: usize) void {
        const target: u32 = base_index + @as(u32, @intCast(target_position));
        var index = self.next_to_update;
        while (index < target) : (index += 1) {
            const position: usize = @intCast(index - base_index);
            const hash = hashAt(self.input, position);
            const previous = self.hash_table[hash];
            const distance = @min(index - previous, @as(u32, max_distance));
            self.chain_table[index & chain_mask] = @intCast(distance);
            self.hash_table[hash] = index;
        }
        self.next_to_update = target;
    }
};

/// Reusable liblz4 1.9.3-compatible LZ4HC fill-output encoder.
///
/// Every call models a fresh `LZ4_compress_HC_destSize()` state. The large
/// hash, chain, and optimal-parser workspaces are retained across calls while
/// the tables themselves are reset, matching the upstream API's independent
/// block behavior.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    hash_table: []u32,
    chain_table: []u16,
    optimal: []Optimal,

    pub fn init(allocator: std.mem.Allocator) std.mem.Allocator.Error!Encoder {
        const hash_table = try allocator.alloc(u32, hash_table_len);
        errdefer allocator.free(hash_table);
        const chain_table = try allocator.alloc(u16, chain_table_len);
        errdefer allocator.free(chain_table);
        return .{
            .allocator = allocator,
            .hash_table = hash_table,
            .chain_table = chain_table,
            .optimal = &.{},
        };
    }

    pub fn deinit(self: *Encoder) void {
        self.allocator.free(self.hash_table);
        self.allocator.free(self.chain_table);
        if (self.optimal.len != 0) self.allocator.free(self.optimal);
        self.* = undefined;
    }

    pub fn compress(
        self: *Encoder,
        input: []const u8,
        output: []u8,
        compression_level: i32,
    ) Error!Result {
        if (input.len > max_input_len) return error.InputTooLarge;
        if (output.len == 0) return error.OutputTooSmall;
        var context = Context{
            .input = input,
            .hash_table = self.hash_table,
            .chain_table = self.chain_table,
        };
        context.reset(input);
        const level = normalizeLevel(compression_level);
        if (level >= 10 and self.optimal.len == 0)
            self.optimal = try self.allocator.alloc(
                Optimal,
                optimal_slots + trailing_literals,
            );
        return switch (level) {
            1, 2 => compressHashChain(&context, output, 2),
            3 => compressHashChain(&context, output, 4),
            4 => compressHashChain(&context, output, 8),
            5 => compressHashChain(&context, output, 16),
            6 => compressHashChain(&context, output, 32),
            7 => compressHashChain(&context, output, 64),
            8 => compressHashChain(&context, output, 128),
            9 => compressHashChain(&context, output, 256),
            10 => compressOptimal(&context, output, self.optimal, 96, 64, false),
            11 => compressOptimal(&context, output, self.optimal, 512, 128, false),
            12 => compressOptimal(&context, output, self.optimal, 16_384, optimal_slots, true),
            else => unreachable,
        };
    }
};

pub fn compress(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    compression_level: i32,
) Error!Result {
    var encoder = try Encoder.init(allocator);
    defer encoder.deinit();
    return encoder.compress(input, output, compression_level);
}

fn normalizeLevel(level: i32) u8 {
    if (level < 1) return 9;
    return @intCast(@min(level, 12));
}

fn compressHashChain(
    context: *Context,
    output: []u8,
    max_attempts: usize,
) Result {
    const input = context.input;
    if (input.len < min_input_len)
        return emitLastLiterals(input, output, 0, 0);
    const match_find_position_limit = input.len - match_find_margin;
    const match_limit = input.len - last_literals;
    const reserved_end: isize = @as(isize, @intCast(output.len)) - last_literals;
    const pattern_analysis = max_attempts > 128;

    var input_position: usize = 0;
    var anchor: usize = 0;
    var output_position: usize = 0;

    main_loop: while (input_position <= match_find_position_limit) {
        const first = findWiderMatch(
            context,
            input_position,
            input_position,
            match_limit,
            min_match - 1,
            max_attempts,
            pattern_analysis,
            false,
        );
        if (first.len < min_match) {
            input_position += 1;
            continue;
        }

        var match_len = first.len;
        var match_position = first.position;
        var original_start = input_position;
        var original_match = match_position;
        var original_len = match_len;

        search2: while (true) {
            const second = if (input_position + match_len <= match_find_position_limit)
                findWiderMatch(
                    context,
                    input_position + match_len - 2,
                    input_position,
                    match_limit,
                    match_len,
                    max_attempts,
                    pattern_analysis,
                    false,
                )
            else
                Match{ .len = match_len };

            if (second.len == match_len) {
                const output_saved = output_position;
                if (encodeSequence(
                    input,
                    output,
                    &input_position,
                    &output_position,
                    &anchor,
                    match_len,
                    match_position,
                    reserved_end,
                    true,
                )) return finishOverflow(
                    input,
                    output,
                    output_saved,
                    input_position,
                    anchor,
                    match_len,
                    match_position,
                    reserved_end,
                );
                continue :main_loop;
            }

            var second_start = second.start;
            var second_match = second.position;
            var second_len = second.len;
            if (original_start < input_position and
                second_start < input_position + original_len)
            {
                input_position = original_start;
                match_position = original_match;
                match_len = original_len;
            }
            if (second_start - input_position < 3) {
                match_len = second_len;
                input_position = second_start;
                match_position = second_match;
                original_start = input_position;
                original_match = match_position;
                original_len = match_len;
                continue :search2;
            }

            search3: while (true) {
                if (second_start - input_position < optimal_match_len) {
                    var new_len: usize = @min(match_len, optimal_match_len);
                    if (input_position + new_len > second_start + second_len - min_match)
                        new_len = second_start - input_position + second_len - min_match;
                    const gap = second_start - input_position;
                    if (new_len > gap) {
                        const correction = new_len - gap;
                        second_start += correction;
                        second_match += correction;
                        second_len -= correction;
                    }
                }

                const third = if (second_start + second_len <= match_find_position_limit)
                    findWiderMatch(
                        context,
                        second_start + second_len - 3,
                        second_start,
                        match_limit,
                        second_len,
                        max_attempts,
                        pattern_analysis,
                        false,
                    )
                else
                    Match{ .len = second_len };

                if (third.len == second_len) {
                    if (second_start < input_position + match_len)
                        match_len = second_start - input_position;
                    var output_saved = output_position;
                    if (encodeSequence(
                        input,
                        output,
                        &input_position,
                        &output_position,
                        &anchor,
                        match_len,
                        match_position,
                        reserved_end,
                        true,
                    )) return finishOverflow(
                        input,
                        output,
                        output_saved,
                        input_position,
                        anchor,
                        match_len,
                        match_position,
                        reserved_end,
                    );
                    input_position = second_start;
                    output_saved = output_position;
                    if (encodeSequence(
                        input,
                        output,
                        &input_position,
                        &output_position,
                        &anchor,
                        second_len,
                        second_match,
                        reserved_end,
                        true,
                    )) return finishOverflow(
                        input,
                        output,
                        output_saved,
                        input_position,
                        anchor,
                        second_len,
                        second_match,
                        reserved_end,
                    );
                    continue :main_loop;
                }

                const third_start = third.start;
                const third_match = third.position;
                const third_len = third.len;
                if (third_start < input_position + match_len + 3) {
                    if (third_start >= input_position + match_len) {
                        if (second_start < input_position + match_len) {
                            const correction = input_position + match_len - second_start;
                            second_start += correction;
                            second_match += correction;
                            second_len -= correction;
                            if (second_len < min_match) {
                                second_start = third_start;
                                second_match = third_match;
                                second_len = third_len;
                            }
                        }
                        const output_saved = output_position;
                        if (encodeSequence(
                            input,
                            output,
                            &input_position,
                            &output_position,
                            &anchor,
                            match_len,
                            match_position,
                            reserved_end,
                            true,
                        )) return finishOverflow(
                            input,
                            output,
                            output_saved,
                            input_position,
                            anchor,
                            match_len,
                            match_position,
                            reserved_end,
                        );
                        input_position = third_start;
                        match_position = third_match;
                        match_len = third_len;
                        original_start = second_start;
                        original_match = second_match;
                        original_len = second_len;
                        continue :search2;
                    }
                    second_start = third_start;
                    second_match = third_match;
                    second_len = third_len;
                    continue :search3;
                }

                if (second_start < input_position + match_len) {
                    if (second_start - input_position < optimal_match_len) {
                        match_len = @min(match_len, @as(usize, optimal_match_len));
                        if (input_position + match_len > second_start + second_len - min_match)
                            match_len = second_start - input_position + second_len - min_match;
                        const gap = second_start - input_position;
                        if (match_len > gap) {
                            const correction = match_len - gap;
                            second_start += correction;
                            second_match += correction;
                            second_len -= correction;
                        }
                    } else {
                        match_len = second_start - input_position;
                    }
                }
                const output_saved = output_position;
                if (encodeSequence(
                    input,
                    output,
                    &input_position,
                    &output_position,
                    &anchor,
                    match_len,
                    match_position,
                    reserved_end,
                    true,
                )) return finishOverflow(
                    input,
                    output,
                    output_saved,
                    input_position,
                    anchor,
                    match_len,
                    match_position,
                    reserved_end,
                );

                input_position = second_start;
                match_position = second_match;
                match_len = second_len;
                second_start = third_start;
                second_match = third_match;
                second_len = third_len;
            }
        }
    }
    return emitLastLiterals(input, output, output_position, anchor);
}

fn compressOptimal(
    context: *Context,
    output: []u8,
    optimal: []Optimal,
    search_count: usize,
    requested_sufficient_len: usize,
    full_update: bool,
) Result {
    const input = context.input;
    if (input.len < min_input_len)
        return emitLastLiterals(input, output, 0, 0);
    const match_find_position_limit = input.len - match_find_margin;
    const match_limit = input.len - last_literals;
    const reserved_end: isize = @as(isize, @intCast(output.len)) - last_literals;
    const sufficient_len = @min(requested_sufficient_len, optimal_slots - 1);

    var input_position: usize = 0;
    var anchor: usize = 0;
    var output_position: usize = 0;

    while (input_position <= match_find_position_limit) {
        const initial_literal_len = input_position - anchor;
        const first_match = findLongerMatch(
            context,
            input_position,
            match_limit,
            min_match - 1,
            search_count,
        );
        if (first_match.len == 0) {
            input_position += 1;
            continue;
        }
        if (first_match.len > sufficient_len) {
            const output_saved = output_position;
            if (encodeSequence(
                input,
                output,
                &input_position,
                &output_position,
                &anchor,
                first_match.len,
                first_match.position,
                reserved_end,
                true,
            )) return finishOverflow(
                input,
                output,
                output_saved,
                input_position,
                anchor,
                first_match.len,
                first_match.position,
                reserved_end,
            );
            continue;
        }

        for (0..min_match) |relative_position| {
            const cost = literalsPrice(initial_literal_len + relative_position);
            optimal[relative_position] = .{
                .match_len = 1,
                .offset = 0,
                .literal_len = initial_literal_len + relative_position,
                .price = cost,
            };
        }
        var match_len: usize = min_match;
        const first_offset = input_position - first_match.position;
        while (match_len <= first_match.len) : (match_len += 1) {
            optimal[match_len] = .{
                .match_len = match_len,
                .offset = first_offset,
                .literal_len = initial_literal_len,
                .price = sequencePrice(initial_literal_len, match_len),
            };
        }
        var last_match_position = first_match.len;
        for (1..trailing_literals + 1) |added_literals| {
            optimal[last_match_position + added_literals] = .{
                .match_len = 1,
                .offset = 0,
                .literal_len = added_literals,
                .price = optimal[last_match_position].price +
                    literalsPrice(added_literals),
            };
        }

        var current: usize = 1;
        var best_match_len: usize = 0;
        var best_offset: usize = 0;
        var encode_immediately = false;
        while (current < last_match_position) : (current += 1) {
            const current_position = input_position + current;
            if (current_position > match_find_position_limit) break;
            if (full_update) {
                if (optimal[current + 1].price <= optimal[current].price and
                    optimal[current + min_match].price < optimal[current].price + 3)
                    continue;
            } else if (optimal[current + 1].price <= optimal[current].price) {
                continue;
            }

            const new_match = findLongerMatch(
                context,
                current_position,
                match_limit,
                if (full_update) min_match - 1 else last_match_position - current,
                search_count,
            );
            if (new_match.len == 0) continue;
            if (new_match.len > sufficient_len or
                new_match.len + current >= optimal_slots)
            {
                best_match_len = new_match.len;
                best_offset = current_position - new_match.position;
                last_match_position = current + 1;
                encode_immediately = true;
                break;
            }

            const base_literal_len = optimal[current].literal_len;
            for (1..min_match) |literal_len| {
                const price = optimal[current].price -
                    literalsPrice(base_literal_len) +
                    literalsPrice(base_literal_len + literal_len);
                const position = current + literal_len;
                if (price < optimal[position].price) {
                    optimal[position] = .{
                        .match_len = 1,
                        .offset = 0,
                        .literal_len = base_literal_len + literal_len,
                        .price = price,
                    };
                }
            }

            match_len = min_match;
            const new_offset = current_position - new_match.position;
            while (match_len <= new_match.len) : (match_len += 1) {
                const position = current + match_len;
                const literal_len: usize = if (optimal[current].match_len == 1)
                    optimal[current].literal_len
                else
                    0;
                const previous_price = if (optimal[current].match_len == 1 and
                    current > literal_len)
                    optimal[current - literal_len].price
                else if (optimal[current].match_len == 1)
                    0
                else
                    optimal[current].price;
                const price = previous_price + sequencePrice(literal_len, match_len);
                if (position > last_match_position + trailing_literals or
                    price <= optimal[position].price)
                {
                    if (match_len == new_match.len and
                        last_match_position < position)
                        last_match_position = position;
                    optimal[position] = .{
                        .match_len = match_len,
                        .offset = new_offset,
                        .literal_len = literal_len,
                        .price = price,
                    };
                }
            }
            for (1..trailing_literals + 1) |added_literals| {
                optimal[last_match_position + added_literals] = .{
                    .match_len = 1,
                    .offset = 0,
                    .literal_len = added_literals,
                    .price = optimal[last_match_position].price +
                        literalsPrice(added_literals),
                };
            }
        }

        if (!encode_immediately) {
            best_match_len = optimal[last_match_position].match_len;
            best_offset = optimal[last_match_position].offset;
            current = last_match_position - best_match_len;
        }

        var candidate_position = current;
        var selected_match_len = best_match_len;
        var selected_offset = best_offset;
        while (true) {
            const next_match_len = optimal[candidate_position].match_len;
            const next_offset = optimal[candidate_position].offset;
            optimal[candidate_position].match_len = selected_match_len;
            optimal[candidate_position].offset = selected_offset;
            selected_match_len = next_match_len;
            selected_offset = next_offset;
            if (next_match_len > candidate_position) break;
            candidate_position -= next_match_len;
        }

        var relative_position: usize = 0;
        while (relative_position < last_match_position) {
            const selected = optimal[relative_position];
            if (selected.match_len == 1) {
                input_position += 1;
                relative_position += 1;
                continue;
            }
            relative_position += selected.match_len;
            const output_saved = output_position;
            const match_position = input_position - selected.offset;
            if (encodeSequence(
                input,
                output,
                &input_position,
                &output_position,
                &anchor,
                selected.match_len,
                match_position,
                reserved_end,
                true,
            )) return finishOverflow(
                input,
                output,
                output_saved,
                input_position,
                anchor,
                selected.match_len,
                match_position,
                reserved_end,
            );
        }
    }
    return emitLastLiterals(input, output, output_position, anchor);
}

fn findLongerMatch(
    context: *Context,
    input_position: usize,
    input_high_limit: usize,
    minimum_len: usize,
    search_count: usize,
) Match {
    const match = findWiderMatch(
        context,
        input_position,
        input_position,
        input_high_limit,
        minimum_len,
        search_count,
        true,
        true,
    );
    if (match.len <= minimum_len) return .{ .len = 0 };
    return match;
}

fn findWiderMatch(
    context: *Context,
    input_position: usize,
    input_low_limit: usize,
    input_high_limit: usize,
    initial_longest: usize,
    max_attempts: usize,
    pattern_analysis: bool,
    chain_swap: bool,
) Match {
    const input = context.input;
    const input_index = base_index + @as(u32, @intCast(input_position));
    const lowest_match_index = @max(
        base_index,
        input_index -| @as(u32, max_distance),
    );
    const look_back = input_position - input_low_limit;
    const pattern = readU32(input, input_position);
    var longest = initial_longest;
    var best_position: usize = 0;
    var best_start = input_position;
    var attempts = max_attempts;
    var match_chain_position: u32 = 0;
    var source_pattern_length: usize = 0;
    var repeat_tested = false;
    var repeat_confirmed = false;

    context.insert(input_position);
    var match_index = context.hash_table[hashAt(input, input_position)];
    while (match_index >= lowest_match_index and attempts != 0) {
        attempts -= 1;
        const match_position: usize = @intCast(match_index - base_index);
        var match_length: usize = 0;
        const probe_position = match_position + longest -| look_back -| 1;
        if (match_position + longest >= look_back + 1 and
            readU16(input, input_low_limit + longest - 1) ==
                readU16(input, probe_position) and
            readU32(input, match_position) == pattern)
        {
            const back = countBack(
                input,
                input_position,
                match_position,
                input_low_limit,
            );
            match_length = min_match + countMatch(
                input,
                input_position + min_match,
                match_position + min_match,
                input_high_limit,
            ) + back;
            if (match_length > longest) {
                longest = match_length;
                best_position = match_position - back;
                best_start = input_position - back;
            }
        }

        if (chain_swap and match_length == longest and
            match_index + @as(u32, @intCast(longest)) <= input_index)
        {
            var distance_to_next: u32 = 1;
            const end = longest - min_match + 1;
            var step: usize = 1;
            var acceleration: usize = 1 << 4;
            var position: usize = 0;
            while (position < end) : (position += step) {
                const candidate = context.chain_table[
                    (match_index + @as(u32, @intCast(position))) & chain_mask
                ];
                step = acceleration >> 4;
                acceleration += 1;
                if (candidate > distance_to_next) {
                    distance_to_next = candidate;
                    match_chain_position = @intCast(position);
                    acceleration = 1 << 4;
                }
            }
            if (distance_to_next > 1) {
                if (distance_to_next > match_index) break;
                match_index -= distance_to_next;
                continue;
            }
        }

        const distance_next = context.chain_table[match_index & chain_mask];
        if (pattern_analysis and distance_next == 1 and
            match_chain_position == 0)
        {
            const candidate_index = match_index - 1;
            if (!repeat_tested) {
                repeat_tested = true;
                repeat_confirmed = (pattern & 0xffff) == (pattern >> 16) and
                    (pattern & 0xff) == (pattern >> 24);
                if (repeat_confirmed)
                    source_pattern_length = countPattern(
                        input,
                        input_position,
                        input_high_limit,
                        pattern,
                    );
            }
            if (repeat_confirmed and candidate_index >= lowest_match_index) {
                const candidate_position: usize = @intCast(candidate_index - base_index);
                if (readU32(input, candidate_position) == pattern) {
                    const forward = countPattern(
                        input,
                        candidate_position,
                        input_high_limit,
                        pattern,
                    );
                    var back = reverseCountPattern(
                        input,
                        candidate_position,
                        0,
                        pattern,
                    );
                    const lowest_position: usize = @intCast(lowest_match_index - base_index);
                    back = @min(back, candidate_position - lowest_position);
                    const segment_length = back + forward;
                    if (segment_length >= source_pattern_length and
                        forward <= source_pattern_length)
                    {
                        if (forward >= source_pattern_length) {
                            match_index = candidate_index + @as(
                                u32,
                                @intCast(forward - source_pattern_length),
                            );
                        } else {
                            match_index = candidate_index - @as(
                                u32,
                                @intCast(source_pattern_length - forward),
                            );
                        }
                    } else {
                        match_index = candidate_index - @as(u32, @intCast(back));
                        if (look_back == 0) {
                            const max_length = @min(segment_length, source_pattern_length);
                            if (longest < max_length) {
                                if (input_index - match_index > max_distance) break;
                                longest = max_length;
                                best_position = @intCast(match_index - base_index);
                                best_start = input_position;
                            }
                            const next_pattern = context.chain_table[match_index & chain_mask];
                            if (next_pattern > match_index) break;
                            match_index -= next_pattern;
                        }
                    }
                    continue;
                }
            }
        }

        const next = context.chain_table[
            (match_index + match_chain_position) & chain_mask
        ];
        if (next > match_index) break;
        match_index -= next;
    }
    return .{
        .len = longest,
        .position = best_position,
        .start = best_start,
    };
}

fn encodeSequence(
    input: []const u8,
    output: []u8,
    input_position: *usize,
    output_position: *usize,
    anchor: *usize,
    match_len: usize,
    match_position: usize,
    reserved_end: isize,
    limited: bool,
) bool {
    const literal_len = input_position.* - anchor.*;
    const token_position = output_position.*;
    var cursor = token_position + 1;
    if (limited and @as(isize, @intCast(
        cursor + literal_len / 255 + literal_len + 2 + 1 + last_literals,
    )) > reserved_end) return true;

    if (literal_len >= 15) {
        output[token_position] = 15 << 4;
        var remaining = literal_len - 15;
        while (remaining >= 255) : (remaining -= 255) {
            output[cursor] = 255;
            cursor += 1;
        }
        output[cursor] = @intCast(remaining);
        cursor += 1;
    } else {
        output[token_position] = @intCast(literal_len << 4);
    }
    @memcpy(
        output[cursor..][0..literal_len],
        input[anchor.*..input_position.*],
    );
    cursor += literal_len;
    std.mem.writeInt(
        u16,
        output[cursor..][0..2],
        @intCast(input_position.* - match_position),
        .little,
    );
    cursor += 2;

    var match_code = match_len - min_match;
    if (limited and @as(isize, @intCast(
        cursor + match_code / 255 + 1 + last_literals,
    )) > reserved_end) return true;
    if (match_code >= 15) {
        output[token_position] += 15;
        match_code -= 15;
        while (match_code >= 510) : (match_code -= 510) {
            output[cursor] = 255;
            output[cursor + 1] = 255;
            cursor += 2;
        }
        if (match_code >= 255) {
            match_code -= 255;
            output[cursor] = 255;
            cursor += 1;
        }
        output[cursor] = @intCast(match_code);
        cursor += 1;
    } else {
        output[token_position] += @intCast(match_code);
    }
    output_position.* = cursor;
    input_position.* += match_len;
    anchor.* = input_position.*;
    return false;
}

fn finishOverflow(
    input: []const u8,
    output: []u8,
    output_saved: usize,
    initial_input_position: usize,
    initial_anchor: usize,
    initial_match_len: usize,
    match_position: usize,
    reserved_end: isize,
) Result {
    var input_position = initial_input_position;
    var anchor = initial_anchor;
    var output_position = output_saved;
    var match_len = initial_match_len;
    const literal_len = input_position - anchor;
    const literal_add_bytes = (literal_len + 240) / 255;
    const literal_cost = 1 + literal_add_bytes + literal_len;
    const max_literal_position = reserved_end - 3;
    if (max_literal_position >= 0 and
        @as(isize, @intCast(output_position + literal_cost)) <= max_literal_position)
    {
        const bytes_for_match: usize = @intCast(
            max_literal_position - @as(isize, @intCast(output_position + literal_cost)),
        );
        const max_match_len = min_match + 14 + bytes_for_match * 255;
        match_len = @min(match_len, max_match_len);
        const remaining_expression = @as(isize, @intCast(output.len)) -
            @as(isize, @intCast(output_position + literal_cost + 2)) - 1 +
            @as(isize, @intCast(match_len));
        if (remaining_expression >= match_find_margin) {
            _ = encodeSequence(
                input,
                output,
                &input_position,
                &output_position,
                &anchor,
                match_len,
                match_position,
                reserved_end,
                false,
            );
        }
    }
    return emitLastLiterals(input, output, output_position, anchor);
}

fn emitLastLiterals(
    input: []const u8,
    output: []u8,
    initial_output_position: usize,
    anchor: usize,
) Result {
    var output_position = initial_output_position;
    var literal_len = input.len - anchor;
    const add_bytes = (literal_len + 255 - 15) / 255;
    const total_size = 1 + add_bytes + literal_len;
    if (output_position + total_size > output.len) {
        literal_len = output.len - output_position - 1;
        literal_len -= (literal_len + 256 - 15) / 256;
    }
    if (literal_len >= 15) {
        output[output_position] = 15 << 4;
        output_position += 1;
        var remaining = literal_len - 15;
        while (remaining >= 255) : (remaining -= 255) {
            output[output_position] = 255;
            output_position += 1;
        }
        output[output_position] = @intCast(remaining);
        output_position += 1;
    } else {
        output[output_position] = @intCast(literal_len << 4);
        output_position += 1;
    }
    @memcpy(
        output[output_position..][0..literal_len],
        input[anchor..][0..literal_len],
    );
    output_position += literal_len;
    return .{
        .written = output_position,
        .consumed = anchor + literal_len,
    };
}

fn literalsPrice(literal_len: usize) usize {
    return literal_len + if (literal_len >= 15)
        1 + (literal_len - 15) / 255
    else
        0;
}

fn sequencePrice(literal_len: usize, match_len: usize) usize {
    return 3 + literalsPrice(literal_len) + if (match_len >= 19)
        1 + (match_len - 19) / 255
    else
        0;
}

fn hashAt(input: []const u8, position: usize) usize {
    const value = readU32(input, position) *% @as(u32, 2_654_435_761);
    return @intCast(value >> (32 - hash_log));
}

fn readU16(input: []const u8, position: usize) u16 {
    return std.mem.readInt(u16, input[position..][0..2], .little);
}

fn readU32(input: []const u8, position: usize) u32 {
    return std.mem.readInt(u32, input[position..][0..4], .little);
}

fn countMatch(
    input: []const u8,
    input_position: usize,
    match_position: usize,
    limit: usize,
) usize {
    var current = input_position;
    var candidate = match_position;
    while (current < limit and input[current] == input[candidate]) {
        current += 1;
        candidate += 1;
    }
    return current - input_position;
}

fn countBack(
    input: []const u8,
    input_position: usize,
    match_position: usize,
    input_low_limit: usize,
) usize {
    var count: usize = 0;
    while (input_position - count > input_low_limit and
        match_position > count and
        input[input_position - count - 1] == input[match_position - count - 1])
    {
        count += 1;
    }
    return count;
}

fn countPattern(
    input: []const u8,
    start: usize,
    limit: usize,
    pattern: u32,
) usize {
    var position = start;
    while (position < limit) : (position += 1) {
        const shift: u5 = @intCast((position - start & 3) * 8);
        if (input[position] != @as(u8, @truncate(pattern >> shift))) break;
    }
    return position - start;
}

fn reverseCountPattern(
    input: []const u8,
    start: usize,
    low: usize,
    pattern: u32,
) usize {
    var position = start;
    var pattern_index: usize = 3;
    while (position > low) {
        if (input[position - 1] != @as(u8, @truncate(pattern >> @as(u5, @intCast(pattern_index * 8)))))
            break;
        position -= 1;
        pattern_index = (pattern_index -% 1) & 3;
    }
    return start - position;
}

test "LZ4HC dest-size handles empty and one-byte output" {
    var encoder = try Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    var output: [16]u8 = undefined;
    var result = try encoder.compress("", output[0..], 9);
    try std.testing.expectEqual(@as(usize, 1), result.written);
    try std.testing.expectEqual(@as(usize, 0), result.consumed);
    result = try encoder.compress("hello", output[0..1], 9);
    try std.testing.expectEqual(@as(usize, 1), result.written);
    try std.testing.expectEqual(@as(usize, 0), result.consumed);
    try std.testing.expectError(
        error.OutputTooSmall,
        encoder.compress("hello", output[0..0], 9),
    );
}

test "LZ4HC dest-size matches pinned liblz4 1.9.3 vectors" {
    var encoder = try Encoder.init(std.testing.allocator);
    defer encoder.deinit();
    const input = "abcabcabcabcabcabcabcabc0123456789" ** 32;
    const vectors = [_]struct {
        level: i32,
        capacity: usize,
        consumed: usize,
        encoded: []const u8,
    }{
        .{
            .level = 5,
            .capacity = 16,
            .consumed = 32,
            .encoded = &.{ 0x3f, 0x61, 0x62, 0x63, 0x03, 0x00, 0x02, 0x80, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37 },
        },
        .{
            .level = 9,
            .capacity = 31,
            .consumed = input.len,
            .encoded = &.{ 0x3f, 0x61, 0x62, 0x63, 0x03, 0x00, 0x02, 0xaf, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x22, 0x00, 0xff, 0xff, 0xff, 0xff, 0x0a, 0x50, 0x35, 0x36, 0x37, 0x38, 0x39 },
        },
        .{
            .level = 10,
            .capacity = 31,
            .consumed = input.len,
            .encoded = &.{ 0x3f, 0x61, 0x62, 0x63, 0x03, 0x00, 0x02, 0xaf, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x22, 0x00, 0xff, 0xff, 0xff, 0xff, 0x0a, 0x50, 0x35, 0x36, 0x37, 0x38, 0x39 },
        },
        .{
            .level = 12,
            .capacity = 64,
            .consumed = input.len,
            .encoded = &.{ 0x3f, 0x61, 0x62, 0x63, 0x03, 0x00, 0x02, 0xaf, 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x22, 0x00, 0xff, 0xff, 0xff, 0xff, 0x0a, 0x50, 0x35, 0x36, 0x37, 0x38, 0x39 },
        },
    };
    for (vectors) |vector| {
        var output: [64]u8 = undefined;
        const result = try encoder.compress(
            input,
            output[0..vector.capacity],
            vector.level,
        );
        try std.testing.expectEqual(vector.consumed, result.consumed);
        try std.testing.expectEqual(vector.encoded.len, result.written);
        try std.testing.expectEqualSlices(
            u8,
            vector.encoded,
            output[0..result.written],
        );
    }

    var default_output: [64]u8 = undefined;
    var level_nine_output: [64]u8 = undefined;
    const default_result = try encoder.compress(input, &default_output, 0);
    const level_nine_result = try encoder.compress(input, &level_nine_output, 9);
    try std.testing.expectEqual(default_result, level_nine_result);
    try std.testing.expectEqualSlices(
        u8,
        default_output[0..default_result.written],
        level_nine_output[0..level_nine_result.written],
    );
}

test "LZ4HC dest-size releases every workspace allocation failure" {
    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            var encoder = try Encoder.init(allocator);
            defer encoder.deinit();
            var output: [64]u8 = undefined;
            _ = try encoder.compress(
                "allocation-safe LZ4HC optimal workspace " ** 32,
                &output,
                12,
            );
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{},
    );
}
