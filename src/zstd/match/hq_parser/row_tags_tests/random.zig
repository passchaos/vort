const std = @import("std");
const r = @import("properties.zig");
const state = @import("../state.zig");
const Random = struct {
    seed: u64 = 0xbed0517382e9136a,
    fn next(self: *@This()) u64 {
        self.seed ^= self.seed >> 12;
        self.seed ^= self.seed << 25;
        self.seed ^= self.seed >> 27;
        return self.seed *% 0x2545f4914f6cdd1d;
    }
    fn value(self: *@This(), comptime T: type) T {
        return switch (self.next() % 6) {
            0 => 0,
            1 => std.math.maxInt(T),
            2 => std.math.maxInt(T) - 1,
            3 => @as(T, 1) << (@bitSizeOf(T) - 1),
            4 => @intCast(self.next() % 32),
            else => @truncate(self.next()),
        };
    }
    fn node(self: *@This(), comptime Node: type) Node {
        return .{
            .cost = self.value(u64),
            .literal_len = self.value(u32),
            .repeats = .{ self.value(usize), self.value(usize), self.value(usize) },
            .match_len = self.value(u32),
            .offset_value = self.value(u32),
            .distance = self.value(usize),
            .previous_slot = self.value(u8),
            .previous_position = self.value(@TypeOf(@as(Node, .{}).previous_position)),
        };
    }
};

pub fn contracts(comptime Codec: type) !void {
    inline for (.{ state.Node, state.WholeNode }) |Node| {
        inline for (.{ 1, 8, 16 }) |width| {
            var rng: Random = .{};
            for (0..32) |_| {
                var actual: [width]Node = undefined;
                for (&actual) |*node| node.* = rng.node(Node);
                var tags = Codec.init(&actual);
                var expected = actual;
                for (0..128) |iteration| {
                    var candidate = rng.node(Node);
                    if (iteration % 3 == 1) {
                        candidate = actual[@intCast(rng.next() % width)];
                        candidate.cost -|= @intCast(rng.next() % 2);
                        candidate.previous_slot = rng.value(u8);
                    } else if (iteration % 3 == 2) {
                        candidate.literal_len = @intCast(rng.next() % 4);
                        candidate.repeats = .{ @intCast(rng.next() % 4), @intCast(rng.next() % 4), @intCast(rng.next() % 4) };
                    }
                    _ = try r.step(Codec, &actual, &expected, &tags, candidate);
                }
            }
        }
    }
}
