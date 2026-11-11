//! Borrow preservation before chunk joining, exercised through the checked
//! join module and the public decode facades wired by br.zig.
const std = @import("std");
const h = @import("helpers.zig");
const f = @import("fixtures.zig");
const joiner = @import("../chunk_join.zig");
const shared = @import("../../shared_dictionary.zig");
const serialized = @import("../../serialized_dictionary.zig");
const budget = @import("../budget.zig");

pub fn joinContracts() !void {
    try sourceMoves();
    try tablesAndSizes();
    try dictionaryBorrows();
    try dictionaryCountGuards();
    try observerGeometry();
}

fn sourceMoves() !void {
    var identity = "abcdef".*;
    try std.testing.expectEqualStrings("abcdef", try joiner.join(&.{ identity[0..2], "", identity[2..4], identity[4..] }, &identity, &.{}, .{}));
    var left = "xxabcdefyy".*;
    try std.testing.expectEqualStrings("abcdef", try joiner.join(&.{ left[2..5], left[5..8] }, left[0..6], &.{}, .{}));
    var right = "abcdefxxxx".*;
    try std.testing.expectEqualStrings("abcdef", try joiner.join(&.{right[0..6]}, right[2..8], &.{}, .{}));
    var duplicate = "abxxxx".*;
    try std.testing.expectEqualStrings("abab", try joiner.join(&.{ duplicate[0..2], duplicate[0..2] }, duplicate[0..4], &.{}, .{}));
    var trailing_identity = "xxuvxxxx".*;
    try std.testing.expectEqualStrings("AAuvuv", try joiner.join(&.{ "AA", trailing_identity[2..4], trailing_identity[2..4] }, trailing_identity[0..6], &.{}, .{}));

    var cycle = f.external[12..].* ++ f.external[0..12].*;
    const before_cycle = cycle;
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&.{ cycle[12..], cycle[0..12] }, &cycle, &.{}, .{}));
    try std.testing.expectEqualSlices(u8, &before_cycle, &cycle);
    var independent: [f.external.len]u8 = undefined;
    try std.testing.expectEqualSlices(u8, &f.external, try joiner.join(&.{ cycle[12..], cycle[0..12] }, &independent, &.{}, .{}));

    var unsafe_right = "abcdefxxxx".*;
    const before_right = unsafe_right;
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&.{ unsafe_right[0..3], unsafe_right[3..6] }, unsafe_right[2..8], &.{}, .{}));
    try std.testing.expectEqualSlices(u8, &before_right, &unsafe_right);
    // The constant-space envelope intentionally refuses safe reads into gaps
    // between distinct writes. Leading/trailing identity spans above remain
    // accepted because they do not enlarge that envelope.
    var gap = "xxuvxxxx".*;
    const before_gap = gap;
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&.{ "AA", gap[2..4], "CC", gap[2..4] }, &gap, &.{}, .{}));
    try std.testing.expectEqualSlices(u8, &before_gap, &gap);
}

fn tablesAndSizes() !void {
    var descriptors = [_][]const u8{ f.external[0..1], f.external[1..], "", "" };
    const before = std.mem.asBytes(&descriptors).*;
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&descriptors, std.mem.asBytes(&descriptors), &.{}, .{}));
    try std.testing.expectEqualSlices(u8, &before, std.mem.asBytes(&descriptors));
    var protected = [_][]const u8{ "", "", "", "" };
    const protected_before = std.mem.asBytes(&protected).*;
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&.{&f.external}, std.mem.asBytes(&protected), &protected, .{}));
    try std.testing.expectEqualSlices(u8, &protected_before, std.mem.asBytes(&protected));

    const forged: [*]const []const u8 = @ptrFromInt(@alignOf([]const u8));
    const count = std.math.maxInt(usize) / @sizeOf([]const u8) + 1;
    try std.testing.expectError(error.IntegerOverflow, joiner.join(forged[0..count], &.{}, &.{}, .{}));
    try std.testing.expectError(error.IntegerOverflow, joiner.join(&.{}, &.{}, forged[0..count], .{}));
    const bytes: [*]const u8 = @ptrFromInt(1);
    try std.testing.expectError(error.IntegerOverflow, joiner.join(&.{ bytes[0..std.math.maxInt(usize)], "x" }, &.{}, &.{}, .{}));
    const invalid: shared.Dictionary = .{ .raw_prefixes = forged[0 .. shared.max_raw_prefixes + 1] };
    try std.testing.expectError(error.OutputTooSmall, joiner.join(&.{"x"}, &.{}, &.{}, invalid));
    var scratch: [4]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&.{"x"}, &scratch, &.{&scratch}, invalid));
    try std.testing.expectError(error.CorruptFrame, joiner.join(&.{"x"}, &scratch, &.{}, invalid));
    try std.testing.expectError(error.CorruptFrame, joiner.join(&.{"x"}, &scratch, &.{}, .{ .raw_prefixes = &.{bytes[0 .. shared.max_raw_size + 1]} }));
    try std.testing.expectError(error.IntegerOverflow, joiner.join(&.{"x"}, &scratch, &.{}, .{ .raw_prefixes = &.{ bytes[0..std.math.maxInt(usize)], "x" } }));
    for (scratch) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);

    var storage: [32]u8 = @splat(0xa5);
    try std.testing.expectEqualStrings("abc", try joiner.join(&.{"abc"}, &storage, &.{storage[3..]}, .{}));
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&.{"abc"}, &storage, &.{storage[2..]}, .{}));
    try std.testing.expectEqual(@as(usize, 0), (try joiner.join(&.{ "", "" }, &storage, &.{&storage}, .{})).len);
}

