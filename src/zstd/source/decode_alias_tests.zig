//! Public source destinations must not become live decoder scratch/history.
const std = @import("std");
const common = @import("stream_cursor_tests/common.zig");
const a = std.testing.allocator;
const raw_wire = [_]u8{ 0x28, 0xb5, 0x2f, 0xfd, 0, 0, 0x18, 0, 0, 'a', 'b', 'c', 0x19, 0, 0, 'd', 'e', 'f' };

fn Storage(comptime D: type) type {
    return struct {
        history: [1024]u8 = @splat(0xa7),
        staging: [1024]u8 = @splat(0xb8),
        literal: [17]u8 = @splat(0xc9),
        sequence: [17]u8 = @splat(0xda),

        fn view(self: *@This()) D.SourceFrameWorkspace {
            return .{ .history = &self.history, .staging = &self.staging, .literal_page = &self.literal, .sequence_page = &self.sequence };
        }
        fn region(self: *@This(), comptime index: usize) []u8 {
            return switch (index) {
                0 => &self.history,
                1 => &self.staging,
                2 => &self.literal,
                3 => &self.sequence,
                else => unreachable,
            };
        }
    };
}

fn fixedDestinations(comptime D: type) !void {
    inline for (.{ false, true }) |checksum| {
        var fixture: common.Fixture = .{};
        common.appendDataHeader(&fixture, if (checksum) 4 else 0, 0, null);
        common.appendRawBlock(&fixture, "abc", false);
        common.appendRawBlock(&fixture, "def", true);
        if (checksum) common.appendChecksum(&fixture, "abcdef");
        if (!checksum) try std.testing.expectEqualSlices(u8, &raw_wire, fixture.bytes());
        const oracle = try D.decodeFrameAlloc(a, fixture.bytes());
        defer a.free(oracle);
        try std.testing.expectEqualStrings("abcdef", oracle);

        inline for (0..4) |index| {
            inline for (.{ .frame, .stream, .cursor }) |route| {
                var storage: Storage(D) = .{};
                const before = storage;
                const target = storage.region(index)[1..7];
                var source: common.TrackingSource = .{ .bytes = fixture.bytes() };
                var cursor = try D.SourceStreamCursor.init(source.source(), .standard);
                if (route == .cursor) _ = try cursor.next();
                const cursor_before = cursor;
                const calls = source.calls;
                const result = switch (route) {
                    .frame => D.decodeSourceFrameInto(source.source(), target, storage.view(), .{}),
                    .stream => D.decodeSourceStreamInto(source.source(), target, storage.view(), .{}),
                    .cursor => cursor.decodeInto(target, storage.view(), .{}),
                    else => unreachable,
                };
                try std.testing.expectError(error.InvalidBlockPlan, result);
                try std.testing.expectEqualDeep(before, storage);
                try std.testing.expectEqualDeep(cursor_before, cursor);
                try std.testing.expectEqual(calls, source.calls);
                var output: [6]u8 = undefined;
                switch (route) {
                    .frame => _ = try D.decodeSourceFrameInto(source.source(), &output, storage.view(), .{}),
                    .stream => _ = try D.decodeSourceStreamInto(source.source(), &output, storage.view(), .{}),
                    .cursor => {
                        _ = try cursor.decodeInto(&output, storage.view(), .{});
                        try std.testing.expect(!cursor.pending());
                        try std.testing.expectEqual(@as(u64, 6), @as(u64, @intCast(cursor.totalDecoded())));
                    },
                    else => unreachable,
                }
                try std.testing.expectEqualStrings("abcdef", &output);
            }
        }
    }
}

