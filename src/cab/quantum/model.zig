const std = @import("std");
const max_model_entries: usize = 64;

const ModelSymbol = struct {
    symbol: u16 = 0,
    cumulative: u16 = 0,
};

pub const Model = struct {
    shifts_left: u8 = 4,
    entries: usize,
    symbols: [max_model_entries + 1]ModelSymbol = @splat(.{}),

    pub fn init(start: u16, entries: usize) Model {
        std.debug.assert(entries > 0 and entries <= max_model_entries);
        var model = Model{ .entries = entries };
        for (model.symbols[0 .. entries + 1], 0..) |*item, index| {
            item.* = .{
                .symbol = start + @as(u16, @intCast(index)),
                .cumulative = @intCast(entries - index),
            };
        }
        return model;
    }

    pub fn record(self: *Model, boundary_index: usize) void {
        var index = boundary_index;
        while (index != 0) {
            index -= 1;
            self.symbols[index].cumulative += 8;
        }
        if (self.symbols[0].cumulative > 3800) self.update();
    }

    fn update(self: *Model) void {
        self.shifts_left -= 1;
        if (self.shifts_left != 0) {
            var index = self.entries;
            while (index != 0) {
                index -= 1;
                self.symbols[index].cumulative >>= 1;
                if (self.symbols[index].cumulative <= self.symbols[index + 1].cumulative)
                    self.symbols[index].cumulative = self.symbols[index + 1].cumulative + 1;
            }
            return;
        }

        self.shifts_left = 50;
        for (0..self.entries) |index| {
            self.symbols[index].cumulative -= self.symbols[index + 1].cumulative;
            self.symbols[index].cumulative = (self.symbols[index].cumulative + 1) >> 1;
        }

        for (0..self.entries - 1) |index| {
            for (index + 1..self.entries) |candidate| {
                if (self.symbols[index].cumulative < self.symbols[candidate].cumulative)
                    std.mem.swap(ModelSymbol, &self.symbols[index], &self.symbols[candidate]);
            }
        }

        var index = self.entries;
        while (index != 0) {
            index -= 1;
            self.symbols[index].cumulative += self.symbols[index + 1].cumulative;
        }
    }
};

pub const State = [9]Model;
pub const selector_index: usize = 8;
pub const length_index: usize = 7;
pub const position_index: usize = 6;

pub fn initialState(window_bits: u5) State {
    const entries = @as(usize, window_bits) * 2;
    return .{
        Model.init(0, 64),                Model.init(64, 64),               Model.init(128, 64),    Model.init(192, 64),
        Model.init(0, @min(entries, 24)), Model.init(0, @min(entries, 36)), Model.init(0, entries), Model.init(0, 27),
        Model.init(0, 7),
    };
}
