//! Owned meta-block diagnostics through public decode and summary contracts.
const std = @import("std");
const testing = std.testing;
const allocator = testing.allocator;

pub fn contracts(comptime Br: type) !void {
    try emptyStoredAndMetadata(Br);
    try mixedTransitions(Br);
    try shortSwitches(Br);
    try resourceLimits(Br);
    try allocationFailures(Br);
    try malformedAndTruncated(Br);
}

fn inspect(comptime Br: type, wire: []const u8, options: Br.DecodeMetaBlockDiagnosticOptions) !Br.DecodeMetaBlockDiagnosticReport {
    return Br.diagnoseMetaBlocksAlloc(testing.io, allocator, wire, options);
}

fn checkReport(comptime Br: type, wire: []const u8, plain: []const u8, report: Br.DecodeMetaBlockDiagnosticReport) !void {
    const summary = try Br.summarizeStream(wire);
    try testing.expectEqualSlices(u8, plain, report.output);
    try testing.expectEqual(summary.window_bits, report.window_bits);
    try testing.expectEqual(@as(@TypeOf(summary.decoded_bytes), plain.len), summary.decoded_bytes);
    try testing.expectEqual(@as(@TypeOf(summary.input_bytes), wire.len), summary.input_bytes);
    try testing.expectEqual(@as(@TypeOf(summary.meta_block_count), report.records.len), summary.meta_block_count - summary.empty_meta_block_count);
    const decoded = try allocator.alloc(u8, plain.len);
    defer allocator.free(decoded);
    try testing.expectEqual(plain.len, try Br.decodeStreamInto(wire, decoded));
    try testing.expectEqualSlices(u8, plain, decoded);

    var totals: Br.StreamSummary = .{ .window_bits = report.window_bits, .input_bytes = wire.len };
    var compressed: usize = 0;
    var stored: usize = 0;
    var metadata: usize = 0;
    var decoded_end: usize = 0;
    var payload_end: Br.BitCount = 0;
    for (report.records, 0..) |record, index| {
        try testing.expectEqual(index, record.meta_block_index);
        try testing.expectEqual(decoded_end, record.decoded_start);
        try testing.expect(record.decoded_end >= record.decoded_start);
        try testing.expect(record.header_start >= payload_end);
        try testing.expect(record.header_start <= record.payload_start);
        try testing.expect(record.payload_start <= record.payload_end);
        try testing.expect(record.payload_end <= @as(Br.BitCount, wire.len) * 8);
        if (index != 0) try testing.expectEqual(payload_end, record.header_start);
        switch (record.kind) {
            .compressed => {
                compressed += 1;
                try testing.expect(record.decoded_end > record.decoded_start);
                try testing.expect(record.compressed_header_start != null);
                try testing.expect(record.header_start <= record.compressed_header_start.?);
                try testing.expect(record.compressed_header_start.? <= record.payload_start);
                try testing.expect(record.route != null);
                try testing.expectEqual(record.route.? == .small_generic, record.small_payload_includes_header);
                try testing.expect(record.literal_trees > 0 and record.command_trees > 0 and record.distance_trees > 0);
                try testing.expectEqual(@as(usize, record.literal_trees), record.stats.max_literal_context_trees);
                try testing.expectEqual(@as(usize, record.command_trees), record.stats.max_command_block_types);
                try testing.expectEqual(@as(usize, record.distance_trees), record.stats.max_distance_context_trees);
                try testing.expectEqual(record.npostfix, record.stats.max_distance_postfix_bits);
                try testing.expectEqual(record.ndirect, record.stats.max_direct_distance_codes);
            },
            .stored => {
                stored += 1;
                try testing.expect(record.decoded_end > record.decoded_start);
                try testing.expectEqual(@as(Br.BitCount, record.decoded_end - record.decoded_start) * 8, record.payload_end - record.payload_start);
                try testing.expectEqual(@as(Br.BitCount, 0), record.payload_start % 8);
                try testing.expect(record.route == null and record.compressed_header_start == null);
            },
            .metadata => {
                metadata += 1;
                try testing.expectEqual(record.decoded_start, record.decoded_end);
                try testing.expect(record.route == null and record.compressed_header_start == null);
            },
        }
        if (record.kind != .compressed) {
            try testing.expectEqual(@as(u16, 0), record.literal_trees);
            try testing.expectEqual(@as(u16, 0), record.command_trees);
            try testing.expectEqual(@as(u16, 0), record.distance_trees);
            try testing.expect(!record.small_payload_includes_header);
            try testing.expectEqualDeep(@as(@TypeOf(record.stats), .{}), record.stats);
        }
        inline for (.{
            "static_dictionary_copy_count",          "static_dictionary_bytes",               "shared_dictionary_copy_count",        "shared_dictionary_bytes",
            "command_count",                         "zero_insert_command_count",             "single_literal_insert_command_count", "implicit_distance_command_count",
            "implicit_distance_copy_count",          "short_distance_copy_count",             "direct_distance_copy_count",          "regular_distance_copy_count",
            "lz77_copy_count",                       "lz77_copy_bytes",                       "non_overlapping_lz77_copy_count",     "non_overlapping_lz77_copy_bytes",
            "short_non_overlapping_lz77_copy_count", "short_non_overlapping_lz77_copy_bytes",
        }) |name| {
            @field(totals, name) += @intCast(@field(record.stats, name));
        }
        inline for (.{
            "max_lz77_distance",        "max_literal_block_types",    "max_literal_context_trees", "max_command_block_types",
            "max_distance_block_types", "max_distance_context_trees", "max_distance_postfix_bits", "max_direct_distance_codes",
        }) |name| {
            @field(totals, name) = @max(@field(totals, name), @field(record.stats, name));
        }
        for (&totals.copy_length_log2_histogram, record.stats.copy_length_log2_histogram) |*total, value| total.* += @intCast(value);
        for (&totals.literal_context_mode_bytes, record.stats.literal_context_mode_bytes) |*total, value| total.* += @intCast(value);
        decoded_end = record.decoded_end;
        payload_end = record.payload_end;
    }
    try testing.expectEqual(report.output.len, decoded_end);
    try testing.expectEqual(@as(@TypeOf(summary.compressed_meta_block_count), compressed), summary.compressed_meta_block_count);
    try testing.expectEqual(@as(@TypeOf(summary.uncompressed_meta_block_count), stored), summary.uncompressed_meta_block_count);
    try testing.expectEqual(@as(@TypeOf(summary.metadata_meta_block_count), metadata), summary.metadata_meta_block_count);
    inline for (.{
        "static_dictionary_copy_count",    "static_dictionary_bytes",         "shared_dictionary_copy_count",          "shared_dictionary_bytes",
        "command_count",                   "zero_insert_command_count",       "single_literal_insert_command_count",   "implicit_distance_command_count",
        "implicit_distance_copy_count",    "short_distance_copy_count",       "direct_distance_copy_count",            "regular_distance_copy_count",
        "copy_length_log2_histogram",      "lz77_copy_count",                 "lz77_copy_bytes",                       "max_lz77_distance",
        "non_overlapping_lz77_copy_count", "non_overlapping_lz77_copy_bytes", "short_non_overlapping_lz77_copy_count", "short_non_overlapping_lz77_copy_bytes",
        "literal_context_mode_bytes",      "max_literal_block_types",         "max_literal_context_trees",             "max_command_block_types",
        "max_distance_block_types",        "max_distance_context_trees",      "max_distance_postfix_bits",             "max_direct_distance_codes",
    }) |name| try testing.expectEqualDeep(@field(summary, name), @field(totals, name));
}

