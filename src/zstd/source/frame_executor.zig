//! Transactional execution of one source-backed Zstandard data frame.
//!
//! The executor walks block headers in the caller's random-access source,
//! executes Raw, RLE and Compressed blocks into caller-owned staging, and
//! publishes history plus frame state only after each complete block succeeds.
//! After the last block it consumes the optional XXH64 content-checksum footer
//! and reports the exact frame end offset.
//!
//! Scope is deliberately one data frame. Skippable frames, concatenated stream
//! orchestration and dictionary-set selection belong to a higher layer. The
//! caller supplies the already-selected dictionary bytes and the initial frame
//! state (entropy tables and repeated offsets); a mismatched header dictionary
//! ID is rejected before the first block.
//!
//! Source backing, dictionary bytes and every caller workspace must remain
//! alive and immutable for the executor lifetime. Staging, the two entropy
//! pages, history storage, dictionary history, the frame state and the history
//! binding must not alias each other. A retryable source failure (including
//! truncation) leaves the current block uncommitted; a later `execute` restarts
//! only that block because block publication is atomic. Other failures poison
//! the executor.
const std = @import("std");
const core = @import("../../core.zig");
const StreamingXxHash64 = @import("../../checksum/xxh64_stream.zig").XxHash64;
const history_workspace = @import("../decode/history_workspace.zig");
const stable_output = @import("../decode/stable_output.zig");
const frame_checksum = @import("../frame/checksum.zig");
const compressed_block = @import("compressed_block.zig");
const source_frame = @import("frame.zig");
const source_huffman = @import("huffman.zig");
const source_input = @import("input.zig");
const literal_stream = @import("literal_stream.zig");

const Count = core.StreamCount;
const count = core.stream_count;

pub const Error = core.Error || source_input.Error;

pub const Limits = struct {
    /// Whole-frame decoded-byte cap, independent of the declared content size.
    frame_decoded_max: Count = std.math.maxInt(Count),
    /// Consume the footer without comparing it to the decoded content hash.
    ignore_checksum: bool = false,
};

pub const Phase = enum {
    next_block,
    drain,
    footer,
    done,
};

pub const Snapshot = struct {
    phase: Phase,
    block_index: usize,
    frame_decoded: Count,
    staged_len: usize,
    drained_len: usize,
    last_block: bool,
    has_checksum: bool,
    failed: bool,
};

pub const DrainResult = struct {
    written: usize,
    status: Status,

    pub const Status = enum {
        need_output,
        block_drained,
    };
};

