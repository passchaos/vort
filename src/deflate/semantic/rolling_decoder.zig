//! Semantic dynamic decoding into one bounded circular history generation.
//! Bit accounting uses call-local reservoir deltas, including preloaded bits.
const std = @import("std");
const rolling_window = @import("rolling_window.zig");
const tables = @import("tables.zig");
const secondary_index = @import("../decoder/secondary_index.zig");

pub fn decode(comptime S: type, reader: anytype, window: rolling_window.Window, decoder: anytype) S.Error!S.LinearStep {
    if (window.base == 0)
        return S.oldWindow(reader, window.storage[0..window.output_limit], window.prefix_len, decoder);
    return decodeMode(S, false, reader, window, decoder, {});
}

/// Diagnostic mode always uses this body, including base zero, so committed
/// logical progress is available on an error without instrumenting decode().
/// The controller still owns rollback of the failed generation and reader.
pub fn decodeObserved(comptime S: type, reader: anytype, window: rolling_window.Window, decoder: anytype, output_position: *usize) S.Error!S.LinearStep {
    return decodeMode(S, true, reader, window, decoder, output_position);
}

inline fn observe(comptime enabled: bool, position: if (enabled) *usize else void, value: usize) void {
    if (enabled) position.* = value;
}

inline fn room(window: rolling_window.Window, position: usize) bool {
    return window.output_limit - position >= 258;
}

inline fn pair(window: rolling_window.Window, logical: usize, physical: usize, contiguous: bool, entry: u32) void {
    // Fast-loop headroom proves both bytes belong to free generation storage,
    // including the second speculative byte of a single-literal entry.
    if (contiguous) {
        std.mem.writeInt(u16, window.storage[physical..][0..2], @truncate(entry >> 16), .little);
    } else window.putPair(logical, @truncate(entry >> 16), @truncate(entry >> 24));
}

