const std = @import("std");

pub fn Harness(comptime Codec: type) type {
    return struct {
        const cursor_module = Codec;
        pub const allocator = std.testing.allocator;
        pub const poison: u32 = 0xfedc_ba98;
        pub const poison16: u16 = 0xbeef;
        pub const empty16 = std.math.maxInt(u16);
        pub const Mode = enum { exact, foreign_four, tiny };

        pub fn checked16(value: u32) !u16 {
            return std.math.cast(u16, value) orelse error.OracleValueDoesNotFit;
        }

        fn threeBucket(input: []const u8, position: usize, mode: Mode) u32 {
            const value = @as(u32, input[position]) |
                (@as(u32, input[position + 1]) << 8) |
                (@as(u32, input[position + 2]) << 16);
            return if (mode == .tiny) value % 7 else value;
        }

        fn fourBucket(input: []const u8, position: usize, mode: Mode) u32 {
            if (mode == .foreign_four) return input[position + 3];
            const value = @as(u32, input[position]) |
                (@as(u32, input[position + 1]) << 8) |
                (@as(u32, input[position + 2]) << 16) |
                (@as(u32, input[position + 3]) << 24);
            return if (mode == .tiny) value % 5 else value;
        }

        pub const Fixture = struct {
            input: []u8 = &.{},
            three_buckets: []u32 = &.{},
            four_buckets: []u32 = &.{},
            three_prev: []u32 = &.{},
            four_prev32: []u32 = &.{},
            expected_ordinals: []u32 = &.{},
            scratch: cursor_module.Scratch = .{},
            saved_input: []u8 = &.{},
            saved_three_buckets: []u32 = &.{},
            saved_four_buckets: []u32 = &.{},
            saved_three_prev: []u32 = &.{},
            saved_four_prev32: []u32 = &.{},
            saved_four_prev: []u16 = &.{},
            saved_ordinals: []u16 = &.{},

            pub fn init(input: []const u8, mode: Mode) !Fixture {
                var self: Fixture = .{};
                errdefer self.deinit();
                self.input = try allocator.dupe(u8, input);
                self.three_buckets = try allocator.alloc(u32, input.len);
                self.four_buckets = try allocator.alloc(u32, input.len);
                self.three_prev = try allocator.alloc(u32, input.len);
                self.four_prev32 = try allocator.alloc(u32, input.len);
                self.expected_ordinals = try allocator.alloc(u32, input.len);
                @memset(self.three_buckets, poison);
                @memset(self.four_buckets, poison);
                @memset(self.three_prev, poison);
                @memset(self.four_prev32, poison);
                @memset(self.expected_ordinals, poison);

                // Construct predecessors by scanning the complete prior-position list,
                // rather than sharing a bucket-head builder or the cursor's ordinal
                // recurrence. Prefix equality implies equality of both independent
                // bucket mappings, including their deliberately small collision maps.
                for (0..input.len -| 2) |position| {
                    self.three_buckets[position] = threeBucket(input, position, mode);
                    self.three_prev[position] = cursor_module.empty;
                    self.expected_ordinals[position] = 1;
                    for (0..position) |prior| {
                        if (self.three_buckets[prior] != self.three_buckets[position]) continue;
                        self.three_prev[position] = @intCast(prior);
                        self.expected_ordinals[position] += 1;
                    }
                }
                for (0..input.len -| 3) |position| {
                    self.four_buckets[position] = fourBucket(input, position, mode);
                    self.four_prev32[position] = cursor_module.empty;
                    for (0..position) |prior| {
                        if (self.four_buckets[prior] == self.four_buckets[position])
                            self.four_prev32[position] = @intCast(prior);
                    }
                }
                try self.prepareAndSnapshot();
                return self;
            }

            pub fn prepareAndSnapshot(self: *Fixture) !void {
                self.saved_three_prev = try allocator.dupe(u32, self.three_prev);
                self.saved_four_prev32 = try allocator.dupe(u32, self.four_prev32);
                try self.scratch.ordinals.resize(allocator, self.input.len);
                try self.scratch.four_prev.resize(allocator, self.input.len);
                @memset(self.scratch.ordinals.items, poison16);
                @memset(self.scratch.four_prev.items, poison16);
                try self.scratch.prepare(allocator, self.three_prev);
                try std.testing.expectEqualSlices(u32, self.saved_three_prev, self.three_prev);
                for (0..self.input.len -| 2) |position| {
                    const expected = try checked16(self.expected_ordinals[position]);
                    try std.testing.expectEqual(expected, self.scratch.ordinals.items[position]);
                }
                for (self.scratch.ordinals.items[self.input.len -| 2..]) |tail|
                    try std.testing.expectEqual(poison16, tail);
                // Both predecessor arrays were independently built as u32 first.
                // Convert only valid four-byte positions; unused tails stay poisoned.
                for (0..self.input.len -| 3) |position| {
                    const previous = self.four_prev32[position];
                    self.scratch.four_prev.items[position] = if (previous == cursor_module.empty)
                        empty16
                    else
                        try checked16(previous);
                }
                self.saved_input = try allocator.dupe(u8, self.input);
                self.saved_three_buckets = try allocator.dupe(u32, self.three_buckets);
                self.saved_four_buckets = try allocator.dupe(u32, self.four_buckets);
                self.saved_four_prev = try allocator.dupe(u16, self.scratch.four_prev.items);
                self.saved_ordinals = try allocator.dupe(u16, self.scratch.ordinals.items);
            }

            pub fn deinit(self: *Fixture) void {
                allocator.free(self.input);
                allocator.free(self.three_buckets);
                allocator.free(self.four_buckets);
                allocator.free(self.three_prev);
                allocator.free(self.four_prev32);
                allocator.free(self.expected_ordinals);
                self.scratch.deinit(allocator);
                allocator.free(self.saved_input);
                allocator.free(self.saved_three_buckets);
                allocator.free(self.saved_four_buckets);
                allocator.free(self.saved_three_prev);
                allocator.free(self.saved_four_prev32);
                allocator.free(self.saved_four_prev);
                allocator.free(self.saved_ordinals);
            }

            pub fn expectImmutable(self: *const Fixture) !void {
                try std.testing.expectEqualSlices(u8, self.saved_input, self.input);
                try std.testing.expectEqualSlices(u32, self.saved_three_buckets, self.three_buckets);
                try std.testing.expectEqualSlices(u32, self.saved_four_buckets, self.four_buckets);
                try std.testing.expectEqualSlices(u32, self.saved_three_prev, self.three_prev);
                try std.testing.expectEqualSlices(u32, self.saved_four_prev32, self.four_prev32);
                try std.testing.expectEqualSlices(u16, self.saved_four_prev, self.scratch.four_prev.items);
                try std.testing.expectEqualSlices(u16, self.saved_ordinals, self.scratch.ordinals.items);
            }
        };

        // The oracle knows only the old three-chain quota and window. It neither reads
        // ordinal values nor models physical limits, fallback, or the four frontier.
        pub fn oldCandidates(fixture: *const Fixture, position: usize, quota: usize, window: usize) !std.ArrayList(u32) {
            var result: std.ArrayList(u32) = .empty;
            errdefer result.deinit(allocator);
            var candidate = fixture.three_prev[position];
            var visited: usize = 0;
            while (candidate != cursor_module.empty and visited < quota) {
                if (position - candidate > window) break;
                visited += 1;
                if (std.mem.eql(u8, fixture.input[position..][0..4], fixture.input[candidate..][0..4]))
                    try result.append(allocator, candidate);
                candidate = fixture.three_prev[candidate];
            }
            return result;
        }

        // A deliberately naive four-chain walk demonstrates the lost-match control:
        // physical foreign collisions consume its quota, unlike the old oracle.
        pub fn physicallyCappedFour(fixture: *const Fixture, position: usize, quota: usize, window: usize) !std.ArrayList(u32) {
            var result: std.ArrayList(u32) = .empty;
            errdefer result.deinit(allocator);
            var candidate = fixture.four_prev32[position];
            var visited: usize = 0;
            while (candidate != cursor_module.empty and visited < quota) {
                if (position - candidate > window) break;
                visited += 1;
                if (std.mem.eql(u8, fixture.input[position..][0..4], fixture.input[candidate..][0..4]))
                    try result.append(allocator, candidate);
                candidate = fixture.four_prev32[candidate];
            }
            return result;
        }

        pub const Stats = struct {
            returned: usize,
            physical: usize,
            replay: usize,
            chain_nodes: usize,
            switches: usize,
            frontier: usize,
            rejections: usize,

            pub fn skipped(self: Stats, quota: usize) usize {
                return self.physical + @min(self.replay, quota) - self.chain_nodes;
            }
        };

        pub fn compareCandidates(fixture: *const Fixture, position: usize, quota: usize, window: usize) !Stats {
            var expected = try oldCandidates(fixture, position, quota, window);
            defer expected.deinit(allocator);
            var cursor = cursor_module.Cursor.init(
                fixture.three_prev,
                fixture.scratch.four_prev.items,
                fixture.scratch.ordinals.items,
                fixture.input,
                position,
                quota,
                window,
            );
            var returned: usize = 0;
            for (expected.items) |candidate| {
                const actual = cursor.next(fixture.input);
                try std.testing.expectEqual(@as(?u32, candidate), actual);
                returned += 1;
            }
            try std.testing.expectEqual(@as(?u32, null), cursor.next(fixture.input));
            try std.testing.expectEqual(expected.items.len, returned);
            try std.testing.expect(cursor.physical <= quota);
            // The u16 variant stops before reading an old node beyond its quota.
            try std.testing.expect(cursor.fallback_visited <= quota);
            try std.testing.expect(cursor.physical + cursor.fallback_visited <= quota * 2);
            try std.testing.expect(cursor.chain_nodes <= quota * 2);
            try std.testing.expect(cursor.fallback_switches <= 1);
            const stats: Stats = .{
                .returned = returned,
                .physical = cursor.physical,
                .replay = cursor.fallback_visited,
                .chain_nodes = cursor.chain_nodes,
                .switches = cursor.fallback_switches,
                .frontier = cursor.last_four,
                .rejections = cursor.prefix_rejections,
            };
            try std.testing.expectEqual(@as(?u32, null), cursor.next(fixture.input));
            try std.testing.expectEqual(@as(?u32, null), cursor.next(fixture.input));
            try fixture.expectImmutable();
            return stats;
        }

        pub fn records(prefixes: []const [4]u8) ![]u8 {
            const input = try allocator.alloc(u8, prefixes.len * 8);
            @memset(input, 0xa5);
            for (prefixes, 0..) |prefix, index|
                @memcpy(input[index * 8 ..][0..4], &prefix);
            return input;
        }

        pub fn linearBoundaryFixture() !Fixture {
            const len = 65536;
            var self: Fixture = .{};
            errdefer self.deinit();
            self.input = try allocator.alloc(u8, len);
            @memset(self.input, 'A');
            self.three_buckets = try allocator.alloc(u32, len);
            self.four_buckets = try allocator.alloc(u32, len);
            self.three_prev = try allocator.alloc(u32, len);
            self.four_prev32 = try allocator.alloc(u32, len);
            self.expected_ordinals = try allocator.alloc(u32, len);
            @memset(self.three_buckets, poison);
            @memset(self.four_buckets, poison);
            @memset(self.three_prev, poison);
            @memset(self.four_prev32, poison);
            @memset(self.expected_ordinals, poison);
            // This single-bucket boundary fixture has a closed-form predecessor and
            // ordinal sequence, so constructing 65536 positions stays linear. Both
            // reference arrays remain u32 until prepareAndSnapshot checks conversion.
            for (0..len - 2) |position| {
                self.three_buckets[position] = threeBucket(self.input, position, .exact);
                self.three_prev[position] = if (position == 0) cursor_module.empty else @intCast(position - 1);
                self.expected_ordinals[position] = @intCast(position + 1);
            }
            for (0..len - 3) |position| {
                self.four_buckets[position] = fourBucket(self.input, position, .exact);
                self.four_prev32[position] = if (position == 0) cursor_module.empty else @intCast(position - 1);
            }
            try self.prepareAndSnapshot();
            return self;
        }
    };
}
