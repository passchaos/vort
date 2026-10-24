const std = @import("std");
const core = @import("../../core.zig");
const format = @import("../format.zig");
const fse = @import("../fse.zig");
const history_mod = @import("history.zig");

pub const Retained = struct { literal: usize, lmd: usize };

/// Reverse FSE consumes at most one transition per symbol and the value's
/// extra bits. Only that bounded suffix and its final high-bit padding matter.
pub fn retainedSizes(header: format.CompressedHeader) !Retained {
    if (header.literal_count > format.max_literal_count or header.literal_count % 4 != 0 or
        header.match_count > format.max_match_count) return error.InvalidLzfseStream;
    var sizes = Retained{ .literal = 0, .lmd = 0 };
    if (header.literal_count != 0) {
        const bits = try maxBits(&header.literal_frequencies, format.literal_state_count, null);
        sizes.literal = try suffixSize(header.literal_count, bits, header.literal_bits, header.literal_payload_size);
    }
    if (header.match_count != 0) {
        const bits = try maxBits(&header.l_frequencies, format.l_state_count, &format.l_extra_bits) +
            try maxBits(&header.m_frequencies, format.m_state_count, &format.m_extra_bits) +
            try maxBits(&header.d_frequencies, format.d_state_count, &format.d_extra_bits);
        sizes.lmd = try suffixSize(header.match_count, bits, header.lmd_bits, header.lmd_payload_size);
    }
    return sizes;
}

fn maxBits(frequencies: []const u16, states: usize, extras: ?[]const u8) !usize {
    try fse.validateFrequencies(frequencies, states);
    const state_log = std.math.log2_int(usize, states);
    var maximum: usize = 0;
    for (frequencies, 0..) |frequency, symbol| {
        if (frequency == 0) continue;
        const transition = state_log - std.math.log2_int(usize, frequency);
        maximum = @max(maximum, transition + @as(usize, if (extras) |widths| widths[symbol] else 0));
    }
    return maximum;
}

fn suffixSize(count: usize, width: usize, final_bits: i8, payload_size: usize) !usize {
    if (final_bits < -7 or final_bits > 0) return error.InvalidLzfseStream;
    const padding: usize = @intCast(-final_bits);
    const content_bits = std.math.mul(usize, count, width) catch return error.IntegerOverflow;
    const padded_bits = std.math.add(usize, content_bits, padding) catch return error.IntegerOverflow;
    const rounded_bits = std.math.add(usize, padded_bits, 7) catch return error.IntegerOverflow;
    return @min(payload_size, rounded_bits / 8);
}

