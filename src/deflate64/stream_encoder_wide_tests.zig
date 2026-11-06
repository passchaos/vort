//! Public IncrementalEncoder contracts at cumulative-count boundaries.
//! Cross-2^32 cases use a lawful prefix model: verified identical full-flush
//! cycles are extrapolated arithmetically, followed by real bounded input and
//! real independently inspected wire. No actual 4GiB payload/tool run is claimed.
//! CounterMax cases are explicit boundary injections, not prefix evidence.
const std = @import("std");
const h = @import("stream_encoder_wide_test_helpers.zig");

fn publicTypes(comptime Encoder: type) !void {
    inline for (h.fields) |field|
        try std.testing.expectEqual(h.Count, @FieldType(Encoder, field));
    inline for (.{ "input_read", "output_written", "block_count", "fixed_block_count", "dynamic_block_count", "stored_block_count", "match_count" }) |field|
        try std.testing.expectEqual(h.Count, @FieldType(Encoder.Snapshot, field));
    try std.testing.expectEqual(?h.Count, @FieldType(Encoder, "expected_input_len"));
    try std.testing.expectEqual(h.Count, @FieldType(Encoder.Options, "max_input_len"));
    inline for (.{ "block_len", "max_pending_output_len", "max_chain" }) |field|
        try std.testing.expectEqual(usize, @FieldType(Encoder.Options, field));
    inline for (.{ "pending_offset", "max_match_length", "max_match_distance" }) |field|
        try std.testing.expectEqual(usize, @FieldType(Encoder, field));
    inline for (.{ "buffered_input", "pending_output", "history_len", "max_match_length", "max_match_distance", "retained_input_capacity", "retained_pending_capacity" }) |field|
        try std.testing.expectEqual(usize, @FieldType(Encoder.Snapshot, field));
    try std.testing.expectEqual(usize, @FieldType(h.core.Progress, "input_read"));
    try std.testing.expectEqual(usize, @FieldType(h.core.Progress, "output_written"));
}

const oracleDelta = h.oracleDelta;

fn crossing(comptime Encoder: type) !void {
    inline for (.{ .fixed, .dynamic, .stored, .adaptive }) |compression| {
        const options = Encoder.Options{ .block_len = h.prefix.len, .compression = compression };
        var evidence = try h.provePrefix(Encoder, options);
        defer evidence.deinit();
        // Every nonzero byte/block/match total is independently crossed. The
        // chosen field starts below 2^32; two real cycles carry it above 2^32.
        for (evidence.increment, 0..) |increment, crossed| {
            if (increment == 0) continue;
            const repeats = (h.boundary - 1) / increment;
            const pledge = (repeats + 2) * h.prefix.len;
            var wide_options = options;
            wide_options.max_input_len = pledge;
            var wide = Encoder.initExactSize(h.allocator, wide_options, pledge);
            defer wide.deinit();
            var local = Encoder.initWithOptions(h.allocator, options);
            defer local.deinit();
            var wire: std.ArrayList(u8) = .empty;
            defer wire.deinit(h.allocator);
            var local_wire: std.ArrayList(u8) = .empty;
            defer local_wire.deinit(h.allocator);
            try h.fullPrefix(&wide, &wire);
            try h.fullPrefix(&local, &local_wire);
            try h.repeatModel(&wide, evidence, repeats);
            const before = h.ledger(wide);
            const local_before = h.ledger(local);
            try std.testing.expect(before[crossed] < h.boundary);
            wire.clearRetainingCapacity();
            local_wire.clearRetainingCapacity();
            for (0..2) |_| {
                try h.fullPrefix(&wide, &wire);
                try h.fullPrefix(&local, &local_wire);
            }
            try std.testing.expect(h.ledger(wide)[crossed] > h.boundary);
            try h.finish(&wide, &wire, 1);
            try h.finish(&local, &local_wire, 1);
            try std.testing.expectEqualSlices(u8, local_wire.items, wire.items);
            const suffix = h.prefix ++ h.prefix;
            const physical = h.delta(before, h.ledger(wide));
            try std.testing.expectEqualDeep(h.delta(local_before, h.ledger(local)), physical);
            try oracleDelta(wire.items, suffix, physical);
            try std.testing.expectEqual(pledge, wide.snapshot().input_read);
            try std.testing.expect(wide.snapshot().done);
            inline for (h.fields, 0..) |field, index|
                try std.testing.expectEqual(evidence.increment[index] * repeats + physical[index], @field(wide, field));
            try std.testing.expectEqual(local.snapshot().max_match_length, wide.snapshot().max_match_length);
            try std.testing.expectEqual(local.snapshot().max_match_distance, wide.snapshot().max_match_distance);
        }
    }
}

