//! Admission contracts for caller-owned Raw Deflate chunk joins.
const std = @import("std");
const t = std.testing;
const List = std.ArrayList(u8);
const Family = enum { into, into_dict, alloc, alloc_dict, exact, exact_dict, limited, limited_dict, append, append_dict, append_exact, append_exact_dict, append_limited, append_limited_dict };
const all_families = std.enums.values(Family);
const header = [_]u8{ 0x01, 0x04, 0x00, 0xfb, 0xff };
const raw = [_]u8{ 0x01, 0x04, 0x00, 0xfb, 0xff, 'a', 'b', 'c', 'd' };
const dictionary_raw = [_]u8{ 0x8b, 0x48, 0x44, 0x13, 0x00, 0x00 };
const dictionary = "abcdefghijklmnop";
const dictionary_plain = "Xabcdefghijklmnop";

fn withDictionary(comptime family: Family) bool {
    return @intFromEnum(family) % 2 == 1;
}
fn into(comptime family: Family) bool {
    return @intFromEnum(family) < 2;
}
fn appending(comptime family: Family) bool {
    return @intFromEnum(family) >= 8;
}

// Observe every allocator callback, including failed resize/remap attempts.
const NoCalls = struct {
    calls: usize = 0,
    fn touch(context: *anyopaque) void {
        const self: *NoCalls = @ptrCast(@alignCast(context));
        self.calls += 1;
    }
    fn alloc(context: *anyopaque, _: usize, _: std.mem.Alignment, _: usize) ?[*]u8 {
        touch(context);
        return null;
    }
    fn resize(context: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        touch(context);
        return false;
    }
    fn remap(context: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        touch(context);
        return null;
    }
    fn free(context: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize) void {
        touch(context);
    }
    fn allocator(self: *NoCalls) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
};

fn initList() !List {
    var list = try List.initCapacity(t.allocator, 64);
    @memset(list.allocatedSlice(), 0xa5);
    @memcpy(list.allocatedSlice()[0..3], "pre");
    list.items.len = 3;
    return list;
}

fn exercise(comptime D: type, comptime family: Family, allocator: std.mem.Allocator, chunks: []const []const u8, scratch: []u8, output: []u8, dict: []const u8, list: *List, plain: []const u8) !void {
    if (comptime into(family)) {
        const result = if (family == .into)
            try D.decodeRawChunks(chunks, scratch, output)
        else
            try D.decodeRawChunksWithDictionary(chunks, scratch, output, dict);
        var total: usize = 0;
        for (chunks) |chunk| total += chunk.len;
        try t.expectEqual(total, result.input_read);
        try t.expectEqual(plain.len, result.output_written);
        try t.expectEqualSlices(u8, plain, output[0..result.output_written]);
    } else if (comptime appending(family)) {
        const start = list.items.len;
        const written = switch (family) {
            .append => try D.decodeRawChunksAppend(allocator, list, chunks, scratch),
            .append_dict => try D.decodeRawChunksAppendWithDictionary(allocator, list, chunks, scratch, dict),
            .append_exact => try D.decodeRawChunksAppendExactSize(allocator, list, chunks, scratch, plain.len),
            .append_exact_dict => try D.decodeRawChunksAppendWithDictionaryExactSize(allocator, list, chunks, scratch, dict, plain.len),
            .append_limited => try D.decodeRawChunksAppendLimited(allocator, list, chunks, scratch, plain.len),
            .append_limited_dict => try D.decodeRawChunksAppendWithDictionaryLimited(allocator, list, chunks, scratch, dict, plain.len),
            else => unreachable,
        };
        try t.expectEqual(plain.len, written);
        try t.expectEqualSlices(u8, "pre", list.items[0..start]);
        try t.expectEqualSlices(u8, plain, list.items[start..]);
    } else {
        const bytes = switch (family) {
            .alloc => try D.decodeRawChunksAlloc(allocator, chunks, scratch),
            .alloc_dict => try D.decodeRawChunksAllocWithDictionary(allocator, chunks, scratch, dict),
            .exact => try D.decodeRawChunksAllocExactSize(allocator, chunks, scratch, plain.len),
            .exact_dict => try D.decodeRawChunksAllocWithDictionaryExactSize(allocator, chunks, scratch, dict, plain.len),
            .limited => try D.decodeRawChunksAllocLimited(allocator, chunks, scratch, plain.len),
            .limited_dict => try D.decodeRawChunksAllocWithDictionaryLimited(allocator, chunks, scratch, dict, plain.len),
            else => unreachable,
        };
        defer allocator.free(bytes);
        try t.expectEqualSlices(u8, plain, bytes);
    }
}

