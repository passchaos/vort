//! Independent fixed/stored/dynamic token inspection and resumable encoder contracts.
//! The public decoder is imported directly, without the Deflate64 facade.
const std = @import("std");
const decoder = @import("decoder.zig");
const stored_encoder = @import("encoder.zig");
const core = @import("../core.zig");

const test_wire = @import("test_wire.zig");
const inspect = test_wire.inspect;

fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn checkedStep(encoder: anytype, input: []const u8, output: []u8) !core.StepResult {
    const before = encoder.snapshot();
    const result = encoder.step(input, output) catch |err| {
        const after = encoder.snapshot();
        const failure = encoder.failedProgress() orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(failure.input_read, after.input_read - before.input_read);
        try std.testing.expectEqual(failure.output_written, after.output_written - before.output_written);
        try std.testing.expect(failure.input_read <= input.len and failure.output_written <= output.len);
        try untouched(output[failure.output_written..]);
        return err;
    };
    const after = encoder.snapshot();
    try std.testing.expectEqual(result.progress.input_read, after.input_read - before.input_read);
    try std.testing.expectEqual(result.progress.output_written, after.output_written - before.output_written);
    try std.testing.expect(result.progress.input_read <= input.len);
    try std.testing.expect(result.progress.output_written <= output.len);
    try untouched(output[result.progress.output_written..]);
    return result;
}

fn feed(encoder: anytype, input: []const u8, input_quota: usize, output_quota: usize, wire: *std.ArrayList(u8)) !void {
    var offset: usize = 0;
    var output: [521]u8 = undefined;
    for (0..input.len * 4 + 4096) |call| {
        const end = @min(input.len, offset + input_quota);
        @memset(&output, 0xa5);
        const result = try checkedStep(encoder, input[offset..end], output[0..if (call % 11 == 0) 0 else output_quota]);
        offset += result.progress.input_read;
        try wire.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
        if (offset == input.len and result.status == .need_input) return;
    }
    return error.TestUnexpectedResult;
}

fn complete(encoder: anytype, input: []const u8, input_quota: usize, output_quota: usize) ![]u8 {
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(std.testing.allocator);
    try feed(encoder, input, input_quota, output_quota, &wire);
    encoder.finish();
    var output: [521]u8 = undefined;
    for (0..input.len * 4 + 4096) |call| {
        @memset(&output, 0xa5);
        const result = try checkedStep(encoder, "", output[0..if (call % 11 == 0) 0 else output_quota]);
        try wire.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
        if (result.status == .done) return wire.toOwnedSlice(std.testing.allocator);
    }
    return error.TestUnexpectedResult;
}

fn decodedEqual(wire: []const u8, input: []const u8) !void {
    var parsed = try inspect(wire, input.len);
    defer parsed.deinit();
    try std.testing.expectEqualSlices(u8, input, parsed.output);
    const actual = try decoder.decodeAlloc(std.testing.allocator, wire);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(u8, input, actual);
}

fn fill(bytes: []u8, seed: u32) void {
    var random = seed;
    for (bytes) |*byte| {
        random = random *% 1664525 +% 1013904223;
        byte.* = @truncate(random >> 24);
    }
}