const Flush = h.Flush;
const requestFlush = h.requestFlush;

fn expectReset(encoder: anytype, pledge: h.Count, input_capacity: usize, pending_capacity: usize) !void {
    const snapshot = encoder.snapshot();
    try std.testing.expectEqualDeep(@as(h.Ledger, @splat(0)), h.ledger(encoder.*));
    try std.testing.expectEqual(@as(?h.Count, pledge), encoder.expected_input_len);
    try std.testing.expectEqual(input_capacity, snapshot.retained_input_capacity);
    try std.testing.expectEqual(pending_capacity, snapshot.retained_pending_capacity);
    try std.testing.expectEqual(@as(usize, 0), snapshot.buffered_input);
    try std.testing.expectEqual(@as(usize, 0), snapshot.pending_output);
    try std.testing.expectEqual(@as(usize, 0), snapshot.history_len);
    try std.testing.expectEqual(@as(usize, 0), snapshot.max_match_length);
    try std.testing.expectEqual(@as(usize, 0), snapshot.max_match_distance);
    try std.testing.expect(!snapshot.failed and !snapshot.flushing and !snapshot.finishing and !snapshot.done);
    try std.testing.expect(encoder.failedProgress() == null);
}

fn wideFlushAndReset(comptime Encoder: type) !void {
    inline for (.{ .fixed, .dynamic }) |compression| {
        const options = Encoder.Options{ .block_len = h.prefix.len, .compression = compression };
        var evidence = try h.provePrefix(Encoder, options);
        defer evidence.deinit();
        for (std.enums.values(Flush)) |mode| {
            const repeats = (h.boundary - 1) / h.prefix.len;
            const first = h.prefix ++ h.prefix;
            const tail = "real-wide-tail-RRRRRRRRRRRR";
            const pledge = repeats * h.prefix.len + first.len + tail.len;
            var wide = Encoder.initExactSize(h.allocator, options, pledge);
            defer wide.deinit();
            var local = Encoder.initWithOptions(h.allocator, options);
            defer local.deinit();
            var wire: std.ArrayList(u8) = .empty;
            defer wire.deinit(h.allocator);
            var local_wire: std.ArrayList(u8) = .empty;
            defer local_wire.deinit(h.allocator);
            try h.fullPrefix(&wide, &wire);
            try h.fullPrefix(&local, &local_wire);
            try h.repeatModel(&wide, evidence, repeats);
            const before = h.ledger(wide);
            wire.clearRetainingCapacity();
            local_wire.clearRetainingCapacity();
            inline for (.{ &wide, &local }) |encoder| {
                const collected = if (encoder == &wide) &wire else &local_wire;
                try h.feed(encoder, first, collected, 3, 1);
                requestFlush(encoder, mode);
                try h.drain(encoder, collected, 1, false);
                const flushed = h.ledger(encoder.*);
                const bytes = collected.items.len;
                requestFlush(encoder, mode);
                try h.drain(encoder, collected, 1, false);
                try std.testing.expectEqualDeep(flushed, h.ledger(encoder.*));
                try std.testing.expectEqual(bytes, collected.items.len);
                if (mode == .full) {
                    try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().history_len);
                } else try std.testing.expect(encoder.snapshot().history_len != 0);
                try h.feed(encoder, tail, collected, 2, 1);
                try h.finish(encoder, collected, 1);
            }
            try std.testing.expectEqualSlices(u8, local_wire.items, wire.items);
            try oracleDelta(wire.items, first ++ tail, h.delta(before, h.ledger(wide)));
            try std.testing.expectEqual(pledge, wide.snapshot().input_read);
            try std.testing.expect(wide.snapshot().input_read > h.boundary);
            const snapshot = wide.snapshot();
            wide.reset();
            try expectReset(&wide, pledge, snapshot.retained_input_capacity, snapshot.retained_pending_capacity);
            wide.resetWithOptions(.{ .compression = .stored, .max_input_len = pledge + 7 });
            try expectReset(&wide, pledge, snapshot.retained_input_capacity, snapshot.retained_pending_capacity);
            try std.testing.expectEqual(pledge + 7, wide.options.max_input_len);
            wide.resetExactSize(h.boundary + 19);
            try expectReset(&wide, h.boundary + 19, snapshot.retained_input_capacity, snapshot.retained_pending_capacity);
        }
    }
}