fn dictionaryBorrows() !void {
    var raw = f.raw_plain.*;
    const before_raw = raw;
    const dictionary: shared.Dictionary = .{ .raw_prefixes = &.{&raw} };
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&.{&f.raw}, &raw, &.{}, dictionary));
    try std.testing.expectEqualSlices(u8, &before_raw, &raw);
    var raw_table = [_][]const u8{ f.raw_plain, "", "", "" };
    const before_table = std.mem.asBytes(&raw_table).*;
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&.{&f.raw}, std.mem.asBytes(&raw_table), &.{}, .{ .raw_prefixes = &raw_table }));
    try std.testing.expectEqualSlices(u8, &before_table, std.mem.asBytes(&raw_table));

    var encoded = f.serialized;
    var view = try serialized.parse(&encoded);
    const before_encoded = encoded;
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&.{&f.raw}, &encoded, &.{}, .{ .serialized = &view }));
    try std.testing.expectEqualSlices(u8, &before_encoded, &encoded);
    // Capture the initialized descriptor header rather than unused parsed
    // dictionary table slots, which intentionally contain undefined storage.
    const view_scratch = std.mem.asBytes(&view)[0..f.raw.len];
    const before_view = try h.a.dupe(u8, view_scratch);
    defer h.a.free(before_view);
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&.{&f.raw}, view_scratch, &.{}, .{ .serialized = &view }));
    try std.testing.expectEqualSlices(u8, before_view, view_scratch);
    const full_raw_slots = [_][]const u8{""} ** shared.max_raw_prefixes;
    var independent: [f.raw.len]u8 = undefined;
    try std.testing.expectError(error.CorruptFrame, joiner.join(&.{&f.raw}, &independent, &.{}, .{ .raw_prefixes = &full_raw_slots, .serialized = &view }));
    var detached_raw: [16]u8 = @splat('r');
    view.raw_prefix = &detached_raw;
    try std.testing.expectError(error.InvalidBlockPlan, joiner.join(&.{&f.raw}, &detached_raw, &.{}, .{ .serialized = &view }));
    for (detached_raw) |byte| try std.testing.expectEqual(@as(u8, 'r'), byte);
    var scratch: [f.raw.len]u8 = undefined;
    try std.testing.expectEqualSlices(u8, &f.raw, try joiner.join(&.{&f.raw}, &scratch, &.{}, dictionary));
}