fn rejected(comptime D: type, comptime family: Family, expected: anyerror, chunks: []const []const u8, scratch: []u8, output: []u8, dict: []const u8, list: *List) !void {
    var spy: NoCalls = .{};
    const before = list.*;
    var allocation_before: [64]u8 = undefined;
    @memcpy(&allocation_before, list.allocatedSlice());
    // Exact-size/limited families receive a zero bound: admission precedes codec caps.
    try t.expectError(expected, exercise(D, family, spy.allocator(), chunks, scratch, output, dict, list, ""));
    try t.expectEqual(@as(usize, 0), spy.calls);
    try t.expectEqual(before.items.ptr, list.items.ptr);
    try t.expectEqual(before.items.len, list.items.len);
    try t.expectEqual(before.capacity, list.capacity);
    try t.expectEqualSlices(u8, &allocation_before, list.allocatedSlice());
}

const Conflict = enum { unread, shifted, descriptors, dictionary_scratch, output_tail, list_spare, list_descriptor };

fn conflicts(comptime D: type, comptime family: Family) !void {
    inline for (std.enums.values(Conflict)) |conflict| {
        if (comptime conflict == .dictionary_scratch and !withDictionary(family)) continue;
        if (comptime conflict == .output_tail and !into(family)) continue;
        if (comptime (conflict == .list_spare or conflict == .list_descriptor) and !appending(family)) continue;
        var list = try initList();
        defer list.deinit(t.allocator);
        var backing: [128]u8 = @splat(0xa5);
        var output_storage: [32]u8 = @splat(0xa5);
        var output: []u8 = &output_storage;
        // Four descriptors leave at least nine bytes beyond the first on 32-bit too.
        var chunks = [_][]const u8{ &header, "abcd", "", "" };
        var scratch: []u8 = backing[0..9];
        var dict: []const u8 = "";
        switch (conflict) {
            .unread => {
                @memcpy(backing[0..4], "abcd");
                chunks[1] = backing[0..4];
            },
            .shifted => {
                // The safe current move would overwrite the future second chunk.
                @memcpy(backing[0..9], &raw);
                chunks[0] = backing[0..5];
                chunks[1] = backing[5..9];
                scratch = backing[1..10];
            },
            .descriptors => scratch = std.mem.asBytes(&chunks)[@sizeOf([]const u8)..][0..9],
            .dictionary_scratch => {
                @memcpy(backing[0..16], dictionary);
                chunks[0] = dictionary_raw[0..3];
                chunks[1] = dictionary_raw[3..6];
                scratch = backing[0..6];
                dict = backing[0..16];
            },
            .output_tail => {
                scratch = backing[64..73];
                output = backing[59..65]; // Four actual output bytes precede scratch.
            },
            .list_spare => scratch = list.allocatedSlice()[32..41],
            .list_descriptor => scratch = std.mem.asBytes(&list)[0..9],
        }
        const backing_before = backing;
        const output_before = output_storage;
        const descriptors_before = chunks;
        try rejected(D, family, error.InvalidBlockPlan, &chunks, scratch, output, dict, &list);
        try t.expectEqualSlices(u8, &backing_before, &backing);
        try t.expectEqualSlices(u8, &output_before, &output_storage);
        try t.expectEqualSlices(u8, std.mem.asBytes(&descriptors_before), std.mem.asBytes(&chunks));
        if (conflict == .dictionary_scratch and into(family)) {
            try rejected(D, family, error.InvalidBlockPlan, &chunks, scratch, output[0..0], dict, &list);
            try t.expectEqualSlices(u8, &backing_before, &backing);
        }
        // Independent retry consumes the same untouched borrowed pieces.
        var retry_scratch: [9]u8 = undefined;
        const plain = if (conflict == .dictionary_scratch) dictionary_plain else "abcd";
        try exercise(D, family, t.allocator, &chunks, &retry_scratch, &output_storage, dict, &list, plain);
        try t.expectEqualSlices(u8, &backing_before, &backing);
        try t.expectEqualSlices(u8, std.mem.asBytes(&descriptors_before), std.mem.asBytes(&chunks));
    }
}