fn widePreflight(comptime Encoder: type) !void {
    const options = Encoder.Options{ .block_len = h.prefix.len, .compression = .stored };
    var evidence = try h.provePrefix(Encoder, options);
    defer evidence.deinit();
    const repeats = (h.boundary - 1) / h.prefix.len;
    const base = repeats * h.prefix.len;
    for ([_]bool{ false, true }) |pledged| {
        var configured = options;
        configured.max_input_len = h.boundary + (if (pledged) @as(h.Count, 8) else 4);
        var encoder = if (pledged)
            Encoder.initExactSize(h.allocator, configured, h.boundary + 4)
        else
            Encoder.initWithOptions(h.allocator, configured);
        defer encoder.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(h.allocator);
        try h.fullPrefix(&encoder, &wire);
        try h.repeatModel(&encoder, evidence, repeats);
        // Automatic emission leaves genuine pending output while input is
        // permitted: the seventeenth offered byte is still unaccepted.
        _ = try h.step(&encoder, h.prefix ++ "x", &.{});
        try std.testing.expect(encoder.snapshot().pending_output != 0);
        try std.testing.expectEqual(base + h.prefix.len, encoder.total_input);
        // All five offered bytes must be checked, although a full pending
        // block would otherwise return need_output before consuming any.
        try h.atomicFailure(&encoder, if (pledged) error.SizeMismatch else error.OutputLimitExceeded, "abcde");
    }

    var short = Encoder.initExactSize(h.allocator, options, h.boundary + 4);
    defer short.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(h.allocator);
    try h.fullPrefix(&short, &wire);
    try h.repeatModel(&short, evidence, repeats);
    _ = try h.step(&short, h.prefix ++ "x", &.{});
    try std.testing.expectEqual(h.boundary, short.total_input);
    try std.testing.expect(short.snapshot().pending_output != 0);
    short.finish();
    try h.atomicFailure(&short, error.SizeMismatch, "");
    const capacity = short.snapshot();
    short.reset();
    try expectReset(&short, h.boundary + 4, capacity.retained_input_capacity, capacity.retained_pending_capacity);

    // A pledge larger than a wide cap is itself inadmissible, even for empty
    // offered input; this rejects before the first lazy allocation.
    var backing = std.testing.FailingAllocator.init(h.allocator, .{ .fail_index = 0 });
    var invalid = Encoder.initExactSize(backing.allocator(), .{ .max_input_len = h.boundary + 3 }, h.boundary + 4);
    defer invalid.deinit();
    try h.atomicFailure(&invalid, error.OutputLimitExceeded, "");
    try std.testing.expectEqual(@as(usize, 0), backing.alloc_index);
}

pub fn contracts(comptime Codec: type) !void {
    const Encoder = Codec.IncrementalEncoder;
    try publicTypes(Encoder);
    try crossing(Encoder);
    try wideFlushAndReset(Encoder);
    try widePreflight(Encoder);
    try @import("stream_encoder_wide_failure_tests.zig").contracts(Encoder);
}
