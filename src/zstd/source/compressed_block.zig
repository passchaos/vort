//! Transactional execution of one source-backed Zstandard compressed block.
//!
//! Preparation retains only checked source ranges and pending entropy state.
//! Execution writes into caller-owned block staging; history and frame state
//! are published together only after the complete block has validated. The
//! prepared value, frame state, history binding, staging, and both exclusive
//! pages must keep stable addresses for the executor lifetime. Source backing
//! and dictionary-history bytes must remain alive and immutable for that whole
//! lifetime, and must not alias any executor state or mutable workspace.
//!
//! A successfully executed block leases `staging[0..committedBytes().len]`
//! until `drain` has consumed it. The caller must not reuse or mutate that
//! storage while the lease is active.
const core = @import("../../core.zig");
const history_workspace = @import("../decode/history_workspace.zig");
const stable_output = @import("../decode/stable_output.zig");
const execution = @import("compressed_block/execute.zig");
const preparation = @import("compressed_block/prepare.zig");
const workspace = @import("compressed_block/workspace.zig");
const source_frame = @import("frame.zig");
const source_huffman = @import("huffman.zig");
const literal_stream = @import("literal_stream.zig");
const source_sequence_cursor = @import("sequence_cursor.zig");
const source_input = @import("input.zig");

const Count = core.StreamCount;

pub const Error = core.Error || source_input.Error;

pub const Limits = struct {
    block_decoded_max: usize,
    frame_decoded_max: Count,
    expected_frame_size: ?Count = null,
};

pub const Phase = enum {
    sequence,
    sequence_literals,
    sequence_match,
    tail_literals,
    finalize,
    committed,
    drained,
};

pub const Snapshot = struct {
    phase: Phase,
    staged_len: usize,
    drained_len: usize,
    committed: bool,
    failed: bool,
};

pub const DrainResult = struct {
    written: usize,
    status: Status,

    pub const Status = enum {
        need_output,
        done,
    };
};

pub fn FrameState(comptime HuffmanCodec: type, comptime SequenceCodec: type) type {
    return struct {
        huffman: ?HuffmanCodec.Table = null,
        sequence_tables: ?SequenceCodec.Tables = null,
        repeated_offsets: [3]usize = .{ 1, 4, 8 },
        frame_decoded: Count = 0,
    };
}

pub const Prepared = preparation.Prepared;

/// Parse one outer compressed block in the same error-priority order as the
/// slice decoder: literal prefix, Huffman preparation, literal layout finish,
/// then sequence preparation. The committed frame state is never modified.
pub fn prepare(
    comptime HuffmanCodec: type,
    comptime SequenceCodec: type,
    block: source_frame.BlockLayout,
    committed: *const FrameState(HuffmanCodec, SequenceCodec),
    scratch: []u8,
) Error!Prepared(HuffmanCodec, SequenceCodec) {
    return preparation.prepare(
        HuffmanCodec,
        SequenceCodec,
        block,
        committed,
        scratch,
    );
}

