//! Each Job runs the original Block planners with independent entropy priors,
//! the original settings, and the entire legal borrowed frame-history window.
const std = @import("std");

pub fn Encoder(comptime S: type) type {
    return struct {
        pub fn encode(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, start: usize, end: usize, options: S.Options, dictionary: ?S.Dictionary, work: *S.Profile) S.Error!void {
            if (start > end or end > input.len or (start == end and input.len != 0)) return error.InvalidBlockPlan;
            const original_len = out.items.len;
            errdefer out.items.len = original_len;
            var inner = options;
            inner.control_profile = work;
            inner.memory_profile = null;
            inner.max_total_working_memory = null;
            const selected = (try S.largeLegacyOptions(inner)) orelse inner;
            S.profileOptions(selected, work);
            if (S.controlled(selected)) {
                try encodeBlocks(allocator, out, input, start, end, selected, dictionary, true);
                return;
            }
            if (inner.selection == .raw_or_rle) {
                try encodeRaw(allocator, out, input, start, end, try S.blockSize(inner));
                return;
            }
            if (inner.selection != .auto) {
                try encodeBlocks(allocator, out, input, start, end, inner, dictionary, false);
                return;
            }
            var candidate: std.ArrayList(u8) = .empty;
            defer candidate.deinit(allocator);
            try encodeBlocks(allocator, &candidate, input, start, end, inner, dictionary, false);
            const raw_len = try rawLength(input, start, end, try S.blockSize(inner));
            if (candidate.items.len < raw_len)
                try out.appendSlice(allocator, candidate.items)
            else
                try encodeRaw(allocator, out, input, start, end, try S.blockSize(inner));
        }

        fn encodeBlocks(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, start: usize, end: usize, options: S.Options, dictionary: ?S.Dictionary, controlled: bool) S.Error!void {
            var state: S.EncoderState = .{};
            // Even when dictionary content has left the current matching
            // window, its initial entropy/repcodes belong to the whole frame.
            try S.ensureEncoderState(&state, dictionary);
            var records: std.ArrayList(S.Record) = .empty;
            defer records.deinit(allocator);
            var scratch: S.SequenceScratch = .{};
            defer S.deinitScratch(&scratch, allocator);
            var blocks: S.BlockScratch = .{ .force_serial_mixed = true, .heap_mixed_workspace = true };
            defer S.deinitBlockScratch(&blocks, allocator);
            var beam: S.RepBeamScratch = .{};
            defer beam.deinit(allocator);
            var index: S.HistoryIndex = .{};
            defer index.deinit(allocator);
            const block_size = try S.blockSize(options);
            const history_window = try S.encoderWindow(options);
            const entropy = !controlled and options.selection != .fast_compressed;
            if (entropy and (start != 0 or end < input.len or end - start > block_size)) {
                try index.prepare(allocator, history_window > S.default_window_len);
                const prefix_start = start - @min(start, history_window);
                index.insertBlock(input[prefix_start..start], prefix_start);
            }
            var offset = start;
            while (true) {
                const block_end = offset + @min(block_size, end - offset);
                const block = input[offset..block_end];
                const last = block_end == input.len;
                const prefix_start = offset - @min(offset, history_window);
                const history = input[prefix_start..offset];
                if (controlled) {
                    try S.Controlled.writeBlock(allocator, out, block, last, options, &state, dictionary, history, offset, &records, &scratch, &blocks);
                } else if (options.selection == .fast_compressed) {
                    const visible = S.visibleDictionary(dictionary, offset, try S.windowForBlock(options, offset, block.len, last));
                    try S.emitFast(allocator, out, block, last, &state, visible, &scratch, &blocks);
                } else {
                    const view: S.HistoryView = .{ .bytes = history, .absolute_start = prefix_start, .index = &index };
                    try S.emitEntropy(true, allocator, out, block, last, &state, dictionary, view, offset, options.match_search_budget, options.rep_beam_search, &beam, &scratch, &blocks, try S.windowForBlock(options, offset, block.len, last));
                    if (!last) index.insertBlock(block, offset);
                }
                offset = block_end;
                if (offset == end) break;
            }
        }

        fn rawLength(input: []const u8, start: usize, end: usize, block_size: usize) S.Error!usize {
            if (start == end) return 3;
            var total: usize = 0;
            var offset = start;
            while (offset < end) {
                const search_end = offset + @min(block_size, end - offset);
                if (S.findRle(input[offset..search_end])) |run| {
                    const run_start = offset + run.start;
                    if (run_start > offset) total = std.math.add(usize, total, 3 + payloadLength(input[offset..run_start])) catch return error.IntegerOverflow;
                    total = std.math.add(usize, total, 4) catch return error.IntegerOverflow;
                    offset = run_start + run.len;
                } else {
                    total = std.math.add(usize, total, 3 + payloadLength(input[offset..search_end])) catch return error.IntegerOverflow;
                    offset = search_end;
                }
            }
            return total;
        }

        fn payloadLength(bytes: []const u8) usize {
            return if (S.rle(bytes) != null) 1 else bytes.len;
        }

        fn encodeRaw(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, start: usize, end: usize, block_size: usize) S.Error!void {
            if (start == end) return S.emitRaw(allocator, out, "", true);
            var offset = start;
            while (offset < end) {
                const search_end = offset + @min(block_size, end - offset);
                if (S.findRle(input[offset..search_end])) |run| {
                    const run_start = offset + run.start;
                    if (run_start > offset) try S.emitBlock(allocator, out, input[offset..run_start], false);
                    const run_end = run_start + run.len;
                    try S.emitRle(allocator, out, input[run_start], run.len, run_end == input.len);
                    offset = run_end;
                } else {
                    try S.emitBlock(allocator, out, input[offset..search_end], search_end == input.len);
                    offset = search_end;
                }
            }
        }
    };
}
