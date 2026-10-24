//! HQ parser/format boundary. Parser costs borrow committed coding tables;
//! explicit offset values remain authoritative through entropy emission.
const std = @import("std");
const controls = @import("controls.zig");
const source_mod = @import("../match/controlled_source.zig");
const parser = @import("../match/hq_parser.zig");
pub const EntropyModel = parser.EntropyModel;

pub fn Encoder(comptime Codec: type) type {
    return struct {
        pub fn writeBlock(allocator: std.mem.Allocator, output: *std.ArrayList(u8), source: source_mod.Source, last: bool, options: Codec.Options, state: *Codec.State, dictionary: ?Codec.Dictionary, scratch: *Codec.SequenceScratch, block_scratch: *Codec.BlockScratch) Codec.Error!void {
            const emission = controls.EmissionTransaction.init(options.control_profile);
            errdefer emission.rollback();
            const start = output.items.len;
            errdefer output.items.len = start;
            var next_state = state.*;
            const model = try Codec.hqModel(state, dictionary);
            var consumed_model = model;
            consumed_model.initialized = true;
            next_state.hq_entropy = consumed_model;
            const hq_options = (try controls.effectiveHq(options)).?;
            const plan = try parser.planAlloc(allocator, source, .{ .strategy = options.strategy, .hq_options = hq_options, .initial_repeated_offsets = state.sequence_state.repeated_offsets, .entropy = &model, .profile = options.control_profile });
            defer plan.deinit(allocator);
            try validate(source, plan.records, plan.final_repeated_offsets, state.sequence_state.repeated_offsets);
            Codec.clearBlockScratch(block_scratch);
            const candidate = &block_scratch.candidate;
            const fallback = &block_scratch.best;
            const ready = plan.records.len != 0 and try Codec.writeHqSequences(allocator, candidate, source.block, last, plan.records, scratch, state);
            var next_huffman = state.previous_huffman_plan;
            if (!try Codec.writeHuffman(allocator, fallback, source.block, last, &next_huffman)) try Codec.writeRaw(allocator, fallback, source.block, last);
            if (ready and candidate.items.len <= fallback.items.len) {
                // The same decoder authority verifies table transitions and
                // exact offset selectors before publishing the output/state.
                try Codec.commitHqSequences(allocator, output, candidate.items, last, &next_state, plan.final_repeated_offsets);
                next_state.previous_huffman_plan = null;
                const committed_model = try Codec.hqModelFromCommitted(&next_state, null);
                next_state.hq_entropy = committed_model.refined(&plan.statistics);
                countReferences(options.control_profile, source, plan.records);
            } else {
                try output.appendSlice(allocator, fallback.items);
                if (blockType(fallback.items) == 2) {
                    next_state.previous_huffman_plan = next_huffman;
                    next_state.hq_entropy = try Codec.hqModelFromCommitted(&next_state, next_huffman);
                }
            }
            state.* = next_state;
            if (options.control_profile) |profile| switch (blockType(output.items[start..])) {
                0 => profile.add("raw_blocks", 1),
                1 => profile.add("rle_blocks", 1),
                2 => profile.add("compressed_blocks", 1),
                else => unreachable,
            };
        }
        fn validate(source: source_mod.Source, records: []const source_mod.Record, final_reps: [3]usize, initial_reps: [3]usize) Codec.Error!void {
            var previous_end: usize = 0;
            var reps = initial_reps;
            for (records) |record| {
                const start = std.math.add(usize, previous_end, record.literal_len) catch return error.IntegerOverflow;
                const end = std.math.add(usize, start, record.match_len) catch return error.IntegerOverflow;
                const value = std.math.cast(u32, record.offset_value orelse return error.InvalidBlockPlan) orelse return error.InvalidBlockPlan;
                const choice = try parser.rep.resolve(record.literal_len, value, reps);
                if (choice.distance != record.distance or record.match_len < 3 or record.match_end != end or end > source.block.len or record.distance > source.window_len or record.distance > source.prefixLen() + start) return error.InvalidBlockPlan;
                reps = choice.repeats;
                previous_end = end;
            }
            if (!std.mem.eql(usize, &reps, &final_reps)) return error.InvalidBlockPlan;
        }
        fn countReferences(profile: ?*controls.Profile, source: source_mod.Source, records: []const source_mod.Record) void {
            const value = profile orelse return;
            var end: usize = 0;
            for (records) |record| {
                const start = end + record.literal_len;
                const candidate = source.prefixLen() + start - record.distance;
                switch (source.origin(candidate)) {
                    .dictionary => value.add("dictionary_sequences", 1),
                    .history => value.add("history_sequences", 1),
                    .block => {},
                }
                value.max_distance = @max(value.max_distance, record.distance);
                end = record.match_end;
            }
        }
        fn blockType(bytes: []const u8) u2 {
            return @truncate(std.mem.readInt(u24, bytes[0..3], .little) >> 1);
        }
    };
}