fn check(comptime Br: type, wire: []const u8, plain: []const u8) !void {
    const before = try allocator.dupe(u8, wire);
    defer allocator.free(before);
    var report = try inspect(Br, wire, .{});
    defer report.deinit(allocator);
    try checkReport(Br, wire, plain, report);
    try testing.expectEqualSlices(u8, before, wire);
    try testing.expectEqual((@as(usize, 1) << report.window_bits) - 16, report.replay_history_bytes);
}

fn emptyStoredAndMetadata(comptime Br: type) !void {
    try check(Br, &.{0x06}, "");
    try check(Br, &.{ 0x0c, 0x03 }, ""); // Empty metadata, then final-empty marker.
    const plain = "hello";
    const stored = [_]u8{ 0x40, 0x00, 0x10, 'h', 'e', 'l', 'l', 'o', 0x03 };
    try check(Br, &stored, plain);
    var report = try inspect(Br, &stored, .{ .max_output_len = plain.len, .max_meta_blocks = 1 });
    defer report.deinit(allocator);
    try testing.expectEqual(@as(usize, 1), report.records.len);
    try testing.expectEqual(@as(Br.BitCount, 1), report.records[0].header_start);
    try testing.expectEqual(@as(Br.BitCount, 24), report.records[0].payload_start);
    try testing.expectEqual(@as(Br.BitCount, 64), report.records[0].payload_end);
    try testing.expectEqual(plain.len, report.replay_history_bytes);
    for ([_]u5{ 10, 16, 24 }) |window| {
        const wire = try Br.encodeStoredStreamWithOptionsAlloc(allocator, plain, .{ .window_bits = window, .metadata = "tag" });
        defer allocator.free(wire);
        var limited = try inspect(Br, wire, .{ .max_output_len = plain.len, .max_meta_blocks = 2 });
        defer limited.deinit(allocator);
        try checkReport(Br, wire, plain, limited);
        try testing.expectEqual(window, limited.window_bits);
        try testing.expectEqual(plain.len, limited.replay_history_bytes);
    }
}