fn appendDestinations(comptime D: type) !void {
    inline for (.{ false, true }) |declared| {
        var fixture: common.Fixture = .{};
        common.appendDataHeader(&fixture, if (declared) 0x20 else 0, if (declared) null else 0, if (declared) 6 else null);
        common.appendRawBlock(&fixture, "abc", false);
        common.appendRawBlock(&fixture, "def", true);
        inline for (0..4) |index| {
            inline for (.{ false, true }) |stream| {
                var storage: Storage(D) = .{};
                const before = storage;
                // The alias is in spare capacity; checking items alone misses it.
                var output: std.ArrayList(u8) = .{ .items = storage.region(index)[0..0], .capacity = storage.region(index).len };
                const old = output;
                var source: common.TrackingSource = .{ .bytes = fixture.bytes() };
                var failing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
                const result = if (stream)
                    D.decodeSourceStreamAppend(failing.allocator(), source.source(), storage.view(), &output, .{})
                else
                    D.decodeSourceFrameAppend(failing.allocator(), source.source(), storage.view(), &output, .{});
                try std.testing.expectError(error.InvalidBlockPlan, result);
                try std.testing.expectEqualDeep(old, output);
                try std.testing.expectEqual(old.items.ptr, output.items.ptr);
                try std.testing.expectEqualDeep(before, storage);
                try std.testing.expectEqual(@as(usize, 0), source.calls);
                try std.testing.expect(!failing.has_induced_failure);
                // Replace the destination, then retry the same unchanged input.
                var valid: std.ArrayList(u8) = .empty;
                defer valid.deinit(a);
                try valid.appendSlice(a, "pre!");
                if (stream) {
                    _ = try D.decodeSourceStreamAppend(a, source.source(), storage.view(), &valid, .{});
                } else {
                    _ = try D.decodeSourceFrameAppend(a, source.source(), storage.view(), &valid, .{});
                }
                try std.testing.expectEqualStrings("pre!abcdef", valid.items);
            }
        }
    }
}

fn unusedTail(comptime D: type) !void {
    // Only the unused destination tail overlaps. Refuse before publishing an
    // otherwise fitting six-byte output into the independent leading span.
    var slab: [1043]u8 = @splat(0x8e);
    var storage: Storage(D) = .{};
    var workspace = storage.view();
    workspace.history = slab[19..];
    const before = slab;
    var source: common.TrackingSource = .{ .bytes = &raw_wire };
    try std.testing.expectError(error.InvalidBlockPlan, D.decodeSourceStreamInto(source.source(), slab[0..20], workspace, .{}));
    try std.testing.expectEqualDeep(before, slab);
    try std.testing.expectEqual(@as(usize, 0), source.calls);
    _ = try D.decodeSourceStreamInto(source.source(), slab[0..19], workspace, .{});
    try std.testing.expectEqualStrings("abcdef", slab[0..6]);
    try std.testing.expect(std.mem.allEqual(u8, slab[6..19], 0x8e));
}

fn dictionaryBorrows(comptime D: type) !void {
    var storage: Storage(D) = .{};
    var bytes: [32]u8 = @splat(0x9f);
    var entries = [_]D.NativeDictionary{D.NativeDictionary.init(77, &bytes)};
    const options: D.SourceStreamDecodeOptions = .{ .dictionary_set = D.NativeDictionarySet.init(&entries) };
    var source: common.TrackingSource = .{ .bytes = &raw_wire };
    try std.testing.expectError(error.InvalidBlockPlan, D.decodeSourceStreamInto(source.source(), bytes[0..6], storage.view(), options));
    try std.testing.expect(std.mem.allEqual(u8, &bytes, 0x9f));
    const records = entries;
    try std.testing.expectError(error.InvalidBlockPlan, D.decodeSourceStreamInto(source.source(), std.mem.asBytes(&entries), storage.view(), options));
    try std.testing.expectEqualDeep(records, entries);
    var workspace = storage.view();
    workspace.literal_page = bytes[0..17];
    var output: [6]u8 = @splat(0x6b);
    try std.testing.expectError(error.InvalidBlockPlan, D.decodeSourceStreamInto(source.source(), &output, workspace, options));
    try std.testing.expect(std.mem.allEqual(u8, &output, 0x6b));
    try std.testing.expectEqual(@as(usize, 0), source.calls);

    // Protect full dictionary encoding even when the content view is disjoint.
    entries[0].content = "unrelated";
    entries[0].standard_bytes = &bytes;
    try std.testing.expectError(error.InvalidBlockPlan, D.decodeSourceStreamInto(source.source(), bytes[0..6], storage.view(), options));
    entries[0].standard_bytes = null;
    const Prepared = @typeInfo(@typeInfo(@FieldType(D.NativeDictionary, "prepared")).optional.child).pointer.child;
    var prepared: Prepared = undefined;
    entries[0].prepared = &prepared;
    const prepared_bytes = std.mem.asBytes(&prepared);
    @memset(prepared_bytes, 0x7a);
    try std.testing.expectError(error.InvalidBlockPlan, D.decodeSourceStreamInto(source.source(), prepared_bytes[0..6], storage.view(), options));
    try std.testing.expect(std.mem.allEqual(u8, prepared_bytes, 0x7a));
}