fn roundTrips(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    const repetitive = "Deflate64 stream exact caller progress abcdefghabcdefgh\n" ** 79;
    var random: [4097]u8 = undefined;
    fill(&random, 0x243f6a88);
    inline for (.{ .adaptive, .fixed, .dynamic, .stored }) |compression| {
        for ([_][]const u8{ "", "x", "abc", "tiny", repetitive, &random }) |input| {
            var baseline = Encoder.initWithOptions(std.testing.allocator, .{ .block_len = 1024, .compression = compression });
            defer baseline.deinit();
            const expected = try complete(&baseline, input, input.len + 1, 521);
            defer std.testing.allocator.free(expected);
            try decodedEqual(expected, input);
            for ([_][2]usize{ .{ 1, 1 }, .{ 17, 5 }, .{ 511, 257 } }) |quotas| {
                var encoder = Encoder.initExactSize(std.testing.allocator, .{ .block_len = 1024, .compression = compression }, input.len);
                defer encoder.deinit();
                const actual = try complete(&encoder, input, quotas[0], quotas[1]);
                defer std.testing.allocator.free(actual);
                try std.testing.expectEqualSlices(u8, expected, actual);
                try std.testing.expectEqual(input.len, encoder.snapshot().input_read);
                try std.testing.expectEqual(actual.len, encoder.snapshot().output_written);
                try std.testing.expect(encoder.snapshot().done);
            }
        }
    }
    // Explicit stored mode at the historical 65535-byte block size preserves
    // the old no-compression wire, separately from adaptive-format behavior.
    const input = try std.testing.allocator.alloc(u8, 65536);
    defer std.testing.allocator.free(input);
    fill(input, 17);
    var encoder = Encoder.initWithOptions(std.testing.allocator, .{ .block_len = 65535, .compression = .stored });
    defer encoder.deinit();
    const actual = try complete(&encoder, input, 4096, 521);
    defer std.testing.allocator.free(actual);
    const expected = try std.testing.allocator.alloc(u8, try stored_encoder.encodedBound(input.len));
    defer std.testing.allocator.free(expected);
    _ = try stored_encoder.encodeStoredInto(input, expected);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

fn extendedTokens(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    inline for (.{ .fixed, .dynamic }) |compression| {
        const input = try std.testing.allocator.alloc(u8, 131072);
        defer std.testing.allocator.free(input);
        fill(input[0..65536], 0x243f6a88);
        @memcpy(input[65536..], input[0..65536]);
        var encoder = Encoder.initWithOptions(std.testing.allocator, .{ .compression = compression, .max_chain = 128, .nice_length = 65538 });
        defer encoder.deinit();
        const wire = try complete(&encoder, input, 4096, 521);
        defer std.testing.allocator.free(wire);
        var parsed = try inspect(wire, input.len);
        defer parsed.deinit();
        try std.testing.expectEqualSlices(u8, input, parsed.output);
        var distance_65536 = false;
        for (parsed.matches.items) |match| if (match.distance == 65536) {
            distance_65536 = true;
            try std.testing.expectEqual(@as(u16, 31), match.distance_code);
            try std.testing.expect(match.length >= 32768);
        };
        try std.testing.expect(distance_65536);

        @memset(input[0..65539], 'R');
        var long = Encoder.initWithOptions(std.testing.allocator, .{ .compression = compression });
        defer long.deinit();
        const long_wire = try complete(&long, input[0..65539], 4096, 521);
        defer std.testing.allocator.free(long_wire);
        var long_tokens = try inspect(long_wire, 65539);
        defer long_tokens.deinit();
        try std.testing.expectEqual(@as(usize, 1), long_tokens.literals);
        try std.testing.expectEqual(@as(usize, 1), long_tokens.matches.items.len);
        try std.testing.expectEqual(@as(u16, 285), long_tokens.matches.items[0].length_code);
        try std.testing.expectEqual(@as(usize, 65538), long_tokens.matches.items[0].length);
        try std.testing.expectEqual(@as(usize, 1), long_tokens.matches.items[0].distance);
        var length258 = Encoder.initWithOptions(std.testing.allocator, .{ .compression = compression });
        defer length258.deinit();
        const short_wire = try complete(&length258, input[0..259], 17, 5);
        defer std.testing.allocator.free(short_wire);
        var short_tokens = try inspect(short_wire, 259);
        defer short_tokens.deinit();
        try std.testing.expectEqual(@as(usize, 1), short_tokens.matches.items.len);
        try std.testing.expectEqual(@as(u16, 284), short_tokens.matches.items[0].length_code);
        try std.testing.expectEqual(@as(usize, 258), short_tokens.matches.items[0].length);
        var length259 = Encoder.initWithOptions(std.testing.allocator, .{ .compression = compression });
        defer length259.deinit();
        const boundary_wire = try complete(&length259, input[0..260], 17, 5);
        defer std.testing.allocator.free(boundary_wire);
        var boundary = try inspect(boundary_wire, 260);
        defer boundary.deinit();
        try std.testing.expectEqual(@as(usize, 1), boundary.matches.items.len);
        try std.testing.expectEqual(@as(u16, 285), boundary.matches.items[0].length_code);
        try std.testing.expectEqual(@as(usize, 259), boundary.matches.items[0].length);
    }
}
fn drainFlush(encoder: anytype, wire: *std.ArrayList(u8)) !void {
    var output: [521]u8 = undefined;
    for (0..8192) |_| {
        @memset(&output, 0xa5);
        const result = try checkedStep(encoder, "", output[0..5]);
        try wire.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
        if (result.status == .need_input and !encoder.snapshot().flushing) return;
    }
    return error.TestUnexpectedResult;
}

fn flushHistory(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    var input: [2048]u8 = undefined;
    fill(input[0..1024], 0x6a09e667);
    @memcpy(input[1024..], input[0..1024]);
    const Flush = enum { block, partial, sync, full };
    inline for (.{ .fixed, .dynamic }) |compression| {
        for (std.enums.values(Flush)) |mode| {
            var encoder = Encoder.initWithOptions(std.testing.allocator, .{ .compression = compression, .block_len = 1024 });
            defer encoder.deinit();
            var wire: std.ArrayList(u8) = .empty;
            defer wire.deinit(std.testing.allocator);
            try feed(&encoder, input[0..1024], 17, 5, &wire);
            switch (mode) {
                .block => encoder.blockFlush(),
                .partial => encoder.partialFlush(),
                .sync => encoder.flush(),
                .full => encoder.fullFlush(),
            }
            try drainFlush(&encoder, &wire);
            const boundary_len = wire.items.len;
            switch (mode) {
                .block => encoder.blockFlush(),
                .partial => encoder.partialFlush(),
                .sync => encoder.flush(),
                .full => encoder.fullFlush(),
            }
            try drainFlush(&encoder, &wire);
            try std.testing.expectEqual(boundary_len, wire.items.len);
            if (mode == .full) try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().history_len) else try std.testing.expect(encoder.snapshot().history_len != 0);
            const rest = try complete(&encoder, input[1024..], 17, 5);
            defer std.testing.allocator.free(rest);
            try wire.appendSlice(std.testing.allocator, rest);
            try decodedEqual(wire.items, &input);
            var parsed = try inspect(wire.items, input.len);
            defer parsed.deinit();
            var cross_history = false;
            for (parsed.matches.items) |match| {
                if (match.position == 1024 and match.distance == 1024 and match.length == 1024) cross_history = true;
            }
            try std.testing.expectEqual(mode != .full, cross_history);
            if (mode == .partial) try std.testing.expect(parsed.fixed_blocks >= (if (compression == .fixed) @as(usize, 3) else 1));
            if (mode == .sync or mode == .full) try std.testing.expect(parsed.stored_blocks != 0);
        }
        var automatic = Encoder.initWithOptions(std.testing.allocator, .{ .compression = compression, .block_len = 1024 });
        defer automatic.deinit();
        const wire = try complete(&automatic, &input, input.len, 521);
        defer std.testing.allocator.free(wire);
        var parsed = try inspect(wire, input.len);
        defer parsed.deinit();
        try std.testing.expectEqual(@as(usize, 2), if (compression == .fixed) parsed.fixed_blocks else parsed.dynamic_blocks);
        var shared = false;
        for (parsed.matches.items) |match| if (match.position == 1024 and match.distance == 1024) {
            shared = true;
        };
        try std.testing.expect(shared);
    }
}
fn dynamicModes(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    const input = "A" ** 512;
    // Each real non-final fixed block containing a single high literal is
    // nineteen bits long. Its 3-bit residue visits every q0...q7 alignment.
    for (0..8) |prefix_blocks| {
        inline for (.{ .adaptive, .dynamic }) |compression| {
            for ([_]bool{ false, true }) |final| {
                var encoder = Encoder.initWithOptions(std.testing.allocator, .{ .block_len = 1024, .compression = .fixed, .max_chain = 0 });
                defer encoder.deinit();
                var wire: std.ArrayList(u8) = .empty;
                defer wire.deinit(std.testing.allocator);
                for (0..prefix_blocks) |_| {
                    try feed(&encoder, "\xa5", 1, 5, &wire);
                    encoder.blockFlush();
                    try drainFlush(&encoder, &wire);
                }
                encoder.options.compression = compression;
                try feed(&encoder, input, 17, 5, &wire);
                if (!final) {
                    encoder.blockFlush();
                    try drainFlush(&encoder, &wire);
                    encoder.options.compression = .fixed;
                }
                const tail = try complete(&encoder, "", 1, 5);
                defer std.testing.allocator.free(tail);
                try wire.appendSlice(std.testing.allocator, tail);
                var expected: [input.len + 7]u8 = undefined;
                @memset(expected[0..prefix_blocks], 0xa5);
                @memcpy(expected[prefix_blocks..][0..input.len], input);
                var parsed = try inspect(wire.items, prefix_blocks + input.len);
                defer parsed.deinit();
                try std.testing.expectEqualSlices(u8, expected[0 .. prefix_blocks + input.len], parsed.output);
                const block = parsed.blocks.items[prefix_blocks];
                try std.testing.expectEqual(@as(u2, 2), block.kind);
                try std.testing.expectEqual(final, block.final);
                try std.testing.expectEqual((prefix_blocks * 19) % 8, block.bit_start % 8);
                const bits = block.bit_end - block.bit_start;
                const q = block.bit_start % 8;
                const fixed_bits = 10 + input.len * 8;
                const stored_bits = 3 + (8 - (q + 3) % 8) % 8 + 32 + input.len * 8;
                const own_cost = if (final) (q + bits + 7) / 8 else bits;
                const fixed_cost = if (final) (q + fixed_bits + 7) / 8 else fixed_bits;
                const stored_cost = if (final) (q + stored_bits + 7) / 8 else stored_bits;
                try std.testing.expect(own_cost < fixed_cost and own_cost < stored_cost);
                try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().dynamic_block_count);
                try std.testing.expect(block.header.?.repeat_18 != 0);
                try decodedEqual(wire.items, expected[0 .. prefix_blocks + input.len]);
            }
        }
    }
}