fn mixedTransitions(comptime Br: type) !void {
    const F = Br.IncrementalTestSupport;
    const mixed = try F.encodeCompressedHelloThenMetadataAndStoredBlocks(allocator, "diagnostic", &.{ "ABC", "def" });
    defer allocator.free(mixed);
    try check(Br, mixed, "helloABCdef");
    var report = try inspect(Br, mixed, .{});
    defer report.deinit(allocator);
    try testing.expectEqual(@as(usize, 4), report.records.len);
    try testing.expect(report.records[0].kind == .compressed and report.records[1].kind == .metadata and report.records[2].kind == .stored and report.records[3].kind == .stored);
    try testing.expect(report.records[0].route.? == .small_generic and report.records[0].small_payload_includes_header);
    const metadata_first = try F.encodeMetadataThenCompressedHello(allocator, "first");
    defer allocator.free(metadata_first);
    try check(Br, metadata_first, "hello");
    const context = try F.encodeCompressedLiteralContextAcrossMetaBlocks(allocator);
    defer allocator.free(context);
    try check(Br, context, "ab");
    const stored_context = try F.encodeStoredThenCompressedContext(allocator);
    defer allocator.free(stored_context);
    try check(Br, stored_context, "ab");
    const ring = try F.encodeCompressedCopiesAcrossMetaBlocks(allocator);
    defer allocator.free(ring);
    try check(Br, ring, "aaaaa");
}

const Switch = enum { command, literal, distance };

/// Independent short RFC bit writer. No codec-private header/planner helpers.
const Wire = struct {
    bytes: [64]u8 = @splat(0),
    bits: usize = 0,

    fn put(self: *Wire, value: u16, width: u5) void {
        for (0..width) |index| {
            self.bytes[self.bits / 8] |= @as(u8, @intCast((value >> @as(u4, @intCast(index))) & 1)) << @as(u3, @intCast(self.bits % 8));
            self.bits += 1;
        }
    }

    fn slice(self: *const Wire) []const u8 {
        return self.bytes[0 .. (self.bits + 7) / 8];
    }

    fn count(self: *Wire, value: u16) void {
        std.debug.assert(value == 1 or value == 2);
        if (value == 1) self.put(0, 1) else self.put(1, 4);
    }

    fn symbols(self: *Wire, alphabet: u16, values: []const u16) void {
        self.put(1, 2); // Simple prefix.
        self.put(@intCast(values.len - 1), 2);
        const width: u5 = @intCast(std.math.log2_int_ceil(u16, alphabet));
        for (values) |value| self.put(value, width);
    }

    fn blockSwitch(self: *Wire) void {
        self.count(2);
        self.symbols(4, &.{1});
        self.symbols(26, &.{0});
        self.put(0, 2); // First block has one symbol.
    }

    fn contextMap(self: *Wire, literal: bool) void {
        self.put(0, 1); // No zero RLE.
        self.symbols(2, &.{ 0, 1 });
        const context_entries: usize = if (literal) 128 else 8;
        for (0..context_entries) |index| self.put(@intFromBool(if (literal) index >= 64 else index == 4), 1);
        self.put(0, 1); // No inverse move-to-front.
    }
};

