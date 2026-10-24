const std = @import("std");
const Count = @import("../../core.zig").StreamCount;
const controls = @import("controls.zig");
const source_mod = @import("../match/controlled_source.zig");
const fast = @import("../match/controlled_fast.zig");
const search = @import("../match/controlled_search.zig");
const hq_codec = @import("hq_codec.zig");

/// Opt-in control flow shares the existing format/entropy authority through a
/// narrow codec bridge. Legacy positive/default candidate arbitration is separate.
pub fn Encoder(comptime Codec: type) type {
    return struct {
        pub fn append(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, options: Codec.Options, dictionary: ?Codec.Dictionary, records: *std.ArrayList(source_mod.Record), scratch: *Codec.SequenceScratch, block_scratch: *Codec.BlockScratch) Codec.Error!void {
            const emission = controls.EmissionTransaction.init(options.control_profile);
            errdefer emission.rollback();
            const original_len = out.items.len;
            errdefer out.items.len = original_len;
            try options.validate();
            try Codec.writeHeader(allocator, out, input.len, options);
            const block_size = try Codec.blockSize(options);
            var state: Codec.State = .{};
            if (input.len == 0) {
                try writeBlock(allocator, out, input, true, options, &state, dictionary, &.{}, 0, records, scratch, block_scratch);
            } else {
                var offset: usize = 0;
                while (offset != input.len) {
                    const end = offset + @min(block_size, input.len - offset);
                    try writeBlock(allocator, out, input[offset..end], end == input.len, options, &state, dictionary, input[0..offset], offset, records, scratch, block_scratch);
                    offset = end;
                }
            }
            try Codec.writeChecksum(allocator, out, input, options);
        }

        pub fn writeBlock(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, last: bool, options: Codec.Options, state: *Codec.State, dictionary: ?Codec.Dictionary, history: []const u8, frame_offset: Count, records: *std.ArrayList(source_mod.Record), scratch: *Codec.SequenceScratch, block_scratch: *Codec.BlockScratch) Codec.Error!void {
            // Dictionary initialization belongs to the block transaction too.
            const original_state = state.*;
            errdefer state.* = original_state;
            const emission = controls.EmissionTransaction.init(options.control_profile);
            errdefer emission.rollback();
            try options.validate();
            try Codec.ensureState(state, dictionary);
            const selected = controls.strategy(options);
            const acceleration = options.fast_acceleration orelse 1;
            const profile = options.control_profile;
            if (profile) |p| {
                p.available = true;
                p.controls_used = true;
                p.resolved_strategy = selected;
                p.fast_acceleration = acceleration;
                p.recordEffectiveHq(try controls.effectiveHq(options));
            }
            const output_start = out.items.len;
            errdefer out.items.len = output_start;
            // Empty single-segment frames legitimately advertise a zero-byte
            // window. They need only the mandatory terminal raw block.
            if (block.len == 0 or Codec.rle(block)) {
                try Codec.writeRaw(allocator, out, block, last);
                countBlock(profile, out.items[output_start..]);
                return;
            }
            const window = try Codec.matchWindow(options, frame_offset, block.len, last);
            const source = try source_mod.Source.initChecked(if (dictionary) |dict| dict.content else &.{}, history, block, window);
            const parameters: source_mod.Parameters = .{ .strategy = selected, .acceleration = acceleration, .search_budget = options.match_search_budget, .initial_repeated_offsets = state.sequence_state.repeated_offsets, .profile = profile };
            switch (selected) {
                .fast, .double_fast => try fast.planReuse(records, allocator, source, parameters),
                .greedy, .lazy, .optimal => try search.planReuse(records, allocator, source, parameters),
                .lazy2, .btlazy2, .btopt, .btultra, .btultra2 => return hq_codec.Encoder(Codec).writeBlock(allocator, out, source, last, options, state, dictionary, scratch, block_scratch),
                .auto => return error.InvalidBlockPlan,
            }
            Codec.clearBlockScratch(block_scratch);
            const candidate = &block_scratch.candidate;
            const fallback = &block_scratch.best;
            try validateRecords(source, records.items);
            const ready = records.items.len != 0 and try Codec.writeSequences(allocator, candidate, block, last, records.items, scratch, block_scratch, state) and
                try Codec.prepareSequences(allocator, candidate, block, last, state, scratch);
            var next_huffman = state.previous_huffman_plan;
            if (!try Codec.writeHuffman(allocator, fallback, block, last, &next_huffman))
                try Codec.writeRaw(allocator, fallback, block, last);
            if (ready and candidate.items.len <= fallback.items.len) {
                try Codec.commitSequences(allocator, out, candidate.items, last, state);
                state.previous_huffman_plan = null;
                countReferences(profile, source, records.items);
            } else {
                try out.appendSlice(allocator, fallback.items);
                if (blockType(fallback.items) == 2) state.previous_huffman_plan = next_huffman;
            }
            countBlock(profile, out.items[output_start..]);
        }
        fn validateRecords(source: source_mod.Source, records: []const source_mod.Record) Codec.Error!void {
            var end: usize = 0;
            for (records) |record| {
                const start = std.math.add(usize, end, record.literal_len) catch return error.IntegerOverflow;
                end = std.math.add(usize, start, record.match_len) catch return error.IntegerOverflow;
                if (record.match_len < 3 or record.match_end != end or end > source.block.len or record.distance == 0 or
                    record.distance > source.window_len or record.distance > source.prefixLen() + start)
                    return error.InvalidBlockPlan;
            }
        }
        fn countReferences(profile: ?*controls.Profile, source: source_mod.Source, records: []const source_mod.Record) void {
            const p = profile orelse return;
            var previous_end: usize = 0;
            for (records) |record| {
                const start = previous_end + record.literal_len;
                const candidate = source.prefixLen() + start - record.distance;
                switch (source.origin(candidate)) {
                    .dictionary => p.add("dictionary_sequences", 1),
                    .history => p.add("history_sequences", 1),
                    .block => {},
                }
                p.max_distance = @max(p.max_distance, record.distance);
                previous_end = record.match_end;
            }
        }
        fn blockType(bytes: []const u8) u2 {
            return @truncate(std.mem.readInt(u24, bytes[0..3], .little) >> 1);
        }
        fn countBlock(profile: ?*controls.Profile, bytes: []const u8) void {
            const p = profile orelse return;
            switch (blockType(bytes)) {
                0 => p.add("raw_blocks", 1),
                1 => p.add("rle_blocks", 1),
                2 => p.add("compressed_blocks", 1),
                else => unreachable,
            }
        }
    };
}
