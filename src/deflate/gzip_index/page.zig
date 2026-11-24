//! Reuse the unread part of a bounded random-access input page.
const model = @import("types.zig");

pub const Cursor = struct {
    source: model.Source,
    page: []u8,
    offset: u64,
    end: u64,
    read_len: usize = 0,
    used: usize = 0,

    pub fn init(source: model.Source, page: []u8, start: u64, end: u64) model.Error!Cursor {
        if (start > end or end > source.len) return error.InvalidBlockPlan;
        if (page.len == 0) return error.OutputTooSmall;
        return .{ .source = source, .page = page, .offset = start, .end = end };
    }

    pub fn current(self: *Cursor) model.Error![]const u8 {
        if (self.used == self.read_len) {
            if (self.offset == self.end) return &.{};
            const len: usize = @intCast(@min(self.page.len, self.end - self.offset));
            try self.source.readExact(self.offset, self.page[0..len]);
            self.read_len = len;
            self.used = 0;
        }
        return self.page[self.used..self.read_len];
    }

    pub fn advance(self: *Cursor, amount: usize) model.Error!void {
        if (amount > self.read_len - self.used) return error.InvalidStreamState;
        self.offset += amount;
        self.used += amount;
    }
};