fn preflight(comptime D: type, comptime family: Family) !void {
    var list = try initList();
    defer list.deinit(t.allocator);
    var backing: [16]u8 = @splat(0xa5);
    @memcpy(backing[0..4], "abcd");
    const before = backing;
    const chunks = [_][]const u8{ &header, backing[0..4] };
    // Capacity wins over the real scratch/chunk alias.
    try rejected(D, family, error.OutputTooSmall, &chunks, backing[0..8], backing[0..0], "", &list);
    try t.expectEqualSlices(u8, &before, &backing);
    // Only lengths are read: arithmetic overflow precedes capacity and pointer checks.
    const huge = @as([*]const u8, @ptrCast(&raw))[0..std.math.maxInt(usize)];
    const overflow = [_][]const u8{ huge, "x" };
    try rejected(D, family, error.IntegerOverflow, &overflow, backing[0..0], backing[0..0], "", &list);
    try t.expectEqualSlices(u8, &before, &backing);
    // A reserved first block cannot reach the parser before a conflicting join is rejected.
    const malformed = [_][]const u8{ &.{0x07}, backing[0..1] };
    try rejected(D, family, error.InvalidBlockPlan, &malformed, backing[0..2], backing[0..0], "", &list);
    try t.expectEqualSlices(u8, &before, &backing);
}