fn dictionaryCountGuards() !void {
    var view = try serialized.parse(&f.serialized);
    const forged: [*]const []const u8 = @ptrFromInt(@alignOf([]const u8));
    var scratch: [8]u8 = @splat(0xa5);
    const huge: shared.Dictionary = .{ .raw_prefixes = forged[0..std.math.maxInt(usize)], .serialized = &view };
    try std.testing.expectError(error.IntegerOverflow, joiner.join(&.{"x"}, &scratch, &.{}, huge));
    view.raw_prefix = "";
    try std.testing.expectError(error.CorruptFrame, joiner.join(&.{"x"}, &scratch, &.{}, huge));
    inline for (.{ "word_list_count", "transform_list_count", "dictionary_count" }) |field| {
        view = try serialized.parse(&f.serialized);
        @field(view, field) = serialized.max_contexts + 1;
        try std.testing.expectError(error.CorruptFrame, joiner.join(&.{"x"}, &scratch, &.{}, .{ .serialized = &view }));
        // Observation does geometry only and cannot traverse the bad table.
        try joiner.validateObserver(&.{}, &.{}, &.{}, .{ .serialized = &view }, &scratch);
    }
    for (scratch) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn observerGeometry() !void {
    var data: [32]u8 = @splat(0xa5);
    const observer = data[8..16];
    try joiner.validateObserver(&.{"abcd"}, &data, &.{}, .{}, observer);
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{"abcdefghijkl"}, &data, &.{}, .{}, observer));
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{observer}, data[0..8], &.{}, .{}, observer));
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &.{observer}, .{}, observer));
    // Short scratch remains a join error when the observer binding is valid.
    try joiner.validateObserver(&.{"abcd"}, data[0..2], &.{}, .{}, observer);
    try std.testing.expectError(error.OutputTooSmall, joiner.join(&.{"abcd"}, data[0..2], &.{}, .{}));
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{"abcd"}, observer[0..2], &.{}, .{}, observer));
    var table = [_][]const u8{ "a", "b" };
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&table, &data, &.{}, .{}, std.mem.asBytes(&table)));
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &table, .{}, std.mem.asBytes(&table)));
    const forged: [*]const []const u8 = @ptrFromInt(@alignOf([]const u8));
    const count = std.math.maxInt(usize) / @sizeOf([]const u8) + 1;
    try std.testing.expectError(error.IntegerOverflow, joiner.validateObserver(forged[0..count], &data, &.{}, .{}, observer));
    try std.testing.expectError(error.IntegerOverflow, joiner.validateObserver(&.{}, &data, forged[0..count], .{}, observer));
    const bytes: [*]const u8 = @ptrFromInt(1);
    try std.testing.expectError(error.IntegerOverflow, joiner.validateObserver(&.{ bytes[0..std.math.maxInt(usize)], "x" }, &data, &.{}, .{}, observer));
    try joiner.validateObserver(&.{}, &.{}, &.{}, .{ .raw_prefixes = forged[0 .. shared.max_raw_prefixes + 1] }, observer);
    const dictionary: shared.Dictionary = .{ .raw_prefixes = &table };
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &.{}, dictionary, std.mem.asBytes(&table)));
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &.{}, dictionary, table[0]));
    var invalid_raw_table = [_][]const u8{""} ** (shared.max_raw_prefixes + 1);
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &.{}, .{ .raw_prefixes = &invalid_raw_table }, std.mem.asBytes(&invalid_raw_table)));
    var view = try serialized.parse(&f.serialized);
    const parsed: shared.Dictionary = .{ .serialized = &view };
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &.{}, parsed, std.mem.asBytes(&view)));
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &.{}, parsed, view.encoded));
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &.{}, parsed, view.raw_prefix));
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &.{}, parsed, view.word_lists[0].data));
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &.{}, parsed, view.transform_lists[0].prefix_suffix));
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &.{}, parsed, view.transform_lists[0].transforms));
    var params = [_]u8{ 0, 0 };
    view.transform_lists[0].params = &params;
    try std.testing.expectError(error.InvalidBlockPlan, joiner.validateObserver(&.{}, &.{}, &.{}, parsed, &params));
    for (data) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

const Mode = enum { owned, owned_limited, owned_exact, prefix_owned, append, append_limited, append_exact, prefix_append, into, into_limited, into_exact, prefix_into, summary, summary_limited, eager, eager_limited, eager_exact };
const Policy = enum { defaults, profile, cap_zero };
const Borrow = enum { cycle, chunks, raw_bytes, raw_table, serialized_bytes, serialized_view, serialized_raw };
const dictionary_plain = "x";

pub fn contracts(comptime B: type) !void {
    @setEvalBranchQuota(10000);
    try joinContracts();
    const stored = try B.encodeStoredStreamAlloc(h.a, dictionary_plain);
    defer h.a.free(stored);
    inline for (std.enums.values(Mode)) |mode| {
        inline for (std.enums.values(Policy)) |policy| {
            inline for (std.enums.values(Borrow)) |borrow| try publicBorrow(B, mode, policy, borrow, stored);
        }
    }
    try protectedMetadata(B);
    try malformedAndLimits(B);
    try inheritedRefusals(B);
    const custom_wire = try f.serializedWire(B);
    defer h.a.free(custom_wire);
    inline for (.{ Mode.owned, Mode.append, Mode.into, Mode.summary, Mode.eager }) |mode| {
        inline for (std.enums.values(Detached)) |kind| {
            inline for (.{ @as(?usize, null), @as(?usize, 0) }) |cap| try detachedStatic(B, mode, kind, custom_wire, cap);
        }
    }
    inline for (std.enums.values(Mode)) |mode| try observerScratch(B, mode);
    try publicObserverGeometry(B, custom_wire);
}

fn allocating(comptime mode: Mode) bool {
    return mode == .owned or mode == .owned_limited or mode == .owned_exact or mode == .prefix_owned or
        mode == .append or mode == .append_limited or mode == .append_exact or mode == .prefix_append;
}

fn appending(comptime mode: Mode) bool {
    return mode == .append or mode == .append_limited or mode == .append_exact or mode == .prefix_append;
}