fn dynamicLimits(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    const input = "A" ** 513;
    var baseline = Encoder.initWithOptions(std.testing.allocator, .{ .compression = .dynamic, .max_chain = 0 });
    defer baseline.deinit();
    const expected = try complete(&baseline, input, 17, 5);
    defer std.testing.allocator.free(expected);
    var exact = Encoder.initWithOptions(std.testing.allocator, .{ .compression = .dynamic, .max_chain = 0, .max_pending_output_len = expected.len });
    defer exact.deinit();
    const actual = try complete(&exact, input, 1, 1);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(u8, expected, actual);
    var below = Encoder.initWithOptions(std.testing.allocator, .{ .compression = .dynamic, .max_chain = 0, .max_pending_output_len = expected.len - 1 });
    defer below.deinit();
    var discarded: std.ArrayList(u8) = .empty;
    defer discarded.deinit(std.testing.allocator);
    try feed(&below, input, 17, 5, &discarded);
    below.finish();
    var output: [128]u8 = undefined;
    try checkSticky(&below, error.OutputLimitExceeded, "", &output);
    try std.testing.expectEqual(@as(usize, 0), below.snapshot().dynamic_block_count);
    try std.testing.expectEqual(input.len, below.snapshot().buffered_input);
    below.resetWithOptions(.{ .compression = .dynamic, .max_chain = 0 });
    const recovered = try complete(&below, input, 17, 5);
    defer std.testing.allocator.free(recovered);
    try std.testing.expectEqualSlices(u8, expected, recovered);

    var heap = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var failing = Encoder.initWithOptions(heap.allocator(), .{ .compression = .dynamic, .max_chain = 0 });
    defer failing.deinit();
    var buffered: [1]u8 = undefined;
    @memset(&buffered, 0xa5);
    _ = try checkedStep(&failing, input, &buffered);
    failing.finish();
    heap.fail_index = heap.alloc_index;
    try checkSticky(&failing, error.OutOfMemory, "", &output);
    try std.testing.expectEqual(@as(usize, 0), failing.snapshot().dynamic_block_count);
    try std.testing.expectEqual(input.len, failing.snapshot().buffered_input);
}