fn accepted(comptime D: type, comptime family: Family) !void {
    inline for (0..8) |placement| {
        var list = try initList();
        defer list.deinit(t.allocator);
        var backing: [80]u8 = @splat(0xa5);
        var output: [32]u8 = undefined;
        var chunks = [_][]const u8{ &header, "abcd", "", "" };
        var scratch: []u8 = backing[0..9];
        switch (placement) {
            0 => { // One non-empty span among empties ignores scratch entirely.
                @memcpy(backing[0..9], &raw);
                chunks = .{ "", backing[0..9], "", "" };
                scratch = backing[0..0];
            },
            1 => { // Both identity copies must be skipped, rather than memcpy'd.
                @memcpy(backing[0..9], &raw);
                chunks = .{ backing[0..5], "", backing[5..9], "" };
            },
            2 => { // One identity and one independent copy.
                @memcpy(backing[0..5], &header);
                chunks[0] = backing[0..5];
            },
            3 => { // Source and scratch write ranges are adjacent.
                @memcpy(backing[0..9], &raw);
                chunks = .{ backing[0..5], backing[5..9], "", "" };
                scratch = backing[9..18];
            },
            4 => { // The original chunks are inside unused scratch capacity.
                @memcpy(backing[16..25], &raw);
                chunks = .{ backing[16..21], backing[21..25], "", "" };
                scratch = &backing;
            },
            5 => { // Current source can move forward; future input is independent.
                @memcpy(backing[0..5], &header);
                chunks[0] = backing[0..5];
                scratch = backing[1..10];
            },
            6 => { // Current source can move backward using memmove.
                @memcpy(backing[1..6], &header);
                chunks[0] = backing[1..6];
            },
            7 => { // Single-span borrowing ignores even overlapping non-empty scratch.
                @memcpy(backing[0..9], &raw);
                chunks = .{ "", backing[0..9], "", "" };
                scratch = &backing;
            },
            else => unreachable,
        }
        const before = backing;
        try exercise(D, family, t.allocator, &chunks, scratch, &output, "", &list, "abcd");
        if (placement < 2 or placement == 7) try t.expectEqualSlices(u8, &before, &backing);
        if (placement == 4) try t.expectEqualSlices(u8, before[9..], backing[9..]);
    }
    if (comptime withDictionary(family)) {
        var list = try initList();
        defer list.deinit(t.allocator);
        var backing: [80]u8 = @splat(0xa5);
        @memcpy(backing[16..32], dictionary);
        var output: [17]u8 = undefined;
        const chunks = [_][]const u8{ dictionary_raw[0..3], dictionary_raw[3..6] };
        try exercise(D, family, t.allocator, &chunks, &backing, &output, backing[16..32], &list, dictionary_plain);
        try t.expectEqualSlices(u8, dictionary, backing[16..32]);
        list.items.len = 3;
        // Original input and dictionary remain compatible read borrows.
        const single = [_][]const u8{ "", &raw, "" };
        try exercise(D, family, t.allocator, &single, backing[0..0], &output, &raw, &list, "abcd");
        list.items.len = 3;
        @memcpy(backing[0..9], &raw);
        const identities = [_][]const u8{ backing[0..5], backing[5..9] };
        // No join writes means scratch may share the read-only dictionary.
        try exercise(D, family, t.allocator, &identities, backing[0..9], &output, backing[0..9], &list, "abcd");
        try t.expectEqualSlices(u8, &raw, backing[0..9]);
        list.items.len = 3;
        const mixed = [_][]const u8{ backing[0..5], "abcd" };
        // The identity prefix lies outside the actual write envelope [5..9].
        try exercise(D, family, t.allocator, &mixed, backing[0..9], &output, backing[0..5], &list, "abcd");
        try t.expectEqualSlices(u8, &header, backing[0..5]);
    }
}

fn singleOutputBorrows(comptime D: type, comptime family: Family) !void {
    if (comptime !into(family)) return;
    var list = try initList();
    defer list.deinit(t.allocator);
    var storage: [32]u8 = @splat(0xa5);
    @memcpy(storage[0..9], &raw);
    const before = storage;
    const chunks = [_][]const u8{ "", storage[0..9], "" };
    try rejected(D, family, error.InvalidBlockPlan, &chunks, storage[0..0], storage[0..9], "", &list);
    try t.expectEqualSlices(u8, &before, &storage);
}

