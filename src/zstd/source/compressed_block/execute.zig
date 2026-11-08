//! Internal phase machine for a prepared compressed-block executor.
const std = @import("std");
const core = @import("../../../core.zig");
const source_input = @import("../input.zig");

const count = core.stream_count;

pub const Error = core.Error || source_input.Error;

pub fn drive(self: anytype) Error!void {
    while (true) switch (self.phase) {
        .sequence => try beginSequence(self),
        .sequence_literals => try copyLiteralRun(self, .sequence_match),
        .sequence_match => {
            try copyPendingMatch(self);
            self.phase = .sequence;
        },
        .tail_literals => {
            if (self.literal_run_remaining == 0) {
                const tail = self.literals.remaining();
                try validateGrowth(self, tail);
                self.literal_run_remaining = tail;
                if (tail == 0) {
                    self.phase = .finalize;
                    continue;
                }
            }
            try copyLiteralRun(self, .finalize);
        },
        .finalize => {
            try finishAndCommit(self);
            return;
        },
        .committed, .drained => return error.InvalidStreamState,
    };
}

fn beginSequence(self: anytype) Error!void {
    const cursor = if (self.sequences) |*cursor| cursor else {
        self.phase = .tail_literals;
        return;
    };
    const next = try cursor.next();
    const sequence = next orelse {
        self.phase = .tail_literals;
        return;
    };
    if (sequence.literal_len > self.literals.remaining())
        return error.CorruptFrame;
    const sequence_len = std.math.add(
        usize,
        sequence.literal_len,
        sequence.match_len,
    ) catch return error.IntegerOverflow;
    try validateGrowth(self, sequence_len);
    self.literal_run_remaining = sequence.literal_len;
    self.match_offset = sequence.match_offset;
    self.match_len = sequence.match_len;
    self.phase = if (sequence.literal_len == 0)
        .sequence_match
    else
        .sequence_literals;
}

fn copyLiteralRun(self: anytype, next_phase: anytype) Error!void {
    if (self.literal_run_remaining == 0) {
        self.phase = next_phase;
        return;
    }
    if (self.written > self.staging.len or
        self.literal_run_remaining > self.staging.len - self.written)
        return error.OutputTooSmall;
    const requested = self.literal_run_remaining;
    const end = self.written + requested;
    var literal_error: ?Error = null;
    var committed_prefix: usize = 0;
    self.literals.copyNext(
        self.staging[self.written..end],
        &committed_prefix,
    ) catch |err| {
        literal_error = err;
    };
    if (committed_prefix > requested)
        return error.InvalidStreamState;
    self.written += committed_prefix;
    self.literal_run_remaining -= committed_prefix;
    if (literal_error) |err| return err;
    if (committed_prefix != requested)
        return error.InvalidStreamState;
    self.phase = next_phase;
}

fn copyPendingMatch(self: anytype) Error!void {
    // Keep the executor's physical-capacity and visible-span arithmetic
    // explicit before entering the shared history copier.
    if (self.written > self.staging.len or
        self.match_len > self.staging.len - self.written)
        return error.OutputTooSmall;
    const available = try self.history.availableLenWithCurrent(
        self.dictionary_history.len,
        self.initial_frame_decoded,
        self.written,
    );
    _ = std.math.add(usize, available, self.match_len) catch
        return error.IntegerOverflow;
    if (self.match_offset == 0 or self.match_offset > available)
        return error.InvalidMatch;
    try self.history.copyMatch(
        self.dictionary_history,
        self.staging,
        &self.written,
        0,
        self.initial_frame_decoded,
        self.match_offset,
        self.match_len,
    );
}

fn validateGrowth(self: anytype, additional: usize) Error!void {
    const next_block = std.math.add(usize, self.written, additional) catch
        return error.IntegerOverflow;
    if (next_block > self.limits.block_decoded_max)
        return error.CorruptFrame;
    const next_frame = try count.addLocal(
        self.initial_frame_decoded,
        next_block,
    );
    if (next_frame > self.limits.frame_decoded_max)
        return error.OutputLimitExceeded;
    if (self.limits.expected_frame_size) |expected|
        if (next_frame > expected) return error.SizeMismatch;
}

fn finishAndCommit(self: anytype) Error!void {
    var final_repeated_offsets = self.committed.repeated_offsets;
    if (self.sequences) |*cursor| {
        if (!cursor.isFinished()) return error.CorruptFrame;
        final_repeated_offsets = try cursor.finalRepeatedOffsets();
    } else if (self.prepared.literals.sequence_count != 0) {
        return error.CorruptFrame;
    }
    if (self.literals.remaining() != 0) return error.CorruptFrame;
    try self.literals.expectEnd();
    if (!self.literals.isFinished()) return error.CorruptFrame;
    try validateGrowth(self, 0);

    const next_frame_decoded = try count.addLocal(
        self.initial_frame_decoded,
        self.written,
    );
    if (self.prepared.last)
        if (self.limits.expected_frame_size) |expected|
            if (next_frame_decoded != expected) return error.SizeMismatch;

    // Every operation below is infallible. History and frame state therefore
    // become visible as one successful block publication.
    self.history.append(self.staging[0..self.written]);
    if (self.prepared.pending_huffman) |pending| {
        if (pending.replace_on_block_success) {
            self.committed.huffman = pending.table;
        }
    }
    if (self.prepared.pending_sequences) |pending| {
        self.committed.sequence_tables = pending.tables;
        self.committed.repeated_offsets = final_repeated_offsets;
    }
    self.committed.frame_decoded = next_frame_decoded;
    self.phase = .committed;
}