noinline fn publicBorrow(comptime B: type, comptime mode: Mode, comptime policy: Policy, comptime borrow: Borrow, stored: []const u8) !void {
    errdefer std.debug.print("Brotli chunk borrows: {s}, {s}, {s}\n", .{ @tagName(mode), @tagName(policy), @tagName(borrow) });
    var tracker = h.CountingAllocator.init(h.a);
    const heap = tracker.allocator();
    const output_allocator = if (appending(mode)) heap else h.a;
    var out = std.ArrayList(u8).fromOwnedSlice(try output_allocator.alloc(u8, 128));
    defer out.deinit(output_allocator);
    @memset(out.allocatedSlice(), 0xa5);
    out.items.len = 8;
    const pointer = out.items.ptr;
    var output: [128]u8 = @splat(0xa5);
    var profile: B.DecodeMemoryProfile = .{};
    var options: B.DecodeOptions = .{
        .memory_profile = if (policy == .defaults) null else &profile,
        .max_total_working_memory = if (policy == .cap_zero) 0 else null,
    };
    var cycle = f.external[12..].* ++ f.external[0..12].*;
    var chunk_table = [_][]const u8{ f.external[0..1], f.external[1..], "", "" };
    var raw = f.raw_plain.*;
    var raw_table = [_][]const u8{ f.raw_plain, "", "", "" };
    var encoded = f.serialized;
    var view = try B.parseSerializedSharedDictionary(&encoded);
    var detached_raw: [128]u8 = @splat('r');
    var chunks: []const []const u8 = undefined;
    var scratch: []u8 = undefined;
    var plain: []const u8 = f.external_plain;
    const source = [_][]const u8{if (borrow == .raw_bytes or borrow == .raw_table) &f.raw else stored};
    switch (borrow) {
        .cycle => {
            chunks = &.{ cycle[12..], cycle[0..12] };
            scratch = &cycle;
        },
        .chunks => {
            chunks = &chunk_table;
            scratch = std.mem.asBytes(&chunk_table);
        },
        .raw_bytes => {
            chunks = &source;
            scratch = &raw;
            plain = f.raw_plain;
            options.shared_dictionary.raw_prefixes = &.{&raw};
        },
        .raw_table => {
            chunks = &source;
            scratch = std.mem.asBytes(&raw_table);
            plain = f.raw_plain;
            options.shared_dictionary.raw_prefixes = &raw_table;
        },
        .serialized_bytes, .serialized_view, .serialized_raw => {
            chunks = &source;
            plain = dictionary_plain;
            options.shared_dictionary.serialized = &view;
            scratch = switch (borrow) {
                .serialized_bytes => &encoded,
                .serialized_view => std.mem.asBytes(&view)[0..stored.len],
                .serialized_raw => &detached_raw,
                else => unreachable,
            };
            if (borrow == .serialized_raw) view.raw_prefix = &detached_raw;
        },
    }
    const before = try h.a.dupe(u8, scratch);
    defer h.a.free(before);
    tracker.begin();
    try std.testing.expectError(error.InvalidBlockPlan, publicCall(B, mode, heap, &out, chunks, scratch, &output, plain, options));
    try std.testing.expectEqualSlices(u8, before, scratch);
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(@as(usize, 128), out.capacity);
    try std.testing.expectEqual(@as(usize, 8), out.items.len);
    for (out.allocatedSlice()) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    if (policy != .defaults) try h.zeroProfile(profile, options.max_total_working_memory);
    var independent: [128]u8 = undefined;
    const retried = publicCall(B, mode, heap, &out, chunks, &independent, &output, plain, options);
    if (policy == .cap_zero and allocating(mode)) {
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, retried);
        for (out.allocatedSlice()) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
        try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    } else try retried;
    if (policy != .defaults) {
        if (allocating(mode)) try h.profileMatches(profile, &tracker) else try h.zeroProfile(profile, options.max_total_working_memory);
    }
}

fn publicCall(comptime B: type, comptime mode: Mode, heap: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, scratch: []u8, output: []u8, plain: []const u8, options: B.DecodeOptions) !void {
    switch (mode) {
        .owned, .owned_limited, .owned_exact => {
            const decoded = try switch (mode) {
                .owned => B.decodeStreamChunksAllocWithOptions(heap, chunks, scratch, options),
                .owned_limited => B.decodeStreamChunksAllocLimitedWithOptions(heap, chunks, scratch, plain.len, options),
                .owned_exact => B.decodeStreamChunksAllocExactSizeWithOptions(heap, chunks, scratch, plain.len, options),
                else => unreachable,
            };
            defer heap.free(decoded);
            try std.testing.expectEqualSlices(u8, plain, decoded);
        },
        .prefix_owned => {
            const decoded = try B.decodeStreamPrefixChunksAllocWithOptions(heap, chunks, scratch, options);
            defer decoded.deinit(heap);
            try std.testing.expectEqualSlices(u8, plain, decoded.bytes);
        },
        .append, .append_limited, .append_exact, .prefix_append => {
            const written = switch (mode) {
                .append => try B.decodeStreamChunksAppendWithOptions(heap, out, chunks, scratch, options),
                .append_limited => try B.decodeStreamChunksAppendLimitedWithOptions(heap, out, chunks, scratch, plain.len, options),
                .append_exact => try B.decodeStreamChunksAppendExactSizeWithOptions(heap, out, chunks, scratch, plain.len, options),
                .prefix_append => (try B.decodeStreamPrefixChunksAppendWithOptions(heap, out, chunks, scratch, options)).output_written,
                else => unreachable,
            };
            try std.testing.expectEqual(plain.len, written);
            try std.testing.expectEqualSlices(u8, plain, out.items[8..]);
        },
        .into, .into_limited, .into_exact, .prefix_into => {
            const written = switch (mode) {
                .into => try B.decodeStreamChunksIntoWithOptions(chunks, scratch, output, options),
                .into_limited => try B.decodeStreamChunksIntoLimitedWithOptions(chunks, scratch, output, plain.len, options),
                .into_exact => try B.decodeStreamChunksIntoExactSizeWithOptions(chunks, scratch, output, plain.len, options),
                .prefix_into => (try B.decodeStreamPrefixChunksIntoWithOptions(chunks, scratch, output, options)).output_written,
                else => unreachable,
            };
            try std.testing.expectEqual(plain.len, written);
            try std.testing.expectEqualSlices(u8, plain, output[0..written]);
        },
        .summary, .summary_limited => {
            const summary = try if (mode == .summary) B.summarizeStreamChunksWithOptions(chunks, scratch, options) else B.summarizeStreamChunksLimitedWithOptions(chunks, scratch, plain.len, options);
            try std.testing.expectEqual(@as(B.Counter, plain.len), summary.decoded_bytes);
        },
        .eager, .eager_limited, .eager_exact => {
            const decoder = try switch (mode) {
                .eager => B.StreamDecoder.initFromChunksWithOptions(chunks, scratch, output, options),
                .eager_limited => B.StreamDecoder.initFromChunksLimitedWithOptions(chunks, scratch, output, plain.len, options),
                .eager_exact => B.StreamDecoder.initFromChunksExactSizeWithOptions(chunks, scratch, output, plain.len, options),
                else => unreachable,
            };
            try std.testing.expectEqual(plain.len, decoder.snapshot().expected_output_len);
            try std.testing.expectEqualSlices(u8, plain, output[0..plain.len]);
        },
    }
}

