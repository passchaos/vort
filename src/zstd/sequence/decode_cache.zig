const std = @import("std");

const max_description_len = 256;
const slot_count = 4;

pub fn Cache(comptime Spec: type) type {
    return struct {
        const Self = @This();
        const Entry = struct {
            description: [max_description_len]u8 = undefined,
            description_len: usize = 0,
            sequence_count: usize = 0,
            spec: Spec = undefined,
            valid: bool = false,

            fn lookup(
                self: *const Entry,
                block: []const u8,
                description_start: usize,
                sequence_count: usize,
            ) ?Spec {
                if (!self.valid or self.sequence_count != sequence_count) return null;
                if (self.description_len > block.len - description_start) return null;
                if (!std.mem.eql(
                    u8,
                    self.description[0..self.description_len],
                    block[description_start..][0..self.description_len],
                )) return null;
                var spec = self.spec;
                spec.bitstream_offset = description_start + self.description_len;
                return spec;
            }

            fn store(self: *Entry, description: []const u8, sequence_count: usize, spec: Spec) void {
                @memcpy(self.description[0..description.len], description);
                self.description_len = description.len;
                self.sequence_count = sequence_count;
                self.spec = spec;
                self.valid = true;
            }
        };

        slots: [slot_count]Entry = @splat(.{}),
        next_slot: usize = 0,
        hit_count: usize = 0,

        pub fn lookup(
            self: *Self,
            block: []const u8,
            description_start: usize,
            sequence_count: usize,
        ) ?Spec {
            if (description_start >= block.len) return null;
            for (&self.slots) |*slot| {
                const spec = slot.lookup(block, description_start, sequence_count) orelse continue;
                self.hit_count += 1;
                return spec;
            }
            return null;
        }

        pub fn store(
            self: *Self,
            block: []const u8,
            description_start: usize,
            sequence_count: usize,
            spec: Spec,
        ) void {
            if (spec.bitstream_offset < description_start) return;
            const description_len = spec.bitstream_offset - description_start;
            // FSE normalized-count descriptions are self-delimiting. Matching
            // this exact byte-aligned prefix proves both the table contents and
            // the current block's sequence-bitstream offset.
            if (description_len == 0 or description_len > max_description_len) return;
            self.slots[self.next_slot].store(
                block[description_start..spec.bitstream_offset],
                sequence_count,
                spec,
            );
            self.next_slot = (self.next_slot + 1) % self.slots.len;
        }
    };
}

test "sequence decode cache requires an exact self-delimiting description" {
    const Spec = struct { bitstream_offset: usize, marker: u8 };
    var cache: Cache(Spec) = .{};
    const block = [_]u8{ 0xaa, 0xbb, 0xcc, 0x10, 0x20 };
    cache.store(&block, 1, 7, .{ .bitstream_offset = 3, .marker = 42 });

    const hit = cache.lookup(&block, 1, 7) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 3), hit.bitstream_offset);
    try std.testing.expectEqual(@as(u8, 42), hit.marker);
    try std.testing.expectEqual(@as(usize, 1), cache.hit_count);

    var changed = block;
    changed[2] ^= 1;
    try std.testing.expect(cache.lookup(&changed, 1, 7) == null);
    try std.testing.expect(cache.lookup(&block, 1, 8) == null);
}
