//! Synchronous delivery of Zstandard skippable frame payloads.
const Count = @import("../../core.zig").StreamCount;

pub const Start = struct {
    /// Zero-based ordinal among skippable frames in the logical stream.
    skippable_index: Count,
    id: u4,
    /// Absolute compressed offset of the skippable magic.
    frame_offset: Count,
    payload_len: u32,
};

pub const Chunk = struct {
    skippable_index: Count,
    id: u4,
    /// Byte offset within the frame's payload, excluding the header.
    offset: u32,
    /// Nonempty and valid only during the callback.
    bytes: []const u8,
};

pub const Observation = union(enum) {
    /// A complete header has been admitted. For an empty frame this is the
    /// only event. A truncated frame may deliver only a prefix of its body.
    start: Start,
    chunk: Chunk,
};

pub const Observer = struct {
    /// Keep context and mutable callback storage independent of the decoder,
    /// its inputs, outputs, capture buffers and workspaces. Do not reenter the
    /// decoder or mutate those buffers from a callback.
    context: ?*anyopaque = null,
    on_event: *const fn (?*anyopaque, Observation) void,

    pub fn emit(self: Observer, observation: Observation) void {
        self.on_event(self.context, observation);
    }
};