fn checkSticky(encoder: anytype, expected_error: anyerror, input: []const u8, output: []u8) !void {
    @memset(output, 0xa5);
    const before = encoder.snapshot();
    try std.testing.expectError(expected_error, encoder.step(input, output));
    const after = encoder.snapshot();
    const failure = encoder.failedProgress() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(failure.input_read, after.input_read - before.input_read);
    try std.testing.expectEqual(failure.output_written, after.output_written - before.output_written);
    try std.testing.expectEqualDeep(failure, after.last_step_progress);
    try untouched(output[failure.output_written..]);
    const preserved = encoder.snapshot();
    @memset(output, 0xa5);
    try std.testing.expectError(expected_error, encoder.step("unaccepted", output));
    try std.testing.expectEqualDeep(preserved, encoder.snapshot());
    try std.testing.expectEqualDeep(@as(?core.Progress, failure), encoder.failedProgress());
    try untouched(output);
}

fn limitsAndReset(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    const a = std.testing.allocator;
    var output: [128]u8 = @splat(0xa5);
    for ([_]Encoder.Options{ .{ .block_len = 0 }, .{ .block_len = 131073 }, .{ .nice_length = 2 }, .{ .nice_length = 65539 } }) |options| {
        try std.testing.expectError(error.InvalidBlockPlan, Encoder.validateOptions(options));
        var backing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
        var invalid = Encoder.initWithOptions(backing.allocator(), options);
        defer invalid.deinit();
        try checkSticky(&invalid, error.InvalidBlockPlan, "valid input", &output);
        try std.testing.expectEqual(@as(usize, 0), backing.alloc_index);
    }
    var limited = Encoder.initWithOptions(a, .{ .max_input_len = 3 });
    defer limited.deinit();
    try checkSticky(&limited, error.OutputLimitExceeded, "four", &output);
    try std.testing.expectEqual(@as(usize, 0), limited.snapshot().input_read);
    limited.resetWithOptions(.{ .compression = .fixed, .max_chain = 0 });
    try std.testing.expect(limited.failedProgress() == null);
    const recovered = try complete(&limited, "recovered", 1, 5);
    defer a.free(recovered);
    try decodedEqual(recovered, "recovered");

    var over_pledge = Encoder.initExactSize(a, .{}, 3);
    defer over_pledge.deinit();
    try checkSticky(&over_pledge, error.SizeMismatch, "four", &output);
    try std.testing.expectEqual(@as(usize, 0), over_pledge.snapshot().input_read);
    over_pledge.resetWithOptions(.{});
    over_pledge.resetExactSize(4);
    const corrected = try complete(&over_pledge, "four", 1, 1);
    defer a.free(corrected);
    try decodedEqual(corrected, "four");
    var short = Encoder.initExactSize(a, .{}, 4);
    defer short.deinit();
    @memset(&output, 0xa5);
    _ = try checkedStep(&short, "abc", &output);
    short.finish();
    try checkSticky(&short, error.SizeMismatch, "", &output);
    var pending = Encoder.initWithOptions(a, .{ .max_pending_output_len = 0 });
    defer pending.deinit();
    @memset(&output, 0xa5);
    _ = try checkedStep(&pending, "abc", &output);
    pending.finish();
    try checkSticky(&pending, error.OutputLimitExceeded, "", &output);
    pending.reset();
    try std.testing.expect(pending.failedProgress() == null);

    var stored: [128]u8 = undefined;
    fill(&stored, 17);
    var exact_pending = Encoder.initWithOptions(a, .{ .compression = .stored, .block_len = stored.len, .max_pending_output_len = stored.len + 5 });
    defer exact_pending.deinit();
    const stored_wire = try complete(&exact_pending, &stored, 17, 5);
    defer a.free(stored_wire);
    try std.testing.expectEqual(@as(usize, stored.len + 5), stored_wire.len);
    try decodedEqual(stored_wire, &stored);
    var below_pending = Encoder.initWithOptions(a, .{ .compression = .stored, .block_len = stored.len, .max_pending_output_len = stored.len + 4 });
    defer below_pending.deinit();
    var collected: std.ArrayList(u8) = .empty;
    defer collected.deinit(a);
    try feed(&below_pending, &stored, 17, 5, &collected);
    below_pending.finish();
    try checkSticky(&below_pending, error.OutputLimitExceeded, "", &output);

    var literals_only = Encoder.initWithOptions(a, .{ .compression = .fixed, .max_chain = 0 });
    defer literals_only.deinit();
    const plain = "R" ** 513;
    const literal_wire = try complete(&literals_only, plain, 17, 5);
    defer a.free(literal_wire);
    var literal_tokens = try inspect(literal_wire, plain.len);
    defer literal_tokens.deinit();
    try std.testing.expectEqual(plain.len, literal_tokens.literals);
    try std.testing.expectEqual(@as(usize, 0), literal_tokens.matches.items.len);
}

