//! Each Job runs the original Block planners with independent entropy priors,
//! the original settings, and the entire legal borrowed frame-history window.
const std = @import("std");
const View = @import("job_view.zig").View;

pub fn Encoder(comptime S: type) type {
    return struct {
        pub fn encode(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, start: usize, end: usize, options: S.Options, dictionary: ?S.Dictionary, work: *S.Profile) S.Error!void {
            if (start > end or end > input.len or (start == end and input.len != 0)) return error.InvalidBlockPlan;
            return encodeOwned(allocator, out, try View.oneShot(input, start, end), options, dictionary, work);
        }

        pub fn encodeOwned(allocator: std.mem.Allocator, out: *std.ArrayList(u8), view: View, options: S.Options, dictionary: ?S.Dictionary, work: *S.Profile) S.Error!void {
            try view.validate();
            const history_window = @min(try S.encoderWindow(options), view.window_limit orelse std.math.maxInt(usize));
            try view.validatePrefix(history_window);
            if (view.plain().len == 0 and !view.final) return error.InvalidBlockPlan;
            if (view.plain().len != 0 and history_window == 0 and
                options.selection != .raw_or_rle) return error.SizeMismatch;
            const original_len = out.items.len;
            errdefer out.items.len = original_len;
            var inner = options;
            inner.control_profile = null;
            inner.memory_profile = null;
            inner.max_total_working_memory = null;
            try inner.validate();
            inner.control_profile = work;
            const selected = (try S.largeLegacyOptions(inner)) orelse inner;
            S.profileOptions(selected, work);
            if (view.window_limit != null and view.plain().len == 0) {
                try S.emitRaw(allocator, out, "", view.final);
                return;
            }
            if (S.controlled(selected)) {
                try encodeBlocks(allocator, out, view, selected, dictionary, true);
                return;
            }
            if (inner.selection == .raw_or_rle) {
                try encodeRaw(allocator, out, view, try blockSize(inner, view));
                return;
            }
            if (inner.selection != .auto) {
                try encodeBlocks(allocator, out, view, inner, dictionary, false);
                return;
            }
            var candidate: std.ArrayList(u8) = .empty;
            defer candidate.deinit(allocator);
            try encodeBlocks(allocator, &candidate, view, inner, dictionary, false);
            const raw_len = try rawLength(view.plain(), 0, view.plain().len, try blockSize(inner, view));
            if (candidate.items.len < raw_len)
                try out.appendSlice(allocator, candidate.items)
            else
                try encodeRaw(allocator, out, view, try blockSize(inner, view));
        }

        fn blockSize(options: S.Options, view: View) S.Error!usize {
            if (view.window_limit != null) {
                const expected = if (options.include_content_size and view.final) @as(?@import("job_view.zig").Count, try view.globalPosition(view.plain().len)) else null;
                return S.streamBlockSize(options, expected);
            }
            return S.blockSize(options);
        }

        fn encodeBlocks(allocator: std.mem.Allocator, out: *std.ArrayList(u8), view: View, options: S.Options, dictionary: ?S.Dictionary, controlled: bool) S.Error!void {
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
            const block_size = try blockSize(options, view);
            const history_window = @min(try S.encoderWindow(options), view.window_limit orelse std.math.maxInt(usize));
            const plain = view.plain();
            const entropy = !controlled and options.selection != .fast_compressed;
            if (entropy and (view.frame_offset != 0 or !view.final or plain.len > block_size)) {
                try index.prepare(allocator, history_window > S.default_window_len);
                const prefix = try view.historyBefore(0, history_window);
                index.insertBlock(prefix, try view.historyStart(0, history_window));
            }
            var offset: usize = 0;
            while (true) {
                const block_end = offset + @min(block_size, plain.len - offset);
                const block = plain[offset..block_end];
                const last = view.final and block_end == plain.len;
                const global_offset = try view.globalPosition(offset);
                const history = try view.historyBefore(offset, history_window);
                const prefix_start = try view.historyStart(offset, history_window);
                const window = if (view.window_limit != null)
                    @as(?usize, history_window)
                else
                    try S.windowForBlock(options, global_offset, block.len, last);
                if (controlled) {
                    try S.Controlled.writeBlockBounded(allocator, out, block, last, options, &state, dictionary, history, global_offset, &records, &scratch, &blocks, window);
                } else if (options.selection == .fast_compressed) {
                    const visible = S.visibleDictionary(dictionary, global_offset, window);
                    try S.emitFast(allocator, out, block, last, &state, visible, &scratch, &blocks);
                } else {
                    const history_view: S.HistoryView = .{ .bytes = history, .absolute_start = prefix_start, .index = &index };
                    try S.emitEntropy(true, allocator, out, block, last, &state, dictionary, history_view, global_offset, options.match_search_budget, options.rep_beam_search, &beam, &scratch, &blocks, window);
                    if (!last) index.insertBlock(block, global_offset);
                }
                offset = block_end;
                if (offset == plain.len) break;
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

        fn encodeRaw(allocator: std.mem.Allocator, out: *std.ArrayList(u8), view: View, block_size: usize) S.Error!void {
            const input = view.plain();
            const end = input.len;
            if (end == 0) return S.emitRaw(allocator, out, "", view.final);
            var offset: usize = 0;
            while (offset < end) {
                const search_end = offset + @min(block_size, end - offset);
                if (S.findRle(input[offset..search_end])) |run| {
                    const run_start = offset + run.start;
                    if (run_start > offset) try S.emitBlock(allocator, out, input[offset..run_start], false);
                    const run_end = run_start + run.len;
                    try S.emitRle(allocator, out, input[run_start], run.len, view.final and run_end == end);
                    offset = run_end;
                } else {
                    try S.emitBlock(allocator, out, input[offset..search_end], view.final and search_end == end);
                    offset = search_end;
                }
            }
        }
    };
}