fn switchWire(kind: Switch) Wire {
    var wire: Wire = .{};
    wire.put(0, 1); // RFC WBITS=16.
    wire.put(1, 1); // Final compressed meta-block.
    wire.put(0, 1); // Not final-empty.
    wire.put(0, 2); // Four length nibbles.
    wire.put(switch (kind) {
        .command => 3,
        .literal => 1,
        .distance => 6,
    }, 16);
    if (kind == .literal) wire.blockSwitch() else wire.count(1);
    if (kind == .command) wire.blockSwitch() else wire.count(1);
    if (kind == .distance) wire.blockSwitch() else wire.count(1);
    wire.put(0, 2); // NPOSTFIX=0.
    wire.put(switch (kind) {
        .command => 1,
        .literal => 0,
        .distance => 3,
    }, 4);
    wire.put(0, 2); // Literal context mode 0.
    if (kind == .literal) wire.put(0, 2); // Second literal block type.
    wire.count(if (kind == .literal) 2 else 1);
    if (kind == .literal) wire.contextMap(true);
    wire.count(if (kind == .distance) 2 else 1);
    if (kind == .distance) wire.contextMap(false);
    switch (kind) {
        .command => {
            wire.symbols(256, &.{ 'a', 'b' });
            wire.symbols(704, &.{136});
            wire.symbols(704, &.{8});
            wire.symbols(65, &.{16});
            wire.put(0, 1); // First literal a; direct copy produces aaa.
            wire.put(0, 2); // Next command block count.
            wire.put(1, 1); // Final literal b.
        },
        .literal => {
            wire.symbols(256, &.{'a'});
            wire.symbols(256, &.{'b'});
            wire.symbols(704, &.{16});
            wire.symbols(64, &.{0});
            wire.put(0, 2); // Next literal block count.
        },
        .distance => {
            wire.symbols(256, &.{ 'a', 'b', 'c' });
            wire.symbols(704, &.{ 152, 128 });
            wire.symbols(67, &.{18});
            wire.symbols(67, &.{17});
            wire.put(1, 1); // Insert three, then copy two at distance 3.
            wire.put(0, 1);
            wire.put(1, 2);
            wire.put(3, 2);
            wire.put(0, 1); // Zero insert, then copy two at distance 2.
            wire.put(0, 2); // Next distance block count.
        },
    }
    return wire;
}

fn switchPlain(kind: Switch) []const u8 {
    return switch (kind) {
        .command => "aaab",
        .literal => "ab",
        .distance => "abcabab",
    };
}

fn shortSwitches(comptime Br: type) !void {
    for ([_]Switch{ .command, .literal, .distance }) |kind| {
        const wire = switchWire(kind);
        try check(Br, wire.slice(), switchPlain(kind));
        var report = try inspect(Br, wire.slice(), .{});
        defer report.deinit(allocator);
        try testing.expectEqual(@as(usize, 1), report.records.len);
        const record = report.records[0];
        try testing.expect(record.route.? == .small_generic and record.small_payload_includes_header);
        switch (kind) {
            .command => try testing.expectEqual(@as(u16, 2), record.command_trees),
            .literal => try testing.expectEqual(@as(usize, 2), record.stats.max_literal_block_types),
            .distance => try testing.expectEqual(@as(usize, 2), record.stats.max_distance_block_types),
        }
    }
}

