//! Cost views for reverse DP whose longest edge is 258 input bytes.
const std = @import("std");
pub const max_ahead = 258;
pub const capacity = 512;
const mask = capacity - 1;

pub const Full = struct {
    values: []usize,
    len: usize,

    pub fn init(values: []usize) Full {
        return .{ .values = values, .len = values.len };
    }
    pub inline fn get(self: *const Full, index: usize) usize {
        return self.values[index];
    }
    pub inline fn set(self: *Full, index: usize, value: usize) void {
        self.values[index] = value;
    }
};

pub const Window = struct {
    values: [capacity]usize = undefined,
    len: usize,
    lowest: usize,

    pub fn init(length: usize) Window {
        return .{ .len = length, .lowest = length };
    }
    pub inline fn get(self: *const Window, index: usize) usize {
        std.debug.assert(index < self.len and index >= self.lowest and index - self.lowest <= max_ahead);
        return self.values[index & mask];
    }
    pub inline fn set(self: *Window, index: usize, value: usize) void {
        std.debug.assert(index < self.len and (index == self.lowest or index + 1 == self.lowest));
        self.lowest = index;
        self.values[index & mask] = value;
    }
};

/// Test observer captures every position before the circular slot is reused.
/// Production Window carries no observer or full-size cost allocation.
pub const Audited = struct {
    window: Window,
    values: []usize,
    len: usize,

    pub fn init(values: []usize) Audited {
        return .{ .window = Window.init(values.len), .values = values, .len = values.len };
    }
    pub inline fn get(self: *const Audited, index: usize) usize {
        return self.window.get(index);
    }
    pub inline fn set(self: *Audited, index: usize, value: usize) void {
        self.window.set(index, value);
        self.values[index] = value;
    }
};

/// Existing scalar queue/length tests can continue to supply ordinary slices.
pub inline fn get(costs: anytype, index: usize) usize {
    const child = @typeInfo(@TypeOf(costs)).pointer.child;
    if (comptime child == usize or @typeInfo(child) == .array) return costs[index];
    return costs.get(index);
}

test "optimal suffix window preserves every live cost across repeated wrap boundaries" {
    var full: [4099]usize = undefined;
    var window = Window.init(full.len);
    var audited_values: [full.len]usize = undefined;
    var audited = Audited.init(&audited_values);
    var pos = full.len;
    while (pos > 0) {
        pos -= 1;
        const value = pos * 19 ^ (pos >> 3);
        full[pos] = value;
        window.set(pos, value + 1);
        window.set(pos, value);
        audited.set(pos, value);
        for (pos..@min(full.len, pos + max_ahead + 1)) |suffix| {
            try std.testing.expectEqual(full[suffix], window.get(suffix));
            try std.testing.expectEqual(full[suffix], get(&audited, suffix));
        }
    }
    try std.testing.expectEqualSlices(usize, &full, &audited_values);
    try std.testing.expect(@sizeOf(Window) <= (capacity + 2) * @sizeOf(usize));
}
