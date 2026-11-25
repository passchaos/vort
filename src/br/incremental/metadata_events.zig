//! Synchronous, allocation-free observation of Brotli metadata meta-blocks.
const Counter = @import("../../core.zig").StreamCount;

pub const Block = struct {
    /// Zero-based metadata block index within the current stream.
    block_index: Counter,
    len: usize,
    final: bool,
};

pub const Chunk = struct {
    block_index: Counter,
    /// Zero-based byte offset within the metadata block.
    offset: usize,
    /// Nonempty, read-only bytes valid only during the callback.
    bytes: []const u8,
};

pub const Event = union(enum) {
    /// A complete, aligned metadata header was validated. For an empty block
    /// this is the only event. Otherwise the block is complete once chunks
    /// cover its declared length; input may still fail or end before then.
    start: Block,
    chunk: Chunk,
};

pub const Observer = struct {
    /// Keep context and any mutable callback storage independent of the
    /// decoder and its input, output, history, scratch and capture storage.
    /// The callback must not reenter or mutate these while decoding.
    context: ?*anyopaque = null,
    on_event: *const fn (?*anyopaque, Event) void,

    pub fn emitStart(self: Observer, block_index: Counter, len: usize, final: bool) void {
        self.on_event(self.context, .{ .start = .{ .block_index = block_index, .len = len, .final = final } });
    }

    pub fn emitChunk(self: Observer, block_index: Counter, offset: usize, bytes: []const u8) void {
        if (bytes.len != 0)
            self.on_event(self.context, .{ .chunk = .{ .block_index = block_index, .offset = offset, .bytes = bytes } });
    }
};
