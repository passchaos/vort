//! Validate independent worker blocks and encode them against published state.
const std = @import("std");
const View = @import("job_view.zig").View;

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

        /// Borrow a one-shot span through the same bounded job contract.
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
            return appendOwned(allocator, out, job_bytes, try View.oneShot(full_input, start, end), options, dictionary, state, profile);
        }

        /// Roll back published bytes and coding priors together while retaining
        /// the reusable decoding and candidate buffers after a failed job.
        pub fn appendOwned(
            allocator: std.mem.Allocator,
            out: *std.ArrayList(u8),
            job_bytes: []const u8,
            view: View,
            options: S.Options,
            dictionary: ?S.Dictionary,
            state: *State,
            profile: *S.Profile,
        ) S.Error!void {
            const original_len = out.items.len;
            const original_actual = state.actual;
            const original_emitted = profile.emitted();
            errdefer {
                out.items.len = original_len;
                state.actual = original_actual;
                profile.restoreEmitted(original_emitted);
            }
            try view.validate();
            const plain = view.plain();
            if (job_bytes.len == 0) return error.CorruptFrame;
            const expected = if (options.include_content_size and view.final) @as(?@import("job_view.zig").Count, try view.globalPosition(plain.len)) else null;
            const block_size = if (view.window_limit != null) try S.streamBlockSize(options, expected) else try S.blockSize(options);
            var original = try S.initialDecodeState(dictionary);
            var encoded_cursor: usize = 0;
            var decoded_cursor: usize = 0;
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
                        if (size > plain.len - decoded_cursor) return error.CorruptFrame;
                        decoded_cursor += size;
                        try validateLast(view, last, decoded_cursor, encoded_cursor, job_bytes.len);
                        _ = try blockWindow(view, block_start, size, last, options);
                        const block = plain[block_start..decoded_cursor];
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
                        const decoded = try decodeCompressed(allocator, payload, plain, block_start, block_size, state, &original);
                        decoded_cursor += decoded.len;
                        try validateLast(view, last, decoded_cursor, encoded_cursor, job_bytes.len);
                        const block = plain[block_start..decoded_cursor];
                        const window = try blockWindow(view, block_start, block.len, last, options);
                        const count = decoded.sequence_count;
                        if (count == 0) {
                            if (!try S.emitHuffman(allocator, out, block, last, &state.actual.previous_huffman_plan))
                                try S.emitBlock(allocator, out, block, last);
                        } else {
                            const ll = state.values.items[0..count];
                            const distances = state.values.items[count .. count * 2];
                            const ml = state.values.items[count * 2 .. count * 3];
                            const ends = state.values.items[count * 3 .. count * 4];
                            const global_offset = try view.globalPosition(block_start);
                            const visible_dictionary = S.visibleDictionary(dictionary, global_offset, window);
                            const source = try S.Source.initChecked(if (visible_dictionary) |dict| dict.content else &.{}, try view.historyBefore(block_start, window), block, window);
                            try validateMatches(source, ll, distances, ml);
                            state.candidate.clearRetainingCapacity();
                            const compressed = if (count <= S.max_small_sequence_count)
                                try S.replaceSequences(allocator, &state.candidate, block, last, ll, distances, ml, ends, decoded.tail_start, &state.actual.sequence_state)
                            else
                                try S.emitLargeSequences(allocator, &state.candidate, block, last, ll, distances, ml, ends, decoded.tail_start, &state.scratch, if (state.actual.sequence_state.previous_tables) |*tables| tables else null, state.actual.sequence_state.repeated_offsets);
                            if (compressed) {
                                try S.commitSequences(allocator, out, state.candidate.items, last, &state.actual.sequence_state);
                                state.actual.previous_huffman_plan = null;
                                try countReferences(profile, source, ll, distances, ml);
                            } else {
                                try S.emitBlock(allocator, out, block, last);
                            }
                        }
                        countBlock(profile, out.items[original_output_len..]);
                    },
                    else => unreachable,
                }
            }
            if (decoded_cursor != plain.len) return error.SizeMismatch;
        }

        fn validateLast(view: View, last: bool, decoded_end: usize, encoded_end: usize, job_len: usize) S.Error!void {
            if (last != (view.final and decoded_end == view.plain().len)) return error.CorruptFrame;
            if (last and encoded_end != job_len) return error.TrailingData;
        }

        fn blockWindow(view: View, block_start: usize, block_len: usize, last: bool, options: S.Options) S.Error!usize {
            const window = if (view.window_limit) |limit|
                @min(try S.encoderWindow(options), limit)
            else
                try S.matchWindow(options, try view.globalPosition(block_start), block_len, last);
            if (window == 0 and block_len != 0 and
                options.selection != .raw_or_rle) return error.SizeMismatch;
            try view.validatePrefix(window);
            return window;
        }

        fn decodeCompressed(
            allocator: std.mem.Allocator,
            payload: []const u8,
            plain: []const u8,
            start: usize,
            block_size: usize,
            state: *State,
            original: *S.DecodeState,
        ) S.Error!DecodedBlock {
            const section = try S.parseLiterals(payload, original);
            const limit = @min(block_size, plain.len - start);
            if (section.regenerated_size > limit or section.sequence_count > S.max_sequence_count)
                return error.CorruptFrame;
            try decodeLiterals(allocator, payload, section, &state.literals);
            if (section.sequence_count == 0) {
                if (section.sequence_payload_offset != payload.len) return error.CorruptFrame;
                if (!std.mem.eql(u8, state.literals.items, plain[start..][0..section.regenerated_size]))
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
            var cursor: usize = 0;
            var literal_cursor: usize = 0;
            for (0..count) |index| {
                const sequence = try S.readSequence(&decoder);
                if (sequence.literal_len > state.literals.items.len - literal_cursor or sequence.literal_len > limit - cursor)
                    return error.CorruptFrame;
                const literals = state.literals.items[literal_cursor..][0..sequence.literal_len];
                if (!std.mem.eql(u8, literals, plain[start + cursor ..][0..sequence.literal_len]))
                    return error.CorruptFrame;
                literal_cursor += sequence.literal_len;
                cursor += sequence.literal_len;
                if (sequence.match_len < 3 or sequence.match_offset == 0) return error.InvalidMatch;
                if (sequence.match_len > limit - cursor) return error.CorruptFrame;
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
            if (!std.mem.eql(u8, tail, plain[start + cursor ..][0..tail.len])) return error.CorruptFrame;
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

        fn validateMatches(source: S.Source, ll: []const usize, distances: []const usize, ml: []const usize) S.Error!void {
            var cursor: usize = 0;
            for (ll, distances, ml) |literal_len, distance, match_len| {
                cursor = std.math.add(usize, cursor, literal_len) catch return error.IntegerOverflow;
                const position = try source.checkedBlockPosition(cursor);
                if (distance == 0 or distance > source.window_len or distance > position or match_len < 3)
                    return error.InvalidMatch;
                const candidate = position - distance;
                // Source checks dictionary/history seams and overlapping copies
                // against immutable plaintext through its validated geometry.
                if (source.match(cursor, candidate, match_len).length < match_len) return error.InvalidMatch;
                cursor = std.math.add(usize, cursor, match_len) catch return error.IntegerOverflow;
            }
        }

        fn countReferences(profile: *S.Profile, source: S.Source, ll: []const usize, distances: []const usize, ml: []const usize) S.Error!void {
            var cursor: usize = 0;
            for (ll, distances, ml) |literal_len, distance, match_len| {
                cursor = std.math.add(usize, cursor, literal_len) catch return error.IntegerOverflow;
                const position = try source.checkedBlockPosition(cursor);
                switch (source.origin(position - distance)) {
                    .dictionary => profile.add("dictionary_sequences", 1),
                    .history => profile.add("history_sequences", 1),
                    .block => {},
                }
                profile.max_distance = @max(profile.max_distance, distance);
                cursor = std.math.add(usize, cursor, match_len) catch return error.IntegerOverflow;
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