fn protectedMetadata(comptime B: type) !void {
    var profile: B.DecodeMemoryProfile = .{};
    const options: B.DecodeOptions = .{ .max_total_working_memory = 0, .memory_profile = &profile };
    var history: [128]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidBlockPlan, B.summarizeStreamChunksLimitedWithHistoryAndOptions(&.{&f.external}, &history, &history, f.external_plain.len, options));
    for (history) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    var diagnostics: B.StreamSummaryDiagnostics = .{};
    try std.testing.expectError(error.InvalidBlockPlan, B.summarizeStreamChunksWithOptionsAndDiagnostics(&.{&f.raw}, std.mem.asBytes(&diagnostics), options, &diagnostics));
    var output: [128]u8 = @splat(0xa5);
    var decoder: B.StreamDecoder = .{ .decoded = output[0..8], .stream_len = 7, .offset = 2 };
    try std.testing.expectError(error.InvalidBlockPlan, decoder.resetFromChunksWithOptions(&.{&f.raw}, std.mem.asBytes(&decoder), &output, options));
    try std.testing.expectEqual(output[0..8].ptr, decoder.decoded.ptr);
    try std.testing.expectEqual(@as(usize, 8), decoder.decoded.len);
    try std.testing.expectEqual(@as(usize, 7), decoder.stream_len);
    try std.testing.expectEqual(@as(usize, 2), decoder.offset);
    try std.testing.expectEqualStrings("InvalidBlockPlan", decoder.snapshot().last_error_name);
    const empty = try B.encodeStoredStreamAlloc(h.a, "");
    defer h.a.free(empty);
    var out = std.ArrayList(u8).fromOwnedSlice(try h.a.dupe(u8, "caller-prefix"));
    defer out.deinit(h.a);
    const before = out;
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksAppendWithOptions(h.a, &out, &.{empty}, std.mem.asBytes(&out), options));
    try std.testing.expectEqual(before.items.ptr, out.items.ptr);
    try std.testing.expectEqual(before.items.len, out.items.len);
    try std.testing.expectEqual(before.capacity, out.capacity);
    try std.testing.expectEqualStrings("caller-prefix", out.items);
    try h.zeroProfile(profile, 0);
}

fn inheritedRefusals(comptime B: type) !void {
    var tracker = h.CountingAllocator.init(h.a);
    defer std.debug.assert(tracker.live == 0);
    var profile: B.DecodeMemoryProfile = .{};
    var lease = try budget.Lease.init(tracker.allocator(), null, &profile, 0);
    defer lease.deinit();
    const parent = lease.allocator();
    try lease.setLimit(tracker.live);
    lease.beginOperation();
    try std.testing.expectError(error.OutOfMemory, parent.alloc(u8, 1));
    const before = lease.snapshot();
    const original_profile = profile;
    var cycle = f.external[12..].* ++ f.external[0..12].*;
    const original_cycle = cycle;
    const chunks = [_][]const u8{ cycle[12..], cycle[0..12] };
    const outer: B.DecodeOptions = .{ .max_total_working_memory = before.limit, .memory_profile = &profile };
    inline for (.{ false, true }) |forwarded| {
        const options = if (forwarded) budget.forward(outer) else outer;
        try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksAllocWithOptions(parent, &chunks, &cycle, options));
        try std.testing.expectEqual(before, lease.snapshot());
        try std.testing.expectEqual(original_profile, profile);
        try std.testing.expectEqualSlices(u8, &original_cycle, &cycle);
    }
    var scratch: [f.external.len]u8 = undefined;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, B.decodeStreamChunksAllocWithOptions(parent, &chunks, &scratch, .{}));
    try lease.setLimit(std.math.maxInt(usize));
    lease.beginOperation();
    tracker.fail_at = tracker.attempts;
    try std.testing.expectError(error.OutOfMemory, B.decodeStreamChunksAllocWithOptions(parent, &chunks, &scratch, .{}));
    try std.testing.expect(!lease.snapshot().last_failure_was_limit);
}