pub fn Executor(comptime HuffmanCodec: type, comptime SequenceCodec: type) type {
    return struct {
        const Self = @This();
        const State = compressed_block.FrameState(HuffmanCodec, SequenceCodec);
        const BlockExecutor = compressed_block.Executor(HuffmanCodec, SequenceCodec);

        frame: source_frame.DataFrameLayout,
        state: *State,
        history: *history_workspace.Binding,
        dictionary_history: []const u8,
        staging: []u8,
        literal_page: []u8,
        sequence_page: []u8,
        limits: Limits,
        hasher: StreamingXxHash64,
        phase: Phase = .next_block,
        next_header_offset: u64,
        block_index: usize = 0,
        staged_len: usize = 0,
        drain_offset: usize = 0,
        last_block: bool = false,
        frame_end_offset: u64 = 0,
        failure: ?Error = null,

        /// Validate the frame header, dictionary identity and every caller
        /// workspace before the first source payload callback. `state` must be
        /// the frame-local state: its decoded counter starts at zero, while
        /// dictionary entropy tables and repeated offsets may already be set.
        pub fn init(
            frame: source_frame.DataFrameLayout,
            state: *State,
            history: *history_workspace.Binding,
            dictionary_history: []const u8,
            dictionary_id: u32,
            staging: []u8,
            literal_page: []u8,
            sequence_page: []u8,
            limits: Limits,
        ) Error!Self {
            if (frame.header.dictionary_id != dictionary_id) {
                if (dictionary_id == 0) return error.NeedDictionary;
                return error.DictionaryMismatch;
            }
            if (staging.len < frame.header.block_size_max)
                return error.OutputTooSmall;
            if (literal_page.len < literal_stream.minimum_page_len or
                sequence_page.len < literal_stream.minimum_page_len)
                return error.OutputTooSmall;
            if (!history.active()) return error.InvalidStreamState;

            const window = try count.toLocal(frame.header.window_size);
            if (history.window != window) return error.InvalidStreamState;
            const required_limit = try history_workspace.requiredLen(
                frame.header.window_size,
                dictionary_history.len,
            );
            if (history.limit != required_limit or
                history.limit > history.storage.len or
                history.len != 0 or
                frame.header.block_size_max > history.window or
                (history.limit == 0 and history.head != 0) or
                (history.limit != 0 and history.head >= history.limit))
                return error.InvalidStreamState;
            if (state.frame_decoded != 0) return error.InvalidStreamState;

            // History append uses ordinary additions after its branch. A
            // conservative one-block proof keeps final publication infallible.
            const block_max = frame.header.block_size_max;
            _ = std.math.add(usize, history.head, block_max) catch
                return error.IntegerOverflow;
            _ = std.math.add(usize, history.len, block_max) catch
                return error.IntegerOverflow;
            _ = std.math.add(usize, history.limit, history.limit) catch
                return error.IntegerOverflow;

            if (frame.header.content_size) |expected|
                if (expected > limits.frame_decoded_max)
                    return error.OutputLimitExceeded;

            try validateAliases(
                state,
                history,
                dictionary_history,
                staging,
                literal_page,
                sequence_page,
            );

            return .{
                .frame = frame,
                .state = state,
                .history = history,
                .dictionary_history = dictionary_history,
                .staging = staging,
                .literal_page = literal_page,
                .sequence_page = sequence_page,
                .limits = limits,
                .hasher = StreamingXxHash64.init(0),
                .next_header_offset = frame.first_block_offset,
            };
        }

        /// Execute exactly one complete block, or validate the footer once the
        /// last block has drained. Retryable source failures leave the executor
        /// in its current phase without publishing block state.
        pub fn execute(self: *Self) Error!void {
            if (self.failure != null) return error.InvalidStreamState;
            switch (self.phase) {
                .next_block => self.executeBlock() catch |err| {
                    self.poison(err);
                    return err;
                },
                .footer => self.finishFrame() catch |err| {
                    self.poison(err);
                    return err;
                },
                .drain, .done => return error.InvalidStreamState,
            }
        }

        /// Copy the committed block lease into an arbitrarily small
        /// destination. A zero destination makes no progress.
        pub fn drain(self: *Self, destination: []u8) Error!DrainResult {
            if (self.phase != .drain) return error.InvalidStreamState;
            const remaining = self.staged_len - self.drain_offset;
            const amount = @min(destination.len, remaining);
            if (amount == 0) {
                if (remaining == 0) {
                    self.finishBlock();
                    return .{ .written = 0, .status = .block_drained };
                }
                return .{ .written = 0, .status = .need_output };
            }
            if (stable_output.overlaps(
                destination[0..amount],
                self.staging[0..self.staged_len],
            )) return error.InvalidBlockPlan;
            @memcpy(
                destination[0..amount],
                self.staging[self.drain_offset..][0..amount],
            );
            self.drain_offset += amount;
            if (self.drain_offset == self.staged_len) {
                self.finishBlock();
                return .{ .written = amount, .status = .block_drained };
            }
            return .{ .written = amount, .status = .need_output };
        }

        /// Borrow the successful block lease before it has been fully drained.
        pub fn committedBytes(self: *const Self) Error![]const u8 {
            if (self.phase != .drain) return error.InvalidStreamState;
            return self.staging[0..self.staged_len];
        }

        /// Byte offset immediately after the checksum footer (or last block).
        /// Only available after the frame has completed successfully.
        pub fn frameEndOffset(self: *const Self) Error!u64 {
            if (self.phase != .done) return error.InvalidStreamState;
            return self.frame_end_offset;
        }

        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .block_index = self.block_index,
                .frame_decoded = self.state.frame_decoded,
                .staged_len = self.staged_len,
                .drained_len = self.drain_offset,
                .last_block = self.last_block,
                .has_checksum = self.frame.header.has_checksum,
                .failed = self.failure != null,
            };
        }

        fn poison(self: *Self, err: Error) void {
            if (!isRetryableSourceError(err)) self.failure = err;
        }

        fn executeBlock(self: *Self) Error!void {
            const block = try source_frame.parseBlock(
                self.frame,
                self.next_header_offset,
            );
            switch (block.header.kind) {
                .raw => try self.executeRaw(block),
                .rle => try self.executeRle(block),
                .compressed => try self.executeCompressed(block),
            }
            self.next_header_offset = block.next_header_offset;
            self.last_block = block.header.last;
            self.block_index += 1;
            self.phase = .drain;
            self.drain_offset = 0;
        }

        fn executeRaw(
            self: *Self,
            block: source_frame.BlockLayout,
        ) Error!void {
            const len = block.header.declared_len;
            if (block.header.wire_len != len or block.payload.len != len)
                return error.CorruptFrame;
            try block.payload.readExact(0, self.staging[0..len]);
            try self.commitStaged(len, block.header.last);
        }

        fn executeRle(
            self: *Self,
            block: source_frame.BlockLayout,
        ) Error!void {
            if (block.payload.len != 1) return error.CorruptFrame;
            const value = try block.payload.byte(0);
            const len = block.header.declared_len;
            @memset(self.staging[0..len], value);
            try self.commitStaged(len, block.header.last);
        }

        fn executeCompressed(
            self: *Self,
            block: source_frame.BlockLayout,
        ) Error!void {
            var scratch: [source_huffman.maximum_scratch_len]u8 = undefined;
            var prepared = try compressed_block.prepare(
                HuffmanCodec,
                SequenceCodec,
                block,
                self.state,
                &scratch,
            );
            var executor = try BlockExecutor.init(
                &prepared,
                self.state,
                self.history,
                self.dictionary_history,
                self.staging,
                self.literal_page,
                self.sequence_page,
                .{
                    .block_decoded_max = self.frame.header.block_size_max,
                    .frame_decoded_max = self.limits.frame_decoded_max,
                    .expected_frame_size = self.frame.header.content_size,
                },
            );
            try executor.execute();
            const committed = try executor.committedBytes();
            self.hasher.update(committed);
            self.staged_len = committed.len;
        }

        fn commitStaged(self: *Self, len: usize, last: bool) Error!void {
            try self.validateGrowth(len, last);
            self.history.append(self.staging[0..len]);
            self.state.frame_decoded = try count.addLocal(
                self.state.frame_decoded,
                len,
            );
            self.hasher.update(self.staging[0..len]);
            self.staged_len = len;
        }

        fn validateGrowth(self: *Self, additional: usize, last: bool) Error!void {
            if (additional > self.frame.header.block_size_max)
                return error.CorruptFrame;
            const next_frame = try count.addLocal(
                self.state.frame_decoded,
                additional,
            );
            if (next_frame > self.limits.frame_decoded_max)
                return error.OutputLimitExceeded;
            if (self.frame.header.content_size) |expected| {
                if (next_frame > expected) return error.SizeMismatch;
                if (last and next_frame != expected)
                    return error.SizeMismatch;
            }
        }

        fn finishBlock(self: *Self) void {
            self.phase = if (self.last_block) .footer else .next_block;
            self.staged_len = 0;
            self.drain_offset = 0;
        }

        fn finishFrame(self: *Self) Error!void {
            if (self.frame.header.content_size) |expected|
                if (self.state.frame_decoded != expected)
                    return error.SizeMismatch;

            var end = self.next_header_offset;
            if (self.frame.header.has_checksum) {
                const relative = std.math.sub(
                    u64,
                    end,
                    self.frame.available.offset,
                ) catch return error.IntegerOverflow;
                var footer: [4]u8 = undefined;
                try self.frame.available.readExact(relative, &footer);
                const expected = std.mem.readInt(u32, &footer, .little);
                const actual: u32 = @truncate(self.hasher.final());
                try frame_checksum.validate(
                    expected,
                    actual,
                    self.limits.ignore_checksum,
                );
                end = std.math.add(u64, end, footer.len) catch
                    return error.IntegerOverflow;
            }
            self.frame_end_offset = end;
            self.phase = .done;
        }
    };
}

fn isRetryableSourceError(err: Error) bool {
    return err == error.SourceReadFailed or err == error.TruncatedFrame;
}

fn validateAliases(
    state: anytype,
    history: *history_workspace.Binding,
    dictionary_history: []const u8,
    staging: []const u8,
    literal_page: []const u8,
    sequence_page: []const u8,
) Error!void {
    const regions = [_][]const u8{
        history.storage,
        dictionary_history,
        staging,
        literal_page,
        sequence_page,
        std.mem.asBytes(state),
        std.mem.asBytes(history),
    };
    for (regions, 0..) |first, first_index|
        for (regions[first_index + 1 ..]) |second|
            if (stable_output.overlaps(first, second))
                return error.InvalidBlockPlan;
}
