const core = @import("../../core.zig");
const Count = core.StreamCount;

/// Cumulative decoded limits do not constrain one caller buffer's geometry.
pub fn addWithinLimit(current: Count, additional: Count, limit: Count) core.Error!Count {
    const next = try core.stream_count.add(current, additional);
    if (next > limit) return error.OutputLimitExceeded;
    return next;
}

/// Preflight validates only history the streaming decoder can retain. The
/// resulting conceptual window remains wide until a physical allocation needs
/// a local length.
pub fn historyLength(decoded: Count, dictionary_len: usize, window: u64) core.Error!Count {
    const in_frame: Count = @intCast(@min(@as(u64, @intCast(decoded)), window));
    return core.stream_count.addLocal(in_frame, dictionary_len);
}