fn decodeMode(comptime S: type, comptime observed: bool, reader: anytype, window: rolling_window.Window, decoder: anytype, output_position: if (observed) *usize else void) S.Error!S.LinearStep {
    const Decoder = @TypeOf(decoder.*);
    std.debug.assert(window.valid());
    const input = reader.input;
    const initial_byte_index = reader.byte_index;
    const initial_bit_count = reader.bit_count;
    const initial_consumed_bits = reader.consumed_bits;
    var buffer = reader.bit_buffer;
    var count = reader.bit_count;
    var index = reader.byte_index;
    var out = window.prefix_len;
    observe(observed, output_position, out);
    if (room(window, out) and index + 8 <= input.len) S.refill(input, &index, &buffer, &count);
    var entry = decoder.literal[@intCast(buffer & Decoder.literal_lookup_mask)];

    while (room(window, out) and index + 8 <= input.len) {
        var physical = window.physical(out);
        const contiguous = rolling_window.capacity - physical >= 258;
        if ((entry & Decoder.literal_flag) != 0) {
            const first_bits: u6 = @truncate(entry);
            const second = decoder.literal[@intCast((buffer >> first_bits) & Decoder.literal_lookup_mask)];
            const second_bits: u6 = @truncate(second);
            const first_two: u6 = first_bits + second_bits;
            const third = decoder.literal[@intCast((buffer >> first_two) & Decoder.literal_lookup_mask)];
            const third_bits: u6 = @truncate(third);
            const first_three: u6 = first_two + third_bits;
            const fourth = decoder.literal[@intCast((buffer >> first_three) & Decoder.literal_lookup_mask)];
            const advance_first: usize = @intCast((entry >> 8) & 0xf);
            pair(window, out, physical, contiguous, entry);
            out += advance_first;
            physical += advance_first;
            observe(observed, output_position, out);
            if ((second & Decoder.literal_flag) != 0) {
                const advance_second: usize = @intCast((second >> 8) & 0xf);
                pair(window, out, physical, contiguous, second);
                out += advance_second;
                physical += advance_second;
                observe(observed, output_position, out);
                if ((third & Decoder.literal_flag) != 0) {
                    pair(window, out, physical, contiguous, third);
                    out += @as(usize, @intCast((third >> 8) & 0xf));
                    observe(observed, output_position, out);
                    buffer >>= first_three;
                    count -= first_three;
                    entry = fourth;
                    S.refill(input, &index, &buffer, &count);
                    continue;
                }
                buffer >>= first_two;
                count -= first_two;
                entry = third;
            } else {
                buffer >>= first_bits;
                count -= first_bits;
                entry = second;
            }
            physical = window.physical(out);
        }

        // LL/extra and the distance primary fit after packed literals. No
        // match bits retire before the complete distance/capacity is known.
        var match_bits: u6 = @truncate(entry);
        var length_entry = entry;
        if ((entry & Decoder.exceptional_flag) != 0) {
            if ((entry & Decoder.secondary_flag) != 0) {
                const start: usize = @intCast(entry >> 16);
                const mask: usize = @intCast(entry & 0xff);
                const slot = start + secondary_index.suffix(buffer, Decoder.literal_lookup_bits, mask);
                if (slot >= decoder.literal_secondary_len) return error.InvalidHuffmanCode;
                const secondary = decoder.literal_secondary[slot];
                const symbol: u16 = secondary >> 4;
                const bits: u6 = @truncate(secondary & 0xf);
                if (symbol < 256) {
                    buffer >>= bits;
                    count -= bits;
                    window.storage[physical] = @truncate(symbol);
                    out += 1;
                    observe(observed, output_position, out);
                    if (count >= Decoder.literal_lookup_bits) {
                        entry = decoder.literal[@intCast(buffer & Decoder.literal_lookup_mask)];
                        S.refill(input, &index, &buffer, &count);
                    } else {
                        S.refill(input, &index, &buffer, &count);
                        entry = decoder.literal[@intCast(buffer & Decoder.literal_lookup_mask)];
                    }
                    continue;
                }
                if (symbol == 256) {
                    buffer >>= bits;
                    count -= bits;
                    S.publishReader(reader, buffer, count, index, initial_bit_count, initial_byte_index, initial_consumed_bits);
                    return .{ .output_written = out, .status = .end_of_block };
                }
                if (symbol > 285) return error.InvalidHuffmanCode;
                const metadata = tables.length_table[symbol - 257];
                length_entry = (@as(u32, metadata.base) << 16) | (@as(u32, metadata.extra_bits) << 8);
                match_bits = bits;
            } else {
                if (match_bits == 0) return error.InvalidHuffmanCode;
                buffer >>= match_bits;
                count -= match_bits;
                S.publishReader(reader, buffer, count, index, initial_bit_count, initial_byte_index, initial_consumed_bits);
                return .{ .output_written = out, .status = .end_of_block };
            }
        }

        var bits = buffer >> match_bits;
        const length_extra: u6 = @truncate(length_entry >> 8);
        const length_mask = (@as(u64, 1) << length_extra) - 1;
        const length = @as(usize, @intCast(length_entry >> 16)) + @as(usize, @intCast(bits & length_mask));
        bits >>= length_extra;
        const distance_start: u6 = match_bits + length_extra;
        var distance_entry = decoder.distance[@intCast(bits & Decoder.distance_lookup_mask)];
        if ((distance_entry & Decoder.literal_flag) == 0) {
            if ((distance_entry & Decoder.secondary_flag) == 0) return error.InvalidHuffmanCode;
            if (count < distance_start + @as(u6, 15)) {
                S.refill(input, &index, &buffer, &count);
                bits = buffer >> distance_start;
            }
            const start: usize = @intCast(distance_entry >> 16);
            const mask: usize = @intCast(distance_entry & 0xff);
            const slot = start + secondary_index.suffix(bits, Decoder.distance_lookup_bits, mask);
            if (slot >= decoder.distance_secondary_len) return error.InvalidHuffmanCode;
            const secondary = decoder.distance_secondary[slot];
            const symbol: u16 = secondary >> 4;
            if (symbol >= tables.distance_table.len) return error.InvalidHuffmanCode;
            const metadata = tables.distance_table[symbol];
            distance_entry = (@as(u32, metadata.base) << 16) | (@as(u32, metadata.extra_bits) << 8) | @as(u32, secondary & 0xf);
        }
        const distance_bits: u6 = @truncate(distance_entry);
        const distance_extra: u6 = @truncate(distance_entry >> 8);
        const total: u6 = distance_start + distance_bits + distance_extra;
        if (count < total) S.refill(input, &index, &buffer, &count);
        bits = buffer >> (distance_start + distance_bits);
        const distance_mask = (@as(u64, 1) << distance_extra) - 1;
        const distance = @as(usize, @intCast(distance_entry >> 16)) + @as(usize, @intCast(bits & distance_mask));
        if (distance == 0 or distance > out) return error.InvalidMatch;
        if (length > window.output_limit - out) {
            S.publishReader(reader, buffer, count, index, initial_bit_count, initial_byte_index, initial_consumed_bits);
            return .{ .output_written = out, .status = .need_output };
        }
        buffer >>= total;
        count -= total;
        if (count >= Decoder.literal_lookup_bits) {
            entry = decoder.literal[@intCast(buffer & Decoder.literal_lookup_mask)];
            S.refill(input, &index, &buffer, &count);
        } else {
            S.refill(input, &index, &buffer, &count);
            entry = decoder.literal[@intCast(buffer & Decoder.literal_lookup_mask)];
        }
        try window.copyMatch(out, length, distance);
        out += length;
        observe(observed, output_position, out);
    }
    S.publishReader(reader, buffer, count, index, initial_bit_count, initial_byte_index, initial_consumed_bits);
    return tail(S, observed, reader, window, decoder, out, output_position);
}

fn tail(comptime S: type, comptime observed: bool, reader: anytype, window: rolling_window.Window, decoder: anytype, initial_out: usize, output_position: if (observed) *usize else void) S.Error!S.LinearStep {
    var out = initial_out;
    while (true) {
        const saved = reader.*;
        switch (try S.decodeTail(reader, decoder)) {
            .literal => |literal| {
                if (out == window.output_limit) {
                    reader.* = saved;
                    return .{ .output_written = out, .status = .need_output };
                }
                window.putLiteral(out, literal);
                out += 1;
            },
            .double_literal => |literals| {
                if (window.output_limit - out < 2) {
                    reader.* = saved;
                    if (out == window.output_limit)
                        return .{ .output_written = out, .status = .need_output };
                    const first = try decoder.compact_literal.decodeValue(reader);
                    if (first >= 256) return error.InvalidHuffmanCode;
                    window.putLiteral(out, @truncate(first));
                    out += 1;
                } else {
                    window.putPair(out, literals[0], literals[1]);
                    out += 2;
                }
            },
            .length => |metadata| {
                const length = metadata.base + try S.extraOf(reader, metadata.extra_bits);
                const symbol = try decoder.compact_distance.decodeValue(reader);
                const distance = try S.distanceOf(symbol, reader);
                if (length > window.output_limit - out) {
                    reader.* = saved;
                    return .{ .output_written = out, .status = .need_output };
                }
                try window.copyMatch(out, length, distance);
                out += length;
            },
            .eob => return .{ .output_written = out, .status = .end_of_block },
        }
        observe(observed, output_position, out);
    }
}

test "rolling semantic independent token and window oracle" {
    try @import("rolling_decoder_tests.zig").check(@This());
}