fn stagingReads(comptime D: type) !void {
    const Site = enum { input_allocation, dictionary_allocation, dictionary_object };
    inline for (all_families) |family| {
        if (comptime !appending(family)) continue;
        inline for (std.enums.values(Site)) |site| {
            if (comptime site != .input_allocation and !withDictionary(family)) continue;
            var list = try initList();
            defer list.deinit(t.allocator);
            var output: [32]u8 = undefined;
            var oracle: [17]u8 = undefined;
            var chunks = [_][]const u8{ "", &raw, "" };
            var dict: []const u8 = "";
            var plain: []const u8 = "abcd";
            switch (site) {
                .input_allocation => {
                    @memcpy(list.allocatedSlice()[32..41], &raw);
                    chunks[1] = list.allocatedSlice()[32..41];
                },
                .dictionary_allocation => {
                    // Direct output would overwrite the history needed by the match.
                    @memcpy(list.allocatedSlice()[3..19], dictionary);
                    chunks[1] = &dictionary_raw;
                    dict = list.allocatedSlice()[3..19];
                    plain = dictionary_plain;
                },
                .dictionary_object => {
                    // Distance six needs only six history bytes, including on 32-bit.
                    chunks[1] = &.{ 0xcb, 0x40, 0x27, 0x01 };
                    dict = std.mem.asBytes(&list);
                    var snapshot: [@sizeOf(List)]u8 = undefined;
                    @memcpy(&snapshot, dict);
                    const result = try D.decodeRawAutoWithDictionary(chunks[1], &snapshot, &oracle);
                    try t.expectEqual(@as(usize, 4), result.input_read);
                    try t.expectEqual(oracle.len, result.output_written);
                    plain = &oracle;
                },
            }
            const before = list;
            var allocation_before: [64]u8 = undefined;
            @memcpy(&allocation_before, list.allocatedSlice());
            var spy: NoCalls = .{};
            // Staging is a real caller-allocator operation; ordinary OOM propagates.
            try t.expectError(error.OutOfMemory, exercise(D, family, spy.allocator(), &chunks, output[0..0], &output, dict, &list, plain));
            try t.expect(spy.calls > 0);
            try t.expectEqual(before.items.ptr, list.items.ptr);
            try t.expectEqual(before.items.len, list.items.len);
            try t.expectEqual(before.capacity, list.capacity);
            try t.expectEqualSlices(u8, &allocation_before, list.allocatedSlice());
            // Same untouched reads can now be retried with an independent staged output.
            try exercise(D, family, t.allocator, &chunks, output[0..0], &output, dict, &list, plain);
            if (site == .input_allocation) try t.expectEqualSlices(u8, &raw, list.allocatedSlice()[32..41]);
        }
    }
}

fn dictionaryOutputAdmission(comptime D: type) !void {
    var list = try initList();
    defer list.deinit(t.allocator);
    var backing: [64]u8 = @splat(0xa5);
    @memcpy(backing[16..32], dictionary);
    const before = backing;
    const chunks = [_][]const u8{ dictionary_raw[0..3], dictionary_raw[3..6] };
    // Dictionary/output conflict is rejected before otherwise-disjoint join writes.
    try rejected(D, .into_dict, error.InvalidBlockPlan, &chunks, backing[0..6], backing[16..33], backing[16..32], &list);
    try t.expectEqualSlices(u8, &before, &backing);
}

fn ownedSnapshotOutput(comptime D: type) !void {
    inline for (.{ Family.into, Family.into_dict }) |family| {
        var list = try initList();
        defer list.deinit(t.allocator);
        var backing: [64]u8 = @splat(0xa5);
        @memcpy(backing[16..25], &raw);
        const chunks = [_][]const u8{ backing[16..21], backing[21..25] };
        // Output may reuse original source after the join has taken its snapshot;
        // both are also inside unused scratch capacity beyond its write prefix.
        try exercise(D, family, t.allocator, &chunks, &backing, backing[16..20], "", &list, "abcd");
    }
}

fn zeroOutput(comptime D: type) !void {
    inline for (.{ Family.into, Family.into_dict }) |family| {
        var list = try initList();
        defer list.deinit(t.allocator);
        var backing: [32]u8 = @splat(0xa5);
        const chunks = [_][]const u8{ &header, "abcd" };
        try rejected(D, family, error.OutputTooSmall, &chunks, backing[0..9], backing[16..16], "", &list);
        const empty = [_][]const u8{ &.{ 0x01, 0x00 }, &.{ 0x00, 0xff, 0xff } };
        try exercise(D, family, t.allocator, &empty, backing[0..5], backing[16..16], "", &list, "");
        const single = [_][]const u8{ "", &raw, "" };
        try rejected(D, family, error.OutputTooSmall, &single, backing[0..0], backing[16..16], "", &list);
    }
}

pub fn contracts(comptime D: type) !void {
    inline for (all_families) |family| {
        try conflicts(D, family);
        try preflight(D, family);
        try accepted(D, family);
        try singleOutputBorrows(D, family);
    }
    try zeroOutput(D);
    try stagingReads(D);
    try dictionaryOutputAdmission(D);
    try ownedSnapshotOutput(D);
}
