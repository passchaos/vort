//! Transactional paged execution of a prepared Zstandard sequence bitstream.
//!
//! One complete sequence is the minimum commit unit. Source failures or
//! malformed fields restore the logical bit cursor and leave FSE states,
//! repeated offsets, and the remaining count unchanged.
const core = @import("../../core.zig");
const source_input = @import("input.zig");
const reverse = @import("reverse_bit_reader.zig");
const source_sequences = @import("sequences.zig");

pub const Error = core.Error || source_input.Error;

pub const Snapshot = struct {
    decoded: usize,
    remaining: usize,
    ll_state: usize,
    of_state: usize,
    ml_state: usize,
    repeated_offsets: [3]usize,
    reader_remaining_bits: usize,
    finished: bool,
    reader: reverse.Snapshot,
};

pub fn Cursor(comptime Codec: type) type {
    return struct {
        const Self = @This();

        prepared: *const source_sequences.Prepared(Codec.Tables),
        reader: reverse.Reader,
        state: Codec.State,
        remaining_count: usize,
        decoded_count: usize = 0,

        /// Return the next complete sequence, or null after exact bitstream end.
        /// Every error rolls back this sequence's logical bit consumption and
        /// leaves all semantic cursor state unchanged.
        pub fn next(self: *Self) Error!?Codec.Sequence {
            if (self.remaining_count == 0) return null;
            const saved = self.reader.checkpoint();
            errdefer self.reader.restore(saved);
            var candidate = self.state;
            const sequence = try Codec.readSequence(
                &self.reader,
                &self.prepared.tables,
                &candidate,
                self.remaining_count == 1,
            );
            self.state = candidate;
            self.remaining_count -= 1;
            self.decoded_count += 1;
            return sequence;
        }

        pub fn remaining(self: Self) usize {
            return self.remaining_count;
        }

        pub fn isFinished(self: Self) bool {
            return self.remaining_count == 0;
        }

        pub fn finalRepeatedOffsets(self: Self) Error![3]usize {
            if (self.remaining_count != 0) return error.InvalidStreamState;
            return Codec.repeatedOffsets(&self.state);
        }

        pub fn snapshot(self: Self) Snapshot {
            return .{
                .decoded = self.decoded_count,
                .remaining = self.remaining_count,
                .ll_state = self.state.ll_state,
                .of_state = self.state.of_state,
                .ml_state = self.state.ml_state,
                .repeated_offsets = Codec.repeatedOffsets(&self.state),
                .reader_remaining_bits = self.reader.available(),
                .finished = self.remaining_count == 0,
                .reader = self.reader.snapshot(),
            };
        }
    };
}

pub fn init(
    comptime Codec: type,
    prepared: *const source_sequences.Prepared(Codec.Tables),
    initial_repeated_offsets: [3]usize,
    page: []u8,
) Error!Cursor(Codec) {
    // `prepared`, its source context, and the exclusive page must remain stable
    // for the cursor lifetime.
    if (page.len < reverse.minimum_page_len) return error.OutputTooSmall;
    if (prepared.sequence_count == 0) return error.CorruptFrame;
    var reader = try reverse.Reader.init(prepared.bitstream, page);
    const state = try Codec.initState(
        &reader,
        &prepared.tables,
        initial_repeated_offsets,
    );
    return .{
        .prepared = prepared,
        .reader = reader,
        .state = state,
        .remaining_count = prepared.sequence_count,
    };
}
