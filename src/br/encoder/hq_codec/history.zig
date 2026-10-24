const std = @import("std");

pub fn capacity(history_len: usize, block_len: usize, limit: usize) usize {
    return if (block_len >= limit) limit else block_len + @min(history_len, limit - block_len);
}

/// The caller reserves capacity before publishing compressed bytes. This
/// update performs no allocation and cannot fail after that publication.
pub fn appendPrepared(history: *std.ArrayList(u8), block: []const u8, limit: usize) void {
    std.debug.assert(history.capacity >= capacity(history.items.len, block.len, limit));
    if (block.len >= limit) {
        history.clearRetainingCapacity();
        history.appendSliceAssumeCapacity(block[block.len - limit ..]);
        return;
    }
    const keep = @min(history.items.len, limit - block.len);
    if (keep != history.items.len)
        std.mem.copyForwards(u8, history.items[0..keep], history.items[history.items.len - keep ..]);
    history.shrinkRetainingCapacity(keep);
    history.appendSliceAssumeCapacity(block);
}