/// Tables live directly in the movable cursor; readers borrow stable retained
/// payload tails. Literals are decoded as needed, including discarded padding.
pub const Cursor = struct {
    const Phase = enum { record, literal, match, padding, done };

    raw_size: usize,
    literal_count: usize,
    record_count: usize,
    prefix_len: usize,
    decoded_len: usize = 0,
    records_done: usize = 0,
    literal_decoded: usize = 0,
    literal_used: usize = 0,
    literal_remaining: usize = 0,
    match_remaining: usize = 0,
    distance: ?usize = null,
    phase: Phase = .record,
    literal_states: [4]u16,
    lmd_states: [3]u16,
    literal_reader: ?fse.BitReader = null,
    lmd_reader: ?fse.BitReader = null,
    literal_table: [format.literal_state_count]fse.DecoderEntry = undefined,
    l_table: [format.l_state_count]fse.ValueDecoderEntry = undefined,
    m_table: [format.m_state_count]fse.ValueDecoderEntry = undefined,
    d_table: [format.d_state_count]fse.ValueDecoderEntry = undefined,

    pub fn init(header: format.CompressedHeader, literal_tail: []const u8, lmd_tail: []const u8, prefix_len: usize) !Cursor {
        const retained = try retainedSizes(header);
        if (literal_tail.len != retained.literal or lmd_tail.len != retained.lmd) return error.InvalidLzfseStream;
        _ = std.math.add(usize, prefix_len, header.raw_size) catch return error.IntegerOverflow;
        var result = Cursor{
            .raw_size = header.raw_size,
            .literal_count = header.literal_count,
            .record_count = header.match_count,
            .prefix_len = prefix_len,
            .literal_states = header.literal_states,
            .lmd_states = .{ header.l_state, header.m_state, header.d_state },
        };
        if (header.literal_count != 0) {
            for (header.literal_states) |state| if (state >= format.literal_state_count) return error.InvalidLzfseStream;
            try fse.initDecoderTable(format.literal_state_count, &header.literal_frequencies, &result.literal_table);
            result.literal_reader = try fse.BitReader.init(literal_tail, header.literal_bits);
        }
        if (header.match_count != 0) {
            if (header.l_state >= format.l_state_count or header.m_state >= format.m_state_count or
                header.d_state >= format.d_state_count) return error.InvalidLzfseStream;
            try fse.initValueDecoderTable(format.l_state_count, &header.l_frequencies, &format.l_extra_bits, &format.l_base_value, &result.l_table);
            try fse.initValueDecoderTable(format.m_state_count, &header.m_frequencies, &format.m_extra_bits, &format.m_base_value, &result.m_table);
            try fse.initValueDecoderTable(format.d_state_count, &header.d_frequencies, &format.d_extra_bits, &format.d_base_value, &result.d_table);
            result.lmd_reader = try fse.BitReader.init(lmd_tail, header.lmd_bits);
        } else {
            if (header.raw_size != 0 or header.literal_count != 0) return error.InvalidLzfseStream;
            result.phase = .done;
        }
        return result;
    }

    /// Payload input is already complete. Success reports only caller output
    /// progress; on failure decoded_len still records bytes already published.
    pub fn step(self: *Cursor, history: history_mod.View, output: []u8) !core.StepResult {
        var written: usize = 0;
        while (true) switch (self.phase) {
            .record => {
                if (self.records_done == self.record_count) {
                    self.phase = .padding;
                    continue;
                }
                const reader = &self.lmd_reader.?;
                self.literal_remaining = try positiveValue(try fse.decodeValue(&self.lmd_states[0], &self.l_table, reader));
                self.match_remaining = try positiveValue(try fse.decodeValue(&self.lmd_states[1], &self.m_table, reader));
                const distance = try positiveValue(try fse.decodeValue(&self.lmd_states[2], &self.d_table, reader));
                if (distance != 0) self.distance = distance;
                if (self.distance == null or self.literal_remaining > self.literal_count - self.literal_used or
                    self.literal_remaining > self.raw_size - self.decoded_len) return error.InvalidLzfseStream;
                self.phase = .literal;
            },
            .literal => {
                while (self.literal_remaining != 0) {
                    if (written == output.len) return needOutput(written);
                    output[written] = try self.nextLiteral();
                    written += 1;
                    self.decoded_len += 1;
                    self.literal_used += 1;
                    self.literal_remaining -= 1;
                }
                self.phase = .match;
            },
            .match => {
                if (self.match_remaining != 0) {
                    const distance = self.distance.?;
                    // Check global format reach before checking retained data.
                    if (distance > self.prefix_len + self.decoded_len or
                        self.match_remaining > self.raw_size - self.decoded_len) return error.InvalidLzfseStream;
                    while (self.match_remaining != 0) {
                        if (written == output.len) return needOutput(written);
                        output[written] = if (distance <= written)
                            output[written - distance]
                        else
                            history_mod.byteFromEnd(history, distance - written) catch |err|
                                return if (err == error.InvalidMatch) error.HistoryLimitExceeded else err;
                        written += 1;
                        self.decoded_len += 1;
                        self.match_remaining -= 1;
                    }
                }
                self.records_done += 1;
                self.phase = .record;
            },
            .padding => {
                // The eager decoder validates every declared literal, even
                // when its final padding is unused by L/M/D records.
                while (self.literal_decoded < self.literal_count) _ = try self.nextLiteral();
                if (self.literal_count - self.literal_used > 3 or self.decoded_len != self.raw_size) return error.SizeMismatch;
                self.phase = .done;
            },
            .done => return .{ .progress = .{ .output_written = written }, .status = .done },
        };
    }

    fn nextLiteral(self: *Cursor) !u8 {
        if (self.literal_decoded == self.literal_count or self.literal_reader == null) return error.InvalidLzfseStream;
        const lane = self.literal_decoded % 4;
        const byte = try fse.decodeSymbol(&self.literal_states[lane], &self.literal_table, &self.literal_reader.?);
        self.literal_decoded += 1;
        return byte;
    }

    fn needOutput(written: usize) core.StepResult {
        return .{ .progress = .{ .output_written = written }, .status = .need_output };
    }
};

fn positiveValue(value: i32) !usize {
    if (value < 0) return error.InvalidLzfseStream;
    return @intCast(value);
}

test {
    _ = @import("fse_cursor_tests.zig");
}