fn resourceLimits(comptime Br: type) !void {
    const wire = try Br.IncrementalTestSupport.encodeCompressedHelloThenMetadataAndStoredBlocks(allocator, "metadata", &.{ "ABC", "def" });
    defer allocator.free(wire);
    const before = try allocator.dupe(u8, wire);
    defer allocator.free(before);
    var exact = try inspect(Br, wire, .{ .max_output_len = 11, .max_meta_blocks = 4 });
    defer exact.deinit(allocator);
    try checkReport(Br, wire, "helloABCdef", exact);
    try testing.expectEqual(@as(usize, 11), exact.replay_history_bytes);
    try testing.expectError(error.WorkingMemoryLimitExceeded, inspect(Br, wire, .{ .max_output_len = 10, .max_meta_blocks = 4 }));
    try testing.expectError(error.WorkingMemoryLimitExceeded, inspect(Br, wire, .{ .max_output_len = 11, .max_meta_blocks = 3 }));
    try testing.expectError(error.InvalidBlockPlan, inspect(Br, wire, .{ .max_meta_blocks = 0 }));
    try testing.expectError(error.InvalidBlockPlan, inspect(Br, &.{0x06}, .{ .max_meta_blocks = 0 }));
    var empty = try inspect(Br, &.{0x06}, .{ .max_output_len = 0, .max_meta_blocks = 1 });
    defer empty.deinit(allocator);
    try testing.expectEqual(@as(usize, 0), empty.output.len);
    try testing.expectEqual(@as(usize, 0), empty.records.len);
    try testing.expectEqual(@as(usize, 0), empty.replay_history_bytes);
    try testing.expectEqualSlices(u8, before, wire);
    // The report owns its results independently of the caller's borrowed wire.
    const first_record = exact.records[0];
    @memset(wire, 0xcc);
    try testing.expectEqualSlices(u8, "helloABCdef", exact.output);
    try testing.expectEqualDeep(first_record, exact.records[0]);
    @memcpy(wire, before);
}

fn oomSweep(comptime Br: type, wire: []const u8) !void {
    const before = try allocator.dupe(u8, wire);
    defer allocator.free(before);
    var baseline = testing.FailingAllocator.init(allocator, .{});
    var report = try Br.diagnoseMetaBlocksAlloc(testing.io, baseline.allocator(), wire, .{});
    report.deinit(baseline.allocator());
    try testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
    for (0..baseline.alloc_index) |failure| {
        var failing = testing.FailingAllocator.init(allocator, .{ .fail_index = failure });
        const result = Br.diagnoseMetaBlocksAlloc(testing.io, failing.allocator(), wire, .{});
        if (result) |owned| {
            var unexpected = owned;
            unexpected.deinit(failing.allocator());
            return error.ExpectedAllocationFailure;
        } else |err| try testing.expectEqual(error.OutOfMemory, err);
        try testing.expect(failing.has_induced_failure);
        try testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
        try testing.expectEqualSlices(u8, before, wire);
    }
}

fn allocationFailures(comptime Br: type) !void {
    try oomSweep(Br, &.{0x06});
    try oomSweep(Br, &.{ 0x0c, 0x03 });
    const stored = [_]u8{ 0x40, 0x00, 0x10, 'h', 'e', 'l', 'l', 'o', 0x03 };
    try oomSweep(Br, &stored);
    const wire = try Br.IncrementalTestSupport.encodeCompressedHelloThenMetadataAndStoredBlocks(allocator, "metadata", &.{ "ABC", "def" });
    defer allocator.free(wire);
    try oomSweep(Br, wire);
    for ([_]Switch{ .command, .literal, .distance }) |kind| {
        const short = switchWire(kind);
        try oomSweep(Br, short.slice());
    }
}

fn reject(comptime Br: type, wire: []const u8) !void {
    const before = try allocator.dupe(u8, wire);
    defer allocator.free(before);
    const result = inspect(Br, wire, .{});
    if (result) |owned| {
        var unexpected = owned;
        unexpected.deinit(allocator);
        return error.ExpectedMalformedDiagnosticFailure;
    } else |_| {}
    try testing.expectEqualSlices(u8, before, wire);
}

