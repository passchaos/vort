const std = @import("std");
const Count = @import("../../../core.zig").StreamCount;
const XxHash64 = @import("../../../checksum/xxh64_stream.zig").XxHash64;
const controls = @import("../../encode/controls.zig");

/// Publish final block and checksum as one pending-output transaction. Input
/// acceptance and already delivered bytes stay committed by the outer stream;
/// only this new final emission, codec/hash state and emitted counts roll back.
pub fn append(comptime Codec: type, comptime BlockEmitter: type, allocator: std.mem.Allocator, pending: *std.ArrayList(u8), block: []const u8, options: Codec.Options, state: *Codec.State, dictionary: ?Codec.Dictionary, history: Codec.HistoryView, frame_offset: Count, hasher: *XxHash64) Codec.Error!void {
    const original_len = pending.items.len;
    var next_state = state.*;
    var next_hasher = hasher.*;
    const emission = controls.EmissionTransaction.init(if (@hasField(Codec.Options, "control_profile")) options.control_profile else null);
    errdefer {
        pending.items.len = original_len;
        emission.rollback();
    }
    try BlockEmitter.write(allocator, pending, block, true, options, &next_state, dictionary, history, frame_offset);
    try Codec.writeChecksum(allocator, pending, options, &next_hasher);
    state.* = next_state;
    hasher.* = next_hasher;
}