fn allocationFailures(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    const input = "Deflate64 reusable allocation and progress fixture abcdefgh\n" ** 24;
    var baseline = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var encoder = Encoder.initWithOptions(baseline.allocator(), .{ .compression = .fixed, .block_len = 1024 });
    const wire = try complete(&encoder, input, 17, 5);
    std.testing.allocator.free(wire);
    const count = baseline.alloc_index;
    encoder.deinit();
    try std.testing.expect(count > 1);
    try std.testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
    for ([_]usize{ 0, 1, count - 1 }) |failure| {
        var backing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        var failing = Encoder.initWithOptions(backing.allocator(), .{ .compression = .fixed, .block_len = 1024 });
        var wire_bytes: std.ArrayList(u8) = .empty;
        defer wire_bytes.deinit(std.testing.allocator);
        const accepted = feed(&failing, input, 17, 5, &wire_bytes);
        if (accepted) |_| {
            failing.finish();
            var output: [128]u8 = @splat(0xa5);
            // A later real allocation can occur only while draining or
            // materializing the last block; do not invent the failure call.
            var failed = false;
            for (0..4096) |_| {
                @memset(&output, 0xa5);
                const step = failing.step("", output[0..5]);
                if (step) |result| {
                    if (result.status == .done) break;
                } else |err| {
                    try std.testing.expectEqual(error.OutOfMemory, err);
                    failed = true;
                    break;
                }
            }
            try std.testing.expect(failed);
        } else |err| try std.testing.expectEqual(error.OutOfMemory, err);
        try std.testing.expect(backing.has_induced_failure);
        const progress = failing.failedProgress() orelse return error.TestUnexpectedResult;
        const before = failing.snapshot();
        var output: [128]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutOfMemory, failing.step("ignored", &output));
        try std.testing.expectEqualDeep(before, failing.snapshot());
        try std.testing.expectEqualDeep(@as(?core.Progress, progress), failing.failedProgress());
        try untouched(&output);
        backing.fail_index = std.math.maxInt(usize);
        failing.resetWithOptions(.{ .compression = .fixed, .block_len = 1024 });
        failing.resetExactSize(9);
        const recovered = try complete(&failing, "recovered", 1, 5);
        defer std.testing.allocator.free(recovered);
        try decodedEqual(recovered, "recovered");
        failing.deinit();
        try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
    }
}