fn cursorStorage(comptime D: type) !void {
    var storage: Storage(D) = .{};
    var source: common.TrackingSource = .{ .bytes = &raw_wire };
    var cursor = try D.SourceStreamCursor.init(source.source(), .standard);
    _ = try cursor.next();
    const saved = cursor;
    const calls = source.calls;
    try std.testing.expectError(error.InvalidBlockPlan, cursor.decodeInto(std.mem.asBytes(&cursor), storage.view(), .{}));
    try std.testing.expectEqualDeep(saved, cursor);
    var workspace = storage.view();
    workspace.literal_page = std.mem.asBytes(&cursor)[0..17];
    var output: [6]u8 = @splat(0x4c);
    try std.testing.expectError(error.InvalidBlockPlan, cursor.decodeInto(&output, workspace, .{}));
    try std.testing.expectEqualDeep(saved, cursor);
    try std.testing.expect(std.mem.allEqual(u8, &output, 0x4c));
    try std.testing.expectEqual(calls, source.calls);
    _ = try cursor.decodeInto(&output, storage.view(), .{});
    try std.testing.expectEqualStrings("abcdef", &output);
}

fn appendGrowthDictionary(comptime D: type) !void {
    // A caller can borrow dictionary bytes from an unused fixed-buffer pool.
    // Check newly allocated output before it writes into that borrowed span.
    inline for (.{ false, true }) |declared| {
        errdefer std.debug.print("source append growth dictionary declared={any}\n", .{declared});
        var fixture: common.Fixture = .{};
        common.appendDataHeader(&fixture, if (declared) 0x20 else 0, if (declared) null else 0, if (declared) 6 else null);
        common.appendRawBlock(&fixture, "abc", false);
        common.appendRawBlock(&fixture, "def", true);
        var pool: [1024]u8 = @splat(0x9f);
        var backing = std.heap.FixedBufferAllocator.init(&pool);
        const entries = [_]D.NativeDictionary{D.NativeDictionary.init(77, &pool)};
        const options: D.SourceStreamDecodeOptions = .{ .dictionary_set = D.NativeDictionarySet.init(&entries) };
        var storage: Storage(D) = .{};
        var source: common.TrackingSource = .{ .bytes = fixture.bytes() };
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(backing.allocator());
        try std.testing.expectError(error.InvalidBlockPlan, D.decodeSourceStreamAppend(backing.allocator(), source.source(), storage.view(), &output, options));
        try std.testing.expectEqual(@as(usize, 0), output.items.len);
        try std.testing.expect(output.capacity != 0);
        // std Allocator may poison newly allocated bytes as undefined before
        // control returns to the codec. No decoded prefix may be published.
        try std.testing.expect(!std.mem.eql(u8, pool[0..6], "abcdef"));
        var independent: std.ArrayList(u8) = .empty;
        defer independent.deinit(a);
        _ = try D.decodeSourceStreamAppend(a, source.source(), storage.view(), &independent, options);
        try std.testing.expectEqualStrings("abcdef", independent.items);
    }
}

pub fn contracts(comptime D: type) !void {
    try fixedDestinations(D);
    try appendDestinations(D);
    try unusedTail(D);
    try dictionaryBorrows(D);
    try cursorStorage(D);
    try appendGrowthDictionary(D);
}