fn truncated(comptime Br: type, wire: []const u8) !void {
    for (0..wire.len) |cut| try reject(Br, wire[0..cut]);
    var full = try inspect(Br, wire, .{});
    defer full.deinit(allocator);
    var rejected_bit_prefixes: usize = 0;
    for (full.records) |record| {
        const boundaries = [_]Br.BitCount{ record.header_start + 1, record.compressed_header_start orelse record.payload_start, record.payload_start + 1, record.payload_end -| 1 };
        for (boundaries) |cut| {
            if (cut == 0 or cut >= @as(Br.BitCount, wire.len) * 8) continue;
            const byte_len: usize = @intCast(cut / 8 + @intFromBool(cut % 8 != 0));
            const prefix = try allocator.dupe(u8, wire[0..byte_len]);
            defer allocator.free(prefix);
            if (cut % 8 != 0) prefix[byte_len - 1] &= @as(u8, 0xff) >> @as(u3, @intCast(8 - cut % 8));
            var oracle: [256]u8 = undefined;
            // A byte API cannot describe a fractional-byte EOF. Only prefixes
            // rejected by the independent public decoder are malformed cases.
            if (Br.decodeStreamInto(prefix, &oracle)) |_| continue else |_| {
                try reject(Br, prefix);
                rejected_bit_prefixes += 1;
            }
        }
    }
    if (full.records.len != 0) try testing.expect(rejected_bit_prefixes != 0);
}

fn malformedAndTruncated(comptime Br: type) !void {
    try truncated(Br, &.{0x06});
    try truncated(Br, &.{ 0x0c, 0x03 });
    const stored = [_]u8{ 0x40, 0x00, 0x10, 'h', 'e', 'l', 'l', 'o', 0x03 };
    try truncated(Br, &stored);
    const mixed = try Br.IncrementalTestSupport.encodeCompressedHelloThenMetadataAndStoredBlocks(allocator, "metadata", &.{ "ABC", "def" });
    defer allocator.free(mixed);
    try truncated(Br, mixed);
    const hello = try Br.IncrementalTestSupport.encodeCompressedHello(allocator);
    defer allocator.free(hello);
    try truncated(Br, hello);
    const metadata_first = try Br.IncrementalTestSupport.encodeMetadataThenCompressedHello(allocator, "first");
    defer allocator.free(metadata_first);
    try truncated(Br, metadata_first);
    const context = try Br.IncrementalTestSupport.encodeCompressedLiteralContextAcrossMetaBlocks(allocator);
    defer allocator.free(context);
    try truncated(Br, context);
    const stored_context = try Br.IncrementalTestSupport.encodeStoredThenCompressedContext(allocator);
    defer allocator.free(stored_context);
    try truncated(Br, stored_context);
    const ring = try Br.IncrementalTestSupport.encodeCompressedCopiesAcrossMetaBlocks(allocator);
    defer allocator.free(ring);
    try truncated(Br, ring);
    for ([_]u5{ 10, 16, 24 }) |window| {
        const with_metadata = try Br.encodeStoredStreamWithOptionsAlloc(allocator, "hello", .{ .window_bits = window, .metadata = "tag" });
        defer allocator.free(with_metadata);
        try truncated(Br, with_metadata);
    }
    for ([_]Switch{ .command, .literal, .distance }) |kind| {
        const wire = switchWire(kind);
        try truncated(Br, wire.slice());
    }
    try reject(Br, &.{0x01}); // Incomplete long window prefix/meta header.
    try reject(Br, &.{ 0x1c, 0x03 }); // Metadata reserved bit set.
    try reject(Br, &.{ 0x8c, 0x03 }); // Nonzero metadata alignment padding.
    try reject(Br, &.{0x0e}); // Final metadata with incomplete remaining header.
    const extended = try Br.encodeStoredStreamWithOptionsAlloc(allocator, "wide", .{ .window_bits = 16, .large_window = true });
    defer allocator.free(extended);
    try reject(Br, extended); // Defaults retain standard RFC-only scope.
    const trailing = try std.mem.concat(allocator, u8, &.{ &stored, "tail" });
    defer allocator.free(trailing);
    try testing.expectError(error.TrailingData, inspect(Br, trailing, .{}));
}