fn boundedOwnership(comptime Codec: type) !void {
    const block_len: usize = 4096;
    const blocks: usize = 1024;
    const pending_bound: usize = block_len + 14;
    var input: [block_len]u8 = undefined;
    fill(&input, 0x243f6a88);
    var backing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var encoder = Codec.Encoder.initWithOptions(backing.allocator(), .{ .block_len = block_len, .compression = .adaptive });
    errdefer encoder.deinit();
    var delivered: usize = 0;
    var warmed_allocations: usize = 0;
    var warmed_live: usize = 0;
    var output: [128]u8 = undefined;
    for (0..blocks) |block| {
        var offset: usize = 0;
        var consumed = false;
        for (0..128) |_| {
            @memset(&output, 0xa5);
            const result = try checkedStep(&encoder, input[offset..], &output);
            offset += result.progress.input_read;
            delivered += result.progress.output_written;
            const snapshot = encoder.snapshot();
            try std.testing.expect(snapshot.history_len <= 65536);
            try std.testing.expect(snapshot.buffered_input <= block_len);
            try std.testing.expect(snapshot.pending_output <= pending_bound);
            try std.testing.expect(snapshot.retained_input_capacity <= block_len);
            try std.testing.expect(snapshot.retained_pending_capacity <= pending_bound);
            if (offset == input.len and result.status == .need_input) {
                consumed = true;
                break;
            }
        }
        try std.testing.expect(consumed);
        if (block == 31) {
            warmed_allocations = backing.alloc_index;
            warmed_live = backing.allocated_bytes - backing.freed_bytes;
            try std.testing.expect(warmed_allocations > 0);
        } else if (block > 31) {
            try std.testing.expectEqual(warmed_allocations, backing.alloc_index);
            try std.testing.expectEqual(warmed_live, backing.allocated_bytes - backing.freed_bytes);
        }
    }
    encoder.finish();
    var finished = false;
    for (0..128) |_| {
        @memset(&output, 0xa5);
        const result = try checkedStep(&encoder, "", &output);
        delivered += result.progress.output_written;
        const snapshot = encoder.snapshot();
        try std.testing.expect(snapshot.history_len <= 65536);
        try std.testing.expect(snapshot.buffered_input <= block_len);
        try std.testing.expect(snapshot.pending_output <= pending_bound);
        try std.testing.expect(snapshot.retained_input_capacity <= block_len);
        try std.testing.expect(snapshot.retained_pending_capacity <= pending_bound);
        if (result.status == .done) {
            finished = true;
            break;
        }
    }
    try std.testing.expect(finished);
    try std.testing.expectEqual(@as(usize, 4 * 1024 * 1024), encoder.snapshot().input_read);
    try std.testing.expectEqual(delivered, encoder.snapshot().output_written);
    try std.testing.expect(delivered != 0);
    try std.testing.expect(encoder.snapshot().block_count >= blocks);
    try std.testing.expectEqual(warmed_allocations, backing.alloc_index);
    // This case discards already-delivered bytes to isolate encoder ownership.
    // Earlier tests independently inspect/round-trip the same codec paths.
    // There is no whole-input or wire collection allocation in this ledger.
    encoder.deinit();
    try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
}

pub fn contracts(comptime Codec: type) !void {
    try roundTrips(Codec);
    try extendedTokens(Codec);
    try dynamicModes(Codec);
    try dynamicLimits(Codec);
    try flushHistory(Codec);
    try limitsAndReset(Codec);
    try allocationFailures(Codec);
    try boundedOwnership(Codec);
}