fn malformedAndLimits(comptime B: type) !void {
    var tracker = h.CountingAllocator.init(h.a);
    tracker.fail_at = 0;
    var profile: B.DecodeMemoryProfile = .{};
    const options: B.DecodeOptions = .{ .max_total_working_memory = 0, .memory_profile = &profile };
    var truncated = [_]u8{ f.external[1], f.external[0] };
    const before_truncated = truncated;
    const truncated_chunks = [_][]const u8{ truncated[1..], truncated[0..1] };
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksAllocWithOptions(tracker.allocator(), &truncated_chunks, &truncated, options));
    try std.testing.expectEqualSlices(u8, &before_truncated, &truncated);
    var independent: [f.external.len]u8 = undefined;
    try std.testing.expectError(error.TruncatedFrame, B.decodeStreamChunksAllocWithOptions(tracker.allocator(), &truncated_chunks, &independent, options));

    var cycle = f.external[12..].* ++ f.external[0..12].*;
    const before_cycle = cycle;
    const chunks = [_][]const u8{ cycle[12..], cycle[0..12] };
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksAllocLimitedWithOptions(tracker.allocator(), &chunks, &cycle, f.external_plain.len - 1, options));
    try std.testing.expectEqualSlices(u8, &before_cycle, &cycle);
    try std.testing.expectError(error.OutputLimitExceeded, B.decodeStreamChunksAllocLimitedWithOptions(tracker.allocator(), &chunks, &independent, f.external_plain.len - 1, options));
    const invalid_raw = [_][]const u8{""} ** (shared.max_raw_prefixes + 1);
    var invalid = options;
    invalid.shared_dictionary.raw_prefixes = &invalid_raw;
    try std.testing.expectError(error.OutputTooSmall, B.decodeStreamChunksAllocWithOptions(tracker.allocator(), &chunks, cycle[0 .. cycle.len - 1], invalid));
    try std.testing.expectError(error.CorruptFrame, B.decodeStreamChunksAllocWithOptions(tracker.allocator(), &chunks, &cycle, invalid));
    try std.testing.expectEqualSlices(u8, &before_cycle, &cycle);
    var output: [128]u8 = @splat(0xa5);
    // Output/metadata rejection retains its earlier precedence over the
    // scalar dictionary validator when both contracts are violated.
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksIntoWithOptions(&.{&f.external}, &output, &output, invalid));
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try std.testing.expectEqual(@as(usize, 0), tracker.live);
    try h.zeroProfile(profile, 0);
}

const Detached = enum { words, prefix_suffix, transforms, params };
const shift_zero = [_]u8{ 0, 21, 0 };

fn detach(view: *serialized.Dictionary, comptime kind: Detached, storage: []u8) void {
    switch (kind) {
        .words => {
            const original = view.word_lists[0].data;
            @memcpy(storage[0..original.len], original);
            view.word_lists[0].data = storage[0..original.len];
        },
        .prefix_suffix => {
            const original = view.transform_lists[0].prefix_suffix;
            @memcpy(storage[0..original.len], original);
            view.transform_lists[0].prefix_suffix = storage[0..original.len];
        },
        .transforms => {
            const original = view.transform_lists[0].transforms;
            @memcpy(storage[0..original.len], original);
            view.transform_lists[0].transforms = storage[0..original.len];
        },
        .params => {
            @memset(storage[0..2], 0);
            view.transform_lists[0].transforms = &shift_zero;
            view.transform_lists[0].params = storage[0..2];
        },
    }
}

noinline fn detachedStatic(comptime B: type, comptime mode: Mode, comptime kind: Detached, wire: []const u8, cap: ?usize) !void {
    errdefer std.debug.print("Brotli detached static borrow: {s}, {s}, cap={any}\n", .{ @tagName(mode), @tagName(kind), cap });
    var view = try B.parseSerializedSharedDictionary(&f.serialized);
    var storage: [128]u8 = @splat(0xa5);
    detach(&view, kind, &storage);
    const before = storage;
    var tracker = h.CountingAllocator.init(h.a);
    const heap = tracker.allocator();
    const output_allocator = if (appending(mode)) heap else h.a;
    var out = std.ArrayList(u8).fromOwnedSlice(try output_allocator.alloc(u8, 128));
    defer out.deinit(output_allocator);
    @memset(out.allocatedSlice(), 0xa5);
    out.items.len = 8;
    var output: [128]u8 = @splat(0xa5);
    var profile: B.DecodeMemoryProfile = .{};
    const options: B.DecodeOptions = .{ .shared_dictionary = .{ .serialized = &view }, .memory_profile = &profile, .max_total_working_memory = cap };
    tracker.begin();
    try std.testing.expectError(error.InvalidBlockPlan, publicCall(B, mode, heap, &out, &.{wire}, &storage, &output, "hello", options));
    try std.testing.expectEqualSlices(u8, &before, &storage);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    try h.zeroProfile(profile, cap);
    var scratch: [128]u8 = undefined;
    const retried = publicCall(B, mode, heap, &out, &.{wire}, &scratch, &output, "hello", options);
    if (cap != null and allocating(mode)) {
        try std.testing.expectError(error.WorkingMemoryLimitExceeded, retried);
        try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
    } else try retried;
    if (allocating(mode)) try h.profileMatches(profile, &tracker) else try h.zeroProfile(profile, cap);
}

