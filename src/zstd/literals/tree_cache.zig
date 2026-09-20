const std = @import("std");

const max_description_len = 128;
const slot_count = 4;

pub fn Cache(comptime Tree: type) type {
    return struct {
        const Self = @This();

        pub const Hit = struct {
            tree: *const Tree,
            description_len: usize,
        };

        const Entry = struct {
            description: [max_description_len]u8 = undefined,
            description_len: u8 = 0,
            tree: Tree = undefined,
            valid: bool = false,

            fn matches(self: *const Entry, description: []const u8) bool {
                return self.valid and
                    self.description_len == description.len and
                    std.mem.eql(u8, self.description[0..self.description_len], description);
            }
        };

        slots: [slot_count]Entry = @splat(.{}),
        next_slot: usize = 0,
        hit_count: usize = 0,

        pub fn find(self: *Self, payload: []const u8) ?Hit {
            const description_len = encodedDescriptionLen(payload) orelse return null;
            const description = payload[0..description_len];
            for (&self.slots) |*slot| {
                if (!slot.matches(description)) continue;
                self.hit_count += 1;
                return .{ .tree = &slot.tree, .description_len = description_len };
            }
            return null;
        }

        pub fn store(self: *Self, payload: []const u8, description_len: usize, tree: Tree) void {
            if (encodedDescriptionLen(payload) != description_len) return;
            const slot = &self.slots[self.next_slot];
            @memcpy(slot.description[0..description_len], payload[0..description_len]);
            slot.description_len = @intCast(description_len);
            slot.tree = tree;
            slot.valid = true;
            self.next_slot = (self.next_slot + 1) % self.slots.len;
        }
    };
}

fn encodedDescriptionLen(payload: []const u8) ?usize {
    if (payload.len == 0) return null;
    const header = payload[0];
    const body_len: usize = if (header < 128)
        header
    else
        (@as(usize, header - 127) + 1) / 2;
    const description_len = 1 + body_len;
    if (description_len > max_description_len or description_len > payload.len) return null;
    return description_len;
}

test "Huffman tree cache matches complete self-delimiting descriptions" {
    const Tree = struct { marker: u32 };
    var cache: Cache(Tree) = .{};
    const compressed = [_]u8{ 3, 0xaa, 0xbb, 0xcc, 0x11, 0x22 };
    cache.store(&compressed, 4, .{ .marker = 42 });

    const hit = cache.find(&compressed) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 4), hit.description_len);
    try std.testing.expectEqual(@as(u32, 42), hit.tree.marker);
    try std.testing.expectEqual(@as(usize, 1), cache.hit_count);

    var changed = compressed;
    changed[3] ^= 1;
    try std.testing.expect(cache.find(&changed) == null);
    try std.testing.expect(cache.find(compressed[0..3]) == null);
    try std.testing.expect(cache.find(&.{ 0, 0xaa }) == null);
}

test "Huffman tree cache derives direct-weight description length" {
    const Tree = struct { marker: u8 };
    var cache: Cache(Tree) = .{};
    // Header 131 represents four explicitly encoded weights and two body bytes.
    const payload = [_]u8{ 131, 0x12, 0x34, 0xaa };
    cache.store(&payload, 3, .{ .marker = 7 });
    const hit = cache.find(&payload) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 3), hit.description_len);
    try std.testing.expectEqual(@as(u8, 7), hit.tree.marker);
}