pub fn Executor(comptime HuffmanCodec: type, comptime SequenceCodec: type) type {
    return struct {
        const Self = @This();
        const State = FrameState(HuffmanCodec, SequenceCodec);
        const BlockPrepared = Prepared(HuffmanCodec, SequenceCodec);
        const LiteralStream = literal_stream.Stream(HuffmanCodec);
        const SequenceCursor = source_sequence_cursor.Cursor(SequenceCodec);

        prepared: *const BlockPrepared,
        committed: *State,
        history: *history_workspace.Binding,
        dictionary_history: []const u8,
        staging: []u8,
        limits: Limits,
        literals: LiteralStream,
        sequences: ?SequenceCursor,
        initial_frame_decoded: Count,
        initial_history_head: usize,
        initial_history_len: usize,
        phase: Phase,
        written: usize = 0,
        literal_run_remaining: usize = 0,
        match_offset: usize = 0,
        match_len: usize = 0,
        drain_offset: usize = 0,
        failure: ?Error = null,

        /// Validate every caller-owned workspace before initializing either
        /// source cursor. This makes undersized, inactive, or aliasing plans
        /// fail before the first source callback. `dictionary_history` must
        /// be the exact immutable history slice whose length configured the
        /// binding; it is borrowed for the full executor lifetime and must
        /// not alias executor state or mutable workspace. Pass `&.{}` when
        /// the frame has no dictionary history.
        pub fn init(
            prepared: *const BlockPrepared,
            committed: *State,
            history: *history_workspace.Binding,
            dictionary_history: []const u8,
            staging: []u8,
            literal_page: []u8,
            sequence_page: []u8,
            limits: Limits,
        ) Error!Self {
            if (staging.len < limits.block_decoded_max)
                return error.OutputTooSmall;
            if (literal_page.len < literal_stream.minimum_page_len or
                sequence_page.len < literal_stream.minimum_page_len)
                return error.OutputTooSmall;
            try workspace.validatePrepared(prepared, limits.block_decoded_max);
            try workspace.validateHistory(
                history.*,
                committed.frame_decoded,
                dictionary_history.len,
                limits.block_decoded_max,
            );
            try workspace.validateAliases(
                prepared,
                committed,
                history,
                dictionary_history,
                staging,
                literal_page,
                sequence_page,
            );
            try workspace.validateInitialFrameLimits(
                committed.frame_decoded,
                limits.frame_decoded_max,
                limits.expected_frame_size,
            );

            const pending_huffman: ?*const source_huffman.Prepared(HuffmanCodec) =
                if (prepared.pending_huffman) |*pending| pending else null;
            const literals = try literal_stream.init(
                HuffmanCodec,
                prepared.literals,
                pending_huffman,
                literal_page,
            );

            var sequences: ?SequenceCursor = null;
            if (prepared.pending_sequences) |*pending| {
                sequences = try source_sequence_cursor.init(
                    SequenceCodec,
                    pending,
                    committed.repeated_offsets,
                    sequence_page,
                );
            }

            return .{
                .prepared = prepared,
                .committed = committed,
                .history = history,
                .dictionary_history = dictionary_history,
                .staging = staging,
                .limits = limits,
                .literals = literals,
                .sequences = sequences,
                .initial_frame_decoded = committed.frame_decoded,
                .initial_history_head = history.head,
                .initial_history_len = history.len,
                .phase = if (sequences == null) .tail_literals else .sequence,
            };
        }

        /// Execute the rest of the block. `SourceReadFailed` and
        /// `TruncatedFrame` preserve a retryable instance. Literal execution
        /// advances `written` by the exact committed prefix reported by the
        /// literal stream; sequence reads remain atomic in their own cursor.
        pub fn execute(self: *Self) Error!void {
            if (self.phase == .committed or self.phase == .drained)
                return error.InvalidStreamState;
            if (self.failure != null) return error.InvalidStreamState;
            if (self.committed.frame_decoded != self.initial_frame_decoded or
                self.history.head != self.initial_history_head or
                self.history.len != self.initial_history_len)
                return error.InvalidStreamState;

            execution.drive(self) catch |err| {
                if (!isRetryableSourceError(err)) self.failure = err;
                return err;
            };
        }

        /// Copy committed bytes into an arbitrarily small destination. A zero
        /// destination makes no progress. Before successful execution there
        /// is no public output and this returns `InvalidStreamState`.
        pub fn drain(self: *Self, destination: []u8) Error!DrainResult {
            switch (self.phase) {
                .committed => {},
                .drained => return .{ .written = 0, .status = .done },
                else => return error.InvalidStreamState,
            }
            const remaining = self.written - self.drain_offset;
            const amount = @min(destination.len, remaining);
            if (amount == 0) {
                if (remaining == 0) {
                    self.phase = .drained;
                    return .{ .written = 0, .status = .done };
                }
                return .{ .written = 0, .status = .need_output };
            }
            if (stable_output.overlaps(
                destination[0..amount],
                self.staging[0..self.written],
            )) return error.InvalidBlockPlan;
            @memcpy(
                destination[0..amount],
                self.staging[self.drain_offset..][0..amount],
            );
            self.drain_offset += amount;
            if (self.drain_offset == self.written) self.phase = .drained;
            return .{
                .written = amount,
                .status = if (self.phase == .drained) .done else .need_output,
            };
        }

        /// Borrow the successful block lease before it has been fully drained.
        pub fn committedBytes(self: *const Self) Error![]const u8 {
            if (self.phase != .committed) return error.InvalidStreamState;
            return self.staging[0..self.written];
        }

        pub fn snapshot(self: *const Self) Snapshot {
            const committed_block = self.phase == .committed or self.phase == .drained;
            return .{
                .phase = self.phase,
                .staged_len = self.written,
                .drained_len = self.drain_offset,
                .committed = committed_block,
                .failed = self.failure != null,
            };
        }
    };
}

fn isRetryableSourceError(err: Error) bool {
    return err == error.SourceReadFailed or err == error.TruncatedFrame;
}