fn observerScratch(comptime B: type, comptime mode: Mode) !void {
    errdefer std.debug.print("Brotli observer scratch mode: {s}\n", .{@tagName(mode)});
    var tracker = h.CountingAllocator.init(h.a);
    const heap = tracker.allocator();
    const output_allocator = if (appending(mode)) heap else h.a;
    var out = std.ArrayList(u8).fromOwnedSlice(try output_allocator.alloc(u8, 128));
    defer out.deinit(output_allocator);
    @memset(out.allocatedSlice(), 0xa5);
    out.items.len = 8;
    const pointer = out.items.ptr;
    var output: [128]u8 = @splat(0xa5);
    var profile: B.DecodeMemoryProfile = .{};
    const before = profile;
    const options: B.DecodeOptions = .{ .memory_profile = &profile, .max_total_working_memory = 0 };
    tracker.begin();
    try std.testing.expectError(error.InvalidBlockPlan, publicCall(B, mode, heap, &out, &.{&f.external}, std.mem.asBytes(&profile), &output, f.external_plain, options));
    try std.testing.expectEqualDeep(before, profile);
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(@as(usize, 128), out.capacity);
    try std.testing.expectEqual(@as(usize, 8), out.items.len);
    for (out.allocatedSlice()) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    try std.testing.expectEqual(@as(usize, 0), tracker.attempts);
}

