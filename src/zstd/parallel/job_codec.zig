//! Validate independent worker blocks and encode them against published state.
const std = @import("std");

pub fn Adapter(comptime S: type) type {
    return struct {
        pub const State = struct {
            actual: S.EncoderState = .{},
            values: std.ArrayList(usize) = .empty,
            literals: std.ArrayList(u8) = .empty,
            candidate: std.ArrayList(u8) = .empty,
            scratch: S.SequenceScratch = .{},
        };

        const DecodedBlock = struct {
            len: usize,
            sequence_count: usize,
            tail_start: usize,
        };

        pub fn init(dictionary: ?S.Dictionary) S.Error!State {
            var state: State = .{};
            try S.ensureEncoderState(&state.actual, dictionary);
            return state;
        }

        pub fn deinit(allocator: std.mem.Allocator, state: *State) void {
            state.values.deinit(allocator);
            state.literals.deinit(allocator);
            state.candidate.deinit(allocator);
            S.deinitScratch(&state.scratch, allocator);
            state.* = .{};
        }

        /// The caller owns frame-level output and profile rollback on failure.
        pub fn append(
            allocator: std.mem.Allocator,
            out: *std.ArrayList(u8),
            job_bytes: []const u8,
            full_input: []const u8,
            start: usize,
            end: usize,
            options: S.Options,
            dictionary: ?S.Dictionary,
            state: *State,
            profile: *S.Profile,
        ) S.Error!void {
            if (start > end or end > full_input.len) return error.InvalidBlockPlan;
            if (job_bytes.len == 0) return error.CorruptFrame;
            const block_size = try S.blockSize(options);
            var original = try S.initialDecodeState(dictionary);
            var encoded_cursor: usize = 0;
            var decoded_cursor = start;
            while (encoded_cursor < job_bytes.len) {
                if (job_bytes.len - encoded_cursor < 3) return error.TruncatedFrame;
                const header = std.mem.readInt(u24, job_bytes[encoded_cursor..][0..3], .little);
                encoded_cursor += 3;
                const last = (header & 1) != 0;
                const kind = (header >> 1) & 3;
                const size: usize = @intCast(header >> 3);
                if (kind == 3 or size > block_size) return error.CorruptFrame;
                const payload_size = if (kind == 1) 1 else size;
                if (payload_size > job_bytes.len - encoded_cursor) return error.TruncatedFrame;
                const payload = job_bytes[encoded_cursor..][0..payload_size];
                encoded_cursor += payload_size;
                const block_start = decoded_cursor;
                const original_output_len = out.items.len;
                switch (kind) {
                    0, 1 => {
                        if (size > end - decoded_cursor) return error.CorruptFrame;
                        decoded_cursor += size;
                        try validateLast(last, decoded_cursor, full_input.len, encoded_cursor, job_bytes.len);
                        const block = full_input[block_start..decoded_cursor];
                        if (kind == 0) {
                            if (!std.mem.eql(u8, payload, block)) return error.CorruptFrame;
                            try S.emitRaw(allocator, out, block, last);
                        } else {
                            for (block) |byte| {
                                if (byte != payload[0]) return error.CorruptFrame;
                            }
                            try S.emitRle(allocator, out, payload[0], size, last);
                        }
                        countBlock(profile, out.items[original_output_len..]);
                    },
                    2 => {
                        const decoded = try decodeCompressed(allocator, payload, full_input, block_start, end, block_size, dictionary, state, &original);
                        decoded_cursor += decoded.len;
                        try validateLast(last, decoded_cursor, full_input.len, encoded_cursor, job_bytes.len);
                        const block = full_input[block_start..decoded_cursor];
                        const window = try S.matchWindow(options, block_start, block.len, last);
                        const count = decoded.sequence_count;
                        if (count == 0) {
                            if (!try S.emitHuffman(allocator, out, block, last, &state.actual.previous_huffman_plan))
                                try S.emitBlock(allocator, out, block, last);
                        } else {
                            const ll = state.values.items[0..count];
                            const distances = state.values.items[count .. count * 2];
                            const ml = state.values.items[count * 2 .. count * 3];
                            const ends = state.values.items[count * 3 .. count * 4];
                            for (distances) |distance| {
                                if (distance > window) return error.InvalidMatch;
                            }
                            state.candidate.clearRetainingCapacity();
                            const compressed = if (count <= S.max_small_sequence_count)
                                try S.replaceSequences(allocator, &state.candidate, block, last, ll, distances, ml, ends, decoded.tail_start, &state.actual.sequence_state)
                            else
                                try S.emitLargeSequences(allocator, &state.candidate, block, last, ll, distances, ml, ends, decoded.tail_start, &state.scratch, if (state.actual.sequence_state.previous_tables) |*tables| tables else null, state.actual.sequence_state.repeated_offsets);
                            if (compressed) {
                                try S.commitSequences(allocator, out, state.candidate.items, last, &state.actual.sequence_state);
                                state.actual.previous_huffman_plan = null;
                                countReferences(profile, block_start, ll, distances, ml);
                            } else {
                                try S.emitBlock(allocator, out, block, last);
                            }
                        }
                        countBlock(profile, out.items[original_output_len..]);
                    },
                    else => unreachable,
                }
            }
            if (decoded_cursor != end) return error.SizeMismatch;
        }

        fn validateLast(last: bool, decoded_end: usize, input_len: usize, encoded_end: usize, job_len: usize) S.Error!void {
            if (last != (decoded_end == input_len)) return error.CorruptFrame;
            if (last and encoded_end != job_len) return error.TrailingData;
        }

        fn decodeCompressed(
            allocator: std.mem.Allocator,
            payload: []const u8,
            full_input: []const u8,
            start: usize,
            end: usize,
            block_size: usize,
            dictionary: ?S.Dictionary,
            state: *State,
            original: *S.DecodeState,
        ) S.Error!DecodedBlock {
            const section = try S.parseLiterals(payload, original);
            const limit = @min(block_size, end - start);
            if (section.regenerated_size > limit or section.sequence_count > S.max_sequence_count)
                return error.CorruptFrame;
            try decodeLiterals(allocator, payload, section, &state.literals);
            if (section.sequence_count == 0) {
                if (section.sequence_payload_offset != payload.len) return error.CorruptFrame;
                if (!std.mem.eql(u8, state.literals.items, full_input[start..][0..section.regenerated_size]))
                    return error.CorruptFrame;
                return .{ .len = section.regenerated_size, .sequence_count = 0, .tail_start = 0 };
            }

            var sequence_offset = section.sequence_payload_offset;
            const spec = try S.resolveSequenceModes(try S.parseSequenceModes(payload, &sequence_offset, section.sequence_count), original.previous_tables);
            if (sequence_offset != payload.len or spec.bitstream_offset >= payload.len) return error.CorruptFrame;
            var decoder = try S.initSequenceDecoder(&spec, section.sequence_count, try S.initReverseReader(payload[spec.bitstream_offset..]), original.repeated_offsets);
            const count = section.sequence_count;
            const value_count = std.math.mul(usize, count, 4) catch return error.IntegerOverflow;
            try state.values.resize(allocator, value_count);
            const ll = state.values.items[0..count];
            const distances = state.values.items[count .. count * 2];
            const ml = state.values.items[count * 2 .. count * 3];
            const ends = state.values.items[count * 3 .. count * 4];
            const dictionary_bytes: []const u8 = if (dictionary) |dict| dict.content else &.{};
            var cursor: usize = 0;
            var literal_cursor: usize = 0;
            for (0..count) |index| {
                const sequence = try S.readSequence(&decoder);
                if (sequence.literal_len > state.literals.items.len - literal_cursor or sequence.literal_len > limit - cursor)
                    return error.CorruptFrame;
                const literals = state.literals.items[literal_cursor..][0..sequence.literal_len];
                if (!std.mem.eql(u8, literals, full_input[start + cursor ..][0..sequence.literal_len]))
                    return error.CorruptFrame;
                literal_cursor += sequence.literal_len;
                cursor += sequence.literal_len;
                if (sequence.match_len < 3 or sequence.match_offset == 0) return error.InvalidMatch;
                if (sequence.match_len > limit - cursor) return error.CorruptFrame;
                try validateMatch(full_input, dictionary_bytes, start + cursor, sequence.match_offset, sequence.match_len);
                cursor += sequence.match_len;
                ll[index] = sequence.literal_len;
                distances[index] = sequence.match_offset;
                ml[index] = sequence.match_len;
                ends[index] = cursor;
            }
            if (decoder.remaining != 0) return error.CorruptFrame;
            const tail_start = cursor;
            const tail = state.literals.items[literal_cursor..];
            if (tail.len > limit - cursor) return error.CorruptFrame;
            if (!std.mem.eql(u8, tail, full_input[start + cursor ..][0..tail.len])) return error.CorruptFrame;
            cursor += tail.len;
            original.previous_tables = S.sequenceTables(&spec);
            original.repeated_offsets = decoder.repeated_offsets;
            return .{ .len = cursor, .sequence_count = count, .tail_start = tail_start };
        }

        fn decodeLiterals(allocator: std.mem.Allocator, payload: []const u8, section: S.Section, literals: *std.ArrayList(u8)) S.Error!void {
            try literals.resize(allocator, section.regenerated_size);
            switch (section.kind) {
                .raw => {
                    if (section.literal_payload_offset > payload.len or section.regenerated_size > payload.len - section.literal_payload_offset)
                        return error.TruncatedFrame;
                    @memcpy(literals.items, payload[section.literal_payload_offset..][0..section.regenerated_size]);
                },
                .rle => {
                    if (section.literal_payload_offset >= payload.len) return error.TruncatedFrame;
                    @memset(literals.items, payload[section.literal_payload_offset]);
                },
                .compressed, .treeless => {
                    var huffman = try S.initHuffmanState(payload, section) orelse return error.CorruptFrame;
                    // Full consumption checks all Huffman stream ends, including
                    // an empty literal section, without decoding twice.
                    try S.copyHuffmanLiterals(&huffman, &section, 0, literals.items);
                },
            }
        }

        fn validateMatch(full_input: []const u8, dictionary: []const u8, match_start: usize, distance: usize, match_len: usize) S.Error!void {
            if (distance > match_start) {
                const dictionary_back = distance - match_start;
                if (dictionary_back > dictionary.len) return error.InvalidMatch;
                const dictionary_start = dictionary.len - dictionary_back;
                for (0..match_len) |index| {
                    const expected = if (index < dictionary_back)
                        dictionary[dictionary_start + index]
                    else
                        full_input[index - dictionary_back];
                    if (full_input[match_start + index] != expected) return error.InvalidMatch;
                }
            } else {
                const source_start = match_start - distance;
                for (0..match_len) |index| {
                    if (full_input[match_start + index] != full_input[source_start + index])
                        return error.InvalidMatch;
                }
            }
        }

        fn countReferences(profile: *S.Profile, block_start: usize, ll: []const usize, distances: []const usize, ml: []const usize) void {
            var cursor: usize = 0;
            for (ll, distances, ml) |literal_len, distance, match_len| {
                cursor += literal_len;
                if (distance > block_start + cursor) {
                    profile.add("dictionary_sequences", 1);
                } else if (distance > cursor) {
                    profile.add("history_sequences", 1);
                }
                profile.max_distance = @max(profile.max_distance, distance);
                cursor += match_len;
            }
        }

        fn countBlock(profile: *S.Profile, bytes: []const u8) void {
            const header = std.mem.readInt(u24, bytes[0..3], .little);
            switch ((header >> 1) & 3) {
                0 => profile.add("raw_blocks", 1),
                1 => profile.add("rle_blocks", 1),
                2 => profile.add("compressed_blocks", 1),
                else => unreachable,
            }
        }
    };
}