fn publicObserverGeometry(comptime B: type, custom_wire: []const u8) !void {
    var case_name: []const u8 = "direct Into source";
    errdefer std.debug.print("Brotli observer binding case: {s}\n", .{case_name});
    var profile: B.DecodeMemoryProfile = .{};
    const before = profile;
    const options: B.DecodeOptions = .{ .memory_profile = &profile, .max_total_working_memory = 0 };
    var scratch: [128]u8 = undefined;
    var output: [128]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamIntoWithOptions(std.mem.asBytes(&profile)[0..1], &output, options));
    try std.testing.expectEqualDeep(before, profile);
    case_name = "direct Into output";
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamIntoWithOptions(&f.external, std.mem.asBytes(&profile), options));
    try std.testing.expectEqualDeep(before, profile);
    case_name = "direct PrefixInto source";
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamPrefixIntoWithOptions(std.mem.asBytes(&profile)[0..1], &output, options));
    try std.testing.expectEqualDeep(before, profile);
    case_name = "direct PrefixInto output";
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamPrefixIntoWithOptions(&f.external, std.mem.asBytes(&profile), options));
    try std.testing.expectEqualDeep(before, profile);
    var direct_out = std.ArrayList(u8).fromOwnedSlice(try h.a.dupe(u8, "caller-prefix"));
    defer direct_out.deinit(h.a);
    const direct_pointer = direct_out.items.ptr;
    const direct_capacity = direct_out.capacity;
    case_name = "direct Append source";
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamAppendWithOptions(h.a, &direct_out, std.mem.asBytes(&profile)[0..1], options));
    try std.testing.expectEqualDeep(before, profile);
    try std.testing.expectEqual(direct_pointer, direct_out.items.ptr);
    try std.testing.expectEqual(direct_capacity, direct_out.capacity);
    try std.testing.expectEqualStrings("caller-prefix", direct_out.items);
    var destination: struct { observer: B.DecodeMemoryProfile = .{}, spare: [128]u8 = @splat(0xa5) } = .{};
    var fixed = std.heap.FixedBufferAllocator.init(std.mem.asBytes(&destination));
    var aliased_out = std.ArrayList(u8).fromOwnedSlice(try fixed.allocator().alloc(u8, @sizeOf(@TypeOf(destination))));
    defer aliased_out.deinit(fixed.allocator());
    aliased_out.items.len = 8;
    // Safety-mode allocation poisons this caller buffer, including observer
    // fields. Initialize its contents after the allocation has completed.
    destination = .{};
    const aliased_pointer = aliased_out.items.ptr;
    const aliased_capacity = aliased_out.capacity;
    case_name = "direct Append output";
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamAppendWithOptions(fixed.allocator(), &aliased_out, &f.external, .{ .memory_profile = &destination.observer }));
    try std.testing.expectEqualDeep(before, destination.observer);
    try std.testing.expectEqual(aliased_pointer, aliased_out.items.ptr);
    try std.testing.expectEqual(aliased_capacity, aliased_out.capacity);
    try std.testing.expectEqual(@as(usize, 8), aliased_out.items.len);
    case_name = "chunk Into source";
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksIntoWithOptions(&.{std.mem.asBytes(&profile)[0..1]}, &scratch, &output, options));
    try std.testing.expectEqualDeep(before, profile);
    case_name = "chunk Into output";
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksIntoWithOptions(&.{&f.external}, &scratch, std.mem.asBytes(&profile), options));
    try std.testing.expectEqualDeep(before, profile);
    case_name = "chunk summary history";
    try std.testing.expectError(error.InvalidBlockPlan, B.summarizeStreamChunksLimitedWithHistoryAndOptions(&.{&f.external}, &scratch, std.mem.asBytes(&profile), f.external_plain.len, options));
    try std.testing.expectEqualDeep(before, profile);
    var table = [_][]const u8{ &f.external, "", "", "", "", "", "", "" };
    const before_table = std.mem.asBytes(&table).*;
    const table_profile: *B.DecodeMemoryProfile = @ptrCast(&table);
    case_name = "chunk descriptor table";
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksIntoWithOptions(&table, &scratch, &output, .{ .memory_profile = table_profile }));
    try std.testing.expectEqualSlices(u8, &before_table, std.mem.asBytes(&table));
    var raw_table = [_][]const u8{ f.raw_plain, "", "", "", "", "", "", "" };
    const before_raw_table = std.mem.asBytes(&raw_table).*;
    const raw_profile: *B.DecodeMemoryProfile = @ptrCast(&raw_table);
    case_name = "RAW descriptor table";
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksIntoWithOptions(&.{&f.raw}, &scratch, &output, .{ .memory_profile = raw_profile, .shared_dictionary = .{ .raw_prefixes = &raw_table } }));
    try std.testing.expectEqualSlices(u8, &before_raw_table, std.mem.asBytes(&raw_table));
    var invalid_raw_table = [_][]const u8{""} ** (shared.max_raw_prefixes + 1);
    const before_invalid_table = std.mem.asBytes(&invalid_raw_table).*;
    const invalid_profile: *B.DecodeMemoryProfile = @ptrCast(&invalid_raw_table);
    case_name = "excessive RAW descriptor table";
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksIntoWithOptions(&.{&f.raw}, &scratch, &output, .{ .memory_profile = invalid_profile, .shared_dictionary = .{ .raw_prefixes = &invalid_raw_table } }));
    try std.testing.expectEqualSlices(u8, &before_invalid_table, std.mem.asBytes(&invalid_raw_table));
    var view = try B.parseSerializedSharedDictionary(&f.serialized);
    const view_header = std.mem.asBytes(&view)[0..@sizeOf(B.DecodeMemoryProfile)];
    const before_header = try h.a.dupe(u8, view_header);
    defer h.a.free(before_header);
    const view_profile: *B.DecodeMemoryProfile = @ptrCast(&view);
    case_name = "serialized view";
    try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksIntoWithOptions(&.{custom_wire}, &scratch, &output, .{ .memory_profile = view_profile, .shared_dictionary = .{ .serialized = &view } }));
    try std.testing.expectEqualSlices(u8, before_header, view_header);
    inline for (std.enums.values(Detached)) |kind| {
        case_name = @tagName(kind);
        view = try B.parseSerializedSharedDictionary(&f.serialized);
        var storage: [128]u8 align(@alignOf(B.DecodeMemoryProfile)) = @splat(0xa5);
        detach(&view, kind, &storage);
        const original = storage;
        const nested_profile: *B.DecodeMemoryProfile = @ptrCast(&storage);
        try std.testing.expectError(error.InvalidBlockPlan, B.decodeStreamChunksIntoWithOptions(&.{custom_wire}, &scratch, &output, .{ .memory_profile = nested_profile, .shared_dictionary = .{ .serialized = &view } }));
        try std.testing.expectEqualSlices(u8, &original, &storage);
    }
    // Unused scratch tail can contain an observer: neither joining nor decode
    // reads that tail as compressed input after observation writes it. Use an
    // explicit byte offset because auto-layout structs may reorder fields.
    var arena: [128]u8 align(@alignOf(B.DecodeMemoryProfile)) = @splat(0xa5);
    const tail_observer: *B.DecodeMemoryProfile = @ptrCast(@alignCast(arena[64..].ptr));
    tail_observer.* = .{};
    case_name = "unused scratch tail";
    const written = B.decodeStreamChunksIntoWithOptions(&.{&f.external}, &arena, &output, .{ .memory_profile = tail_observer, .max_total_working_memory = 0 }) catch |err| {
        std.debug.print("Brotli unused scratch tail error: {s}, observer_offset=64, joined_len={d}, scratch_len={d}\n", .{ @errorName(err), f.external.len, arena.len });
        return err;
    };
    try std.testing.expectEqualStrings(f.external_plain, output[0..written]);
    try h.zeroProfile(tail_observer.*, 0);
}
